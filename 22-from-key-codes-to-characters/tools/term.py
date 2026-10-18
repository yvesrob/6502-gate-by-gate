#!/usr/bin/env python3
# Chapter 20: a terminal for the monitor of our computer, over the serial link
# of the board's USB-C cable. What you type goes to the board, and what the
# board says comes on your screen.
#
#   python3 tools/term.py           (make term does the same)
#
# Ctrl-C leaves. The tool sends only what the monitor uses: letters, digits,
# signs, the space, Return, Delete, Backspace and Escape. Nothing else leaves
# the Mac. In particular, Ctrl-X, then Ctrl-C, then Return would make the
# board's USB chip leave our link for a terminal of its own (Sipeed's wiki).
#
# After a Return or an Escape, the tool sends nothing more until the monitor's
# prompt, *, comes back: what you type in the meantime waits. So a pasted text
# goes one line at a time, as tools/send.py sends a program. If what you type
# comes from a file, the tool leaves once the file is done and the monitor ready.
#
# Plain Python, nothing to install. Like tools/send.py, it uses termios: macOS
# and Linux, not Windows.
import argparse, os, select, sys, termios, time, tty
from send import find_port, open_port, read_some, throw_away_old, PROMPT

# What may go to the board: Backspace, Return, Escape, the space to ~, Delete.
SENT = {8, 13, 27} | set(range(32, 128))
CTRL_C = 3


def main():
    parser = argparse.ArgumentParser(description="A terminal for the monitor of our computer.")
    parser.add_argument("--port", help="the serial port, if not the last /dev/cu.usbserial-* or /dev/ttyUSB*")
    args = parser.parse_args()

    port = find_port(args.port)
    fd = open_port(port)
    old = throw_away_old(fd)
    print("Talking to %s; Ctrl-C to leave.%s" % (port, " (%d old bytes thrown away)" % old if old else ""))
    print("Press Return for the monitor's prompt.", flush=True)

    # The keyboard, one key at a time, as it is typed: no echo of its own,
    # nothing kept until Return. The monitor does the echo.
    keyboard = sys.stdin.fileno()
    saved = termios.tcgetattr(keyboard) if os.isatty(keyboard) else None
    if saved:
        tty.setraw(keyboard)

    waiting = b""           # typed, not sent yet
    busy = False            # from a Return until the prompt comes back
    typing = True           # False once a file of keys is done
    quiet_since = time.monotonic()
    try:
        while typing or waiting or busy or time.monotonic() - quiet_since < 0.3:
            ready, _, _ = select.select([fd, keyboard] if typing else [fd], [], [], 0.05)
            if fd in ready:
                heard = read_some(fd, 0)
                os.write(sys.stdout.fileno(), heard)
                quiet_since = time.monotonic()
                if PROMPT in heard:
                    busy = False
            if typing and keyboard in ready:
                typed = os.read(keyboard, 1024)
                if not typed or CTRL_C in typed:
                    if not typed:
                        typing = False          # the end of a file
                    else:
                        break                   # Ctrl-C: leave
                typed = typed.replace(b"\r\n", b"\r").replace(b"\n", b"\r")
                waiting += bytes(c for c in typed if c in SENT)
            while waiting and not busy:
                key, waiting = waiting[:1], waiting[1:]
                os.write(fd, key)
                if key in (b"\r", b"\x1b"):     # Return or Escape: a line ends
                    busy = True
    finally:
        if saved:
            termios.tcsetattr(keyboard, termios.TCSADRAIN, saved)
        os.close(fd)
        print()


if __name__ == "__main__":
    main()
