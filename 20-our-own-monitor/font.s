; Chapter 18: the font. The 95 characters of ASCII that can be printed, from
; the space (32) to the tilde (126), in that order: eight bytes each, one for
; each line of pixels, from the top. As in the picture, bit 7 is the pixel on
; the left, and a 1 is a pixel in the ink. A letter uses the five columns from
; bit 6 to bit 2 and the seven lines from the top; the eighth line is for what
; goes below the line, as in g, p or y. Read the ones: they draw the letter.
;
; The letter for the code C begins at FONT + 8 x (C - 32).

FONT:
; 32: the space
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
; 33: !
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00000000
        .byte %00010000
        .byte %00000000
; 34: quotation mark
        .byte %00101000
        .byte %00101000
        .byte %00101000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
; 35: #
        .byte %00101000
        .byte %00101000
        .byte %01111100
        .byte %00101000
        .byte %01111100
        .byte %00101000
        .byte %00101000
        .byte %00000000
; 36: $
        .byte %00010000
        .byte %00111100
        .byte %01010000
        .byte %00111000
        .byte %00010100
        .byte %01111000
        .byte %00010000
        .byte %00000000
; 37: %
        .byte %01100000
        .byte %01100100
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %01001100
        .byte %00001100
        .byte %00000000
; 38: &
        .byte %00110000
        .byte %01001000
        .byte %01010000
        .byte %00100000
        .byte %01010100
        .byte %01001000
        .byte %00110100
        .byte %00000000
; 39: apostrophe
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
; 40: (
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %00100000
        .byte %00100000
        .byte %00010000
        .byte %00001000
        .byte %00000000
; 41: )
        .byte %00100000
        .byte %00010000
        .byte %00001000
        .byte %00001000
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %00000000
; 42: *
        .byte %00000000
        .byte %00010000
        .byte %01010100
        .byte %00111000
        .byte %01010100
        .byte %00010000
        .byte %00000000
        .byte %00000000
; 43: +
        .byte %00000000
        .byte %00010000
        .byte %00010000
        .byte %01111100
        .byte %00010000
        .byte %00010000
        .byte %00000000
        .byte %00000000
; 44: ,
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00010000
        .byte %00010000
        .byte %00100000
; 45: -
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %01111100
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
; 46: .
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00010000
        .byte %00000000
; 47: /
        .byte %00000000
        .byte %00000100
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %01000000
        .byte %00000000
        .byte %00000000
; 48: 0
        .byte %00111000
        .byte %01000100
        .byte %01001100
        .byte %01010100
        .byte %01100100
        .byte %01000100
        .byte %00111000
        .byte %00000000
; 49: 1
        .byte %00010000
        .byte %00110000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00111000
        .byte %00000000
; 50: 2
        .byte %00111000
        .byte %01000100
        .byte %00000100
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %01111100
        .byte %00000000
; 51: 3
        .byte %00111000
        .byte %01000100
        .byte %00000100
        .byte %00011000
        .byte %00000100
        .byte %01000100
        .byte %00111000
        .byte %00000000
; 52: 4
        .byte %00001000
        .byte %00011000
        .byte %00101000
        .byte %01001000
        .byte %01111100
        .byte %00001000
        .byte %00001000
        .byte %00000000
; 53: 5
        .byte %01111100
        .byte %01000000
        .byte %01111000
        .byte %00000100
        .byte %00000100
        .byte %01000100
        .byte %00111000
        .byte %00000000
; 54: 6
        .byte %00011000
        .byte %00100000
        .byte %01000000
        .byte %01111000
        .byte %01000100
        .byte %01000100
        .byte %00111000
        .byte %00000000
; 55: 7
        .byte %01111100
        .byte %00000100
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %00100000
        .byte %00100000
        .byte %00000000
; 56: 8
        .byte %00111000
        .byte %01000100
        .byte %01000100
        .byte %00111000
        .byte %01000100
        .byte %01000100
        .byte %00111000
        .byte %00000000
; 57: 9
        .byte %00111000
        .byte %01000100
        .byte %01000100
        .byte %00111100
        .byte %00000100
        .byte %00001000
        .byte %00110000
        .byte %00000000
; 58: :
        .byte %00000000
        .byte %00000000
        .byte %00010000
        .byte %00000000
        .byte %00000000
        .byte %00010000
        .byte %00000000
        .byte %00000000
; 59: ;
        .byte %00000000
        .byte %00000000
        .byte %00010000
        .byte %00000000
        .byte %00000000
        .byte %00010000
        .byte %00010000
        .byte %00100000
; 60: <
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %01000000
        .byte %00100000
        .byte %00010000
        .byte %00001000
        .byte %00000000
; 61: =
        .byte %00000000
        .byte %00000000
        .byte %01111100
        .byte %00000000
        .byte %01111100
        .byte %00000000
        .byte %00000000
        .byte %00000000
