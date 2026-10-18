; Chapter 16: the program of the board runs the functional test of Klaus
; Dormann, again and again. The test tries every documented opcode of the
; 6502 in every addressing mode, checks the results and the flags (all but
; N, V and Z after a decimal ADC or SBC), and stops at the first thing that
; is wrong: in a loop that jumps to itself.
; The test is his, assembled by him: 6502_functional_test.bin is an image of
; a whole memory of 65,536 bytes, and the test lives in its first pages. We
; copy those pages from our ROM into our RAM, and jump to its first
; instruction.
;
; The six LEDs count the times the whole test went well. If the test finds
; something wrong, it stops where it is, and the LEDs stop counting.

LEDS    = $8000         ; a byte stored at this address appears on the LEDs
TEST    = $0400         ; the first instruction of the test
SUCCESS = $3469         ; where it ends when all went well: JMP $3469, a jump to itself
PAGES   = $39           ; the test fits in the first $39 pages: $0000 to $38FF
FROM    = $00           ; two bytes of page zero that the test does not use:
TO      = $02           ; where we copy from, and two more: where to

        .segment "CODE"

; The first $3900 bytes of the ROM, $C000 to $F8FF, are the first $3900
; bytes of his image, as he wrote them: the byte at $C000 + n goes to n.
image:  .incbin "6502_functional_test.bin", 0, PAGES * 256

; Switched on, or button S1: no test has gone well yet.
reset:  lda #0
        sta LEDS

; Copy the test into the RAM, 256 bytes at a time, from page 2 to page $38.
; Page 1 is the stack: the test has nothing there.
again:  lda #<(image + $0200)
        sta FROM
        sta TO
        lda #>(image + $0200)
        sta FROM+1
        lda #$02
        sta TO+1
        ldy #0
copy:   lda (FROM),y
        sta (TO),y
        iny
        bne copy        ; the rest of this page
        inc FROM+1
        inc TO+1
        lda TO+1
        cmp #PAGES
        bne copy        ; the next page

; Then page zero, from $0A, where the test keeps its variables. Not with
; (FROM),y: FROM and TO are in page zero too, and must not change.
        ldx #$0A
zero:   lda image,x
        sta $00,x
        inx
        bne zero

; When all went well, the test ends on JMP SUCCESS, a jump to itself. We
; change where it jumps: to passed.
        lda #<passed
        sta SUCCESS+1
        lda #>passed
        sta SUCCESS+2
        jmp TEST        ; go

; passed: the whole test went well. One more on the LEDs, which can be read
; back. Then copy the test again, fresh, and run it again.
passed: ldx LEDS
        inx
        stx LEDS
        jmp again

        .segment "VECTORS"
        .incbin "6502_functional_test.bin", $FFFA, 2    ; $FFFA: NMI, as the test wants it
        .word reset                                      ; $FFFC: the reset, button S1, and switching on
        .incbin "6502_functional_test.bin", $FFFE, 2    ; $FFFE: IRQ and BRK, as the test wants them
