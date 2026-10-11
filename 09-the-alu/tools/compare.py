#!/usr/bin/env python3
# Chapter 7: compare the bytes we assembled by hand with the bytes of the assembler.
#
#   python3 tools/compare.py count-by-hand.hex build/count.bin
#
# The first file is ours: one byte on each line, and whatever follows // is a
# comment. The second is the ROM written by the linker. Our bytes must be the
# first bytes of the ROM, and everything after them must be empty (zero).
import sys

if len(sys.argv) != 3:
    sys.exit("usage: python3 tools/compare.py count-by-hand.hex build/count.bin")

by_hand = []
for line in open(sys.argv[1]):
    line = line.split("//")[0].strip()
    if line:
        by_hand.append(int(line, 16))

rom = open(sys.argv[2], "rb").read()

print("by hand: " + " ".join("%02X" % byte for byte in by_hand))
print("ca65:    " + " ".join("%02X" % byte for byte in rom[:len(by_hand)]))

errors = 0
for place, byte in enumerate(by_hand):
    if rom[place] != byte:
        print("wrong: byte %d is %02X by hand and %02X for ca65" % (place, byte, rom[place]))
        errors += 1

extra = sum(1 for byte in rom[len(by_hand):] if byte != 0)
if extra:
    print("wrong: the ROM holds %d more byte(s) that are not zero" % extra)
    errors += 1

if errors:
    sys.exit("FAIL: the two programs differ")
print("PASS: the %d bytes assembled by hand are the %d bytes of ca65" % (len(by_hand), len(by_hand)))
