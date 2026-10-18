; Chapter 12: a second program, for a test bench only. It goes through the
; new instructions of this chapter, in a straight line. Its test bench checks
; every cycle against the tables of 64doc, and A and the flags after every
; instruction: a comparison changes nothing but the flags.

LEDS = $8000

        .segment "CODE"

; Two numbers of two bytes in the zero page, low byte first:
; $1290 at $20 and $21, $01A0 at $22 and $23.
start:  lda #$90
        sta $20
        lda #$12
        sta $21
        lda #$A0
        sta $22
        lda #$01
        sta $23

; Their sum, at $24 and $25. The low bytes first, then the high bytes and
; the carry: $1290 + $01A0 = $1430.
        clc
        lda $20             ; A = 90
        adc $22             ; A = 30, and a carry: 90 + A0 is 130
        sta $24
        lda $21             ; A = 12
        adc $23             ; A = 14: 12 + 01 + the carry
        sta $25

; Their difference, at $26 and $27. SEC first: no borrow coming in.
; $1290 - $01A0 = $10F0.
        sec
        lda $20             ; A = 90
        sbc $22             ; A = F0, and a borrow: the carry goes to 0
        sta $26
        lda $21             ; A = 12
        sbc $23             ; A = 10: 12 - 01 - the borrow
        sta $27

; In decimal, each byte holds two digits: 1995 + 0027 = 2022.
        sed
        clc
        lda #$95
        adc #$27            ; A = 22, and a carry: 95 + 27 is 122
        sta $28
        lda #$19
        adc #$00            ; A = 20: 19 + the carry
        sta $29

; And back again: 2022 - 0027 = 1995.
        sec
        lda $28             ; A = 22
        sbc #$27            ; A = 95, and a borrow
        sta $2A
        lda $29             ; A = 20
        sbc #$00            ; A = 19: 20 - the borrow
        sta $2B
        cld                 ; back to binary

; Compare: a subtraction that keeps only its flags.
        lda #$42
        cmp #$41            ; A is larger: C = 1
        cmp #$42            ; the same: Z = 1, and C = 1
        cmp #$43            ; A is smaller: C = 0 (and N = 1, since 42 - 43 is FF)
        ldx $25             ; X = 14
        cpx #$14            ; the same
        ldy $27             ; Y = 10
        cpy $25             ; 10 against 14: smaller

; Bit by bit.
        lda #%11001100
        and #%10101010      ; A = 10001000: 1 where both have a 1
        ora #%00000011      ; A = 10001011: 1 where either has a 1
        eor #%11111111      ; A = 01110100: every bit turned over

; Shifts on A. The bit that goes out lands in the carry.
        lda #%10010110
        asl a               ; A = 00101100, C = 1
        rol a               ; A = 01011001, C = 0: the carry came in on the right
        lsr a               ; A = 00101100, C = 1
        ror a               ; A = 10010110, C = 0: back where we started

; Shifts on a byte of memory: read it, write it back as it was, then write
; the new value, as INC and DEC do.
        lda #%01000001
        sta $0300
        asl $0300           ; $0300 = 10000010
        ldx #$10
        lsr $02F0,x         ; $0300 = 01000001, since $02F0 + 10 is $0300
        lda $0300
        sta LEDS            ; the LEDs show 000001
done:   jmp done
