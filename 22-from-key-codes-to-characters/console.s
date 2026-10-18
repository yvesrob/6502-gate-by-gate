; Chapter 22 uses the console from chapter 18, with one code more: 8, the
; backspace, moves back one cell, so that the monitor can rub a character out
; (monitor.s); and one routine more, cursor, which turns over the cell where
; the next letter will go, so that typing.s can make it blink. Nothing else
; changes.
; Chapter 18: the console. It writes text into the picture from chapter 17:
; 40 letters across and 25 rows down, one letter in each cell of 8 x 8
; pixels. A letter is eight bytes of the font, copied into the bitmap one line
; of pixels at a time. When a row is full, the next letter goes at the start
; of the next row; when the last row is full, the whole text moves up one row:
; the screen scrolls.
;
; Two routines, for the programs that use it:
;   clear   the byte in A in every cell of the colors, every pixel of the
;           bitmap at 0, and the next letter at the top left. It changes
;           A, X and Y.
;   print   the character whose code is in A:
;             32 to 126   its letter, in the next cell
;             13          carriage return: back to the first column
;             10          line feed: down one row, or scroll on the last row
;             8           backspace: back one cell (chapter 22)
;           Any other code does nothing. A, X and Y come back as they were.
;   cursor  (chapter 22) the cell where the next letter will go, turned over:
;           ink where there was paper, paper where there was ink. Turned over
;           again, the cell is as it was. It changes A, X and Y.
; It needs FONT, from font.s.

COLORS  = $9C00         ; the two colors of each cell
BITMAP  = $A000         ; the pixels

; The console's variables, at the top of page zero. The rest of page zero is
; left to the program.
COL     = $F0           ; the column of the next letter, 0 to 39
ROW     = $F1           ; its row, 0 to 24
CHAR    = $F2           ; the code that print was given
GLYPH   = $F3           ; an address in the font, two bytes
CELL    = $F5           ; an address in the bitmap, two bytes
FROM    = $F7           ; scroll copies from this address, two bytes...
TO      = $F9           ; ...to this one, two bytes; fill writes from here

        .segment "CODE"

; clear: the byte in A in every cell, every pixel at 0, and back to the top left.
clear:  ldx #>COLORS
        stx TO+1
        ldx #4          ; 4 pages, $9C00 to $9FFF
        jsr fill
        lda #>BITMAP
        sta TO+1
        ldx #32         ; 32 pages, $A000 to $BFFF
        lda #0          ; every pixel at 0: paper
        jsr fill
        lda #0
        sta COL
        sta ROW
        rts

; fill: the byte in A, in X pages of 256 bytes, from the page in TO+1.
fill:   ldy #0
        sty TO          ; from the first byte of the page
page:   sta (TO),y
        iny
        bne page        ; the rest of this page
        inc TO+1
        dex
        bne page        ; the next page
        rts

; print: the character whose code is in A.
print:  sta CHAR
        txa
        pha
        tya
        pha             ; X and Y wait on the stack
        lda CHAR
        cmp #13
        bne not_cr
        lda #0          ; carriage return: back to the first column
        sta COL
        jmp done
not_cr: cmp #10
        bne not_lf
        jsr down        ; line feed: down one row
        jmp done
not_lf: cmp #32
        bcc control     ; another code below 32: perhaps the backspace
        cmp #127
        bcs done        ; 127 and above: nothing, the font stops at 126
        jsr letter      ; the letter, in the cell (COL, ROW)
        inc COL
        lda COL
        cmp #40
        bne done        ; there is room on this row
        lda #0          ; the row is full: the next letter goes at the
        sta COL         ; start of the next row
        jsr down
done:   pla
        tay
        pla
        tax             ; X and Y as they were
        lda CHAR        ; and A
        rts

; control: a code below 32, other than 13 and 10. Only 8, the backspace, does
; something: back one cell. In the first column, that is the last cell of the
; row above, where a line too long for one row went on; in the top left
; corner there is nowhere to go back to. The backspace only moves: the letter
; stays in its cell until something is written over it.
control: cmp #8
        bne done        ; not the backspace: nothing
        lda COL
        bne left        ; not the first column: one cell to the left
        lda ROW
        beq done        ; the top left corner: nothing
        dec ROW         ; the row above,
        lda #40         ; just past its last cell,
        sta COL
