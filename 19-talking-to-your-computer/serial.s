; Chapter 19: the serial link, for the programs that use it. Two routines:
;   receive   waits until a byte has come from the Mac, and gives it in A.
;             X and Y are not touched.
;   send      waits until the byte before has gone out, and sends the byte in
;             A to the Mac. A, X and Y come back as they were.
; They only wait, reading the state of the link: nothing interrupts the
; processor when a byte comes.

SERIAL  = $8010         ; read: the byte that has arrived; write: a byte to send
STATUS  = $8011         ; bit 7 at 1: a byte has arrived; bit 6 at 1: a byte is going out

        .segment "CODE"

; receive: BIT copies bit 7 of STATUS into N, and changes no register. Reading
; SERIAL takes the byte: bit 7 goes back to 0 until the next one.
receive: bit STATUS
        bpl receive     ; N at 0: nothing has come yet
        lda SERIAL
        rts

; send: BIT copies bit 6 of STATUS into V. A byte stored while the one before
; is still going out would be lost, so we wait for V to be 0.
send:   bit STATUS
        bvs send        ; V at 1: the byte before is still going out
        sta SERIAL
        rts
