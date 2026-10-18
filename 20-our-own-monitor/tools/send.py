#!/usr/bin/env python3
# Chapter 20: send a program to our computer, over the serial link of the
# board's USB-C cable, and let it run. The board's monitor takes it, a line at
# a time.
#
#   python3 tools/send.py build/maze.bin            send it, run it, then show
#                                                   what the computer says, until
#                                                   you press Ctrl-C
#   python3 tools/send.py build/maze.bin --show     only show the lines it would send
#
# maze.bin holds the bytes of a program for the RAM, as the linker writes them
# with ram.cfg: they go from $0300 on. The tool turns them into lines that the
# monitor understands, eight bytes to a line, in hexadecimal:
#
#   0300: A9 00 85 00 85 12 A9 E1
#
# and a last line that runs the program: 0300R. It types them as you would,
# each one followed by a Return. The monitor writes each character on the
# screen and sends it back, does the line, then writes its prompt, *. The tool
# waits for the prompt before it sends the next line. If a line comes back
# different, or the monitor answers anything but its prompt, it stops before
# the last line: the program is never run.
#
# Plain Python, nothing to install. It uses termios, which Python has on macOS
# and on Linux, not on Windows. On a Mac the board's serial port is the last
# /dev/cu.usbserial-*; on Linux it should be the last /dev/ttyUSB* (not
# tried). Close the tool (Ctrl-C) before you send a new circuit to the board:
# Sipeed's examples say the board cannot be loaded while its serial port is open.
import argparse, glob, os, select, sys, termios, time

ADDRESS = 0x0300            # where ram.cfg puts every program
PER_LINE = 8                # bytes on a line: 29 characters, and the Return
PROMPT = b"*"               # what the monitor writes when it is ready
ESCAPE = b"\x1b"


def find_port(name):
    """The serial port given, or the board's: the last one of its kind."""
    ports = sorted(glob.glob("/dev/cu.usbserial-*")) or sorted(glob.glob("/dev/ttyUSB*"))
    port = name or (ports[-1] if ports else None)
    if port is None:
        sys.exit("No serial port found: is the board plugged in?")
    return port


def open_port(name):
    """Open the serial port: 115,200 bits a second, 8 bits, no parity, one
    stop bit, and every byte passed as it is, with no changes on the way."""
    fd = os.open(name, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attributes = termios.tcgetattr(fd)
    attributes[0] = 0                                               # input: as it comes
    attributes[1] = 0                                               # output: as it goes
    attributes[2] = termios.CS8 | termios.CREAD | termios.CLOCAL    # 8 bits, receive, no modem
    attributes[3] = 0                                               # no echo, no lines
    attributes[4] = attributes[5] = termios.B115200                 # the speed, both ways
    termios.tcsetattr(fd, termios.TCSANOW, attributes)
    return fd


def read_some(fd, seconds):
    """What has come within the given seconds (perhaps nothing)."""
    ready, _, _ = select.select([fd], [], [], seconds)
    return os.read(fd, 4096) if ready else b""


def throw_away_old(fd):
    """Bytes the computer sent while nobody listened wait between the board and
    the Mac, and come all at once when the port opens: read them, and drop them."""
    old = b""
    while True:
        some = read_some(fd, 0.3)
        if not some:
            return len(old)
        old += some


def read_until_prompt(fd, seconds):
    """What comes, up to and with the monitor's prompt, waiting at most the
    given seconds; and what came after the prompt in the same read."""
    heard = b""
    end = time.monotonic() + seconds
    while PROMPT not in heard and time.monotonic() < end:
        heard += read_some(fd, end - time.monotonic())
    if PROMPT not in heard:
        return heard, b""
    at = heard.index(PROMPT) + 1
    return heard[:at], heard[at:]


def lines_for(program, address):
    """The lines of text for the bytes of a program, the last one runs it."""
    lines = []
    for start in range(0, len(program), PER_LINE):
        chunk = program[start:start + PER_LINE]
        lines.append("%04X: %s" % (address + start, " ".join("%02X" % b for b in chunk)))
    lines.append("%04XR" % address)
    return lines


def main():
    parser = argparse.ArgumentParser(description="Send a program to our computer, and run it.")
    parser.add_argument("program", help="the .bin file of a program for the RAM, linked with ram.cfg")
    parser.add_argument("--show", action="store_true", help="only print the lines, send nothing")
    parser.add_argument("--port", help="the serial port, if not the last /dev/cu.usbserial-* or /dev/ttyUSB*")
    parser.add_argument("--listen", type=float, help="listen for this many seconds, instead of until Ctrl-C")
    args = parser.parse_args()

    program = open(args.program, "rb").read()
    lines = lines_for(program, ADDRESS)
    if args.show:
        print("\n".join(lines))
        return

    fd = open_port(find_port(args.port))
    old = throw_away_old(fd)
    if old:
        print("(%d old bytes, sent before we listened, thrown away)" % old)

    # Escape first: the monitor drops any line begun by hand, shows \, and
    # writes its prompt.
    started = time.monotonic()
    os.write(fd, ESCAPE)
    heard, _ = read_until_prompt(fd, 1.0)
    if not heard.endswith(PROMPT):
        sys.exit("No answer from the board. Is it running the monitor, from chapter 20? "
                 "Press S1, and send again.")

    # Each line, then its Return. It must come back as it went, the Return as
    # a carriage return and a line feed, and then nothing but the prompt.
    for number, line in enumerate(lines[:-1], 1):
        sent = line.encode("ascii") + b"\r"
        os.write(fd, sent)
        heard, _ = read_until_prompt(fd, 1.0)
        if heard != sent + b"\n" + PROMPT:
            sys.exit("Line %d came back different, so the program was not run.\n"
                     "  sent:  %r\n  heard: %r\nPress S1, and send again." % (number, sent, heard))

    # The last line runs the program. After its echo, what comes is the
    # program's: the first of it may come in the same read as the echo.
    sent = lines[-1].encode("ascii") + b"\r"
    os.write(fd, sent)
    heard = b""
    end = time.monotonic() + 1.0
    while len(heard) < len(sent) + 1 and time.monotonic() < end:
        heard += read_some(fd, end - time.monotonic())
    echo, after = heard[:len(sent) + 1], heard[len(sent) + 1:]
    if echo != sent + b"\n":
        sys.exit("The last line came back different: sent %r, heard %r." % (sent, echo))

    print("%d bytes sent in %d lines, in %.2f s; the program runs from $%04X."
          % (len(program), len(lines) - 1, time.monotonic() - started, ADDRESS))

    # Now the program runs. Whatever it sends us, we show.
    print("What the computer says (Ctrl-C to stop):")
    try:
        end = None if args.listen is None else time.monotonic() + args.listen
        while end is None or time.monotonic() < end:
            if after:
                sys.stdout.write(after.decode("latin-1").replace("\r", ""))
                sys.stdout.flush()
            after = read_some(fd, 0.2)
    except KeyboardInterrupt:
        print()
    os.close(fd)


if __name__ == "__main__":
    main()
