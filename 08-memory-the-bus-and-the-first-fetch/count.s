; Chapter 7: the first program of our computer. It counts on the six LEDs.
;
; A holds the count. The program shows it, adds one, and starts again.

LEDS = $8000            ; a byte stored at this address appears on the LEDs

        .segment "CODE"

start:  lda #0          ; A = 0
loop:   sta LEDS        ; show A on the LEDs
        clc             ; no carry coming into the addition
        adc #1          ; A = A + 1
        jmp loop        ; and again, forever
