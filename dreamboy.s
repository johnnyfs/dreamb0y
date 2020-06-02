;;;;;;;;;;;;;;;;;;;;;;;
;; dreamboy          ;;
;; (c) 2015 johnnygp ;;
;;;;;;;;;;;;;;;;;;;;;;;

	cpu	6502
	output	scode	; motorola S-CODE output
	ilist	ON	; show listing for includes
	mlist	ON	; show listing for macros

include lib/zero.s

;; prg-rom bank 1
*=$c000

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; INTERRUPT HANDLERS ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

;; reset handler {{{
	code
reset	sei
	cld			; unused?
	ldx	#$ff		; reset the stack
	txs	

	;; turn everything off
	inx			; now x is 0
	txa			; now a is 0
	lda	#0
	sta	$2000
	sta	$2001		; turn off the ppu
	sta	$4015		; turn off all sound channels

	;; clear the zero page
	lda	#0		; redundant for modularity
.clrzp	sta	$00, x
	inx
	bne	.clrzp

	;; clear cart ram $0100-$07ff
	lda	#0		; redundant for modularity
	tay			; y = 0 (byte to clear)
	ldx	#8		; clear 8 pages
	sta	src		; redundant
.incram	inc	src + 1	; start at page 1
.clrram	sta	(src), y	; clear byte y of page
	iny
	bne	.clrram		; loop until 256 bytes/page
	dex
	bne	.incram		; loop until we've cleared 8 pages

	;; clear the sprite mem
	lda	#$00		; redundant
	sta	$4014		; will write blank page 0 to ppu

	;; clear the ppu ram
	lda	#$20		; start at $20xx
	sta	$2006
	lsr
	tay			; y = 16 pages to clear
	lda	#0
	sta	$2006		; start at $2000
	tax			; x = 0 (byte to clear)
	lda	#1
.clrppu	sta	$2007	
	inx
	bne	.clrppu		; loop until 256 bytes/page
	dey
	bne	.clrppu		; loop until 16 pages

	;; set the test palette
	lda	#$3f
	sta	$2006
	ldx	#0
	stx	$2006		; start at $3f00
	ldy	#$20		; write 32 palette bytes
.ldpal	lda	palette, x
	sta	$2007
	inx
	dey
	bne	.ldpal

	;; load the status bar
	jsr	status_load

        ;; load the test map.
        lda     #(testmap >> 8) & 0xff
        sta     src + 1
        lda     #(testmap & 0xff)
        sta     src
        jsr     ldmap

	;; copy the test map to the screen
        lda	#$20
	sta	$2006
	lda	#$00
	sta	$2006

        ldy     #0	
.ld1    lda     $0200, y
        sta     $2007
        iny
        bne     .ld1

        ldy     #0	
.ld2    lda     $0300, y
        sta     $2007
        iny
        bne     .ld2

        ldy     #0	
.ld3    lda     $0400, y
        sta     $2007
        iny
        bne     .ld3

        ldy     #0	
.ld4    lda     $0500, y
        sta     $2007
        iny
        bne     .ld4

	;; reset the scroll
	lda	#0
        sta     xscroll
	sta	$2005
	lda	#SCROLL_INITY	; forget why -- we have to start at 248?
        sta     yscroll
	sta	$2005

	;; write the magic sprite 0
	lda	#37
        sta     SPRITES
        lda     #1
        sta     SPRITES + 1
	lda	#%00100000
        sta     SPRITES + 2
	lda	#253
        sta     SPRITES + 3

        ;; TMP: jump start the player
        jsr     entity_spawn_player
        jsr     entity_draw_player

        ;; Blast at least sprite 0 to the sprite mem
        lda     #SPRITES >> 8   ;; high byte of sprite page
        sta     $4014

	;; initialize the engine
	lda	#state_free		; engine initial state
	sta	state
	lda	#realworld_day & $ff	; engine initial map
	sta	maps
	lda	#realworld_day >> 8
	sta	maps + 1

	;; choose the starting sound theme
	lda	#test_theme & $ff	
	sta	snd_theme
	lda	#test_theme >> 8
	sta	snd_theme + 1
	jsr	snd_start_theme

	;; turn sound channels on
	lda	#%00000000
	ldy	#$0f
.zsound	sta	$4000, y
	dey
	bpl	.zsound
	lda	#%00001111
	sta	$4015
	;lda	#%00111111
	;sta	$4000
	;lda	#0
	;sta	$4001
	;lda	#$ab
	;sta	$4002
	;lda	#$01
	;sta	$4003

	;; turn the screen back on.
	lda	#%10101000	; vblank enabled; 8x16 sprites
	sta	$2000
	sta	status		; save for later
	lda	#%00011110	; image/sprite mask off/on, sprites/screen on 
	sta	$2001
;; }}}

