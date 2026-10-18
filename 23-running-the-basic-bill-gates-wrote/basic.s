; Chapter 23: Microsoft BASIC on our computer.
;
; The BASIC is not ours. It is the BASIC that Microsoft wrote for the 6502 in
; the 1970s, as Michael Steil and others rebuilt it for the assembler ca65:
; the source mist64/msbasic, which makes, byte for byte, the BASIC of nine
; machines of the time. make fetches it into build/msbasic; we change none of
; its files.
;
; This file is what we write. It tells that source which BASIC to make and
; where our computer keeps things, and it gives the BASIC the three routines
; that it asks of every machine: one writes a character, one reads a key, one
; says whether to stop. The linker puts it all at $D000 (basic.cfg), and
; tools/rom.py lays it into the ROM next to the monitor. From the monitor,
; D000R starts it.

; Which BASIC: the choices of Microsoft's source of 1978 when it is set for
; neither a Commodore nor an Apple, with the fixes up to that version.
CONFIG_2A               := 1    ; the version of 1978
CONFIG_NULL             := 1    ; NULL: zeros after each line, for slow teletypes
CONFIG_SAFE_NAMENOTFOUND := 1   ; check both bytes of an address on the stack
CONFIG_PEEK_SAVE_LINNUM := 1    ; PEEK gives back the two bytes it borrows
CONFIG_SCRTCH_ORDER     := 2    ; at the start, clear the program after BYTES FREE
; Left out: CONFIG_SMALL_ERROR, the errors in two letters, ?SN ERROR: we keep
; the long ones, ?SYNTAX ERROR, as the KIM-1 and the Commodores had them. And
; CONFIG_PRINT_CR: with it, the BASIC writes a carriage return and a line feed
; itself when a line of 40 is full; our console already goes to the next row
; after the 40th letter, as the screen of a Commodore did, and the two
; together would leave an empty row.

; Page zero: the BASIC takes $01 to $DD. $00 is the monitor's FAST, which S2
; counts up: the BASIC reads it to know when to stop (ISCNTC, below). Above
; $DD, the keyboard and the console keep their own.
ZP_START1       = $01           ; ten bytes of jumps that the BASIC sets up
ZP_START3       = $0B           ; eleven bytes of flags
ZP_START2       = $16           ; six bytes, then the line typed, from $1C
ZP_START4       = $64           ; the rest, then CHRGET, copied to $C1 at the start
USR             := $0280        ; the jump of USR(), after the monitor's line in page 2

; The stack and the program.
STACK_TOP       := $FE          ; the stack starts at $01FE, as in Microsoft's source
SPACE_FOR_GOSUB := $3E          ; room kept on the stack, as in Microsoft's source
NULL_MAX        := $F0          ; the limit that NULL checks, as in Microsoft's source
RAMSTART2       := $0300        ; the program's room starts at $0300, after page 2
WIDTH           := 40           ; our screen: 40 letters to a row,
WIDTH2          := 28           ; and the last column where a comma may start a field

; No tape and no disk: LOAD and SAVE stop with ?ILLEGAL QUANTITY ERROR.
LOAD            := IQERR
SAVE            := IQERR

; What the BASIC uses of the monitor: the two routines from chapter 20, at
; their places in the table of jumps, and the count of S2.
get             = $C304         ; the next key typed, in A
put             = $C307         ; the character in A, on the screen and to the Mac
FAST            = $00

; MONCOUT: the BASIC writes each character through it. put keeps A, X and Y,
; as the BASIC wants.
MONCOUT         := put

        .include "msbasic.s"

        .segment "HEADER"       ; the first bytes of the BASIC, at $D000
        jmp COLD_START          ; D000R: the BASIC starts afresh

        .segment "EXTRA"        ; our routines, after the BASIC

; MONRDKEY: wait for a key and give it in A, as Microsoft's line reader wants
; it; X and Y stay as they were. The reader keeps the keys but does not write
; them, so we write them here. X is where the reader is in its line: 0 while
; the line is empty.
MONRDKEY:
        jsr get
        pha
        lda #0
        sta FAST        ; a key: S2 pressed before it is forgotten
        pla
        cmp #'a'
        bcc capital     ; below a
        cmp #'z' + 1
        bcs capital     ; above z
        and #%11011111  ; a small letter: bit 5 at 0 makes it a capital
capital: cmp #8
        beq delete      ; Backspace,
        cmp #127
        beq delete      ; Delete,
        cmp #'_'
        beq delete      ; or Microsoft's own _
        cmp #27
        bne printable
        lda #'@'        ; Escape: Microsoft's @, which drops the line
        bne echo
delete: cpx #0
        beq MONRDKEY    ; an empty line: nothing to take back, and nothing written
        lda #8          ; rub the character out (chapter 22): back one cell,
        jsr put
        lda #' '        ; a space over it,
        jsr put
        lda #8          ; and back again
        jsr put
        lda #'_'        ; then Microsoft's _, which takes it out of the line,
        rts             ; unwritten
printable: cmp #' '
        bcc done        ; Return and the other codes below 32: not written
echo:   jsr put
done:   rts

; ISCNTC: has S2 been pressed since the last key? The BASIC asks before each
; statement, and before each line that LIST writes. If it has, the BASIC
; stops: it writes BREAK, keeps the program, and waits for a line. FAST goes
; back to 0 with the next key (MONRDKEY).
ISCNTC: lda FAST
        bne pressed
        rts
pressed: lda #0         ; A at 0 and the carry at 1: STOP takes it for a break
        sec
        jmp STOP
