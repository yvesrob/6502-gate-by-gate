; Chapter 22: the Portuguese layout, which gives each key code its character.
; The codes are those of the USB, the same for every keyboard: they say where
; a key is, not what is printed on it. This table says what is printed on the
; keys of a keyboard sold in Portugal, as the layout "pt(nodeadkeys)" of
; xkeyboard-config gives it. typing.s includes layout-us.s; to use this table
; instead, include this file there.
;
; One byte for each code from 0 to 100, in three tables: the key alone, the
; key with Shift, the key with AltGr (the right Alt). 0 means that the key
; gives no character: our font has only the characters of ASCII, so the
; letters with an accent, the cedilla, the ordinals and the guillemets give
; nothing. The keys that would wait for a letter to put an accent on it give
; their sign at once: ~ and ^ for the BASIC, and ` ; the acute accent, which
; ASCII lacks, gives nothing.

PLAIN:  .byte 0, 0, 0, 0                        ; 00-03: no key; three errors
        .byte "abcdefghijklmnopqrstuvwxyz"      ; 04-1D: the letters
        .byte "1234567890"                      ; 1E-27: the digits
        .byte 13, 27, 8, 0, ' '                 ; 28-2C: Return, Escape, Backspace, Tab, the space bar
        .byte "'", 0, "+", 0, "~~", 0, 0, '\', ",.-"  ; 2D-38: no guillemet, acute, c cedilla, ordinal
        .res  19, 0                             ; 39-4B: Caps Lock, F1 to F12, and others
        .byte 127                               ; 4C: Delete
        .res  23, 0                             ; 4D-63: the arrows, the keypad
        .byte '<'                               ; 64: the key left of Z

SHIFTED:
        .byte 0, 0, 0, 0
        .byte "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        .byte "!", '"', "#$%&/()="
        .byte 13, 27, 8, 0, ' '
        .byte "?", 0, "*`^^", 0, 0, "|;:_"
        .res  19, 0
        .byte 127
        .res  23, 0
        .byte '>'

ALTGR:  .byte 0, 0, 0, 0
        .res  16, 0                             ; 04-13: a to p give nothing
        .byte '@'                               ; 14: q
        .res  9, 0                              ; 15-1D: r to z
        .byte 0, '@', 0, 0, 0, 0, "{[]}"        ; 1E-27: the digits
        .byte 13, 27, 8, 0, ' '
        .byte '\', 0, '"', "~``", 0, '^', 0, 0, 0, 0
        .res  19, 0
        .byte 127
        .res  23, 0
        .byte '\'
