;;;
;;; Loads and advances the current musical theme & mixes in
;;; sound effects as needed.
;;;

REST=0
SSS=3  ; sound sample size -- necessary since we can't easily X3

; We need to force this, b/c the assembler won't assume 1-byte for zero page
_SND_INSTR_SIZE=7
IF SND_INSTR_SIZE != _SND_INSTR_SIZE
	FAIL "Mismatch between library and zero page instrument size"
ENDC

SND_CH_REGS=$4000 ;; PPU channel registers start at $4000
SND_REGS_PER_CH=4 ;; 4 registers per channel

;; Declare a described sample in the form "name", rate index, and length in 16-byte chunks
;; Creates a reference to the description in the form `sample_NAME`
;; Expects the existence of sample data in the form `dmc_NAME`
SND_SAMPLE_DECL	MACRO
sample_\1=*
	db	\2
	db	(dmc_\1 - $C000) / 64
	db	\3
	ENDM

PN=	%00010000 	; periodic noise mode flag
ENV2=	%00100000	; noise env swap flag
DMC=	%01000000	; noise play sample flag

SND_SAMPLE_IDX_MASK=	%00111111	; mask off all but the sample index

	;; Note pitch indeces
;A1	equ	0 ; Rest overrides; TODO: we can hack it back in
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
Cs2	equ	16
Db2	equ	16
D2	equ	17
Ds2	equ	18
Eb2	equ	18
E2	equ	19
F2	equ	20
Fs2	equ	21
Gb2	equ	21
G2	equ	22
Gs2	equ	23
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
INAUD	equ	Gb8	; inaudible on square channels at least?

;; Note duration (notes play until -1, so all values are 2^x-1)
WN	equ	127	; whole note
HN	equ	63	; half note
QN	equ	31	; quarter note
EN	equ	15	; eighth note
SN	equ	7	; sixteenth note
TN	equ	3	; thirty-second note
XN	equ	1	; sixty-fourth note
YN	equ	0	; thirty-second note
; Effects flags (high 3 bits)
       ;; TBD