;; main loop {{{
main	lda	frames
.wait	cmp	frames
	beq	.wait		;; loop until the frame counter changes

	jsr	handle_state	;; process the current state

;;; WAIT SPRITE 0 ;;;

	;; Wait for the sprite 0 flag to clear
.waitn0	lda	$2002
	and	#%01000000
	bne	.waitn0

	;; Wait on sprite 0
.wait0	lda	$2002
	and	#%01000000
	beq	.wait0

    	ldx	#32
.spin	dex
	bne	.spin

	;; TODO: incoroprate status loading into the stage/load process so this is less jumpy

	;; And reset the scroll -- nmi will have messed with it
	and	#%00000001
	asl
	asl		    ; we'll now be 4 for swap table, 0 for main
	sta	$2006
	lda	yscroll
	sta	$2005
	ldx	xscroll
	stx	$2005
	and	#$F8
	asl
	asl
	sta	tmp
	txa
	lsr
	lsr
	lsr
	ora	tmp
	sta	$2006

	;; Switch to the map chrs after status bar is done
	lda	status
	sta	$2000

	jsr	entity_draw_player	;; TODO: only when dirty (heh)

	;; Loop (main will wait on frame ctr -- ie, until after status is drawn)
.noscr	jmp	main
;; }}}

;; Nmi/Irq handlers {{{
	code
nmi	pha
        txa
        pha
        tya
        pha

	;; Update sprites while we can
	lda	#SPRITES >> 8
	sta	$4014

        lda     state

;;; LOAD STATE: advance the load one more chunk ;;;
	
	;; TODO: make this less inefficient? set an engine flag for loading?
        cmp	#STATE_LLOAD
	beq	.load
	cmp	#STATE_RLOAD
	beq	.load
	cmp	#STATE_LLOAD2
	beq	.load
	cmp	#STATE_RLOAD2
	beq	.load
	cmp	#STATE_VLOAD
	beq	.load
	cmp	#STATE_VLOAD2
	beq	.load
	cmp	#STATE_VLOAD3
	bne	.n_hld	

	;; Advance the load state in nmi.
.load	jsr     load_next

	;; Set scroll and table for status bar
.n_hld	lda	status
	ora	#%00010000	    ;; bank switch for the status bar
	and	#%11111110	    ;; always use the main table
	sta	$2000	
	lda	#0
	sta     $2005		    ;; x scroll is always 0 for the status bar
	lda	#SCROLL_NMIY
        sta     $2005		    ;; scroll is always init state for status bar

	;; Advance sound subsystem
	jsr	snd_advance

	;; Increment the frame counter
.done	inc	frames

	pla
        tay
        pla
        tax
        pla
irq	rti		    ;; so 12 this path also + 6 for rti
;; }}}

;;;;;;;;;;;;;;;;;;;;;;
;;; STATE HANDLING ;;;
;;;;;;;;;;;;;;;;;;;;;;

;; Handle state by type {{{
handle_state	lda	state
		asl
		tax
		lda	handlers, x
		sta	src
		inx
		lda	handlers, x
		sta	src + 1
		jmp	(src)		;;; this won't work if any of the addresses crosses a page boundary!
;; }}}

;; Handle STATE_SEQ{{{
    code
handle_seq  rts
;; }}}

;; Handle STATE_FREE {{{
    code
handle_free jsr	joypad_strobe
	    lda	joypad_next
;;	    eor	joypad_prev	;; 0 ^ 1 || 1 ^ 0 => state changed
;;	    and	joypad_next	;; & 1 => was pressed
;;
;;	    lsr
;;	    bcc	.n_right
;;	    ;;jsr	start_rscroll
;;	    clv
;;	    bvc	.done
;;.n_right    lsr
;;	    bcc	.n_left
;;	    ;;jsr	start_lscroll
;;	    clv
;;	    bvc .done
;;.n_left	    lsr
;;	    bcc	.n_down
;;	    ;;jsr	start_dscroll
;;	    clv
;;	    bvc	.done
;;.n_down	    lsr
;;	    bcc	.n_up
;;	    ;;jsr	start_uscroll
;;	    clv
;;	    bvc	.done
;;.n_up	    lsr
;;	    bcc	.n_strt
;;.n_strt	    lsr
;;	    bcc	.n_sel
;;.n_sel	    lsr
;;	    beq	.n_b
;;.n_b	    lsr
;;;;	    beq .n_a
.n_a        jsr entity_update_player

            ;; TODO: directly access player entity
            lda entity_x
            cmp #LSCROLL_THRESHOLD
            bcs .no_lscroll
            jsr start_lscroll
.no_lscroll cmp #RSCROLL_THRESHOLD
            bcc .no_rscroll
            jsr start_rscroll
.no_rscroll lda entity_y
            cmp #USCROLL_THRESHOLD
            bcs .no_uscroll
            jsr start_uscroll
.no_uscroll lda entity_y
            cmp #DSCROLL_THRESHOLD
            bcc .no_dscroll
            jsr start_dscroll
.no_dscroll rts
;;; }}}

