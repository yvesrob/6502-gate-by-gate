#!/usr/bin/env python3
# Chapter 23: a terminal for our computer, over the serial link of the board's
# USB-C cable: for the monitor, and for Microsoft's BASIC. What you type goes
# to the board, and what the board says comes on your screen. In chapter 20 it
# waited for the monitor's prompt; the BASIC has none, so it now waits as the
# test benches' Mac does (mac.v).
#
#   python3 tools/term.py           (make term does the same)
#   python3 tools/term.py < hello.bas   types a file, then leaves
#
# Ctrl-C leaves. The tool sends only what the monitor and the BASIC use:
# letters, digits, signs, the space, Return, Delete, Backspace and Escape.
# Nothing else leaves the Mac. In particular, Ctrl-X, then Ctrl-C, then Return
# would make the board's USB chip leave our link for a terminal of its own
# (Sipeed's wiki).
#
# The computer keeps only one key while it is busy, so the tool never sends a
# key before the one before has been read. Within a line, a key goes when the
# one before has come back. After a Return or an Escape, nothing goes until
# the line feed has come back, and then the computer says that it is ready:
# the monitor's prompt, * at the start of a line; the BASIC's OK; or a
# question mark and a space, as in MEMORY SIZE?. A line that begins with a
# digit, or ends with Escape, may get no such answer, since the BASIC keeps it,
# or drops it, and says nothing more: after such a line, a tenth of a second
# of silence will do. If nothing at all comes back for a second, the next key
# goes anyway. So a pasted text, or a file, goes a key at a time.
#
# Plain Python, nothing to install. Like tools/send.py, it uses termios: macOS
# and Linux, not Windows.
import argparse, os, select, sys, termios, time, tty
from send import find_port, open_port, read_some, throw_away_old

# What may go to the board: Backspace, Return, Escape, the space to ~, Delete.
SENT = {8, 13, 27} | set(range(32, 128))
CTRL_C = 3
PATIENCE = 1.0      # seconds without an answer, after which the next key goes anyway
QUIET = 0.1         # the silence that will do after a line that may get no answer


def ready(heard):
    """Does what came back since the end of a line say that the computer waits for the next one?"""
    return heard.endswith(b"\n*") or heard.endswith(b"OK\r\n") or heard.endswith(b"? ")


def main():
    parser = argparse.ArgumentParser(description="A terminal for our computer: its monitor, and the BASIC.")
    parser.add_argument("--port", help="the serial port, if not the last /dev/cu.usbserial-* or /dev/ttyUSB*")
    args = parser.parse_args()

    port = find_port(args.port)
    fd = open_port(port)
    old = throw_away_old(fd)
    print("Talking to %s; Ctrl-C to leave.%s" % (port, " (%d old bytes thrown away)" % old if old else ""))
    print("Press Return for the monitor's prompt.", flush=True)

    # The keyboard, one key at a time, as it is typed: no echo of its own,
    # nothing kept until Return. The computer does the echo.
    keyboard = sys.stdin.fileno()
    saved = termios.tcgetattr(keyboard) if os.isatty(keyboard) else None
    if saved:
        tty.setraw(keyboard)

    waiting = b""           # typed, not sent yet
    sent = None             # the last key sent, until the computer is ready for the next
    since = b""             # what came back since then
    numbered = False        # the line being typed began with a digit
    new_line = True
    typing = True           # False once a file of keys is done
    quiet_since = time.monotonic()
    try:
        while typing or waiting or sent is not None or time.monotonic() - quiet_since < 0.3:
            ready_to_read, _, _ = select.select([fd, keyboard] if typing else [fd], [], [], 0.05)
            if fd in ready_to_read:
                heard = read_some(fd, 0)
                os.write(sys.stdout.fileno(), heard)
                quiet_since = time.monotonic()
                since += heard
            if typing and keyboard in ready_to_read:
                typed = os.read(keyboard, 1024)
                if not typed or CTRL_C in typed:
                    if not typed:
                        typing = False          # the end of a file
                    else:
                        break                   # Ctrl-C: leave
                typed = typed.replace(b"\r\n", b"\r").replace(b"\n", b"\r")
                waiting += bytes(c for c in typed if c in SENT)
            # Is the computer ready for the next key?
            if sent is not None:
                silent = time.monotonic() - quiet_since
                if sent not in b"\r\x1b":
                    done = since != b""                         # the key came back
                else:
                    done = b"\n" in since and (ready(since) or ((sent == b"\x1b" or numbered) and silent > QUIET))
                if done or silent > PATIENCE:
                    sent = None
            if waiting and sent is None:
                sent, waiting = waiting[:1], waiting[1:]
                if new_line:
                    numbered = sent.isdigit()
                new_line = sent in b"\r\x1b"
                since = b""
                quiet_since = time.monotonic()
                os.write(fd, sent)
    finally:
        if saved:
            termios.tcsetattr(keyboard, termios.TCSADRAIN, saved)
        os.close(fd)
        print()


if __name__ == "__main__":
    main()
