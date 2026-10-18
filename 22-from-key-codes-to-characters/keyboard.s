; Chapter 21: the keyboard, for the programs that use it. The keyboard is
; plugged into a module whose chip, the CH9350, asks it which keys are down
; and sends us its answers, a byte at a time, as the Mac does. The bytes wait
; in a queue in the circuit until the processor takes them. Two routines:
;   take     waits until a byte has come from the module, and gives it in A.
;            X and Y are not touched.
;   report   reads the next frame. Carry clear: it was a report of the
;            keyboard, and its eight bytes are in KEYS. Carry set: it was
;            another kind, and it was skipped. It changes A and X; Y is not
;            touched.
;
; The module sends frames. Each begins with two bytes, 57 and AB, then one
; that says what the frame carries, then what it carries:
;   57 AB 01, then 8 bytes: a report of the keyboard
;   57 AB 02, then 4 bytes: a report of the mouse
;   57 AB 80, then 1 byte:  a state of the module
;   anything else: nothing more that we know of
; A report of the keyboard is the modifier keys, one bit each (bit 0, the
; left Control; bit 1, the left Shift...), a byte at 0, then the codes of up
; to six keys held down; a code at 0 is no key. The codes are those of the
; USB: 04 is the key A, 14 the key Q, 2C the space bar. They are keys, not
; letters.
;
; report skips the other frames by counting their bytes: the bytes of the
; mouse can be 57 and AB too, and we must not take them for the start of a
; frame. A byte that cannot begin a frame is skipped too, and counted in
; SKIPPED: when that count moves, we had lost our place in the frames.

KEYBOARD = $8020        ; read: the first byte in the queue; reading takes it
QUEUE    = $8021        ; bit 7 at 1: at least one byte waits in the queue

; The keyboard's variables, just below the console's.
KEYS    = $E0           ; the last report of the keyboard, eight bytes
SKIPPED = $E8           ; bytes that did not begin a frame, counted up to 255, then 0

        .segment "CODE"

; take: BIT copies bit 7 of QUEUE into N. Reading KEYBOARD takes the byte:
; the next one in the queue comes up.
take:   bit QUEUE
        bpl take        ; N at 0: the queue is empty
        lda KEYBOARD
        rts

; report: the next frame, and what it carries.
report: jsr take
seek:   cmp #$57
        beq header      ; perhaps the start of a frame
        inc SKIPPED     ; not a start: skip it
        jmp report
header: jsr take
        cmp #$AB
        beq kind        ; 57 AB: a frame begins
        inc SKIPPED     ; the 57 began nothing...
        jmp seek        ; ...but this byte may
kind:   jsr take        ; what the frame carries
        cmp #$01
        beq keep        ; the keyboard
        ldx #4
        cmp #$02
        beq pass        ; the mouse: 4 bytes to skip
        ldx #1
        cmp #$80
        beq pass        ; a state: 1 byte
        sec             ; anything else: nothing more that we know of
        rts
pass:   jsr take
        dex
        bne pass
        sec             ; not the keyboard's
        rts

; The keyboard's eight bytes, into KEYS.
keep:   ldx #0
keeping: jsr take
        sta KEYS,x
        inx
        cpx #8
        bne keeping
        clc             ; the keyboard's
        rts
