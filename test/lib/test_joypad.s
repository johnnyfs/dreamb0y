    cpu    6502
    output scode
    ilist  on

STDIO=$4016
EXIT=$0000

include lib/zero.s

	code
*=$8000
reset	lda #0
        sta joypad_prev
        sta joypad_next
        ldy #15
.loop   jsr joypad_strobe
        lda joypad_prev
        sta STDIO
        lda joypad_next
        sta STDIO
        dey
        bne .loop
        jmp EXIT

include	lib/joypad.s

*=$fffa
    dw  $0000
    dw	reset
    dw	$0000