;; Handle STATE_LLOAD (first pass: load the staged current map into the swap table and switch view) {{{
    code
handle_lload	dec	step		;; loading is done in nmi, here we just count down
		bne	.done
		inc	state		;; state => LSTAGE
		dec	pos		;; next phase is to load the new map to the main table
		jsr	toggle_viewtbl
		lda	#NAMETBL_MAIN
		jmp	setup_stage	;; setup_stage sets the nametbl from A
.done		rts
;; }}}

;; Handle STATE_LSTAGE (second pass: stage the new map) {{{
    code
handle_lstage	jsr	stage_next	;; advancing the staging process is done in the module
		dec	step
		bne	.done
		inc	state		;; state => LLOAD2
		jmp	setup_load
.done		rts
;; }}}

;; Handle STATE_LLOAD2 (second pass: load the staged new map into the main table) {{{
    code
handle_lload2	dec	step		;; loading is done in nmi, here we just count down
		beq	.fallthrough
		rts
.fallthrough	inc	state		;; state => LSCROLL
		jsr	toggle_viewtbl	;; scroll starts fully scrolled & counts down, so POV is end (main) table
                lda     #3
                sta     step
		;; since fully scrolled is scroll=256=0, fall through to prevent the table jumping
;; }}}

;; Handle STATE_LSCROLL (scroll from the old map in the swap table back to the new map in the main table) {{{
    code
handle_lscroll  lda     entity_x	
                clc
                adc     #SCROLL_DELTA
                sta     entity_x
                dec     step
                bne     .no_nudge
                lda     #4
                sta     step
                dec     entity_x
.no_nudge       lda	xscroll
		sec
		sbc	#SCROLL_DELTA
		sta	xscroll	
		bne	.done		;; scroll left until 0
		lda	#STATE_FREE
		sta	state		;; and we're done
                lda     #RSCROLL_THRESHOLD - 1
                sta     entity_x
.done		rts
;; }}}

;; Handle STATE_RSTAGE (first pass: stage the new map) {{{
    code
handle_rstage	jsr	stage_next
		dec	step
		bne	.done
		inc	state		;; state => RLOAD
		jmp	setup_load
.done		rts
;; }}}

;; Handle STATE_RLOAD (first pass: load the staged new map into the swap table) {{{
    code
handle_rload	dec	step		;; actual loading is done in the nmi	
		beq	.fallthrough
		rts
.fallthrough	inc	state		;; state => RSCROLL
                lda     #3
                sta     step            ;; scroll keeps track of itself; this is for nudging the player
		;; fallthrough isn't necessary here, but keeps the speed consistent
;; }}}

;; Handle STATE_RSCROLL (scroll from the current map in the main table to the new map in the swap table) {{{
    code
handle_rscroll	lda	entity_x
                sec
                sbc     #SCROLL_DELTA        ;; TODO: directly access player ent
                sta     entity_x
                dec     step
                bne     .no_nudge
                lda     #5
                sta     step
                inc     entity_x
.no_nudge       lda     #SCROLL_DELTA
		clc
		adc	xscroll
		sta	xscroll
		bne	.done
		jsr	toggle_viewtbl
		inc	state		;; state => RLOAD2
		lda	#NAMETBL_MAIN
                sta     dsttbl
		jmp	setup_load
.done		rts
;; }}}

;; Handle STATE_RLOAD2 (second pass: load the new map into the main table and switch the view) {{{
    code
handle_rload2	dec	step		;; actual loading is done in the nmi	
		bne	.done
		jsr	toggle_viewtbl
		lda	#STATE_FREE
		sta	state
                lda     #LSCROLL_THRESHOLD + 1
                sta     entity_x
.done		rts
;; }}}

