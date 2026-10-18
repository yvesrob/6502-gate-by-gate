; Chapter 10: a second program, for a test bench only. It stores a byte at the
; LEDs, then all around them: only a byte stored at $8000 may reach the LEDs.

LEDS = $8000

        .segment "CODE"

start:  lda #42
        sta LEDS        ; the LEDs show 42
        lda #21
        sta $0200       ; into the RAM: the LEDs must not move
        sta $7FFF       ; the last byte of the RAM
        sta $8001       ; next door to the LEDs: nobody lives there
        sta $BFFF       ; the last address before the ROM
        sta $C000       ; into the ROM: nothing happens
        lda #63
        sta LEDS        ; the LEDs show 63
done:   jmp done        ; and stay there
