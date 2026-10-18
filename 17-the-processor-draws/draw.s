; Chapter 17: the program of the board draws on the screen. It clears the
; picture, then draws 128 straight lines, four at each step, each from a point
; of the top or bottom edge to a point of the left or right edge. No curve is
; drawn: the curves you see are where the straight lines cross. Then it
; changes the colors of the whole picture, eight times, without touching a
; pixel, and starts again.
;
; Since this chapter the picture is in the processor's memory:
;   $9C00-$9FE7   the colors: one byte for each cell of 8 x 8 pixels, 40
;                 cells across, 25 down. The four high bits are the ink, for
;                 the pixels at 1; the four low bits are the paper, for the
;                 pixels at 0.
;   $A000-$BF3F   the bitmap: one bit for each pixel, 40 bytes for each line
;                 of pixels, 200 lines. Bit 7 of a byte is its pixel on the left.
;
; The six LEDs show the step: 1 to 32 while the lines are drawn, 33 to 40
; while the colors change. Between two steps the program waits, so that we
; can watch. Button S2 (NMI): no more waiting, the rest of the lines at full
; speed. Button S1 is the reset: everything starts again.

LEDS    = $8000         ; a byte stored at this address appears on the LEDs
COLORS  = $9C00         ; the two colors of each cell
BITMAP  = $A000         ; the pixels

; The variables of the program, in page zero.
PX      = $00           ; the pixel that plot lights: x, 0 to 319, two bytes
PY      = $02           ; and y, 0 to 199
ADDR    = $03           ; an address, two bytes, for (ADDR),y
X0      = $05           ; a line goes from (X0, Y0), x on two bytes...
Y0      = $07
X1      = $08           ; ...to (X1, Y1)
Y1      = $0A
DX      = $0B           ; how far x goes, two bytes: 0 or more
DY      = $0D           ; how far y goes, two bytes, as a number: 0 or less
SX      = $0F           ; which way x goes, two bytes: +1, or -1 ($FFFF)
SY      = $11           ; which way y goes: +1, or -1 ($FF)
ERR     = $12           ; the error, two bytes
E2      = $14           ; twice the error, two bytes
XL      = $16           ; the drawing: x of the points on the top and bottom
                        ; edges, from the left, two bytes
XR      = $18           ; the same from the right, 319 - XL, two bytes
YU      = $1A           ; y of the points on the left and right edges, from the bottom
YD      = $1B           ; the same from the top, 199 - YU
FAST    = $1C           ; 0: wait between two steps. Each NMI (S2) adds one
TIME    = $1D           ; for wait

        .segment "CODE"

reset:  ldx #$FF
        txs             ; S = $FF: the stack begins at $01FF, empty

; A round: a blank picture, 32 steps of four lines, eight changes of colors.
round:  lda #0
        sta LEDS        ; step 0
        sta FAST        ; S2 has not been pressed in this round
        lda #$E6        ; light blue ink, blue paper: a Commodore 64 switched on
        jsr paint       ; in every cell
        lda #>BITMAP
        sta ADDR+1
        ldx #32         ; 32 pages of 256 bytes, $A000 to $BFFF
        lda #0          ; every pixel at 0: paper
        jsr fill
        lda FAST
        bne first       ; S2 was pressed: no waiting
        lda #20
        jsr wait        ; the blank picture, about half a second

; The ends of the first four lines.
first:  lda #0
        sta XL
        sta XL+1        ; XL = 0
        lda #<319
        sta XR
        lda #>319
        sta XR+1        ; XR = 319
        lda #199
        sta YU          ; YU = 199
        lda #0
        sta YD          ; YD = 0

step:   ldx LEDS
        inx
        stx LEDS        ; one more step on the LEDs, which can be read back

; From the top edge to the left edge: (XL, 0) to (0, YU).
        lda XL
        sta X0
        lda XL+1
        sta X0+1
        lda #0
        sta Y0
        sta X1
        sta X1+1
        lda YU
        sta Y1
        jsr line
