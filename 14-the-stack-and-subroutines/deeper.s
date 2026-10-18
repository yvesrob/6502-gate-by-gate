; Chapter 14: a program made of subroutines. One of them, deeper, calls
; itself: each call lights one LED more, then goes one call deeper, until
; the six are lit. Then the calls come back, the last one first, and each
; call that went deeper takes back from the stack the pattern it kept there,
; and shows it again. The bar of light grows from the USB-C end, shrinks
; back, and starts again. Each pattern stays on the LEDs about a second.

LEDS = $8000            ; a byte stored at this address appears on the LEDs

        .segment "CODE"

start:  ldx #$FF
        txs             ; S = $FF: the stack begins at $01FF, empty
again:  lda #0          ; no LED lit
        jsr show
        jsr deeper      ; the calls go in, and come back
        jmp again

; deeper: A holds a pattern. Light one LED more, and show it. Unless the six
; are lit, keep the pattern on the stack, call deeper once more, and when
; that call comes back, take the pattern back and show it again.
deeper: sec
        rol a           ; one LED more: the carry comes in at bit 0
        jsr show
        cmp #%111111
        beq back        ; the six are lit: go no deeper
        pha             ; keep this pattern on the stack
        jsr deeper      ; one call deeper
        pla             ; the pattern comes back
        jsr show        ; and goes back on the LEDs
back:   rts

; show: A goes to the LEDs, then a short wait. A does not change; X and the
; flags do.
show:   sta LEDS
        ldx #4
wait:   dex
        bne wait        ; X is not 0 yet: once more
        rts
