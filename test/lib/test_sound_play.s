	cpu	6502
	output	scode
	ilist	ON

STDIO=$fff9	; run6502 i/o vector; reads/writes from/to stdio
EXIT=$0000	; run6502 designated halt vector; if pc==EXIT, the emulator quits

include lib/zero.s

*=$8000
	code
reset	lda	#test_theme & $ff
	sta	sound_theme
	lda	#test_theme >> 8
	sta	sound_theme + 1
	jsr	sound_start_theme
	jsr	dump_frame
	jsr	sound_advance
	jsr	dump_frame
	jmp	EXIT

	code
dump_frame	lda	sound_sq1 + sound_chain_idx
		sta	STDIO
		lda	sound_sq1 + sound_chain_wait
		sta	STDIO
		lda	$4000
		sta	STDIO
		lda	$4001
		sta	STDIO
		lda	$4002
		sta	STDIO
		lda	$4003
		sta	STDIO
		lda	#'!'
		sta	STDIO
		sta	STDIO
		rts

include	lib/sound.s

test_theme	dw	test_instr1, 0, 0, 0
		dw	test_chain1, 0, 0, 0

test_instr1	db	%00111111, 0, 0, %11011111	

test_chain1	db	C3, WN, B2, QN, SOUND_CMD_REPEAT

*=$fffa
    dw  $0000
    dw	reset
    dw	$0000
