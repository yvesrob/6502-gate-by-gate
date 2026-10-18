#!/usr/bin/env python3
# Chapter 19: send a program to our computer, over the serial link of the
# board's USB-C cable, and let it run.
#
#   python3 tools/send.py build/maze.bin            send it, run it, then show
#                                                   what the computer says, until
#                                                   you press Ctrl-C
#   python3 tools/send.py build/maze.bin --show     only show the lines it would send
#
# maze.bin holds the bytes of a program for the RAM, as the linker writes them
# with ram.cfg: they go from $0300 on. The tool turns them into lines of text,
# eight bytes to a line, in hexadecimal, each line with its address:
#
#   0300: A9 00 85 00 85 12 A9 E1
#
# and a last line that runs the program: 0300R. The program of the board, load.s,
# writes each character on the screen and sends it back. The tool sends a line,
# waits until the whole line has come back, the same, and only then sends the
# next one. If a line comes back different, it stops before the last line: the
# program is never run.
#
# Plain Python, nothing to install. It uses termios, which Python has on macOS
# and on Linux, not on Windows. On a Mac the board's serial port is the last
# /dev/cu.usbserial-*; on Linux it should be the last /dev/ttyUSB* (not
# tried). Close the tool (Ctrl-C) before you send a new circuit to the board:
# Sipeed's examples say the board cannot be loaded while its serial port is open.
import argparse, glob, os, select, sys, termios, time

ADDRESS = 0x0300            # where ram.cfg puts every program
PER_LINE = 8                # bytes on a line: 29 characters, and 13 and 10


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


def read_exactly(fd, count, seconds):
    """At least count bytes, unless the given seconds run out first. It may
    give more: what came in the same read as the last of them."""
    heard = b""
    end = time.monotonic() + seconds
    while len(heard) < count and time.monotonic() < end:
        heard += read_some(fd, end - time.monotonic())
    return heard


def lines_for(program, address):
    """The lines of text for the bytes of a program, the last one runs it."""
    lines = []
    for start in range(0, len(program), PER_LINE):
        chunk = program[start:start + PER_LINE]
        lines.append("%04X: %s\r\n" % (address + start, " ".join("%02X" % b for b in chunk)))
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
        sys.stdout.write("\r\n" + "".join(lines))
        return

    ports = sorted(glob.glob("/dev/cu.usbserial-*")) or sorted(glob.glob("/dev/ttyUSB*"))
    port = args.port or (ports[-1] if ports else None)
    if port is None:
        sys.exit("No serial port found: is the board plugged in?")
    fd = open_port(port)

    # Bytes the computer sent while nobody listened wait in the board's USB
    # chip, and come all at once now: throw them away.
    old = b""
    while True:
        some = read_some(fd, 0.3)
        if not some:
            break
        old += some
    if old:
        print("(%d old bytes, sent before we listened, thrown away)" % len(old))

    # A carriage return and a line feed first: if load.s is waiting, they come
    # back, and its next line begins clean.
    started = time.monotonic()
    os.write(fd, b"\r\n")
    if read_exactly(fd, 2, 1.0) != b"\r\n":
        sys.exit("No answer from the board. Is it running load.s, from chapter 19? "
                 "Press S1, and send again.")

    for number, line in enumerate(lines, 1):
        sent = line.encode("ascii")
        os.write(fd, sent)
        back = read_exactly(fd, len(sent), 1.0)
        # After the last line, the program may speak at once, and its first
        # words may come in the same read as the echo: they are kept for later.
        back, first = back[:len(sent)], back[len(sent):]
        if back != sent:
            sys.exit("Line %d came back different, so the program was not run.\n"
                     "  sent:  %r\n  heard: %r\nPress S1, and send again." % (number, sent, back))

    print("%d bytes sent in %d lines, in %.2f s; the program runs from $%04X."
          % (len(program), len(lines) - 1, time.monotonic() - started, ADDRESS))

    # Now the program runs. Whatever it sends us, we show.
    print("What the computer says (Ctrl-C to stop):")
    sys.stdout.write(first.decode("latin-1").replace("\r", ""))
    try:
        end = None if args.listen is None else time.monotonic() + args.listen
        while end is None or time.monotonic() < end:
            some = read_some(fd, 0.2)
            if some:
                sys.stdout.write(some.decode("latin-1").replace("\r", ""))
                sys.stdout.flush()
    except KeyboardInterrupt:
        print()
    os.close(fd)


main()