; Commands (mutually exclusive with notes, indicated by high bit
SND_CMD_FLAG		equ	%10000000
SND_CMD_END_CHAIN	equ	(SND_CMD_FLAG|0)	; end this chain, load next if/a
SND_CMD_PITCH_PTR	equ	(SND_CMD_FLAG|1)	; load next two values as (little-endian) pitch ptr
SND_CMD_MAJ		equ	(SND_CMD_FLAG|2)	; load built-in major arpreggio to pitch ptr
SND_CMD_MIN		equ	(SND_CMD_FLAG|3)	; load built-in minor arpreggio to pitch ptr
SND_CMD_DIM		equ	(SND_CMD_FLAG|4)	; load built-in diminished arpreggio to pitch ptr
SND_CMD_DECAY_OFF	equ	(SND_CMD_FLAG|5)	; alter instrument decay offset
SND_CMD_ENV_PTR		equ	(SND_CMD_FLAG|6)	; set new env ptr (little-endian)
SND_CMD_TRANSPOSE	equ	(SND_CMD_FLAG|7)	; set new transpose delta

;; Built-in arpreggio pitch runs
SND_ARP_WAIT=3
snd_arp_maj=*
	db	SND_ARP_WAIT, 0, SND_ARP_WAIT, 4, SND_ARP_WAIT, 7, -1
snd_arp_min=*
	db	SND_ARP_WAIT, 0, SND_ARP_WAIT, 3, SND_ARP_WAIT, 7, -1
snd_arp_dim=*
	db	SND_ARP_WAIT, 0, SND_ARP_WAIT, 3, SND_ARP_WAIT, 6, -1


; Advance the volume envelope & set the volume register (for square/noise channels)
; zero flag should be unset after return
SND_ENV_ADVANCE		MACRO
			IF	\2 == 0
snd_env1_advance_\1=*
			ELSE
snd_env2_advance_\1=*
			ENDC

			lda	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_env_ptr + 1 + \2 * 2
			beq	.no_env_\1_\2
			ldy	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_env_idx
			lda	(snd_instrs + _SND_INSTR_SIZE * \1 + snd_instr_env_ptr + \2 * 2), y
			bmi	.decay_maybe_\1_\2
			ora	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_duty_vol
			sta	SND_CH_REGS + \1 * SND_REGS_PER_CH
.adv_to_decay_\1_\2	iny
			sty	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_env_idx
			rts
.decay_maybe_\1_\2	lda	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_wait
			cmp	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_decay_off
			beq	.adv_to_decay_\1_\2
.no_env_\1_\2		rts
			ENDM

			; Only the square and noise channels have volume envelopes
			SND_ENV_ADVANCE 0, 0
			SND_ENV_ADVANCE 1, 0
			SND_ENV_ADVANCE 3, 0
			SND_ENV_ADVANCE 3, 1  ; noise gets two envs

SND_PITCH_ADVANCE	MACRO
			;; If we're still waiting, then do nothing
snd_pitch_advance_\1 	dec	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_pitch_wait
			bne	.no_pitch_mod_\1 ; on first call we go from 1 => 0

			;; First byte of pitch mod is duration, where -1 => loop
			ldy	snd_chains  + SND_CHAIN_SIZE * \1 + snd_chain_pitch_idx
.loop_\1		lda	(snd_instrs + _SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr) , y
			bpl	.no_loop_\1 ; loop on -1 (NOTE: if 1st byte is -1 this will hang!)
			ldy	#0
			beq	.loop_\1
.no_loop_\1		sta	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_pitch_wait

			;; Second value is index modulation
			iny
			lda	(snd_instrs + _SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr) , y
			iny
			sty	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_pitch_idx

			;; Calculate pitch index
			clc
			adc	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_note
			asl	; tbl offset = (index + transpose + modulation) * 2 ptr width

			;: Look up and set pitch period
			tax
			lda	snd_pitches, x	; load low byte of pitch
			sta	SND_CH_REGS + \1 * SND_REGS_PER_CH + 2
			inx
			lda	snd_pitches, x	; load high byte
			sta	SND_CH_REGS + \1 * SND_REGS_PER_CH + 3

.no_pitch_mod_\1 	rts
			ENDM

			;; Advance pitch modulation for square and triangle waves
			;; Clobbers Y, sets the pitch regs on first and new values
			;; Caller must check whether pitch mod ptr is NULL or else
			;; behavior is undefined. (This is because NULL handling
			;; requires different behavior on the first call.)
			SND_PITCH_ADVANCE 0
			SND_PITCH_ADVANCE 1
			SND_PITCH_ADVANCE 2

;; Advance the indexed sound channel
;; MACRO \1:channel
;;   channel: the index 0-3 of sq1, sq2, tri, and noi
SND_CHAIN_ADVANCE	MACRO
			;; Do nothing if there is no chain for this channel
snd_chain_advance_\1	lda	snd_chain_ptrs + 2 * \1 + 1
			beq	.done_\1

			;; Count back duration to (-1)
			dec	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_wait
			bmi	.advance_\1
			lda	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_note
			bne	.env_maybe_\1	; note > 0 => apply effects
			beq	.done_\1	; note=0   => REST, do nothing

			;; Advance the index into the channel
.advance_\1		ldy	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_idx

			;; 0 => rest; High bit => command; otherwise => play note
.next_frame_\1		lda	(snd_chain_ptrs + 2 * \1), y
			bmi	.do_command_\1
			bne	.not_rest_\1 ; 0 => REST
.do_rest_\1		sta	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_note ; 0 => rest
			sta	SND_CH_REGS + \1 * SND_REGS_PER_CH + 2 ; zero out freq
			sta	SND_CH_REGS + \1 * SND_REGS_PER_CH + 3
			beq	.duration_\1 ; set the rest duration

			;; Start the note
			IF \1 < 3	;; sq1/2, tri => transpose, look up, maybe pitch mod
				;; Add transposition no matter what
.not_rest_\1			clc
				adc	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_transpose

				;; Run pitch modulation (unless ptr is null)
				ldx	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr + 1
				bne	.do_pitch_mod_\1

				;; On null ptr just set the note exactly once
				asl
				sta	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_note ; save the note regardless, as 0 => rest
				tax
				lda	snd_pitches, x	; load low byte of pitch
				sta	SND_CH_REGS + \1 * SND_REGS_PER_CH + 2
				inx
				lda	snd_pitches, x	; load high byte
				sta	SND_CH_REGS + \1 * SND_REGS_PER_CH + 3
				inx	; ensure bne branches (high byte of period can be $00)
				bne	.skip_pitch_mod_\1
				beq	.skip_pitch_mod_\1 ; in case we roll over (unlikely but possible with high mod)

				;; Otherwise reset modulation and call the common routine
.do_pitch_mod_\1		sta	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_note ; store note for future passes
				sty	snd_theme_tmp 	; save chain index
				ldy	#0		; clear pitch mod index & wait
				sty	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_pitch_idx
				iny	; for sanity w/r/t timing (1 => 1 frame)
				sty	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_pitch_wait
				jsr	snd_pitch_advance_\1 ; clobbers Y, sets A = note index
				ldy	snd_theme_tmp	; restore chain index
			ELSE	;; Noise channel => set period directly, honoring flags
.not_rest_\1			sta	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_note ; save the note regardless, as 0 => rest
				tax	; X = raw period for noise
				and	#DMC	; if set, then play sample instead of noise
				beq	.skip_pitch_mod_\1
				txa
				and	#SND_SAMPLE_IDX_MASK
				jsr	snd_play_sample
				lda	#0
				beq	.do_rest_\1 ; playing a sample => rest noise
			ENDC

			;; Set the duty/volume register
			IF \1 == 2 ; Triangle: no volume control, so just copy the instr value
.skip_pitch_mod_\1		lda	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_duty_vol
				sta	SND_CH_REGS + \1 * SND_REGS_PER_CH
			ELSE       ; Sq/Noi: if not null, reset env idx and advance
.skip_pitch_mod_\1		lda	#0
				sta	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_env_idx
				sty	snd_theme_tmp ; save y from destruction
				;; Noise channel has alternate envelope instead of pitch mod
				IF \1 == 3
					txa
					and	#ENV2
					;; Save 0 => env1, 1 => env2
					sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_transpose
					beq	.adv_env1_\1
					jsr	snd_env2_advance_\1
					ldy	snd_theme_tmp
					bne	.set_noise_period_\1
				ENDC
.adv_env1_\1			jsr	snd_env1_advance_\1
				ldy	snd_theme_tmp ; restore y
			ENDC

			IF \1 == 3 ; sq1/2 + triangle: look up the note value
.set_noise_period_\1		txa
				and	#PN
				beq	.no_pmode_\1
				txa
				and	#%00001111	; mask off the software flag
				ora	#%10000000	; set the hardware flag
				tax
.no_pmode_\1			stx	SND_CH_REGS + \1 * SND_REGS_PER_CH + 2 ; set period+mode
				stx	SND_CH_REGS + \1 * SND_REGS_PER_CH + 3 ; must set?
			ENDC

			;; Set the duration
.duration_\1		iny
			beq	.hang_\1
			lda	(snd_chain_ptrs + 2 * \1), y
			sta	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_wait

			;; Advance to next note/command
			iny
			beq	.hang_\1
			sty	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_idx
			bne	.done_\1

.hang_\1		jmp	.hang_\1	; for now just crash out

			;; Square/noise => advance volume envlope; triange => just time out as/a
			IF \1 != 2
				;; Noise channel, decide which envelope to use
				IF \1 == 3
.env_maybe_\1				lda	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_transpose
					bne	.do_env2_\1
					jsr	snd_env1_advance_\1
					rts	; no pitch mod for noise, so we're done	
.do_env2_\1				jsr	snd_env2_advance_\1
					rts
				ELSE
					;; Sq1/2, just use env1
.env_maybe_\1				jsr	snd_env1_advance_\1
				ENDC
			ELSE
.env_maybe_\1			lda	snd_chains + SND_CHAIN_SIZE * \1 + snd_chain_wait
				cmp	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_decay_off
				bne	.pitch_mod_maybe_\1
				sta	SND_CH_REGS + \1 * SND_REGS_PER_CH + 0
			ENDC
				
			IF \1 != 3
.pitch_mod_maybe_\1		lda	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr + 1
				beq	.done_\1 ; NULL pitch mod ptr => do nothing
				jsr	snd_pitch_advance_\1 ; otherwise advance pitch modulation
			ENDC
.done_\1		rts

			;; Handle a command
.do_command_\1		cmp	#SND_CMD_END_CHAIN
			bne	.not_end_chain_\1
			;;; Count down the repetitions for this chain
			dec	snd_chain_lists + SND_CHAIN_LIST_SIZE * \1 + snd_chain_list_count
			bne	.just_repeat_\1 ; if we haven't reached 0, just repeat
			jsr	snd_chain_list_advance_\1 ; otherwise, advance
.just_repeat_\1		ldy	#0	
			jmp	.next_frame_\1
.not_end_chain_\1	cmp	#SND_CMD_PITCH_PTR
			bne	.not_pitch_ptr_\1	; hang on unrecognized commands
			iny
			lda	(snd_chain_ptrs + 2 * \1), y ; set low byte of new ptr
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr
			iny
			lda	(snd_chain_ptrs + 2 * \1), y ; set high byte of new ptr
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr + 1
			iny
			jmp	.next_frame_\1
.not_pitch_ptr_\1	cmp	#SND_CMD_MAJ
			bne	.not_maj_\1
			lda	#snd_arp_maj & $ff
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr
			lda	#snd_arp_maj >> 8
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr + 1
			iny
			jmp	.next_frame_\1
.not_maj_\1		cmp	#SND_CMD_MIN
			bne	.not_min_\1
			lda	#snd_arp_min & $ff
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr
			lda	#snd_arp_min >> 8
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr + 1
			iny
			jmp	.next_frame_\1
.not_min_\1		cmp	#SND_CMD_DIM
			bne	.not_dim_\1
			lda	#snd_arp_dim & $ff
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr
			lda	#snd_arp_dim >> 8
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_pitch_ptr + 1
			iny
			jmp	.next_frame_\1
.not_dim_\1		cmp	#SND_CMD_DECAY_OFF	
			bne	.not_decay_off_\1
			iny	
			lda	(snd_chain_ptrs + 2 * \1), y ; get new decay offset
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_decay_off
			iny
			jmp	.next_frame_\1	
.not_decay_off_\1	cmp	#SND_CMD_ENV_PTR	
			bne	.not_env_ptr_\1
			iny
			lda	(snd_chain_ptrs + 2 * \1), y ; set low byte of new ptr
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_env_ptr
			iny
			lda	(snd_chain_ptrs + 2 * \1), y ; set high byte of new ptr
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_env_ptr + 1
			iny
			jmp	.next_frame_\1
.not_env_ptr_\1		cmp	#SND_CMD_TRANSPOSE	
.not_transpose_\1	bne	.not_transpose_\1	; hang on unrecognized cmd
			iny	
			lda	(snd_chain_ptrs + 2 * \1), y ; set new transpose delta
			sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_transpose
			iny
			jmp	.next_frame_\1
			ENDM

			;; Advance the specified channel to the next frame
			SND_CHAIN_ADVANCE 0
			SND_CHAIN_ADVANCE 1		
			SND_CHAIN_ADVANCE 2		
			SND_CHAIN_ADVANCE 3

SND_CHAIN_LIST_ADVANCE		MACRO
snd_chain_list_advance_\1	ldy	snd_chain_lists + SND_CHAIN_LIST_SIZE * \1 + snd_chain_list_idx
				lda	(snd_chain_list_ptrs + 2 * \1), y ; get # of repeats
				beq	.end_chain_list_\1 	; 0 => END
				bpl	.no_loop_\1 		; (-1) => LOOP
				
				;; On loop, reset the list index and read first value
				ldy	#0
				sty	snd_chain_lists + SND_CHAIN_LIST_SIZE * \1 + snd_chain_list_idx
				lda	(snd_chain_list_ptrs + 2 * \1), y

				;; Store the repeat count
.no_loop_\1			sta	snd_chain_lists + SND_CHAIN_LIST_SIZE * \1 + snd_chain_list_count
				iny
				lda	(snd_chain_list_ptrs + 2 * \1), y ; get transpose delta
				sta	snd_instrs + SND_INSTR_SIZE * \1 + snd_instr_transpose
				iny
				lda	(snd_chain_list_ptrs + 2 * \1), y ; low byte of chain
				sta	snd_chain_ptrs + 2 * \1
				iny
				lda	(snd_chain_list_ptrs + 2 * \1), y ; high byte of chain
				sta	snd_chain_ptrs + 2 * \1 + 1

				;; Save the advanced index
				iny
				sty	snd_chain_lists + SND_CHAIN_LIST_SIZE * \1 + snd_chain_list_idx
.end_chain_list_\1		rts
				ENDM

				SND_CHAIN_LIST_ADVANCE 0
				SND_CHAIN_LIST_ADVANCE 1
				SND_CHAIN_LIST_ADVANCE 2
				SND_CHAIN_LIST_ADVANCE 3

; Load a theme and prepare the engine to play it
			code
snd_start_theme 	lda	#snd_instr_noi & $ff
			sta	dst	; start writing at last instr
			lda	#snd_instr_noi >> 8
			sta	dst + 1

			ldy	#7	; 4 channels * 2 bytes per instr ptr - 1
.next_instr_ptr		lda	(snd_theme), y	; ptr for instr1
			beq	.null_instr
			sta	src + 1
			dey
			lda	(snd_theme), y
			sta	src	; start reading w/ pointer to last instrument

			tya		; save our index into *theme*
			tax
			ldy	#SND_INSTR_SIZE - 1	; last byte of instrument data

.sync_instr		lda	(src), y
			sta	(dst), y
			dey
			bpl	.sync_instr

.null_rejoin		txa			; we restore and check
			tay			; the theme index
			dey			; before dec'ing the
			bmi	.instr_done	; dst ptr
			tya			; <- save the new y!

			ldy	#SND_INSTR_SIZE
.adv_instr_dst		dec	dst		; dst -= instrument size
			dey
			bne	.adv_instr_dst

			tay			; restore the new y (from A!)
			bpl	.next_instr_ptr ; we know it's positive
			
			;; Reset the channel vars
.instr_done 		iny			; y was -1, so is now 0
			tya
			ldy	#(SND_CHAIN_SIZE + SND_CHAIN_LIST_SIZE) * 4 - 1
.clear_channel		sta	snd_chains, y	; clear channel
			dey
			bpl	.clear_channel

			;; Set the chain list ptrs + sample table ptr
			ldy	#8		; ie, after the ptrs in the theme def
			ldx	#SND_CHAIN_LIST_PTRS_SIZE
.set_chain_ptrs		lda	(snd_theme), y
			sta	snd_chain_list_ptrs - 8, y 
			iny
			dex
			bne	.set_chain_ptrs

			;; Copy the sample ptr (could hack onto end of prev?)
			lda	(snd_theme), y	; y = end of chains, start of sample ptr
			sta	snd_theme_samples
			iny
			lda	(snd_theme), y
			sta	snd_theme_samples + 1

			;; Clear the theme-global vars
			txa			; x must be 0 here
			sta	snd_theme_acc	; finally, 0 out   <- clears scratch
			sta	snd_theme_tmp   ; the global vars

			;; Set the initial chain ptrs
			jsr	snd_chain_list_advance_0
			jsr	snd_chain_list_advance_1
			jsr	snd_chain_list_advance_2
			jsr	snd_chain_list_advance_3
			rts

			;; Handle NULL instruments by 0ing out the settings
.null_instr		dey			; we skipped dey to br here	
			sty	snd_theme_tmp	; use this as scratch (we'll clear it later)
			ldy	#SND_INSTR_SIZE - 1
.next_null		sta	(dst), y	; A must == 0 to be here...
			dey
			bpl	.next_null
			ldx	snd_theme_tmp	; but restore it into X
			bpl	.null_rejoin

	;; Note pitches
snd_pitches	dw	$07f1, $0780, $0713, $06ad, $064d, $05f3
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

;; Start the sample indexed by A (expects A to be already multiplied by SSS, the
;; snd sample size).
		code
snd_play_sample	sty	snd_theme_tmp
		tay

		lda	#%00001111	; halt any currently playing sample
		sta	$4015

		;; TODO: use zp pointer once we're sure this works
		lda	samples, y	; first byte = rate (| 0'ed out flags)
		sta	$4010
		lda	#63		; XXX: do all samples start midrange?
		sta	$4011
		iny
		lda	samples, y	; second byte = address encoded
		sta	$4012		; $C000 + A * 64 => address
		iny
		lda	samples, y	; third byte = sample length encoded
		sta	$4013		; length/16
		iny

		lda	#%00011111	; restart the sample channel
		sta	$4015

		ldy	snd_theme_tmp
		rts

			code
snd_advance		jsr	snd_chain_advance_0
			jsr	snd_chain_advance_1
			jsr	snd_chain_advance_2
			jsr	snd_chain_advance_3
			rts
