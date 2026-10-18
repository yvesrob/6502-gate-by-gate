#!/usr/bin/env python3
# Chapter 7: turn the file that the linker writes into a file that Verilog can read.
#
#   python3 tools/hex.py count.bin rom.hex
#
# count.bin holds the bytes of the ROM as they are, 16,384 of them. rom.hex holds
# the same bytes as text: one byte on each line, two hexadecimal digits, the way
# the memories from chapter 6 are filled. Nothing to install: this is plain Python.
import sys

if len(sys.argv) != 3:
    sys.exit("usage: python3 tools/hex.py count.bin rom.hex")

data = open(sys.argv[1], "rb").read()

with open(sys.argv[2], "w") as out:
    for byte in data:
        out.write("%02x\n" % byte)

print("%s: %d bytes" % (sys.argv[2], len(data)))
