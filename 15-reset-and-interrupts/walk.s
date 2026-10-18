; Chapter 15: a light walks along the six LEDs, from the USB-C end to the
; other, about a second at each LED, and starts again. Button S2 is wired to
; NMI. Press it, and the processor leaves the program wherever it is: it
; pushes where it was and the flags, and runs nmi instead. nmi lights the six
; LEDs for about a second, then puts back what they showed, and RTI takes the
; program back to where it was: the light goes on from where it stopped.
; Button S1 is the reset: the program starts again, from LED 1.

LEDS = $8000            ; a byte stored at this address appears on the LEDs

        .segment "CODE"

reset:  ldx #$FF
        txs             ; S = $FF: the stack begins at $01FF, empty
again:  lda #%000001    ; the light at LED 1
walk:   sta LEDS
        jsr pause
        asl a           ; one LED further
        cmp #%1000000   ; past the sixth?
        bne walk        ; not yet: show it
        jmp again       ; yes: back to LED 1

; pause: about three quarters of a second, with its JSR. A does not change;
; X and the flags do.
pause:  ldx #5
wait:   dex
        bne wait        ; X is not 0 yet: once more
        rts

; nmi: what button S2 runs, wherever the program is. It keeps A, X and what
; the LEDs show on the stack, lights the six LEDs, waits, and puts it all
; back. RTI takes back P and pc, which the NMI pushed.
nmi:    pha             ; A, kept
        txa
        pha             ; X, kept, through A
        lda LEDS        ; what the LEDs show: they can be read back
        pha             ; kept too
        lda #%111111
        sta LEDS        ; the six LEDs
        jsr pause
        pla
        sta LEDS        ; what they showed, back on the LEDs
        pla
        tax             ; X, back
        pla             ; A, back
        rti             ; P and pc, back: the program goes on

        .segment "VECTORS"
        .word nmi       ; $FFFA: NMI, button S2
        .word reset     ; $FFFC: the reset, button S1, and switching on
        .word reset     ; $FFFE: IRQ and BRK, which nothing asks for here