; From the bottom edge to the left edge: (XL, 199) to (0, YD).
        lda #199
        sta Y0
        lda YD
        sta Y1
        jsr line
; From the bottom edge to the right edge: (XR, 199) to (319, YD).
        lda XR
        sta X0
        lda XR+1
        sta X0+1
        lda #<319
        sta X1
        lda #>319
        sta X1+1
        jsr line
; From the top edge to the right edge: (XR, 0) to (319, YU).
        lda #0
        sta Y0
        lda YU
        sta Y1
        jsr line

; The ends of the next four: XL and XR move 10 pixels along the top and
; bottom edges, YU and YD 6 along the sides.
        clc
        lda XL
        adc #10
        sta XL
        lda XL+1
        adc #0
        sta XL+1        ; XL = XL + 10
        sec
        lda XR
        sbc #10
        sta XR
        lda XR+1
        sbc #0
        sta XR+1        ; XR = XR - 10
        sec
        lda YU
        sbc #6
        sta YU          ; YU = YU - 6
        clc
        lda YD
        adc #6
        sta YD          ; YD = YD + 6

        lda FAST
        bne next        ; S2 was pressed: no waiting
        lda #10
        jsr wait        ; about a quarter of a second
next:   lda LEDS
        cmp #32
        bne step        ; 32 steps

; The lines are drawn. Now only the colors change: 1,024 bytes, and not one
; byte of the bitmap.
        lda #$10        ; white on black
        jsr recolor
        lda #$70        ; yellow on black
        jsr recolor
        lda #$D5        ; light green on green
        jsr recolor
        lda #$A2        ; light red on red
        jsr recolor
        lda #$3B        ; cyan on dark gray
        jsr recolor
        lda #$F4        ; light gray on purple
        jsr recolor
        lda #$0F        ; black on light gray
        jsr recolor
        lda #$16        ; white on blue
        jsr recolor
        jmp round

; recolor: one more step on the LEDs, the byte in A in every cell, then
; about a second to look at it.
recolor:
        ldx LEDS
        inx
        stx LEDS
        jsr paint
        lda #40
        jsr wait
        rts

; paint: the byte in A in every cell: 4 pages, $9C00 to $9FFF.
paint:  ldx #>COLORS
        stx ADDR+1
        ldx #4
        jsr fill
        rts

; fill: the byte in A, in X pages of 256 bytes, from the page in ADDR+1.
fill:   ldy #0
        sty ADDR        ; from the first byte of the page
page:   sta (ADDR),y
        iny
        bne page        ; the rest of this page
        inc ADDR+1
        dex
        bne page        ; the next page
        rts

; line: the pixels of a straight line from (X0, Y0) to (X1, Y1), both ends
; included. Bresenham's algorithm, in the form Alois Zingl gives for every
; direction. ERR says how far the pixel is from the true line, x and y
; together. At each pixel, x moves if that brings us closer, y moves if that
; brings us closer, and on a slant both do.
line:   lda X0
        sta PX
        lda X0+1
        sta PX+1
        lda Y0
        sta PY          ; we start at (X0, Y0)

; DX: how far x goes. SX: which way.
        lda #1
        sta SX
        lda #0
        sta SX+1        ; SX = +1, for now: x goes right
        sec
        lda X1
        sbc X0
        sta DX
        lda X1+1
        sbc X0+1
        sta DX+1        ; DX = X1 - X0
        bpl across      ; 0 or more: right it is
        sec
        lda #0
        sbc DX
        sta DX
        lda #0
        sbc DX+1
        sta DX+1        ; DX = 0 - DX: 0 or more
        lda #$FF
        sta SX
        sta SX+1        ; SX = -1: x goes left
across:

; DY: how far y goes, as a number 0 or less. SY: which way.
        sec
        lda Y1
        sbc Y0
        sta DY
        lda #0
        sbc #0
        sta DY+1        ; DY = Y1 - Y0, on two bytes
        bmi up          ; below 0: y goes up, and DY is as we want it
        sec
        lda #0
        sbc DY
        sta DY
        lda #0
        sbc DY+1
        sta DY+1        ; DY = 0 - DY: 0 or less
        lda #1
        sta SY          ; SY = +1: y goes down
        jmp start
