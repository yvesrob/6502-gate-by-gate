; Chapter 20 uses the maze from chapter 19, a program for the RAM; only its
; comments change, where they named load.s. tools/send.py sends it to the
; monitor, which stores it at $0300 and runs it. It draws a maze: each of the
; 1,000 cells of the screen gets one of two diagonals, \ or /, picked at
; random, one cell after the other. It is the idea of a famous program of the
; Commodore 64, one line of BASIC, 10 PRINT CHR$(205.5+RND(1)); : GOTO 10,
; which prints one of its two diagonal characters at random, again and
; again. Our font has no such characters, so this program draws its diagonals
; itself, eight bytes for a cell, straight into the bitmap.
;
; A maze takes about 2.7 seconds, stays 2 seconds, and the next one is drawn
; over it. The LEDs count the mazes. As each maze begins, the program tells
; the Mac which maze it is, and the random number it has reached, in a line
; of text, as "Maze 01, random ACE1". It does not clear the screen: the first
; maze is drawn over what the monitor wrote.
;
; The numbers are random only in looks: each comes from the one before, by
; shifting its bits and turning some over, so they are the same, in the same
; order, each time the program starts.
;
; Button S2 (NMI): the monitor counts it in FAST. From then on, no waiting
; between the cells; the 2 seconds stay. Button S1 is the reset, and the
; monitor starts again.

; In the ROM, the table of jumps.
SEND    = $C301         ; sends the byte in A to the Mac; A, X and Y come back

LEDS    = $8000
BITMAP  = $A000
FAST    = $00           ; the monitor adds one at each NMI

; The variables of the program, in page zero, away from the monitor's.
RANDOM  = $10           ; the random number, two bytes
MAZES   = $12           ; how many mazes so far
ROW_AT  = $13           ; the top line of the row of cells being drawn, two bytes
COLUMN  = $15           ; the cell in that row, 0 to 39
ROWS    = $16           ; rows still to draw
CELL    = $17           ; a line of the cell, in the bitmap, two bytes
LINES   = $19           ; lines of the cell still to draw
TIME    = $1A           ; for wait
REST    = $1B           ; for the 2 seconds

        .segment "CODE"

start:  lda #0
        sta FAST        ; S2 counts from now on
        sta MAZES
        lda #$E1
        sta RANDOM
        lda #$AC
        sta RANDOM+1    ; the first random number: $ACE1

maze:   inc MAZES
        lda MAZES
        sta LEDS        ; one more maze on the LEDs
        jsr report      ; and a line for the Mac
        lda #<BITMAP
        sta ROW_AT
        lda #>BITMAP
        sta ROW_AT+1
        lda #25
        sta ROWS

row:    lda #0
        sta COLUMN

; A cell: its top line is the top line of the row plus the column.
cell:   clc
        lda ROW_AT
        adc COLUMN
        sta CELL
        lda ROW_AT+1
        adc #0
        sta CELL+1
        jsr random      ; a bit in the carry: 0 or 1
        ldx #0          ; 0: \, the first eight bytes of SLANTS
        bcc draw
        ldx #8          ; 1: /, the next eight
draw:   lda #8
        sta LINES
        ldy #0
line:   lda SLANTS,x    ; a line of the diagonal
        sta (CELL),y
        inx
        clc
        lda CELL
        adc #40         ; the next line of the cell is 40 bytes on
        sta CELL
        lda CELL+1
        adc #0
        sta CELL+1
        dec LINES
        bne line

        lda FAST
        bne quick       ; S2 was pressed: no waiting
        lda #1
        jsr wait        ; about 2.7 milliseconds
quick:  inc COLUMN
        lda COLUMN
        cmp #40
        bne cell        ; the next cell of this row
        clc
        lda ROW_AT
        adc #<320
        sta ROW_AT
        lda ROW_AT+1
        adc #>320
        sta ROW_AT+1    ; the next row of cells begins 320 bytes on
        dec ROWS
        bne row

        lda #3
        sta REST
pause:  lda #250
        jsr wait        ; three times 250 x 2.7 ms: about 2 seconds
        dec REST
        bne pause
        jmp maze

; random: the next random number, and one bit of it in the carry. RANDOM
; moves right by one bit; when the bit that falls out is 1, four bits of the
; high byte turn over (EOR #$B4). The sequence goes through all 65,535
; numbers but 0 before it comes back.
random: lsr RANDOM+1
        ror RANDOM      ; the bit that falls out is in the carry
        bcc same
        lda RANDOM+1
        eor #$B4
        sta RANDOM+1    ; LDA, EOR and STA leave the carry alone
same:   rts

; report: "Maze ", the number of the maze, ", random ", the random number,
; and a carriage return and a line feed, to the Mac. The numbers are in
; hexadecimal.
report: ldx #0
        jsr say         ; Maze
        lda MAZES
        jsr hex
        jsr say         ; , random
        lda RANDOM+1
        jsr hex
        lda RANDOM
        jsr hex
        jsr say         ; 13 and 10
        rts

; say: the text in WORDS from X, up to its 0, to the Mac. X ends after the 0.
say:    lda WORDS,x
        inx
        cmp #0
        beq said
        jsr SEND
        jmp say
said:   rts

; hex: the byte in A, as two hexadecimal digits, to the Mac.
hex:    pha
        lsr
        lsr
        lsr
        lsr             ; the high four bits
        jsr nibble
        pla
        and #$0F        ; the low four bits
nibble: cmp #10
        bcc decimal
        clc
        adc #'A' - 10   ; 10 to 15: A to F
        jmp SEND
decimal: adc #'0'       ; 0 to 9 (the carry is 0)
        jmp SEND

; wait: about A x 2.7 milliseconds, doing nothing else.
wait:   sta TIME
again:  ldy #26
outer:  ldx #0
inner:  dex
        bne inner       ; 256 times
        dey
        bne outer       ; 26 times that
        dec TIME
        bne again
        rts

        .segment "RODATA"

; The two diagonals, eight lines each. Bit 7 is the pixel on the left.
SLANTS: .byte %10000000 ; \ : from the top left
        .byte %01000000
        .byte %00100000
        .byte %00010000
        .byte %00001000
        .byte %00000100
        .byte %00000010
        .byte %00000001 ;     to the bottom right
        .byte %00000001 ; / : from the top right
        .byte %00000010
        .byte %00000100
        .byte %00001000
        .byte %00010000
        .byte %00100000
        .byte %01000000
        .byte %10000000 ;     to the bottom left

WORDS:  .byte "Maze ", 0, ", random ", 0, 13, 10, 0
