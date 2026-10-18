; Chapter 11: a second program, for a test bench only. It goes through every
; addressing mode of this chapter, writing bytes into the RAM and reading them
; back, and its test bench checks every cycle against the tables of 64doc.

LEDS    = $8000
NOTHING = $8001             ; nobody answers at this address

        .segment "CODE"

; Immediate: the value follows the opcode. X and Y get theirs.
start:  ldx #$40            ; X = 40
        ldy #$05            ; Y = 05
        lda #$11            ; A = 11

; Page zero: an address of one byte. $30 is the address $0030.
        sta $30             ; $0030 = 11
        ldy $30             ; Y = 11: the byte is back

; Page zero plus X. The sum stays in page zero: $F0 + $40 is $0030.
        lda #$22            ; A = 22
        sta $F0,x           ; $0030 = 22
        ldy $F0,x           ; Y = 22

; Page zero plus Y, which only LDX and STX have.
        stx $20,y           ; $0042 = 40, since $20 + $22 is $42
        ldx $20,y           ; X = 40

; Absolute, for reading as well as for writing.
        sty $0300           ; $0300 = 22
        lda $0300           ; A = 22

; Absolute plus X, or plus Y.
        inx                 ; X = 41
        sta $0280,x         ; $02C1 = 22. A store always reads first, for nothing
        lda $0280,x         ; A = 22, in four cycles: the index stays on the page
        dey                 ; Y = 21
        stx $02F0           ; $02F0 = 41
        lda $02CF,y         ; A = 41, from $02F0
        ldx $02DF,y         ; X = 22, from $0300: one more cycle, the page changes

; An address kept in page zero, at $50 and $51: $02F0, low byte first.
        lda #$F0
        sta $50
        lda #$02
        sta $51

; (zp),Y: the address kept at $50, plus Y.
        ldy #$00            ; Y = 00
        lda ($50),y         ; A = 41, from $02F0
        ldy #$10            ; Y = 10
        lda ($50),y         ; A = 22, from $0300: the page changes
        iny                 ; Y = 11
        sta ($50),y         ; $0301 = 22

; (zp,X): X is added in page zero first, and the address is kept there.
; $50 + $10 is $60, and the address kept at $60 and $61 is $0301.
        ldx #$10            ; X = 10
        lda #$01
        sta $60
        lda #$03
        sta $61
        lda ($50,x)         ; A = 22, from $0301
        lda #$55            ; A = 55
        sta ($50,x)         ; $0301 = 55

; Read a byte, change it, write it back.
        inc $30             ; $0030 = 23
        dec $20,x           ; $0030 = 22, since $20 + $10 is $30
        inc $0300           ; $0300 = 23
        dec $02F0,x         ; $0300 = 22, since $02F0 + $10 is $0300
        dex                 ; X = 0F

; The LEDs can be read back. Where nobody answers, the processor reads 0.
        lda #%101101
        sta LEDS            ; the LEDs show 101101
        ldx LEDS            ; X = 2D
        ldy NOTHING         ; Y = 00

; JMP (address): the target is kept in memory, low byte first. Both bytes
; are read on the same page: JMP ($03FF) takes the high byte at $0300.
        lda #<done
        sta $03FF
        lda #>done
        sta $0300
        jmp ($03FF)
        sta LEDS            ; never done
done:   jmp done            ; the end