;; Handle STATE_VLOAD (first load: old map into swap table in normal pos) {{{
    code
handle_vload	dec	step		;; loading happens in NMI
		beq	.load_done
		rts
.load_done	inc	state		;; state => VSTAGE (stage new map; pos already changed)	
		lda	scroll_speed
		clc
		adc	pos		;; BRITTLE: we need to use a pos/neg pitch value here...
		sta	pos
		jsr	toggle_viewtbl	;; switch to look at the old map we just loaded
		lda	dsttbl		;; annoying -- we're not switching tables (this is dumb)
		jmp	setup_stage
;; }}}

;; Handle STATE_VSTAGE (stage the new map) {{{
    code
handle_vstage	jsr	stage_next	    
		dec	step
		beq	.stage_done
		rts
.stage_done	inc	state		;; state => VLOAD2 (load the new map into the top/bottom pos)
		lda	scroll_speed
		bmi	.uload
		lda	#LOAD_TYPE_AFTER ;; for down scroll, we load the map forward after the map we just loaded
		bne	.common
.uload		lda	#LOAD_TYPE_BEFORE ;; for up scroll, we load the map backward before the map we just loaded
.common		sta	load_type		
		lda	#3
		sta	step		;; load 3 steps (1 row) at a time
		lda	#6
		sta	step2		;; do this (alternating with scrolling) 6 times
		jmp	load_start	;; skip setup_load here b/c it will set the step counter differently
;; }}}

;; Handle STATE_VLOAD2 (load a row, then scroll) {{{
    code
handle_vload2	dec	step
		bne	.done
		inc	state		;; state => vscroll (scroll in the rows we just loaded)
		lda	#8
		sta	step		;; scroll 4 * 4 = 16 pix
.done		rts
;;; }}}

;;; Handle STATE_VSCROLL (scroll in the row just loaded) {{{
    code
handle_vscroll	lda	entity_y
                sec
                sbc     scroll_speed
                sta     entity_y        ;; TODO: directly access player entity!
                lda     scroll_speed
		clc
		adc	yscroll
		sta	yscroll		;; actually scroll (nmi/s0 hit will actually set this in the ppu)
                lda     yscroll         ;; special case
                cmp     #252            ;; bad for some reason?
                bne     .yfine
                lda     #236
                sta     yscroll
.yfine		dec	step
		bne	.done
		dec	step2
		beq	.vscroll_done
		dec	state		;; state back => vload2 (load in next row)
		lda	#3
		sta	step		;; load three more steps (1 row)
.done		rts
.vscroll_done	inc	state		;; state => VLOAD3 (load the new map back into the main table)
		lda	#NAMETBL_MAIN
		sta	dsttbl
		lda	#LOAD_TYPE_OVER
		sta	load_type
		jmp	setup_load	;; this time we use setup_load, b/c we want the normal # of steps
;;; }}}

;;; Handle STATE_VLOAD3 (load the new map back into the main table) {{{
    code
handle_vload3	dec	step		;; loading in NMI (still!)	
		bne	.done
		lda	#STATE_FREE	;; we're done, back to normal state
		sta	state
		jsr	toggle_viewtbl	;; flip to the newly loading new map in the main table
		lda	#SCROLL_INITY
		sta	yscroll		;; and get the scroll back where it belongs
                lda     scroll_speed
                bmi     .down
                lda     #USCROLL_THRESHOLD + 1
                sta     entity_y
                rts
.down           lda     #DSCROLL_THRESHOLD - 1
                sta     entity_y
.done		rts
;;; }}}

;;;;;;;;;;;;;;;;;;;;;;
;;; ENGINE HELPERS ;;;
;;;;;;;;;;;;;;;;;;;;;;

;; Start right scrolling {{{ 


start_rscroll	inc     pos		;; right means pos ++
		lda	#STATE_RSTAGE
		sta	state
		lda	#LOAD_TYPE_OVER
		sta	load_type		;; we'll only use this type, so set it once here
		lda	#NAMETBL_SWAP	;; the first load will happen in the swap table regardless
		;; fallthrough to setup_stage
;;; }}}

;; Common setup for the stage state (arg A == nametbl target) {{{
setup_stage	sta	dsttbl
		lda     #STAGE_STEPS
		sta     step
		jmp     stage_start	;; opt out the second return
;;; }}}

