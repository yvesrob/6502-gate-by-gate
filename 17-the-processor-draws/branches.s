; Chapter 13: a second program, for a test bench only. It goes through the
; new instructions of this chapter: the transfers, NOP, BIT and CLV, then
; each of the eight branches, once when its flag says no and once when it
; says yes, then a loop that goes from one page to the next and back. Its
; test bench checks every cycle against the tables of 64doc, and A, X, Y
; and the flags after every instruction.

LEDS = $8000

        .segment "CODE"

; Copy a register into another. A transfer sets N and Z, as a load does.
start:  ldx #$80            ; X = 80
        txa                 ; A = 80: N = 1
        tay                 ; Y = 80
        lda #0              ; A = 00: Z = 1
        tax                 ; X = 00: Z = 1
        tya                 ; A = 80: N = 1
        nop                 ; nothing, in two cycles

; BIT: N and V become bits 7 and 6 of the byte, and Z says whether A AND
; the byte is 0. A does not change.
        lda #%11000000
        sta $30             ; $0030 = C0
        lda #%00000001      ; A = 01
        bit $30             ; N = 1, V = 1, and Z = 1: 01 AND C0 is 0
        bit bits            ; 41, 01000001: N = 0, V = 1, and Z = 0: 01 AND 41 is 01

; The eight branches, each one twice. When its flag says no, the program
; goes on with the next instruction. When it says yes, it jumps over the
; LDA #$EE that follows, which is never done.
        bvc over1           ; V is 1: not taken
        bvs over1           ; taken
        lda #$EE
over1:  clv                 ; V = 0
        bvs over2           ; not taken
        bvc over2           ; taken
        lda #$EE
over2:  lda #$42
        cmp #$42            ; the same: Z = 1, and C = 1
        bne over3           ; not taken
        beq over3           ; taken
        lda #$EE
over3:  cmp #$41            ; A is larger: Z = 0, and C = 1
        beq over4           ; not taken
        bne over4           ; taken
        lda #$EE
over4:  bcc over5           ; C is 1: not taken
        bcs over5           ; taken
        lda #$EE
over5:  cmp #$43            ; A is smaller: C = 0, and N = 1: 42 - 43 is FF
        bcs over6           ; not taken
        bcc over6           ; taken
        lda #$EE
over6:  bpl over7           ; N is 1: not taken
        bmi over7           ; taken
        lda #$EE
over7:  lda #$01            ; N = 0
        bmi over8           ; not taken
        bpl over8           ; taken
        lda #$EE

; A loop over two pages. The bytes from here to $C0FC are NOP, and never
; run: they put the loop at the end of page $C0. At each lap, BVC goes
; forward into page $C1, and BNE comes back into page $C0.
over8:  ldx #0              ; X counts the laps
        ldy #3              ; Y counts down: three laps
        jmp lap
        .res $FC - (* - start), $EA
lap:    inx
        bvc ahead           ; V is 0: taken, into the next page
        lda #$EE
ahead:  dey
        bne lap             ; Y is not 0: back into the page before
        stx LEDS            ; three laps: the LEDs show 000011
done:   jmp done

bits:   .byte %01000001     ; a byte for BIT, in the ROM
