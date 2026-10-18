; Chapter 22: the US layout, which gives each key code its character. The
; codes are those of the USB, the same for every keyboard: they say where a
; key is, not what is printed on it. This table says what is printed on the
; keys of a keyboard sold in the United States: the names of the codes in the
; USB's HID Usage Tables give the same two characters, such as "Keyboard 1
; and !". typing.s includes it; for another keyboard, include another table.
;
; One byte for each code from 0 to 100, in three tables: the key alone, the
; key with Shift, the key with AltGr (the right Alt). 0 means that the key
; gives no character. A US keyboard has no AltGr: its right Alt is only an
; Alt, and the key gives what it gives alone.

PLAIN:  .byte 0, 0, 0, 0                        ; 00-03: no key; three errors
        .byte "abcdefghijklmnopqrstuvwxyz"      ; 04-1D: the letters
        .byte "1234567890"                      ; 1E-27: the digits
        .byte 13, 27, 8, 0, ' '                 ; 28-2C: Return, Escape, Backspace, Tab, the space bar
        .byte "-=[]", '\', '\', ";'`,./"        ; 2D-38: 32 is a key of other countries; we give it 31's
        .res  19, 0                             ; 39-4B: Caps Lock, F1 to F12, and others
        .byte 127                               ; 4C: Delete
        .res  23, 0                             ; 4D-63: the arrows, the keypad
        .byte '<'                               ; 64: a key that keyboards of other countries have

SHIFTED:
        .byte 0, 0, 0, 0
        .byte "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        .byte "!@#$%^&*()"
        .byte 13, 27, 8, 0, ' '
        .byte "_+{}||:", '"', "~<>?"
        .res  19, 0
        .byte 127
        .res  23, 0
        .byte '>'

ALTGR   = PLAIN
