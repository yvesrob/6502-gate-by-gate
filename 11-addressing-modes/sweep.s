; Chapter 11: a light two LEDs wide sweeps from one end of the six LEDs to
; the other, and back. The processor does not work out where the light goes:
; it reads it in a table, one byte after the other.

LEDS = $8000            ; a byte stored at this address appears on the LEDs

        .segment "CODE"

start:  ldx #0          ; X = 0: the first byte of the table
loop:   lda table,x     ; A = the byte of the table at X
        sta LEDS        ; show it
        inx             ; X = X + 1: the next byte
        jmp loop        ; and again, forever

; Bytes that the program reads and never changes. They go into the ROM too,
; right after the code. Written in binary, each one is a picture of the six
; LEDs as you hold the board, USB-C port on the right.
        .segment "RODATA"

; Eight steps: the light goes to the far end and comes back. X counts up to
; 255, then starts again from 0 by itself. So the table has 256 bytes, one
; for each value of X: the eight steps, 32 times over.
table:  .repeat 32
        .byte %000011, %000110, %001100, %011000
        .byte %110000, %011000, %001100, %000110
        .endrepeat
