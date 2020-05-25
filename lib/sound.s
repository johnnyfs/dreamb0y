;;;
;;; Loads and advances the current musical theme & mixes in
;;; sound effects as needed.
;;;

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
Bb3	equ	25
B3	equ	26
C3	equ	27
Db3	equ	28
D3	equ	29
Eb3	equ	30
E3	equ	31
F3	equ	32
Fs3	equ	33
Gb3	equ	33
G3	equ	34
Ab3	equ	35
A4	equ	36
Bb4	equ	37
B4	equ	38
C4	equ	39
Db4	equ	40
D4	equ	41
Eb4	equ	42
E4	equ	43
F4	equ	44
Gb4	equ	45
G4	equ	46
Ab4	equ	47
A5	equ	48
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

;; Note duration (low 5 bits); engine adds 1
WN	equ	63	; whole note
HN	equ	31	; half note
QN	equ	15	; quarter note
EN	equ	7	; eighth note
SN	equ	3	; sixteenth note
TN	equ	1	; thirty-second note
XN	equ	0	; sixty-fourth note
;; Effects flags (high 3 bits)
       ;; TBD

; Commands (mutually exclusive with notes, indicated by high bit
SOUND_CMD_FLAG		equ	%10000000
SOUND_CMD_REPEAT	equ	(SOUND_CMD_FLAG|0)	; return to beginning of chain

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
			ldy	#SOUND_CHANNEL_SIZE * 4 - 1
.clear_channel		lda	#1
			sta	sound_channels, y	; clear wait to 1
			dey
			lda	#0
			sta	sound_channels, y	; clear index to 0
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

;;;;;
;; advance the sound system once frame
	code
sound_advance		dec	sound_sq1 + sound_chain_wait ; count back duration
			bne	.done                        ; don't do anything until we've hit 0
			ldy	sound_sq1 + sound_chain_idx  ; get current index into sq1
.repeat			lda	(sound_chain_sq1), y         ; get next note/cmd
			bmi	.do_command                  ; hi bit => command

			;; start the note
			asl			; index * 2 = offset
			tax
			lda	sound_sq1_instr + sound_instr_dut_len_vol
			sta	$4000
			lda	sound_sq1_instr + sound_instr_sweep
			sta	$4001
			lda	sound_pitches, x ; load low byte
			sta	$4002
			inx
			lda	sound_pitches, x ; load high byte
			ora	sound_sq1_instr + sound_instr_len_load
			sta	$4003

			;; set the duration
			iny
			beq	.hang	;; we mustn't roll over!
			lda	(sound_chain_sq1), y
			sta	sound_sq1 + sound_chain_wait

			;; advance to next note/command
			iny
			beq	.hang	;; we mustn't roll over!
			sty	sound_sq1 + sound_chain_idx

			rts
			
.hang			jmp	.hang	;; for now (TODO: implement brk dump)
		
			;; handle a command
.do_command		cmp	#SOUND_CMD_REPEAT
			bne	.hang
			ldy	#0
			beq	.repeat
.done			rts

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

