; Chapter 15: the vectors for the programs from chapters 10 to 14, which
; have none of their own. A 6502 reads at $FFFC where to start: here it is
; $C000, the first byte of the ROM, where those programs have always begun.
; Nothing in them asks for an interrupt, and the two other vectors point
; there too.

        .segment "VECTORS"
        .word $C000     ; $FFFA: NMI
        .word $C000     ; $FFFC: the reset
        .word $C000     ; $FFFE: IRQ and BRK
