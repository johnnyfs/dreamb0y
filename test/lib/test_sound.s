	cpu	6502
	output	scode
	ilist	on

STDIO=$fff9	; run6502 i/o vector; reads/writes from/to stdio
EXIT=$0000	; run6502 designated halt vector; if pc==EXIT, the emulator quits

include	lib/zero.s

*=$8000
	code
reset	lda	#$ff	; fill zero page with $ff so 0-writes stand out
	ldy	#0
.mark_z	sta	0, y
	iny
	bne	.mark_z
	lda	#test_theme1 & $ff
	sta	sound_theme
	lda	#test_theme1 >> 8
	sta	sound_theme + 1
	jsr	sound_start_theme
	jsr	write_sound_zp

	lda	#test_theme2 & $ff
	sta	sound_theme
	lda	#test_theme2 >> 8
	sta	sound_theme + 1
	jsr	sound_start_theme
	jsr	write_sound_zp

	lda	#test_theme3 & $ff
	sta	sound_theme
	lda	#test_theme3 >> 8
	sta	sound_theme + 1
	jsr	sound_start_theme
	jsr	write_sound_zp

	lda	#test_theme4 & $ff
	sta	sound_theme
	lda	#test_theme4 >> 8
	sta	sound_theme + 1
	jsr	sound_start_theme
	jsr	write_sound_zp

	lda	#test_theme5 & $ff
	sta	sound_theme
	lda	#test_theme5 >> 8
	sta	sound_theme + 1
	jsr	sound_start_theme
	jsr	write_sound_zp

	lda	#test_theme6 & $ff
	sta	sound_theme
	lda	#test_theme6 >> 8
	sta	sound_theme + 1
	jsr	sound_start_theme
	jsr	write_sound_zp

	jmp	EXIT

	code
write_sound_zp	ldy	#0
		ldx	#SOUND_DATA_SIZE + 12 ; + extra bytes to align xxd
.next		lda	sound_theme, y
		sta	STDIO
		iny
		dex
		bne	.next

		rts

;; Include this before the code so code length changes don't break the test
test_theme1	dw	test_instr1, test_instr2, test_instr3, test_instr4
		dw	test_chain1, test_chain2, test_chain3, test_chain4 
test_theme2	dw	test_instr4, test_instr2, test_instr1, test_instr3
		dw	test_chain2, test_chain1, test_chain4, test_chain3
test_theme3	dw	test_instr1, test_instr2, 0, test_instr4
		dw	test_chain1, test_chain2, test_chain3, 0
test_theme4	dw	0, test_instr2, test_instr3, test_instr4
		dw	test_chain1, test_chain2, test_chain3, 0
test_theme5	dw	test_instr1, test_instr2, test_instr3, 0
		dw	0, 0, 0, 0
test_theme6	dw	0, 0, 0, 0
		dw	0, 0, 0, 0

test_instr1	db	$00, $01, $02, $03
test_instr2	db	$04, $05, $06, $07
test_instr3	db	$08, $09, $0A, $0B
test_instr4	db	$0C, $0D, $0E, $0F

test_chain1	dw	$00
test_chain2	dw	$00
test_chain3	dw	$00
test_chain4	dw	$00

include	lib/sound.s


*=$fffa
    dw  $0000
    dw	reset
    dw	$0000
