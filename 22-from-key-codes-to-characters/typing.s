; Chapter 22: typing. The keyboard tells us which keys are down; the monitor
; wants the characters that someone types, one at a time, as they come from
; the Mac. Two routines:
;   typed     waits for the next character typed, on the keyboard or on the
;             Mac, and gives it in A. X and Y come back as they were.
;   no_keys   at the reset: no key is down yet.
;
; A key gives its character when it goes down: when it is in a report of the
; keyboard and has not given it yet. Its character comes from a table of the
; layout, layout-us.s, with AltGr, with Shift, or alone. A key held down
; gives its character again after half a second, then twenty times a second,
; until it comes up or another key goes down. Nothing in the computer counts
; time: we count the turns of the loop that waits for a byte.
;
; While typed waits, a cursor blinks where the next letter will go: its cell
; is turned over for a quarter of a second, then turned back for a quarter of
; a second, and so on (cursor, in console.s). It first shows after a quarter
; of a second of waiting, so that a line the Mac sends in one go never draws
; it, and it does not blink while a key is held down. typed turns the cell
; back before it gives a character: nothing else is ever written on the
; screen while the cursor shows.
;
; It needs serial.s, keyboard.s and console.s.

; The variables, in page zero, out of the way of the console, the monitor
; and the BASIC to come.
PRESSED = $E9           ; the keys down that have given their character, six bytes; 0: none
HELD    = $EF           ; the key that repeats while it stays down; 0: none
TIME    = $FB           ; turns of the wait, three bytes, counting up to zero
TYPED   = $FE           ; the character, while X and Y come back
SHOWN   = $FF           ; 1 while the cursor shows, 0 while its cell is as it was

; Time, in turns of the loop that waits: 20 cycles a turn, and the processor
; does 12,600,000 cycles a second. TIME starts at minus a number of turns and
; counts up: back at zero, the time is up. If a key is held down, it repeats;
; if not, the cursor blinks.
TURNS   = 12600000 / 20 ; 630,000 turns a second
FIRST   = TURNS / 2     ; half a second before a key held down repeats
AGAIN   = TURNS / 20    ; then twenty times a second
BLINK   = TURNS / 4     ; the cursor: a quarter of a second shown, a quarter hidden

        .segment "CODE"

typed:  txa
        pha
        tya
        pha             ; X and Y wait on the stack
        lda HELD
        bne look        ; a key held down: TIME counts towards its repetition
        jsr quarter     ; none: the cursor shows in a quarter of a second

; Has a key gone down, and not given its character yet?
look:   jsr fresh
        bcc wait        ; no
        beq look        ; yes, but it has no character: perhaps another
        jmp give

; Wait for a byte, from the Mac or from the keyboard's module, and count the
; turns meanwhile.
wait:   bit STATUS
        bmi mac         ; a byte from the Mac
        bit QUEUE
        bmi frame       ; a byte from the keyboard's module
        inc TIME        ; one more turn: TIME + 1, on three bytes
        bne wait
        inc TIME+1
        bne wait
        inc TIME+2
        bne wait
        .assert >* = >wait, error, "the loop must stay in one page: a branch to another page takes a cycle more"
        lda HELD        ; TIME is back to zero: the time is up
        beq blink       ; no key held down: the cursor's turn
        lda #<(-AGAIN)  ; the key held down gives its character again,
        sta TIME        ; and again a twentieth of a second later
        lda #>(-AGAIN)
        sta TIME+1
        lda #^(-AGAIN)
        sta TIME+2
        lda HELD
        jsr character
        beq wait        ; a key with no character
        jmp give

; The cursor's turn: its cell turned over, shown or hidden, for the next
; quarter of a second.
blink:  jsr quarter
        jsr cursor      ; console.s: the cell where the next letter will go
        lda SHOWN
        eor #1
        sta SHOWN       ; shown, or hidden again
        jmp wait

mac:    jsr receive     ; the byte from the Mac, as it came
        jmp give

; A byte from the keyboard's module: the frame it begins.
frame:  jsr report      ; carry clear: a report of the keyboard, in KEYS
        bcs wait        ; another kind of frame: nothing about the keys
        lda KEYS+2
        cmp #1
        beq wait        ; 01: too many keys down, and the report tells nothing
        jsr forget
        jmp look

; give: the character in A, X and Y as they were. If the cursor shows, its
; cell is turned back first: what comes next may write on the screen.
give:   sta TYPED
        lda SHOWN
        beq hidden      ; the cursor does not show
        jsr cursor      ; it does: its cell as it was
        lda #0
        sta SHOWN
hidden: pla
        tay
        pla
        tax
        lda TYPED
        rts

; quarter: TIME at a quarter of a second, until the cursor turns over.
quarter: lda #<(-BLINK)
        sta TIME
        lda #>(-BLINK)
        sta TIME+1
        lda #^(-BLINK)
        sta TIME+2
        rts

; fresh: is a key of the report down that has not given its character yet?
; Carry clear: no. Carry set: yes; it is now in PRESSED, it is the key that
; repeats, and A holds its character, 0 if it has none (Z tells which).
fresh:  ldx #2          ; the codes of the keys are KEYS+2 to KEYS+7
news:   lda KEYS,x
        cmp #4
        bcc older       ; 0: no key in this place (1 to 3 are not keys)
        ldy #5
search: cmp PRESSED,y
        beq older       ; this key has given its character
        dey
        bpl search
        ldy #0          ; a new key: into the first free place of PRESSED.
place:  ldx PRESSED,y   ; There is always one: PRESSED only holds keys of
        beq here        ; this report, and the new one is not among them.
        iny
        bne place
here:   sta PRESSED,y
        sta HELD        ; the key that repeats, from now on
        lda #<(-FIRST)
        sta TIME
        lda #>(-FIRST)
        sta TIME+1
        lda #^(-FIRST)
        sta TIME+2
        lda HELD
        jsr character
        sec             ; a new key
        rts
older:  inx
        cpx #8
        bne news
        clc             ; no new key
        rts

; forget: the keys that have come up leave PRESSED. If it was the key held
; down, nothing repeats, and the cursor shows in a quarter of a second.
forget: ldy #5
gone:   lda PRESSED,y
        beq kept        ; an empty place
        ldx #7
still:  cmp KEYS,x
        beq kept        ; still down
        dex
        cpx #1
        bne still
        cmp HELD        ; it has come up
        bne free
        lda #0
        sta HELD        ; it was the key held down
        jsr quarter
free:   lda #0
        sta PRESSED,y
kept:   dey
        bpl gone
        rts

; character: the character of the key whose code is in A, as the modifier
; keys say, from the tables of the layout; 0 if it has none. Z tells which.
character:
        cmp #101
        bcs none        ; past the tables
        tax
        lda KEYS        ; the modifier keys, one bit each
        and #%01000000  ; bit 6: the right Alt, AltGr
        bne altgr
        lda KEYS
        and #%00100010  ; bits 1 and 5: the left Shift, the right Shift
        bne shifted
        lda PLAIN,x
        rts
altgr:  lda ALTGR,x
        rts
shifted: lda SHIFTED,x
        rts
none:   lda #0
        rts

; no_keys: at the reset, no key is down yet. KEYS, SKIPPED, PRESSED and HELD
; follow one another, from $E0 to $EF: all at 0. And the cursor does not
; show: the screen is about to be cleared.
no_keys: lda #0
        ldx #HELD - KEYS
clean:  sta KEYS,x
        dex
        bpl clean
        sta SHOWN
        rts

        .segment "RODATA"

        .include "layout-us.s"
