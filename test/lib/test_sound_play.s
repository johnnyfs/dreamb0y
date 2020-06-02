	cpu	6502
	output	scode
	ilist	ON

STDIO=$fff9	; run6502 i/o vector; reads/writes from/to stdio
EXIT=$0000	; run6502 designated halt vector; if pc==EXIT, the emulator quits

include lib/zero.s

*=$8000
	code
reset	lda	#test_theme & $ff
	sta	snd_theme
	lda	#test_theme >> 8
	sta	snd_theme + 1
	jsr	snd_start_theme ; WAIT should be 0 initially w/ channels clear
	jsr	dump_frame	
	jsr	snd_advance     ; Now it should be 127 (whole note) w/ C3 (idx 2) playing
	jsr	dump_frame
	jsr	snd_advance	  ; Now it should be 126 w/ C3 still playing
	jsr	dump_frame
	ldy	#WN - 1           ; (126 -- so we'll advance until wait==0)
.ffw_1	jsr	snd_advance
	dey
	bne	.ffw_1
	jsr	dump_frame	  ; Should be last frame of C3
	jsr	snd_advance
	jsr	dump_frame	  ; Now we should be starting note B2 (idx 4)
	ldy	#QN + 1	          ; Skip the entire note this time
.ffw_2	jsr	snd_advance
	dey
	bne	.ffw_2
	jsr	dump_frame	  ; Now we shoule be back at the start of C3
	jmp	EXIT

	code

dump_frame	ldx	#SND_CHAIN_SIZE * 2
		ldy	#0
.dump_ch	lda	snd_chains, y
		sta	STDIO
		iny
		dex
		bne	.dump_ch

		lda	#$ff    ; readability coda
		sta	STDIO
		sta	STDIO

		ldx	#8
		ldy	#0
.dump_regs	lda	$4000, y
		sta	STDIO
		iny
		dex
		bne	.dump_regs

		lda	#$ff    ; readability coda
		sta	STDIO
		sta	STDIO
		rts

; Data before includes so that code changes don't change these indexes.
test_theme	dw	test_instr1, test_instr1, 0, 0
		dw	test_chain1, test_chain2, 0, 0

test_instr1	db	%00111111, 0, 0, %11011111	

test_chain1	db	C3, WN, B2, QN, SND_CMD_REPEAT
test_chain2	db	C4, WN, B3, QN, SND_CMD_REPEAT


include	lib/sound.s

*=$fffa
    dw  $0000
    dw	reset
    dw	$0000
