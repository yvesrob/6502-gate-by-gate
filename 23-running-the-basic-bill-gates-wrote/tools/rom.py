#!/usr/bin/env python3
# Chapter 23: the ROM is the monitor's, with Microsoft's BASIC laid in at its
# own address. Then, as tools/hex.py does, one byte on each line of rom.hex.
#
#   python3 tools/rom.py build/monitor.bin build/basic.bin D000 rom.hex
#
# monitor.bin holds the 16,384 bytes of the ROM, from $C000: the monitor, then
# zeros, then the vectors. basic.bin holds only the BASIC's bytes, from $D000
# (basic.cfg). The tool stops if the BASIC would land on a byte that is not a
# zero, or on the vectors. Nothing to install: this is plain Python.
import sys

if len(sys.argv) != 5:
    sys.exit("usage: python3 tools/rom.py monitor.bin basic.bin D000 rom.hex")

rom = bytearray(open(sys.argv[1], "rb").read())
basic = open(sys.argv[2], "rb").read()
start = int(sys.argv[3], 16) - 0xC000       # where the BASIC goes, in the file
end = start + len(basic)

if len(rom) != 16384:
    sys.exit("%s: %d bytes, not 16,384" % (sys.argv[1], len(rom)))
if start < 0 or end > 0xFFFA - 0xC000:
    sys.exit("the BASIC, $%04X to $%04X, does not fit below the vectors" % (start + 0xC000, end - 1 + 0xC000))
if any(rom[start:end]):
    sys.exit("the monitor already uses some of $%04X to $%04X" % (start + 0xC000, end - 1 + 0xC000))

rom[start:end] = basic

with open(sys.argv[4], "w") as out:
    for byte in rom:
        out.write("%02x\n" % byte)

print("%s: %d bytes, the BASIC from $%04X to $%04X" % (sys.argv[4], len(rom), start + 0xC000, end - 1 + 0xC000))