; 62: >
        .byte %00100000
        .byte %00010000
        .byte %00001000
        .byte %00000100
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %00000000
; 63: ?
        .byte %00111000
        .byte %01000100
        .byte %00000100
        .byte %00001000
        .byte %00010000
        .byte %00000000
        .byte %00010000
        .byte %00000000
; 64: @
        .byte %00111000
        .byte %01000100
        .byte %01011100
        .byte %01010100
        .byte %01011100
        .byte %01000000
        .byte %00111000
        .byte %00000000
; 65: A
        .byte %00111000
        .byte %01000100
        .byte %01000100
        .byte %01111100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00000000
; 66: B
        .byte %01111000
        .byte %01000100
        .byte %01000100
        .byte %01111000
        .byte %01000100
        .byte %01000100
        .byte %01111000
        .byte %00000000
; 67: C
        .byte %00111000
        .byte %01000100
        .byte %01000000
        .byte %01000000
        .byte %01000000
        .byte %01000100
        .byte %00111000
        .byte %00000000
; 68: D
        .byte %01111000
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01111000
        .byte %00000000
; 69: E
        .byte %01111100
        .byte %01000000
        .byte %01000000
        .byte %01111000
        .byte %01000000
        .byte %01000000
        .byte %01111100
        .byte %00000000
; 70: F
        .byte %01111100
        .byte %01000000
        .byte %01000000
        .byte %01111000
        .byte %01000000
        .byte %01000000
        .byte %01000000
        .byte %00000000
; 71: G
        .byte %00111000
        .byte %01000100
        .byte %01000000
        .byte %01011100
        .byte %01000100
        .byte %01000100
        .byte %00111100
        .byte %00000000
; 72: H
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01111100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00000000
; 73: I
        .byte %00111000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00111000
        .byte %00000000
; 74: J
        .byte %00011100
        .byte %00001000
        .byte %00001000
        .byte %00001000
        .byte %00001000
        .byte %01001000
        .byte %00110000
        .byte %00000000
; 75: K
        .byte %01000100
        .byte %01001000
        .byte %01010000
        .byte %01100000
        .byte %01010000
        .byte %01001000
        .byte %01000100
        .byte %00000000
; 76: L
        .byte %01000000
        .byte %01000000
        .byte %01000000
        .byte %01000000
        .byte %01000000
        .byte %01000000
        .byte %01111100
        .byte %00000000
; 77: M
        .byte %01000100
        .byte %01101100
        .byte %01010100
        .byte %01010100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00000000
; 78: N
        .byte %01000100
        .byte %01000100
        .byte %01100100
        .byte %01010100
        .byte %01001100
        .byte %01000100
        .byte %01000100
        .byte %00000000
; 79: O
        .byte %00111000
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00111000
        .byte %00000000
; 80: P
        .byte %01111000
        .byte %01000100
        .byte %01000100
        .byte %01111000
        .byte %01000000
        .byte %01000000
        .byte %01000000
        .byte %00000000
; 81: Q
        .byte %00111000
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01010100
        .byte %01001000
        .byte %00110100
        .byte %00000000
; 82: R
        .byte %01111000
        .byte %01000100
        .byte %01000100
        .byte %01111000
        .byte %01010000
        .byte %01001000
        .byte %01000100
        .byte %00000000
; 83: S
        .byte %00111000
        .byte %01000100
        .byte %01000000
        .byte %00111000
        .byte %00000100
        .byte %01000100
        .byte %00111000
        .byte %00000000
; 84: T
        .byte %01111100
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00000000
; 85: U
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00111000
        .byte %00000000
; 86: V
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00101000
        .byte %00010000
        .byte %00000000
; 87: W
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01010100
        .byte %01010100
        .byte %01010100
        .byte %00101000
        .byte %00000000
; 88: X
        .byte %01000100
        .byte %01000100
        .byte %00101000
        .byte %00010000
        .byte %00101000
        .byte %01000100
        .byte %01000100
        .byte %00000000
; 89: Y
        .byte %01000100
        .byte %01000100
        .byte %00101000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00000000
; 90: Z
        .byte %01111100
        .byte %00000100
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %01000000
        .byte %01111100
        .byte %00000000
; 91: [
        .byte %00111000
        .byte %00100000
        .byte %00100000
        .byte %00100000
        .byte %00100000
        .byte %00100000
        .byte %00111000
        .byte %00000000
; 92: backslash
        .byte %00000000
        .byte %01000000
        .byte %00100000
        .byte %00010000
        .byte %00001000
        .byte %00000100
        .byte %00000000
        .byte %00000000
; 93: ]
        .byte %00111000
        .byte %00001000
        .byte %00001000
        .byte %00001000
        .byte %00001000
        .byte %00001000
        .byte %00111000
        .byte %00000000
; 94: ^
        .byte %00010000
        .byte %00101000
        .byte %01000100
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
; 95: _
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %01111100
; 96: grave accent
        .byte %00100000
        .byte %00010000
        .byte %00001000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
        .byte %00000000
