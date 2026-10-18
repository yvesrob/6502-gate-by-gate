; Chapter 22 uses the monitor from chapter 20. We can now type to it on the
; keyboard as well as on the Mac: get takes the next character from either
; (typing.s). Its table of jumps has two more, get and put, and its title is
; this chapter's. And Delete, or Backspace, now rubs the character out, on
; the screen and on the Mac: back one cell, a space, back again (delete).
; While get waits for a key, a cursor blinks where the next character will
; go (typing.s); it is never sent to the Mac.
; Chapter 20: our own monitor, the program of the board. We type to it from
; the Mac, one line at a time, and it answers on the screen and on the Mac.
; Each line is one command, in the notation of the Apple-1's monitor:
;
;   C108            show the byte at C108
;   C108.C10F       show the bytes from C108 to C10F, eight to a line
;   0300: A9 00     store A9 at 0300, 00 at 0301, and so on
;   : 8D 00 80      store more, where the last store stopped or a later show began
;   0300R           run the program at 0300, as a subroutine
;
; Numbers are in hexadecimal. An address is the last four digits of a number,
; a byte its last two. Spaces only separate. A line the monitor does not
; understand gets a ?, and the rest of it is left; the bytes before the
; mistake are stored all the same.
;
; Each character typed is written on the screen, then sent back to the Mac.
; Small letters become capitals. Delete, or Backspace, takes the last
; character back and rubs it out (in chapter 20 it showed _ instead); on an
; empty line it does nothing. Escape drops the whole line and shows \ ;
; Return does the line.
; Before each line the monitor writes *, its prompt: it is ready for the next
; one. tools/term.py and tools/send.py wait for it.
;
; Button S2 (NMI) adds one to FAST, which a program can read. Button S1 is the
; reset: the screen is cleared, and the monitor starts again; so does a BRK.
; The RAM keeps what it held.

LEDS    = $8000         ; a byte stored at this address appears on the LEDs

; The variables, in page zero. The console has its own, from $F0.
FAST    = $00           ; each NMI (S2) adds one; a program can read it
VALUE   = $01           ; the number being read, two bytes
DIGITS  = $03           ; how many digits it had
WHERE   = $04           ; where the next byte goes, two bytes
HERE    = $06           ; the byte being shown, two bytes

; The line, in page 2, as on the Apple-1: up to 127 characters, then the Return.
LINE    = $0200
LONGEST = 127

        .segment "CODE"

; The font begins the ROM, at $C000, as in chapter 18.
        .include "font.s"

; The table of jumps from chapter 19, just after the font. A program sent by
; the Mac calls the console and the serial link here, at addresses that stay.
        .assert * = $C2F8, error, "the table of jumps must begin at $C2F8"
        jmp clear       ; $C2F8
        jmp print       ; $C2FB
        jmp receive     ; $C2FE
        jmp send        ; $C301
        jmp get         ; $C304: chapter 22, so that a program can read keys
        jmp put         ; $C307: and write characters as the monitor does

        .include "console.s"
        .include "serial.s"
        .include "keyboard.s"
        .include "typing.s"

        .segment "CODE"         ; console.s ends in RODATA: back to CODE

reset:  ldx #$FF
        txs             ; S = $FF: the stack begins at $01FF, empty
        lda #0
        sta LEDS
        sta FAST
        jsr no_keys     ; no key is down yet
        lda #$E6        ; light blue ink, blue paper, as in chapters 17 to 19
        jsr clear
        ldx #0
title:  lda TEXT,x
        beq prompt      ; a 0 ends the text
        jsr put
        inx
        bne title

; A new line: the prompt, then the characters as they come, into LINE. Y
; counts them.
prompt: lda #'*'
        jsr put
        ldy #0
key:    jsr get
        cmp #'a'
        bcc capital     ; below a
        cmp #'z' + 1
        bcs capital     ; above z
        and #%11011111  ; a small letter: bit 5 at 0 makes it a capital
capital: cmp #13
        beq return      ; Return: do the line
        cmp #27
        beq escape      ; Escape: drop it
        cmp #8
        beq delete      ; Backspace, or
        cmp #127
        beq delete      ; Delete: take the last character back
        bcs key         ; above 127: nothing
        cmp #' '
        bcc key         ; another code below 32: nothing
        cpy #LONGEST
        beq key         ; the line is full: only Return, Delete and Escape now
        sta LINE,y
        iny
        jsr put         ; on the screen, and back to the Mac
        jmp key

delete: cpy #0
        beq key         ; nothing to take back
        dey
        lda #8          ; rub it out: back one cell,
        jsr put
        lda #' '        ; a space over the character,
        jsr put
        lda #8          ; and back again, where the next one will go
        jsr put
        jmp key

escape: lda #'\'
        jsr put
        jsr newline
        jmp prompt

return: sta LINE,y      ; the Return ends the line in LINE
        jsr newline
        jsr do
        jmp prompt      ; the line is done: the next one

; do: the command in LINE. It begins with a number, or with nothing before a
; colon; the character after the number says which command it is.
do:     ldy #0
        jsr number
        cmp #13
        beq one         ; the number alone, or nothing at all
        cmp #'.'
        beq block
        cmp #':'
        beq store
        cmp #'R'
        beq run
wrong:  lda #'?'        ; anything else: a mistake
        jsr put
        jmp newline

; One byte: show it, from the number to the number.
one:    lda DIGITS
        beq ok          ; an empty line: nothing to do
        jsr from
        jmp show