left:   dec COL         ; then one cell to the left
        jmp done

; cursor: the cell (COL, ROW), each of its 64 pixels turned over. Its eight
; lines are eight bytes, 40 bytes apart, as letter writes them; EOR with
; %11111111 turns over every bit of a byte. On an empty cell, that is a block
; of ink. Nothing is kept aside: turned over a second time, the cell is as it
; was, and print finds it so.
cursor: ldx ROW
        clc
        lda ROW_LOW,x
        adc COL
        sta CELL
        lda ROW_HIGH,x
        adc #0
        sta CELL+1      ; CELL: the top line of the cell, as in letter
        ldx #8          ; eight lines of pixels
        ldy #0
over:   lda (CELL),y
        eor #%11111111  ; every pixel of the line turned over
        sta (CELL),y
        clc             ; the next line of the cell is 40 bytes on
        lda CELL
        adc #40
        sta CELL
        lda CELL+1
        adc #0
        sta CELL+1
        dex
        bne over
        rts

; down: the next row. After the last row there is none: the text moves up
; one row instead, and we stay on the last row, now empty.
down:   lda ROW
        cmp #24
        beq scroll      ; the last row
        inc ROW
        rts

; scroll: rows 1 to 24 move up one row, and row 24 is cleared. A row of
; letters is 8 lines of pixels of 40 bytes: 320 bytes, one after the other.
; Rows 1 to 24 are 7,680 bytes, exactly 30 pages: the processor reads each one
; back and writes it 320 bytes lower in memory, one row higher on the screen.
scroll: lda #<(BITMAP + 320)
        sta FROM
        lda #>(BITMAP + 320)
        sta FROM+1      ; FROM: the start of row 1
        lda #<BITMAP
        sta TO
        lda #>BITMAP
        sta TO+1        ; TO: the start of row 0
        ldx #30         ; 30 pages
        ldy #0
move:   lda (FROM),y
        sta (TO),y
        iny
        bne move        ; the rest of this page
        inc FROM+1
        inc TO+1
        dex
        bne move        ; the next page
        lda #0          ; TO is now at the start of row 24: two pages at 0,
        ldx #2          ; the 320 bytes of the row and the 192 that the
        jsr fill        ; display does not show
        rts

; letter: the letter whose code is in A, 32 to 126, in the cell (COL, ROW).
letter: sec
        sbc #32         ; its number in the font, 0 to 94
        sta GLYPH
        lda #0
        sta GLYPH+1
        asl GLYPH
        rol GLYPH+1     ; times 2,
        asl GLYPH
        rol GLYPH+1     ; times 4,
        asl GLYPH
        rol GLYPH+1     ; times 8: eight bytes for each letter
        clc
        lda GLYPH
        adc #<FONT
        sta GLYPH
        lda GLYPH+1
        adc #>FONT
        sta GLYPH+1     ; GLYPH: the top line of the letter, in the font
        ldx ROW
        clc
        lda ROW_LOW,x
        adc COL
        sta CELL
        lda ROW_HIGH,x
        adc #0
        sta CELL+1      ; CELL: the top line of the cell, in the bitmap
        ldx #8          ; eight lines of pixels
        ldy #0
line:   lda (GLYPH),y   ; a line of the letter, eight pixels in a byte,
        sta (CELL),y    ; into the same line of the cell
        inc GLYPH       ; the next line of the letter is the next byte...
        bne same
        inc GLYPH+1
same:   clc             ; ...and the next line of the cell is 40 bytes on
        lda CELL
        adc #40
        sta CELL
        lda CELL+1
        adc #0
        sta CELL+1
        dex
        bne line
        rts

        .segment "RODATA"

; Where each row of letters begins: BITMAP + 320 x its number. The assembler
; works these out, as it did the lines of pixels in chapter 17.
ROW_LOW:
        .repeat 25, n
        .byte <(BITMAP + 320 * n)
        .endrepeat
ROW_HIGH:
        .repeat 25, n
        .byte >(BITMAP + 320 * n)
        .endrepeat