up:     lda #$FF
        sta SY          ; SY = -1: y goes up

start:  clc
        lda DX
        adc DY
        sta ERR
        lda DX+1
        adc DY+1
        sta ERR+1       ; ERR = DX + DY

pixel:  jsr plot        ; light (PX, PY)
        lda PX
        cmp X1
        bne on
        lda PX+1
        cmp X1+1
        bne on
        lda PY
        cmp Y1
        bne on
        rts             ; we are at (X1, Y1): the line is done

on:     lda ERR
        asl a
        sta E2
        lda ERR+1
        rol a
        sta E2+1        ; E2 = ERR x 2

; If E2 >= DY, x moves: ERR = ERR + DY, and PX = PX + SX.
        sec
        lda E2
        sbc DY
        lda E2+1
        sbc DY+1        ; E2 - DY: only its sign matters
        bmi no_x        ; below 0: x stays
        clc
        lda ERR
        adc DY
        sta ERR
        lda ERR+1
        adc DY+1
        sta ERR+1
        clc
        lda PX
        adc SX
        sta PX
        lda PX+1
        adc SX+1
        sta PX+1
no_x:

; If E2 <= DX, y moves: ERR = ERR + DX, and PY = PY + SY.
        sec
        lda DX
        sbc E2
        lda DX+1
        sbc E2+1        ; DX - E2: only its sign matters
        bmi pixel       ; below 0: y stays
        clc
        lda ERR
        adc DX
        sta ERR
        lda ERR+1
        adc DX+1
        sta ERR+1
        clc
        lda PY
        adc SY
        sta PY
        jmp pixel

; plot: light the pixel at (PX, PY), and leave the other seven pixels of its
; byte as they are.
plot:   lda PX+1        ; x is 0 to 319, nine bits:
        lsr a           ; its bit 8 goes into the carry...
        lda PX
        ror a           ; ...and comes in at the top: x / 2
        lsr a
        lsr a           ; x / 8: the byte of the line, 0 to 39
        ldy PY
        clc
        adc LINE_LOW,y  ; plus the address where line PY begins
        sta ADDR
        lda LINE_HIGH,y
        adc #0
        sta ADDR+1
        lda PX
        and #%00000111  ; x mod 8: which pixel of the byte
        tax
        lda BITS,x      ; its bit
        ldy #0
        ora (ADDR),y    ; with the pixels already lit in that byte
        sta (ADDR),y
        rts

; wait: about A x 26 milliseconds, doing nothing else.
wait:   sta TIME
again:  ldx #0
        ldy #0
loop:   dex
        bne loop        ; 256 times
        dey
        bne loop        ; 256 times that
        dec TIME
        bne again
        rts

; nmi: button S2. Until the next round, the steps do not wait. INC changes
; no register, and RTI gives the flags back.
nmi:    inc FAST
        rti

        .segment "RODATA"

; Where each of the 200 lines of pixels begins: BITMAP + 40 x its number.
; The assembler works these out, not the processor: .repeat writes the line
; between it and .endrepeat 200 times, with n = 0, 1, 2...
LINE_LOW:
        .repeat 200, n
        .byte <(BITMAP + 40 * n)
        .endrepeat
LINE_HIGH:
        .repeat 200, n
        .byte >(BITMAP + 40 * n)
        .endrepeat

; The bit of each pixel in its byte: the pixel on the left is bit 7.
BITS:   .byte %10000000, %01000000, %00100000, %00010000
        .byte %00001000, %00000100, %00000010, %00000001

        .segment "VECTORS"
        .word nmi       ; $FFFA: NMI, button S2
        .word reset     ; $FFFC: the reset, button S1, and switching on
        .word reset     ; $FFFE: IRQ and BRK, which nothing asks for here