;; Start left scrolling {{{
start_lscroll	lda	#STATE_LLOAD
		sta	state
		lda	#LOAD_TYPE_OVER
		sta	load_type		;; we'll only use this type, so set it once here
		lda	#NAMETBL_SWAP
		sta	dsttbl
		;; fallthrough to setup_load
;; }}}

;; Common setup for the load state {{{
    code
setup_load	lda	#LOAD_STEPS
		sta	step
		jsr	load_start
		rts
;; }}}

;; Start up/down scrolling {{{
    code
start_dscroll	lda	#SCROLL_DELTA	
		bne	.common		;; always branches
start_uscroll	lda	#-SCROLL_DELTA
.common		sta	scroll_speed	
		lda	#STATE_VLOAD
		sta	state
		lda	#LOAD_TYPE_OVER	;; first load is of current map into swap area
		sta	load_type
		lda	#NAMETBL_SWAP
		sta	dsttbl	
		jmp	setup_load
;; }}}

;; Toggle the viewed nametbl {{{
    code
toggle_viewtbl	lda	status
		eor	#%00000001
		sta	status
		rts
;; }}}

;;;;;;;;;;;;;;;;
;;; INCLUDES ;;;
;;;;;;;;;;;;;;;;

;; Modules {{{
    ;; test modules
include	lib/ldmap.s     ;; deprecated
    
include lib/entity.s
include lib/joypad.s
include lib/load.s
include lib/sound.s
include lib/stage.s
include lib/status.s
;; }}}

;;;;;;;;;;;;
;;; DATA ;;;
;;;;;;;;;;;;

;; Test data {{{
;; Test palette

palette	db	$0d, $1a, $27, $18
	db	$0d, $1a, $0a, $08
	db	$0d, $1a, $32, $22
        db      $0d, $1a, $19, $34

	db	$0d, $04, $20, $0d
	db	$0d, $08, $38, $0d
	db	$0d, $04, $20, $0d
	db	$0d, $04, $20, $0d

;; Test map
testmap=*
include	res/realworld_day_indeces_0_0.tbl.rle.s
include	res/realworld_day_palettes_0_0.attr.s
	db	$ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db	$ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
;; }}}

;; Realworld Daytime map {{{
realworld_day=*
	dw  realworld_day_0_0
	dw  realworld_day_1_0
	dw  realworld_day_2_0
	dw  realworld_day_3_0
	dw  realworld_day_0_1
	dw  realworld_day_1_1
	dw  realworld_day_2_1
	dw  realworld_day_3_1
	dw  realworld_day_0_2
	dw  realworld_day_1_2
	dw  realworld_day_2_2
	dw  realworld_day_3_2
	dw  realworld_day_0_3
	dw  realworld_day_1_3
	dw  realworld_day_2_3
	dw  realworld_day_3_3

	;; TODO: since the attrs are regular, store them elsewhere?
realworld_day_0_0=*
include res/realworld_day_palettes_0_0.attr.s
include	res/realworld_day_indeces_0_0.tbl.rle.s
realworld_day_1_0=*
include res/realworld_day_palettes_1_0.attr.s
include	res/realworld_day_indeces_1_0.tbl.rle.s
realworld_day_2_0=*
include res/realworld_day_palettes_2_0.attr.s
include	res/realworld_day_indeces_2_0.tbl.rle.s
realworld_day_3_0=*
include res/realworld_day_palettes_3_0.attr.s
include	res/realworld_day_indeces_3_0.tbl.rle.s
realworld_day_0_1=*
include res/realworld_day_palettes_0_1.attr.s
include	res/realworld_day_indeces_0_1.tbl.rle.s
realworld_day_1_1=*
include res/realworld_day_palettes_1_1.attr.s
include	res/realworld_day_indeces_1_1.tbl.rle.s
realworld_day_2_1=*
include res/realworld_day_palettes_2_1.attr.s
include	res/realworld_day_indeces_2_1.tbl.rle.s
realworld_day_3_1=*
include res/realworld_day_palettes_3_1.attr.s
include	res/realworld_day_indeces_3_1.tbl.rle.s
realworld_day_0_2=*
include res/realworld_day_palettes_0_2.attr.s
include	res/realworld_day_indeces_0_2.tbl.rle.s
realworld_day_1_2=*
include res/realworld_day_palettes_1_2.attr.s
include	res/realworld_day_indeces_1_2.tbl.rle.s
realworld_day_2_2=*
include res/realworld_day_palettes_2_2.attr.s
include	res/realworld_day_indeces_2_2.tbl.rle.s
realworld_day_3_2=*
include res/realworld_day_palettes_3_2.attr.s
include	res/realworld_day_indeces_3_2.tbl.rle.s
realworld_day_0_3=*
include res/realworld_day_palettes_0_3.attr.s
include	res/realworld_day_indeces_0_3.tbl.rle.s
realworld_day_1_3=*
include res/realworld_day_palettes_1_3.attr.s
include	res/realworld_day_indeces_1_3.tbl.rle.s
realworld_day_2_3=*
include res/realworld_day_palettes_2_3.attr.s
include	res/realworld_day_indeces_2_3.tbl.rle.s
realworld_day_3_3=*
include res/realworld_day_palettes_3_3.attr.s
include	res/realworld_day_indeces_3_3.tbl.rle.s

realworld_day_obs=*
include res/realworld_day_obs_0_0.tbl.s
include res/realworld_day_obs_1_0.tbl.s
include res/realworld_day_obs_2_0.tbl.s
include res/realworld_day_obs_3_0.tbl.s
include res/realworld_day_obs_0_1.tbl.s
include res/realworld_day_obs_1_1.tbl.s
include res/realworld_day_obs_2_1.tbl.s
include res/realworld_day_obs_3_1.tbl.s
include res/realworld_day_obs_0_2.tbl.s
include res/realworld_day_obs_1_2.tbl.s
include res/realworld_day_obs_2_2.tbl.s
include res/realworld_day_obs_3_2.tbl.s
include res/realworld_day_obs_0_3.tbl.s
include res/realworld_day_obs_1_3.tbl.s
include res/realworld_day_obs_2_3.tbl.s
include res/realworld_day_obs_3_3.tbl.s
;; }}}

