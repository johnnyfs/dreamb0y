;;;
;;; Loads and advances the current musical theme & mixes in
;;; sound effects as needed.
;;;

SOUND_CH_REGS=$4000 ;; PPU channel registers start at $4000
SOUND_REGS_PER_CH=4 ;; 4 registers per channel

	;; Note pitch indeces
A1	equ	0
Bb1	equ	1
B1	equ	2
C1	equ	3
Db1	equ	4
D1	equ	5
Eb1	equ	6
E1	equ	7
F1	equ	8
Gb1	equ	9
G1	equ	10
Ab1	equ	11
A2	equ	12
Bb2	equ	13
B2	equ	14
C2	equ	15
Db2	equ	16
D2	equ	17
Eb2	equ	18
E2	equ	19
F2	equ	20
Gb2	equ	21
G2	equ	22
Ab2	equ	23
A3	equ	24
As3	equ	25
Bb3	equ	25
B3	equ	26
C3	equ	27
Cs3	equ	28
Db3	equ	28
D3	equ	29
Ds3	equ	30
Eb3	equ	30
E3	equ	31
F3	equ	32
Fs3	equ	33
Gb3	equ	33
G3	equ	34
Gs3	equ	35
Ab3	equ	35
A4	equ	36
As4	equ	37
Bb4	equ	37
B4	equ	38
C4	equ	39
Cs4	equ	40
Db4	equ	40
D4	equ	41
Ds4	equ	42
Eb4	equ	42
E4	equ	43
F4	equ	44
Fs4	equ	45
Gb4	equ	45
G4	equ	46
Gs4	equ	47
Ab4	equ	47
A5	equ	48
As5	equ	49
Bb5	equ	49
B5	equ	50
C5	equ	51
Db5	equ	52
D5	equ	53
Eb5	equ	54
E5	equ	55
F5	equ	56
Gb5	equ	57
G5	equ	58
Ab5	equ	59
A6	equ	60
Bb6	equ	61
B6	equ	62
C6	equ	64
Db6	equ	64
D6	equ	65
Eb6	equ	66
E6	equ	67
F6	equ	68
Gb6	equ	69
G6	equ	70
Ab6	equ	71
A7	equ	72
Bb7	equ	73
B7	equ	74
C7	equ	75
Db7	equ	76
D7	equ	77
Eb7	equ	78
E7	equ	79
F7	equ	80
Gb7	equ	81
G7	equ	82
Ab7	equ	83
A8	equ	84
Bb8	equ	85
B8	equ	86
C8	equ	87
Db8	equ	88
D8	equ	89
Eb8	equ	90
E8	equ	91
F8	equ	92
Gb8	equ	93

;; Note duration (notes play until -1, so all values are 2^x-1)
WN	equ	127	; whole note
HN	equ	63	; half note
QN	equ	31	; quarter note
EN	equ	15	; eighth note
SN	equ	7	; sixteenth note
TN	equ	3	; thirty-second note
XN	equ	1	; sixty-fourth note
YN	equ	0	; thirty-second note
;; Effects flags (high 3 bits)
       ;; TBD

