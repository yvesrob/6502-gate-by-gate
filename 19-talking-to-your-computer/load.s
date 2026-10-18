; Chapter 19: the program of the board listens to the Mac. It waits for lines
; of text on the serial link, stores the bytes they carry into the RAM, and
; runs the program they make. Each line says where its bytes go, in
; hexadecimal, then gives them, two digits each:
;
;   0300: A9 00 8D 00 80 E8 8E 00
;
; puts A9 at $0300, 00 at $0301, and so on. An address followed by R runs the
; program from there:
;
;   0300R
;
; Every character that comes is written on the screen, then sent back to the
; Mac. The Mac waits for each line to come back, the same, before it sends the
; next one: tools/send.py does that.
;
; The program runs as a subroutine: if it ends with RTS, we listen again.
; Button S2 (NMI) adds one to FAST, which a program can read. Button S1 is the
; reset: the screen is cleared, and we wait again. The RAM keeps what it held.

LEDS    = $8000         ; a byte stored at this address appears on the LEDs

; The variables, in page zero. The console has its own, from $F0.
FAST    = $00           ; each NMI (S2) adds one; a program from the Mac can read it
VALUE   = $01           ; the number we are reading, two bytes
DIGITS  = $03           ; how many digits it has so far
WHERE   = $04           ; where the next byte goes, two bytes
STORING = $06           ; 1 once this line has given its address
HEARD   = $07           ; the character that has just come

        .segment "CODE"

; The font begins the ROM, at $C000, as in chapter 18.
        .include "font.s"

; The table of jumps, just after the font. A program sent by the Mac does not
; know where the console and the serial link are in this ROM: their addresses
; depend on everything before them. So it calls them here, at addresses that
; stay: JSR $C2FB, for instance, jumps to print, and print returns to it.
        .assert * = $C2F8, error, "the table of jumps must begin at $C2F8"
        jmp clear       ; $C2F8
        jmp print       ; $C2FB
        jmp receive     ; $C2FE
        jmp send        ; $C301

        .include "console.s"
        .include "serial.s"

        .segment "CODE"         ; console.s ends in RODATA: back to CODE

reset:  ldx #$FF
        txs             ; S = $FF: the stack begins at $01FF, empty
        lda #0
        sta LEDS
        sta FAST
        lda #$E6        ; light blue ink, blue paper, as in chapters 17 and 18
        jsr clear
        ldx #0
title:  lda TEXT,x
        beq listen      ; a 0 ends the text
        jsr print
        inx
        bne title

; A line begins: it has given no address yet.
listen: lda #0
        sta STORING

; A number begins: no digit yet.
begin:  lda #0
        sta VALUE
        sta VALUE+1
        sta DIGITS

; The next character from the Mac: on the screen, then back to the Mac. Then
; a hexadecimal digit goes into VALUE, which moves up one digit, four bits,
; to make room: the number is read from the left, as it is written.
next:   jsr receive
        jsr print       ; on the screen,
        jsr send        ; and back to the Mac, once it is dealt with
        jsr digit
        bcs other       ; not a digit
        ldx #4
times:  asl VALUE
        rol VALUE+1     ; VALUE x 2, on two bytes, four times: x 16
        dex
        bne times
        ora VALUE       ; and the new digit in the four bits now at 0
        sta VALUE
        inc DIGITS
        jmp next

; Not a digit. A colon: the number was the address of the line. R: it was
; where to run. Anything else ends the number: a byte to store, if the line
; has given its address.
other:  cmp #':'
        beq colon
        cmp #'R'
        beq run
        sta HEARD
        lda DIGITS
        beq ended       ; there was no number before this character
        lda STORING
        beq ended       ; no address on this line: nowhere to store it
        lda VALUE       ; the low byte of the number
        ldy #0
        sta (WHERE),y
        inc WHERE       ; the next byte goes just after it
        bne ended
        inc WHERE+1
ended:  lda HEARD
        cmp #13
        beq listen      ; a carriage return ends the line
        jmp begin

colon:  lda VALUE
        sta WHERE
        lda VALUE+1
        sta WHERE+1     ; WHERE: the address of the line
        lda #1
        sta STORING
        jmp begin

; R: run the program at the address in VALUE. JSR cannot jump to an address
; held in memory, but JMP can: we call go, and go jumps there.
run:    lda DIGITS
        beq begin       ; R without an address: nothing to run
        jsr go
        jmp listen      ; the program has returned: we listen again
go:     jmp (VALUE)

; digit: is the character in A a hexadecimal digit, 0 to 9 or A to F? Carry
; clear: yes, and A holds its value, 0 to 15. Carry set: no, and A is unchanged.
digit:  cmp #'0'
        bcc no          ; below 0
        cmp #'9' + 1
        bcc decimal     ; 0 to 9
        cmp #'A'
        bcc no          ; between 9 and A
        cmp #'F' + 1
        bcs no          ; above F
        sbc #'A' - 10 - 1   ; the carry is 0 here: SBC takes one more away
        clc
        rts
decimal: sbc #'0' - 1   ; here too
        clc
        rts
no:     sec
        rts

; nmi: button S2. One more in FAST; INC changes no register, and RTI gives the
; flags back.
nmi:    inc FAST
        rti

        .segment "RODATA"

TEXT:   .byte "Our Own 6502, Gate by Gate", 13, 10
        .byte "Chapter 19: Talking to Your Computer", 13, 10
        .byte 13, 10
        .byte "Waiting for a program.", 0

        .segment "VECTORS"
        .word nmi       ; $FFFA: NMI, button S2
        .word reset     ; $FFFC: the reset, button S1, and switching on
        .word reset     ; $FFFE: IRQ and BRK: a BRK in a program from the Mac starts us again
