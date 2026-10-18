; Chapter 13: a loop that computes, and decides when to stop. It follows the
; Collatz rule: an even number is halved, and an odd number n becomes
; 3n + 1. From 7, the numbers rise and fall: 22, 11, 34, 17, 52, 26, 13, 40,
; 20, 10, 5, 16, 8, 4, 2, 1. The loop stops by itself when it reaches 1. Each
; number stays on the LEDs between one and two seconds, while a second loop,
; inside the first, does nothing but count down.

LEDS = $8000            ; a byte stored at this address appears on the LEDs

; One byte of the zero page: the number we are at.
        .segment "ZEROPAGE"

n:      .res 1

        .segment "CODE"

start:  lda #7          ; the first number
show:   sta n
        sta LEDS        ; show it

; Wait: X counts down from 10, and the loop goes round until X is 0.
        ldx #10
wait:   dex
        bne wait        ; X is not 0 yet: once more

; What comes next? A still holds n.
        cmp #1
        beq done        ; n is 1: the end
        lsr a           ; A = n / 2, and bit 0 of n falls into the carry
        bcc show        ; the carry is 0: n was even, and A is the next number
        lda n           ; the carry is 1: n was odd, and the next one is 3n + 1
        asl a           ; 2n
        sec             ; one more...
        adc n           ; ...and n: 2n + 1 + n
        jmp show
done:   jmp done        ; 1 stays on the LEDs
