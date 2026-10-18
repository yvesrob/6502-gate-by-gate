; Chapter 20: a small program for the RAM, short enough to type into the
; monitor by hand. It writes the 95 characters of the font on the screen, from
; the space to ~, then a carriage return and a line feed, and returns: RTS
; brings us back to the monitor. It calls print through the table of jumps.
;
; Its bytes, as the listing shows them, are the two lines to type:
;
;   0300: A2 20 8A 20 FB C2 E8 E0 7F D0 F7
;   : A9 0D 20 FB C2 A9 0A 20 FB C2 60
;
; then 0300R runs it.

PRINT   = $C2FB         ; in the table: the console's print

        .segment "CODE"

        ldx #32         ; the space, the first character of the font
next:   txa
        jsr PRINT
        inx
        cpx #127        ; after ~, the last one
        bne next
        lda #13
        jsr PRINT       ; a carriage return
        lda #10
        jsr PRINT       ; and a line feed
        rts
