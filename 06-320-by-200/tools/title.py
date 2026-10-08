#!/usr/bin/env python3
# Chapter 6: draw the title picture of our computer, 320 x 200 pixels, in its
# sixteen colors: the name of the channel, a chip marked 6502, and the palette.
# It works with any palette: it picks, for each of its four colors, the closest one.
#
#   python3 tools/title.py            writes picture.bmp
#
# Everything is laid out on the grid of 8 x 8 cells, so that no cell ever needs
# more than two colors. The program checks it, and says so if one does.
import os
import sys
sys.dont_write_bytecode = True          # leave no __pycache__ folder behind
from picture import read_palette        # the sixteen colors, read from palette.hex

W, H = 320, 200

COLORS  = read_palette()
PALETTE = [(red << 16) | (green << 8) | blue for red, green, blue in COLORS]


def nearest(red, green, blue):
    """The number of the color of the palette that is closest to this one."""
    return min(range(16), key=lambda n: (COLORS[n][0] - red) ** 2
                                      + (COLORS[n][1] - green) ** 2
                                      + (COLORS[n][2] - blue) ** 2)


def named(name, red, green, blue):
    """The color that palette.hex calls by this name or, if it has none, the closest."""
    here = os.path.dirname(os.path.abspath(__file__))
    for line in open(os.path.join(here, "..", "palette.hex")):
        if line.strip().endswith(": " + name):
            return int(line.split("//")[1].split(":")[0])
    return nearest(red, green, blue)


# The four colors of the drawing, whatever the palette.
BLACK      = nearest(0, 0, 0)
WHITE      = nearest(255, 255, 255)
YELLOW     = nearest(240, 200, 70)
LIGHT_BLUE = named("light blue", 120, 170, 230)

FONT = {  # 5 x 7, one string per row
    'G': ["01110", "10001", "10000", "10111", "10001", "10001", "01110"],
    'A': ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    'T': ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    'E': ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    'B': ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    'Y': ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    '6': ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
    '5': ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    '0': ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    '2': ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    ' ': ["00000"] * 7,
}

pixels = [[BLACK] * W for _ in range(H)]

def box(x0, y0, x1, y1, color):
    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            pixels[y][x] = color

def text(s, x, y, size, color_of):
    for n, ch in enumerate(s):
        for r, row in enumerate(FONT[ch]):
            for c, bit in enumerate(row):
                if bit == '1':
                    box(x + (n * 6 + c) * size, y + r * size, x + (n * 6 + c + 1) * size, y + (r + 1) * size, color_of(n))

# The name of the channel, in blocks of 4 pixels: white, with BY in yellow.
name = "GATE BY GATE"
text(name, 16, 8, 4, lambda n: YELLOW if name[n] in "BY" and 4 < n < 7 else WHITE)

# The chip: a body of 30 cells by 9, drawn with a white line two pixels thick.
BX0, BY0, BX1, BY1 = 40, 72, 280, 144
box(BX0, BY0, BX1, BY0 + 2, WHITE); box(BX0, BY1 - 2, BX1, BY1, WHITE)
box(BX0, BY0, BX0 + 2, BY1, WHITE); box(BX1 - 2, BY0, BX1, BY1, WHITE)
# The notch on the left side, and the dot that marks pin 1.
box(BX0, 100, BX0 + 8, 102, WHITE); box(BX0, 114, BX0 + 8, 116, WHITE); box(BX0 + 6, 100, BX0 + 8, 116, WHITE)
box(52, 130, 56, 134, WHITE)

# Its name, in blocks of 8 pixels, one cell away from the outline.
text("6502", 72, 80, 8, lambda n: YELLOW)

# Twenty pins on each side, 12 pixels apart, and the tracks that leave them.
# A pin is white for its first cell, next to the body; beyond that the track
# may take another color, since it is alone in its cells.
UP   = [20, 12, 20, 16, 8, 20, 12, 16, 20, 8, 16, 20, 12, 20, 8, 16, 20, 12, 16, 20]
DOWN = [8, 16, 4, 12, 16, 8, 16, 12, 4, 16, 8, 12, 16, 4, 16, 8, 12, 16, 4, 12]
HOT_UP, HOT_DOWN = (3, 9, 15), (6, 12, 17)
for k in range(20):
    x = 46 + 12 * k
    up_color = YELLOW if k in HOT_UP else LIGHT_BLUE
    box(x, 64, x + 2, 72, WHITE)                          # the pin itself
    box(x, 64 - UP[k], x + 2, 64, up_color)               # its track
    box(x - 1, 64 - UP[k] - 3, x + 3, 64 - UP[k], up_color)   # and the pad at its end
    down_color = YELLOW if k in HOT_DOWN else LIGHT_BLUE
    box(x, 144, x + 2, 152, WHITE)
    box(x, 152, x + 2, 152 + DOWN[k], down_color)
    box(x - 1, 152 + DOWN[k], x + 3, 152 + DOWN[k] + 3, down_color)

# The sixteen colors, two cells wide each, on the two rows of cells before the last.
for n in range(16):
    box(32 + n * 16, 176, 32 + (n + 1) * 16, 192, n)

# How many cells would need more than two colors? There must be none.
bad = 0
for cy in range(25):
    for cx in range(40):
        seen = {pixels[cy * 8 + j][cx * 8 + i] for j in range(8) for i in range(8)}
        if len(seen) > 2:
            bad += 1
            print("cell", cx, cy, "needs", len(seen), "colors:", sorted(seen))
if bad:
    sys.exit("picture.bmp not written: %d cell(s) with more than two colors" % bad)

# Write a 24-bit BMP, top line first (a negative height), as in chapter 4.
def number(v, n):
    return (v & (256 ** n - 1)).to_bytes(n, 'little')
out = bytearray(b"BM" + number(54 + W * H * 3, 4) + number(0, 4) + number(54, 4) + number(40, 4)
                + number(W, 4) + number(-H, 4) + number(1, 2) + number(24, 2) + number(0, 4)
                + number(W * H * 3, 4) + number(2835, 4) + number(2835, 4) + number(0, 4) + number(0, 4))
for row in pixels:
    for p in row:
        c = PALETTE[p]
        out += bytes((c & 255, (c >> 8) & 255, c >> 16))
open(sys.argv[1] if len(sys.argv) > 1 else "picture.bmp", "wb").write(out)
