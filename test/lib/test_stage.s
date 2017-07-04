    cpu	    6502
    output  scode
    ilist   on

STDIO=$fff9
EXIT=$0000

include lib/zero.s

	code
*=$8000
reset   lda #0
	sta pos
	lda #test_maps & $ff
	sta maps
	lda #test_maps >> 8
	sta maps + 1
	jsr stage_start
	lda #12
	sta step
.loop	jsr stage_next
	dec step
	bne .loop

	ldx #0
.write1	lda $0280, x
	sta STDIO
	inx
	bne .write1

	ldx #0
.write2	lda $0380, x
	sta STDIO
	inx
	bne .write2

	ldx #0
.write3	lda $0480, x
	sta STDIO
	inx
	bne .write3

	jmp EXIT

include lib/stage.s

test_maps=*
	dw  test_map
test_map=*
	ds  48, 0
include	test/lib/test_map.rle.s

*=$fffa
    dw  $0000
    dw	reset
    dw	$0000
