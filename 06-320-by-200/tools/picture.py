#!/usr/bin/env python3
# Chapter 6: turn a picture into the two files that fill the memories of the display.
#
#   python3 tools/picture.py picture.bmp            writes bitmap.hex and colors.hex
#   python3 tools/picture.py picture.bmp --strip    the same, plus the sixteen colors
#                                                   of the palette along the bottom
#
# The picture must be a BMP file of 320 x 200 pixels, not compressed, with 24 bits
# for each pixel (32 is accepted too). Nothing to install: this is plain Python.
#
# The screen of our computer is made of 40 x 25 cells of 8 x 8 pixels. In one cell
# there can only be two colors, the ink and the paper, taken from the sixteen of
# the palette. So for each cell this program tries every pair of colors, and keeps
# the pair that changes the picture the least.
import os
import re
import struct
import sys

WIDTH, HEIGHT = 320, 200        # the picture, in pixels
COLUMNS, ROWS = 40, 25          # the same picture, in cells of 8 x 8


def read_palette():
    """The sixteen colors. They are written in one place only, palette.hex, and read from there."""
    here = os.path.dirname(os.path.abspath(__file__))
    colors = []
    for line in open(os.path.join(here, "..", "palette.hex")):
        line = line.split("//")[0].strip()          # what follows // is a comment
        if line:
            colors.append((int(line[0:2], 16), int(line[2:4], 16), int(line[4:6], 16)))
    if len(colors) != 16:
        sys.exit("palette.hex: expected sixteen colors, found %d" % len(colors))
    return colors


def read_bmp(name):
    """The picture, as HEIGHT lines of WIDTH pixels (red, green, blue), top line first."""
    data = open(name, "rb").read()
    if data[0:2] != b"BM":
        sys.exit(name + ": not a BMP file")
    start = struct.unpack_from("<I", data, 10)[0]               # where the pixels begin
    width, height = struct.unpack_from("<ii", data, 18)
    bits, compression = struct.unpack_from("<HI", data, 28)
    if (width, abs(height)) != (WIDTH, HEIGHT):
        sys.exit("%s: the picture is %d x %d, it must be %d x %d"
                 % (name, width, abs(height), WIDTH, HEIGHT))
    if bits not in (24, 32) or compression not in (0, 3):
        sys.exit(name + ": the picture must have 24 bits for each pixel, not compressed")
    size = bits // 8                                            # bytes for one pixel
    line_size = (width * size + 3) // 4 * 4                     # a line is padded to 4 bytes
    lines = []
    for y in range(HEIGHT):
        # A BMP file lists its lines from the bottom up, unless its height is negative.
        line = y if height < 0 else HEIGHT - 1 - y
        at = start + line * line_size
        lines.append([(data[at + x * size + 2], data[at + x * size + 1], data[at + x * size])
                      for x in range(WIDTH)])
    return lines


def distance(a, b):
    """How far two colors are from each other."""
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def convert_cell(pixels, palette):
    """The 64 pixels of one cell, top line first. Gives the 8 bytes of the cell and its color byte."""
    # How far each pixel is from each of the sixteen colors.
    far = [[distance(pixel, color) for color in palette] for pixel in pixels]
    best = None
    for first in range(16):
        for second in range(first, 16):
            # With these two colors, every pixel takes the nearer one.
            error = sum(min(f[first], f[second]) for f in far)
            if best is None or error < best[0]:
                best = (error, first, second)
    error, first, second = best
    # The paper is the color that covers the most pixels, the ink is the other one.
    on_second = [f[second] < f[first] for f in far]
    if sum(on_second) > 32:
        paper, ink = second, first
        is_ink = [not s for s in on_second]
    else:
        paper, ink = first, second
        is_ink = on_second
    rows = []
    for y in range(8):
        byte = 0
        for x in range(8):
            if is_ink[y * 8 + x]:
                byte |= 0x80 >> x           # bit 7 is the pixel on the left
        rows.append(byte)
    return rows, (ink << 4) | paper         # the ink in the four high bits


def main():
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(names) != 1:
        sys.exit("usage: python3 tools/picture.py picture.bmp [--strip]")
    palette = read_palette()
    lines = read_bmp(names[0])

    bitmap = [0] * (WIDTH // 8 * HEIGHT)    # 8,000 bytes: 40 for each line of pixels
    colors = [0] * (COLUMNS * ROWS)         # 1,000 bytes: one for each cell
    for row in range(ROWS):
        for column in range(COLUMNS):
            pixels = [lines[row * 8 + y][column * 8 + x] for y in range(8) for x in range(8)]
            rows, color = convert_cell(pixels, palette)
            for y in range(8):
                bitmap[(row * 8 + y) * 40 + column] = rows[y]
            colors[row * 40 + column] = color

    if "--strip" in sys.argv:
        # The sixteen colors along the bottom: three rows of cells high,
        # two cells wide for each color, in the middle of the 40 columns.
        for row in range(ROWS - 3, ROWS):
            for number in range(16):
                for column in (4 + 2 * number, 5 + 2 * number):
                    for y in range(8):
                        bitmap[(row * 8 + y) * 40 + column] = 0x00      # nothing but paper
                    colors[row * 40 + column] = (number << 4) | number

    # One byte on each line, two hexadecimal digits: what $readmemh expects.
    with open("bitmap.hex", "w") as f:
        f.write("".join("%02x\n" % byte for byte in bitmap))
    with open("colors.hex", "w") as f:
        f.write("".join("%02x\n" % byte for byte in colors))
    print("bitmap.hex: %d bytes, colors.hex: %d bytes" % (len(bitmap), len(colors)))


if __name__ == "__main__":
    main()