; 97: a
        .byte %00000000
        .byte %00000000
        .byte %00111000
        .byte %00000100
        .byte %00111100
        .byte %01000100
        .byte %00111100
        .byte %00000000
; 98: b
        .byte %01000000
        .byte %01000000
        .byte %01111000
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01111000
        .byte %00000000
; 99: c
        .byte %00000000
        .byte %00000000
        .byte %00111100
        .byte %01000000
        .byte %01000000
        .byte %01000000
        .byte %00111100
        .byte %00000000
; 100: d
        .byte %00000100
        .byte %00000100
        .byte %00111100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00111100
        .byte %00000000
; 101: e
        .byte %00000000
        .byte %00000000
        .byte %00111000
        .byte %01000100
        .byte %01111100
        .byte %01000000
        .byte %00111000
        .byte %00000000
; 102: f
        .byte %00011000
        .byte %00100000
        .byte %00100000
        .byte %01111000
        .byte %00100000
        .byte %00100000
        .byte %00100000
        .byte %00000000
; 103: g
        .byte %00000000
        .byte %00000000
        .byte %00111100
        .byte %01000100
        .byte %01000100
        .byte %00111100
        .byte %00000100
        .byte %00111000
; 104: h
        .byte %01000000
        .byte %01000000
        .byte %01111000
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00000000
; 105: i
        .byte %00010000
        .byte %00000000
        .byte %00110000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00111000
        .byte %00000000
; 106: j
        .byte %00001000
        .byte %00000000
        .byte %00011000
        .byte %00001000
        .byte %00001000
        .byte %00001000
        .byte %01001000
        .byte %00110000
; 107: k
        .byte %01000000
        .byte %01000000
        .byte %01001000
        .byte %01010000
        .byte %01100000
        .byte %01010000
        .byte %01001000
        .byte %00000000
; 108: l
        .byte %00110000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00111000
        .byte %00000000
; 109: m
        .byte %00000000
        .byte %00000000
        .byte %01101000
        .byte %01010100
        .byte %01010100
        .byte %01010100
        .byte %01000100
        .byte %00000000
; 110: n
        .byte %00000000
        .byte %00000000
        .byte %01111000
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00000000
; 111: o
        .byte %00000000
        .byte %00000000
        .byte %00111000
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00111000
        .byte %00000000
; 112: p
        .byte %00000000
        .byte %00000000
        .byte %01111000
        .byte %01000100
        .byte %01000100
        .byte %01111000
        .byte %01000000
        .byte %01000000
; 113: q
        .byte %00000000
        .byte %00000000
        .byte %00111100
        .byte %01000100
        .byte %01000100
        .byte %00111100
        .byte %00000100
        .byte %00000100
; 114: r
        .byte %00000000
        .byte %00000000
        .byte %01011000
        .byte %01100100
        .byte %01000000
        .byte %01000000
        .byte %01000000
        .byte %00000000
; 115: s
        .byte %00000000
        .byte %00000000
        .byte %00111100
        .byte %01000000
        .byte %00111000
        .byte %00000100
        .byte %01111000
        .byte %00000000
; 116: t
        .byte %00100000
        .byte %00100000
        .byte %01111000
        .byte %00100000
        .byte %00100000
        .byte %00100100
        .byte %00011000
        .byte %00000000
; 117: u
        .byte %00000000
        .byte %00000000
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %01001100
        .byte %00110100
        .byte %00000000
; 118: v
        .byte %00000000
        .byte %00000000
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00101000
        .byte %00010000
        .byte %00000000
; 119: w
        .byte %00000000
        .byte %00000000
        .byte %01000100
        .byte %01000100
        .byte %01010100
        .byte %01010100
        .byte %00101000
        .byte %00000000
; 120: x
        .byte %00000000
        .byte %00000000
        .byte %01000100
        .byte %00101000
        .byte %00010000
        .byte %00101000
        .byte %01000100
        .byte %00000000
; 121: y
        .byte %00000000
        .byte %00000000
        .byte %01000100
        .byte %01000100
        .byte %01000100
        .byte %00111100
        .byte %00000100
        .byte %00111000
; 122: z
        .byte %00000000
        .byte %00000000
        .byte %01111100
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %01111100
        .byte %00000000
; 123: {
        .byte %00001100
        .byte %00010000
        .byte %00010000
        .byte %00100000
        .byte %00010000
        .byte %00010000
        .byte %00001100
        .byte %00000000
; 124: |
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00010000
        .byte %00000000
; 125: }
        .byte %01100000
        .byte %00010000
        .byte %00010000
        .byte %00001000
        .byte %00010000
        .byte %00010000
        .byte %01100000
        .byte %00000000
; 126: ~
        .byte %00000000
        .byte %00000000
        .byte %00100000
        .byte %01010100
        .byte %00001000
        .byte %00000000
        .byte %00000000
        .byte %00000000
