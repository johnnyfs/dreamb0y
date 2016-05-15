    cpu    6502
    output scode

STDIO=$fff9
EXIT=$0000

include lib/zero.s

	code
*=$8000
reset	jsr status_load
	ldy #$40
	ldx #0
.1	lda $0500, x
	sta STDIO
	inx
	dey
	bne .1
	jmp EXIT

include lib/status.s
status_bar  ds 128, 1
	    ds 128, 2
*=$fffa
    dw  $0000
    dw	reset
    dw	$0000