;; Status bar {{{

status_bar=*
include res/status_bar_indeces.tbl.s
;; }}}

;; Music themes {{{

test_theme=*
	dw	test_instr1, test_instr2, test_instr3, test_instr4
	dw	test_chain1, test_chain2, test_chain3, test_chain4

test_chain1=*
	db	E3, QN, B4, QN, Fs3, QN, E3, QN
	db	E3, QN, Gs3, QN, B4, QN, E3, QN

	db	SND_CMD_REPEAT
test_chain2=*
	db	Gs3, QN, Ds4, QN, Cs4, QN, Gs3, QN
	db	B4, QN, Ds4, EN, Ds4, EN, Fs3, QN, B4, QN

	db	SND_CMD_REPEAT

test_chain3=*
	db	E3, WN, B3, WN, SND_CMD_REPEAT

test_chain4=*
	db 	9, SN, 11, SN, 9, SN, 11, SN
	db 	9, SN, 11, SN, 9, SN, 11, SN
	db 	10, SN, 11, SN, 10, SN, 11, SN
	db 	10, SN, 11, SN, 10, SN, 11, SN
	db	SND_CMD_REPEAT

test_instr1=*
	db	%10110111 ; duty 12.5, software volume (TODO: 0 volume)
	db	%00001000 ; no sweep (negate on so channel isn't muted)
	db	%00000000 ; no length
	db	0
	dw	NULL

test_instr2=*
	db	%01110111 ; duty 12.5, software volume (TODO: 0 volume)
	db	%00001000 ; no sweep (negate on so channel isn't muted)
	db	%00000000 ; no length
	db	0
	dw	NULL

test_instr3=*
	db	%10001111
	db	%00000000 ; ignored
	db	%11111000
	db	12
	dw	NULL

test_instr4=*
	db	%00110011
	db	%00000000 ; mode
	db	%00000000 ; length
	db	0	  ; ignored
	dw	NULL

;; }}}

;;;;;;;;;;;;;;;
;;; VECTORS ;;;
;;;;;;;;;;;;;;;

;; State handler jump table {{{
handlers=*
    dw	handle_seq
    dw	handle_free
    dw	handle_lload
    dw	handle_lstage
    dw	handle_lload2
    dw	handle_lscroll
    dw	handle_rstage
    dw	handle_rload
    dw	handle_rscroll
    dw	handle_rload2
    dw	handle_vload
    dw	handle_vstage
    dw	handle_vload2
    dw	handle_vscroll
    dw	handle_vload3
;; }}}

;; Vector table {{{
*=$fffa
	dw	nmi
	dw	reset 
	dw	irq
;;; }}}

;;;;;;;;;;;;;;;;;;;;; 
;;; CHR REFERENCE ;;;
;;;;;;;;;;;;;;;;;;;;;

    ;; Include this in dummy mode so we can reference these values
    dummy
include realworld_day_tileset.s
