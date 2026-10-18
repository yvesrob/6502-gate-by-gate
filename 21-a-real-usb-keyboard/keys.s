; Chapter 21: the program of the board shows what the keyboard says. Each time
; the keyboard's report changes, it writes a line: the report's eight bytes,
; in hexadecimal. Press Q and the line says 00 00 14 00 00 00 00 00: no
; modifier key, then 14, the code of the key Q. Let it go, and a line of
; zeros says that no key is down. A report that is the same as the last one
; written adds nothing, and gets no line. These are the codes of keys: the
; machine does not know letters yet.
;
; If report had to skip bytes that began no frame, a line says so first, with
; the count so far, in hexadecimal: Bytes skipped: 05. We had lost our place
; in the frames, or the module sent something we do not know.
;
; The LEDs show the first byte of the report, the modifier keys: LED 1 is the
; left Control, LED 2 the left Shift, LED 3 the left Alt, LED 4 the left GUI
; key (the Windows key, or the Apple key of a Mac), LED 5 and LED 6 the right
; Control and the right Shift. The right Alt and GUI keys, bits 6 and 7, have
; no LED.
;
; Everything written on the screen also goes to the Mac, on the serial link
; from chapter 19. Button S1 is the reset: the screen is cleared, and we start
; again. Button S2 (NMI) does nothing.

LEDS    = $8000         ; a byte stored at this address appears on the LEDs

; The program's variables, in page zero.
SHOWN   = $10           ; the report on the last line, eight bytes
LOST    = $18           ; SKIPPED, as the last line about it said

        .segment "CODE"

; The font begins the ROM, at $C000, as in chapter 18.
        .include "font.s"

; The table of jumps from chapter 19, just after the font: a program sent by
; the Mac calls the console and the serial link here, at addresses that stay.
        .assert * = $C2F8, error, "the table of jumps must begin at $C2F8"
        jmp clear       ; $C2F8
        jmp print       ; $C2FB
        jmp receive     ; $C2FE
        jmp send        ; $C301

        .include "console.s"
        .include "serial.s"
        .include "keyboard.s"

        .segment "CODE"         ; console.s ends in RODATA: back to CODE

reset:  ldx #$FF
        txs             ; S = $FF: the stack begins at $01FF, empty
        lda #0
        sta LEDS
        sta SKIPPED
        sta LOST
        ldx #7
forget: sta SHOWN,x     ; no key down yet: a line of zeros is no news
        dex
        bpl forget
        lda #$E6        ; light blue ink, blue paper, as in chapters 17 to 19
        jsr clear
        ldx #0
title:  lda TEXT,x
        beq listen      ; a 0 ends the text
        jsr out
        inx
        bne title

; The next report. Were bytes skipped before it? Then a line says how many.
listen: jsr report
        bcs listen      ; not the keyboard's: the next frame
        lda SKIPPED
        cmp LOST
        beq same_count  ; no more than the last line said
        sta LOST
        ldx #0
skips:  lda SKIP_TEXT,x
        beq count       ; a 0 ends the text
        jsr out
        inx
        bne skips
count:  lda LOST
        jsr hex
        jsr line_end

; If the report is the one on the last line, there is nothing to say.
same_count:
        ldx #7
alike:  lda KEYS,x
        cmp SHOWN,x
        bne news        ; one byte differs: a new line
        dex
        bpl alike
        jmp listen

; A new line: the eight bytes, two hexadecimal digits each, a space between.
news:   lda KEYS
        sta LEDS        ; the modifier keys on the LEDs
        ldx #0
byte:   lda KEYS,x
        sta SHOWN,x
        jsr hex
        cpx #7
        beq ended       ; no space after the last
        lda #' '
        jsr out
        inx
        jmp byte
ended:  jsr line_end
        jmp listen

; line_end: a carriage return and a line feed.
line_end:
        lda #13
        jsr out
        lda #10
        jmp out

; hex: the byte in A, as two hexadecimal digits. A is changed; X and Y are not.
hex:    pha
        lsr
        lsr
        lsr
        lsr
        jsr digit       ; the four high bits
        pla
        and #$0F        ; then the four low bits
digit:  cmp #10
        bcc decimal
        adc #'A' - 10 - 1       ; 10 to 15: A to F (the carry is 1 here: one less)
        jmp out
decimal: adc #'0'       ; 0 to 9 (the carry is 0 here)

; out: the character in A, on the screen and to the Mac. A, X and Y come
; back as they were.
out:    jsr print
        jmp send

; nmi: button S2. Nothing to do.
nmi:    rti

        .segment "RODATA"

TEXT:   .byte "Our Own 6502, Gate by Gate", 13, 10
        .byte "Chapter 21: A Real USB Keyboard", 13, 10
        .byte 13, 10
        .byte "Keyboard reports, when they change:", 13, 10, 0
SKIP_TEXT:
        .byte "Bytes skipped: ", 0

        .segment "VECTORS"
        .word nmi       ; $FFFA: NMI, button S2
        .word reset     ; $FFFC: the reset, button S1, and switching on
        .word reset     ; $FFFE: IRQ and BRK: nothing asks for IRQ; a BRK starts again
