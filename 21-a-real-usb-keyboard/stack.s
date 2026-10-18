; Chapter 14: a second program, for a test bench only. It goes through the
; six new instructions: TXS and TSX, then PHA and PLA with S going round from
; $00 to $FF and back, then JSR and RTS: a subroutine that calls another, a
; JSR when S is $00, and a JSR whose last byte is the last of a page. Its
; test bench checks every cycle against the tables of 64doc, and A, X, Y, S
; and the flags after every instruction.

LEDS = $8000

        .segment "CODE"

; S and X. TSX sets N and Z, as a load does; TXS changes no flag.
start:  ldx #0              ; Z = 1
        lda #$80            ; N = 1, Z = 0
        txs                 ; S = 00, and the flags stay as they were
        tsx                 ; X = 00: N = 0, Z = 1

; PHA and PLA. S is 00: the first byte goes to $0100, and S goes round to FF,
; so the second byte goes to $01FF. The stack never leaves page 1.
        pha                 ; $0100 = 80, S = FF. PHA changes no flag
        lda #0
        pha                 ; $01FF = 00, S = FE
        lda #$41            ; N = 0, Z = 0
        pla                 ; S = FF, and A = 00 from $01FF: Z = 1
        pla                 ; S goes round to 00, and A = 80 from $0100: N = 1
        tsx                 ; X = 00: S is back where it was

; JSR and RTS, from an empty stack: S = FF, as a program usually begins.
        ldx #$FF
        txs                 ; S = FF
        lda #$11
        jsr outer           ; outer calls inner: two addresses on the stack
        tsx                 ; X = FF: the stack is empty again

; A JSR when S is 00: the high byte of the address goes to $0100, then S goes
; round, and the low byte goes to $01FF.
        ldx #0
        txs                 ; S = 00
        jsr inner
        tsx                 ; X = 00 again

; A JSR whose last byte is at $C0FF. It pushes C0 FF, and RTS adds one: the
; program goes on at $C100, on the next page. The bytes after jmp last, up
; to $C0FC, are NOP, and never run.
        ldx #$FF
        txs                 ; S = FF
        jmp last
        .res $FD - (* - start), $EA
last:   jsr inner           ; at $C0FD, $C0FE and $C0FF
        stx LEDS            ; at $C100: X is what TSX found in inner
done:   jmp done

; outer: keeps A on the stack around a call to inner.
outer:  pha
        jsr inner
        pla
        rts

; inner: keeps A on the stack, looks at S, uses A for something else, and
; takes A back.
inner:  pha
        tsx                 ; X = S, here
        lda #$22
        pla
        rts
