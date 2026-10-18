; Chapter 12: a stopwatch. Four decimal digits, the seconds and the
; hundredths, kept in two bytes of the RAM. At every lap of its loop the
; processor adds half a second to them, in decimal, and shows the seconds on
; the LEDs. It keeps time because a lap lasts 25 cycles, and 25 cycles at 50
; cycles a second are half a second.

LEDS = $8000            ; a byte stored at this address appears on the LEDs

; Two bytes of the zero page, for the stopwatch. The assembler gives them an
; address and nothing else: a byte of the RAM gets its value from the program.
        .segment "ZEROPAGE"

hundredths: .res 1      ; two digits, 00 to 99
seconds:    .res 1      ; two digits, 00 to 99

        .segment "CODE"

start:  sed             ; from here on, ADC counts in decimal
        lda #0
        sta hundredths  ; the stopwatch starts at 00.00
        sta seconds

; One lap: a sum of two bytes, the low byte first. The carry takes what
; goes past 99 from the hundredths into the seconds.
loop:   clc             ; no carry coming into the low byte
        lda hundredths
        adc #$50        ; half a second more: in decimal, $50 is fifty
        sta hundredths
        lda seconds
        adc #0          ; plus the carry, when the hundredths went past 99
        sta seconds
        sta LEDS        ; show the seconds
        jmp loop        ; and again, forever
