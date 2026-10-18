; Chapter 15: a second program, for a test bench only. It goes through the
; six new instructions, and the test bench interrupts it. The test bench
; plays a device on IRQ: it raises IRQ at chosen cycles, and lets it go back
; to 0 when the program writes at $8001. It raises NMI too. It checks every
; cycle against the tables of 64doc, and A, X, Y, S and the six flags after
; every instruction.

LEDS  = $8000
HEARD = $8001           ; a byte stored here tells the device: IRQ can go back to 0

        .segment "CODE"

; P as one byte. After the reset, I is 1.
start:  ldx #$FF
        txs
        sec                 ; C = 1
        sed                 ; D = 1
        lda #$80            ; N = 1
        php                 ; pushes N V 1 B D I Z C = 1 0 1 1 1 1 0 1: $BD
        pla                 ; A = $BD
        lda #$FF
        pha
        plp                 ; the six flags from $FF: all at 1. Bits 5 and 4 go nowhere
        php                 ; pushes $FF
        pla                 ; A = $FF
        lda #0
        pha
        plp                 ; the six flags from $00: all at 0, I too
        php                 ; pushes $30: bit 5 and B, which PHP always pushes at 1
        pla                 ; A = $30

; IRQ is refused while I is 1. The test bench raises IRQ during the first
; NOP, and holds it. After CLI, one more instruction runs, then the handler.
; There, after the program has told the device, the test bench raises IRQ
; once more: RTI takes I back to 0, and IRQ is served again at once.
        sei                 ; I = 1
        nop                 ; IRQ goes up here, and is refused
        nop
        nop
        cli                 ; I = 0
        lda #1              ; one more instruction
        sta LEDS            ; the handler comes before this one, twice

; SEI, with IRQ raised at the end of its first cycle: I is still 0 when the
; processor looks, so IRQ is served right after SEI. P goes onto the stack
; with I at 1, and RTI brings it back so.
        sei                 ; IRQ goes up at the end of its first cycle
        lda #2              ; the handler comes before this one
        sta LEDS

; PLP takes I to 0 while IRQ asks: as after CLI, one more instruction runs.
        lda #0
        pha                 ; IRQ goes up here, and is refused
        plp                 ; the six flags at 0: I = 0
        lda #3              ; one more instruction
        sta LEDS            ; the handler comes before this one

; The branches. C is 0.
        bcc near            ; taken. IRQ goes up at the end of its first cycle
        nop                 ; jumped over
near:   lda #4              ; the handler comes before this one
        sta LEDS
        bcc next            ; taken. IRQ goes up at the end of its second cycle
        nop                 ; jumped over
next:   lda #5              ; this one still runs: a taken branch does not
        sta LEDS            ; look on its third cycle. The handler comes here
        bcs never           ; not taken. IRQ goes up at the end of its first cycle
        lda #6              ; the handler comes before this one
never:  sta LEDS
        jmp edge            ; over the bytes up to $C0FB, which are NOP
        .res $FC - (* - start), $EA
edge:   bcc far             ; at $C0FC: taken, to the next page. IRQ goes up at the
        nop                 ; end of its third cycle: it is still in time
        nop
far:    lda #7              ; at $C100: the handler comes before this one
        sta LEDS

; BRK, as an interrupt, through the vector at $FFFE, with B at 1 in the P
; that it pushes. It skips the byte that follows it.
        brk
        .byte $E8           ; skipped: if it ran, it would be INX
        lda #8
        sta LEDS

; NMI, while I is 1: it is not refused. Then NMI while I is 0: its handler
; finds I at 1.
        sei
        nop                 ; NMI goes up here
        nop
        cli
        nop                 ; NMI goes up here
        nop

; IRQ and NMI together: NMI first. Its RTI takes I back to 0, and IRQ is
; served at once.
        nop                 ; IRQ and NMI go up at the end of its first cycle
        lda #9              ; NMI, then IRQ, before this one
        sta LEDS
done:   jmp done            ; the test bench presses reset here

; irq: IRQ and BRK come here. B, bit 4 of the P that was pushed, tells them
; apart. For an IRQ, the handler tells the device that it has heard it.
irq:    pha                 ; A, kept
        txa
        pha                 ; X, kept
        tsx
        lda $0103,x         ; P, as it was pushed, before A and X
        and #%00010000      ; B
        bne back            ; 1: a BRK. Nothing to tell anybody
        sta HEARD           ; 0: an IRQ. The device can let IRQ go back to 0
back:   pla
        tax                 ; X, back
        pla                 ; A, back
        rti

; nmi: shows P, as the NMI left it, on the LEDs.
nmi:    pha                 ; A, kept
        php
        pla                 ; A = P: I is 1
        sta LEDS
        pla                 ; A, back
        rti

        .segment "VECTORS"
        .word nmi           ; $FFFA: NMI
        .word start         ; $FFFC: the reset
        .word irq           ; $FFFE: IRQ and BRK
