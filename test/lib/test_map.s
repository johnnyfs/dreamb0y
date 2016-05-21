    cpu    6502
    output scode

include lib/zero.s

STDIO=$fff9
EXIT=$0000

	code
*=$8000
reset	lda	#testmap & $ff
	sta	src
	lda	#(testmap >> 8) & $ff
	sta	src + 1
	jsr	map_load
	ldx	#0
.1	lda	$0200, x
	sta	STDIO
	inx
	bne	.1
	ldx	#0
.2	lda	$0300, x
	sta	STDIO
	inx
	bne	.2
	ldx	#0
.3	lda	$0400, x
	sta	STDIO
	inx
	bne	.4
	ldx	#0
.4	lda	$0500, x
	sta	STDIO
	inx
	bne	.4
	jmp	EXIT

include lib/map.s

testmap=*
include test/lib/test_map.rle.s

*=$fffa
    dw  $0000
    dw	reset
    dw	$0000