; Commands (mutually exclusive with notes, indicated by high bit
SOUND_CMD_FLAG		equ	%10000000
SOUND_CMD_REPEAT	equ	(SOUND_CMD_FLAG|0)	; return to beginning of chain

;; Advance the indexed sound channel
;; MACRO \1:channel
;;   channel: the index 0-3 of sq1, sq2, tri, and noi
SOUND_CHANNEL_ADVANCE	MACRO
			;; Do nothing if there is no chain for this channel
			lda	sound_chains + 2 * \1
			beq	.done_\1
			;; Count back duration to (-1)
			dec	sound_channels + SOUND_CHANNEL_SIZE * \1 + sound_chain_wait
			bpl	.done_\1
			;; Advance the index into the channel
			ldy	sound_channels + SOUND_CHANNEL_SIZE * \1 + sound_chain_idx
			;; High bid set => process command; otherwise => play note
.repeat_\1		lda	(sound_chains + 2 * \1), y
			bmi	.do_command_\1

			;; Start the note
			IF \1 < 3	; noise channel period is copied straight
			clc
			adc	sound_instrs + SOUND_INSTR_SIZE * \1 + sound_instr_transpose
			asl	; tbl offset = (index + transpose) * 2 byte ptr with
			ENDC
			tax

			;; Set the duty/volume register (TODO: impl envelope for sq/noise)
			lda	sound_instrs + SOUND_INSTR_SIZE * \1 + sound_instr_dut_len_vol
			sta	SOUND_CH_REGS + \1 * SOUND_REGS_PER_CH

			;; Set the sweep register
			;; TODO: why does this mute channel 2?
			;IF \1 < 2
				;lda	sound_instrs + SOUND_INSTR_SIZE * \1 + sound_instr_sweep
				;sta	SOUND_CH_REGS + \1 * SOUND_REGS_PER_CH + 1
			;ENDC

			;; Set the pitch
			IF \1 < 3 ; sq1/2 + triangle: look up the note value
				lda	sound_pitches, x	; load low byte of pitch
				sta	SOUND_CH_REGS + \1 * SOUND_REGS_PER_CH + 2
				inx
				lda	sound_pitches, x	; load high byte
				;; Mix in length load (TODO: do we want this?)
				ora	sound_instrs + SOUND_INSTR_SIZE * \1 + sound_instr_len_load
				sta	SOUND_CH_REGS + \1 * SOUND_REGS_PER_CH + 3
			ELSE ; noise channel: no lookup, just copy the period in
				txa
				ora	sound_instrs + SOUND_INSTR_SIZE * \1 + sound_instr_noi_mode
				sta	SOUND_CH_REGS + \1 * SOUND_REGS_PER_CH + 2
				lda	sound_instrs + SOUND_INSTR_SIZE * \1 + sound_instr_len_load
				sta	SOUND_CH_REGS + \1 * SOUND_REGS_PER_CH + 3
			ENDC

			;; Set the duration
			iny
			beq	.hang_\1
			lda	(sound_chains + 2 * \1), y
			sta	sound_channels + SOUND_CHANNEL_SIZE * \1 + sound_chain_wait

			;; Advance to next note/command
			iny
			beq	.hang_\1
			sty	sound_channels + SOUND_CHANNEL_SIZE * \1 + sound_chain_idx
			bne	.done_\1

.hang_\1		jmp	.hang_\1	; for now just crash out

			;; Handle a command
.do_command_\1		cmp	#SOUND_CMD_REPEAT
			bne	.hang_\1	; crash on unrecognized commands
			ldy	#0
			beq	.repeat_\1
.done_\1		nop			; TODO: be smarter
			ENDM

; Load a theme and prepare the engine to play it
			code
sound_start_theme 	lda	#sound_noi_instr & $ff
			sta	dst	; start writing at last instr
			lda	#sound_noi_instr >> 8
			sta	dst + 1

			ldy	#7	; 4 channels * 2 bytes per instr ptr - 1
.next_instr_ptr		lda	(sound_theme), y	; ptr for instr1
			beq	.null_instr
			sta	src + 1
			dey
			lda	(sound_theme), y
			sta	src	; start reading w/ pointer to last instrument

			tya		; save our index into *theme*
			tax
			ldy	#SOUND_INSTR_SIZE - 1	; last byte of instrument data

.sync_instr		lda	(src), y
			sta	(dst), y
			dey
			bpl	.sync_instr

.null_rejoin		txa			; we restore and check
			tay			; the theme index
			dey			; before dec'ing the
			bmi	.instr_done	; dst ptr
			tya			; <- save the new y!

			ldy	#SOUND_INSTR_SIZE
.adv_instr_dst		dec	dst		; dst -= instrument size
			dey
			bne	.adv_instr_dst

			tay			; restore the new y (from A!)
			bpl	.next_instr_ptr ; we know it's positive
			
			;; Reset the channel vars
.instr_done 		iny			; y was -1, so is now 0
			tya
			ldy	#SOUND_CHANNEL_SIZE * 4 - 1
.clear_channel		sta	sound_channels, y	; clear channel
			dey
			bpl	.clear_channel

			;; Set the chain ptrs
			ldy	#8		; right after the instr ptrs
			ldx	#SOUND_CHAINS_SIZE
.set_chain_ptrs		lda	(sound_theme), y
			sta	sound_chains - 8, y 
			iny
			dex
			bne	.set_chain_ptrs

			txa			; x must be 0 here
			sta	sound_theme_idx	; finally, 0 out   <- clears scratch
			sta	sound_theme_vol ; the global vars

			rts

			;; Handle NULL instruments by 0ing out the settings
.null_instr		dey			; we skipped dey to br here	
			sty	sound_theme_idx	; use this as scratch (we'll clear it later)
			ldy	#SOUND_INSTR_SIZE - 1
.next_null		sta	(dst), y	; A must == 0 to be here...
			dey
			bpl	.next_null
			ldx	sound_theme_idx	; but restore it into X
			bpl	.null_rejoin

	;; Note pitches
sound_pitches	dw	$07f1, $0780, $0713, $06ad, $064d, $05f3
		dw	$059d, $054d, $0500, $04b8, $0475, $0435
		dw	$03f8, $03bf, $0389, $0356, $0326, $02f9
		dw	$02ce, $02a6, $027f, $025c, $023a, $021a
		dw	$01fb, $01df, $01c4, $01ab, $0193, $017c
		dw	$0167, $0152, $013f, $012d, $011c, $010c
		dw	$00fd, $00ef, $00e2, $00d2, $00c9, $00bd
		dw	$00b3, $00a9, $009f, $0096, $008e, $0086
		dw	$007e, $0077, $0070, $006a, $0064, $005e
		dw	$0059, $0054, $004f, $004b, $0046, $0042
		dw	$003f, $003b, $0038, $0034, $0031, $002f
		dw	$002c, $0029, $0027, $0025, $0023, $0021
		dw	$001f, $001d, $001b, $001a, $0018, $0017
		dw	$0015, $0014, $0013, $0012, $0011, $0010

			code
sound_advance		SOUND_CHANNEL_ADVANCE 0
			SOUND_CHANNEL_ADVANCE 1		
			SOUND_CHANNEL_ADVANCE 2		
			SOUND_CHANNEL_ADVANCE 3
			rts

