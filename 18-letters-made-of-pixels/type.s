; Chapter 18: the program of the board types on the screen. It clears the
; screen and types a few lines of text, one letter at a time, then the 95
; letters of the font. Then come 48 lines of 40 letters, a line at a time.
; Each begins one letter further in the font than the line before, so the
; letters make slanting stripes. The screen fills up, and scrolls. After a
; pause on the last screen, everything starts again.
;
; The text is stored in the ROM as codes, one byte for each letter. The 95
; letters of the font and the stripes are not stored: the program works out
; their codes. Every letter on the screen is drawn by the console (console.s),
; from the font (font.s).
;
; The six LEDs count the lines. After each letter of the text and of the font,
; and after each line of stripes, the program waits, so that we can watch.
; Button S2 (NMI): no more waiting, except on the last screen. Button S1 is the
; reset: everything starts again.

LEDS    = $8000         ; a byte stored at this address appears on the LEDs

; The variables of the program, in page zero. The console has its own, from $F0.
FAST    = $00           ; 0: wait between letters and lines. Each NMI (S2) adds one
TIME    = $01           ; for wait
HERE    = $02           ; where we are in TEXT
STRIPE  = $03           ; which line of the stripes, 0 to 47

        .segment "CODE"

; The font goes first: it begins the ROM, at $C000. Then the console: its
; code goes on after the font, and its tables go into RODATA, before the text.
        .include "font.s"
        .include "console.s"

        .segment "CODE"         ; console.s ends in RODATA: back to CODE

reset:  ldx #$FF
        txs             ; S = $FF: the stack begins at $01FF, empty

; A round: an empty screen, the text, the font, the stripes, a pause.
round:  lda #0
        sta LEDS        ; no line yet
        sta FAST        ; S2 has not been pressed in this round
        sta HERE
        lda #$E6        ; light blue ink, blue paper, as in chapter 17
        jsr clear
        lda FAST
        bne typing      ; S2 was pressed: no waiting
        lda #20
        jsr wait        ; the empty screen, about half a second

; The text, one letter at a time.
typing: ldx HERE
        lda TEXT,x
        beq show        ; a 0 ends the text
        jsr type
        inc HERE
        cmp #10
        bne typing
        jsr count       ; after each line feed, one more line on the LEDs
        jmp typing

; The 95 letters of the font, one at a time, from the space to the tilde. The
; console goes on to the next row by itself when a row is full.
show:   lda #32
each:   jsr type
        clc
        adc #1
        cmp #127
        bne each
        lda #13
        jsr type
        lda #10
        jsr type
        jsr count

; The stripes: 48 lines of 40 letters, a line at a time. Line n begins with
; letter n of the font (the space is letter 0), and the next 39 letters follow:
; the last line ends with letter 86, the v.
        lda #0
        sta STRIPE
stripe: lda STRIPE
        clc
        adc #32         ; the code of letter number STRIPE
        ldx #40         ; 40 letters fill the row: the console goes on to the
across: jsr print       ; next one by itself, and scrolls when it must
        clc
        adc #1          ; the next letter of the font
        dex
        bne across      ; print gives X back: it still counts the letters
        lda FAST
        bne now         ; S2 was pressed: no waiting
        lda #8
        jsr wait        ; about a fifth of a second
now:    jsr count       ; one more line on the LEDs
        inc STRIPE
        lda STRIPE
        cmp #48
        bne stripe

        lda #80
        jsr wait        ; about two seconds on the last screen, even after S2
        jmp round

; type: print the character in A, then wait about 26 milliseconds, unless S2
; was pressed. A comes back as it was; X and Y do not.
type:   jsr print
        pha
        lda FAST
        bne quick       ; S2 was pressed: no waiting
        lda #1
        jsr wait
quick:  pla
        rts

; count: one more line on the LEDs, which can be read back.
count:  ldx LEDS
        inx
        stx LEDS
        rts

; wait: about A x 26 milliseconds, doing nothing else. (The wait from chapter 17.)
wait:   sta TIME
again:  ldx #0
        ldy #0
loop:   dex
        bne loop        ; 256 times
        dey
        bne loop        ; 256 times that
        dec TIME
        bne again
        rts

; nmi: button S2. Until the next round, no more waiting. INC changes no
; register, and RTI gives the flags back.
nmi:    inc FAST
        rti

        .segment "RODATA"

; The text: the code of each letter, 13 and 10 at the end of each line (a
; carriage return and a line feed), and a 0 at the end.
TEXT:   .byte "Our Own 6502, Gate by Gate", 13, 10
        .byte "Chapter 18: Letters Made of Pixels", 13, 10
        .byte 13, 10
        .byte "Each letter you see is eight bytes of", 13, 10
        .byte "the ROM, copied into the picture by", 13, 10
        .byte "our 6502, one line of pixels at a time.", 13, 10
        .byte "Here are the 95 characters it knows:", 13, 10
        .byte 0

        .segment "VECTORS"
        .word nmi       ; $FFFA: NMI, button S2
        .word reset     ; $FFFC: the reset, button S1, and switching on
        .word reset     ; $FFFE: IRQ and BRK, which nothing asks for here