; A block: from the first number to the second.
block:  lda DIGITS
        beq wrong       ; no first address
        jsr from
        iny             ; past the dot
        jsr number
        cmp #13
        bne wrong       ; something after the second address
        lda DIGITS
        beq wrong       ; no second address
        jmp show

; Store: the number before the colon is where. Without one, the bytes go
; where the last store stopped, or a later show began. Then each number is a byte.
store:  lda DIGITS
        beq colon       ; no address: WHERE stays as it is
        lda VALUE
        sta WHERE
        lda VALUE+1
        sta WHERE+1
colon:  iny             ; past the colon
byte:   jsr number
        ldx DIGITS
        beq last        ; no number here: the line must end
        ldx #0
        lda VALUE       ; the last two digits
        sta (WHERE,x)   ; X at 0: the address in WHERE, as it is
        inc WHERE
        bne byte
        inc WHERE+1
        jmp byte
last:   cmp #13
        bne wrong
ok:     rts

; Run: JMP, not JSR. The program's RTS then comes back where do would have
; returned, and the monitor writes its prompt.
run:    lda DIGITS
        beq wrong       ; R without an address
        iny             ; past the R
        jsr spaces
        cmp #13
        bne wrong       ; something after the R
        jmp (VALUE)

; from: the number is where a block begins. A colon with no address will
; store from there too.
from:   lda VALUE
        sta HERE
        sta WHERE
        lda VALUE+1
        sta HERE+1
        sta WHERE+1
        rts

; show: the bytes from HERE to VALUE, eight to a line, each line beginning
; with the address of its first byte. If VALUE is below HERE, only one byte.
show:   lda HERE+1
        jsr hex
        lda HERE
        jsr hex
        lda #':'
        jsr put
next:   lda #' '
        jsr put
        ldx #0
        lda (HERE,x)    ; the byte at HERE
        jsr hex
        lda HERE        ; was it the last? HERE - VALUE, on two bytes:
        cmp VALUE       ; no borrow, the carry at 1, when HERE is not below
        lda HERE+1
        sbc VALUE+1
        bcc more
        jmp newline     ; that was the last one: end the line
more:   inc HERE
        bne along
        inc HERE+1
along:  lda HERE
        and #%00000111
        bne next        ; the same line, up to an address that ends in 0 or 8
        jsr newline
        jmp show

; number: a number in hexadecimal, from LINE at Y, with the spaces before and
; after it skipped. VALUE: the number, DIGITS: how many digits, 0 if none. A
; holds the character after it, and Y points at it.
number: lda #0
        sta VALUE
        sta VALUE+1
        sta DIGITS
        jsr spaces
digits: jsr digit
        bcs spaces      ; not a digit: skip the spaces after the number
        ldx #4
times:  asl VALUE
        rol VALUE+1     ; VALUE x 2, on two bytes, four times: x 16
        dex
        bne times
        ora VALUE       ; and the new digit in the four bits now at 0
        sta VALUE
        inc DIGITS
        iny
        lda LINE,y
        jmp digits

; spaces: Y past the spaces in LINE. A holds the character it stops on.
spaces: lda LINE,y
        cmp #' '
        bne stop
        iny
        jmp spaces
stop:   rts

; digit: is the character in A a hexadecimal digit, 0 to 9 or A to F? Carry
; clear: yes, and A holds its value, 0 to 15. Carry set: no, and A is unchanged.
digit:  cmp #'0'
        bcc no          ; below 0
        cmp #'9' + 1
        bcc decimal     ; 0 to 9
        cmp #'A'
        bcc no          ; between 9 and A
        cmp #'F' + 1
        bcs no          ; above F
        sbc #'A' - 10 - 1   ; the carry is 0 here: SBC takes one more away
        clc
        rts
decimal: sbc #'0' - 1   ; here too
        clc
        rts
no:     sec
        rts

; hex: the byte in A, as two hexadecimal digits.
hex:    pha
        lsr
        lsr
        lsr
        lsr             ; the high four bits
        jsr nibble
        pla
        and #%00001111  ; the low four bits
nibble: cmp #10
        bcc figure
        adc #'A' - 10 - 1   ; 10 to 15: A to F; the carry is 1 here
        jmp put
figure: adc #'0'        ; 0 to 9; the carry is 0 here
        jmp put

; newline: a carriage return and a line feed.
newline: lda #13
        jsr put
        lda #10
        jmp put

; The monitor reads every character typed through get, and writes every
; character through put: its two doors to the outside.

; get: the next character typed, in A, on the keyboard or on the Mac. X and Y
; come back as they were.
get:    jmp typed

; put: the character in A, on the screen, then to the Mac. A, X and Y come
; back as they were.
put:    jsr print
        jmp send

; nmi: button S2. One more in FAST; INC changes no register, and RTI gives the
; flags back.
nmi:    inc FAST
        rti

        .segment "RODATA"

TEXT:   .byte "Our Own 6502, Gate by Gate", 13, 10
        .byte "Chapter 22: From Key Codes to Characters"
        .byte 13, 10, 0         ; forty letters fill a row: the next stays empty

        .segment "VECTORS"
        .word nmi       ; $FFFA: NMI, button S2
        .word reset     ; $FFFC: the reset, button S1, and switching on
        .word reset     ; $FFFE: IRQ and BRK: a BRK in a program starts the monitor again
