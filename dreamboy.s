;;;;;;;;;;;;;;;;;;;;;;;
;; dreamboy          ;;
;; (c) 2015 johnnygp ;;
;;;;;;;;;;;;;;;;;;;;;;;

	cpu	6502
	output	scode

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
	lda	#248
        sta     yscroll
	sta	$2005

	;; write the magic sprite 0
	ldx	#0
	stx	$2003
	lda	#37
	sta	$2004		; top line of sprite intersects status bar
	stx	$2004		; use chr 0 (ie, top left of status bar, which must have solid pixel at 1,1)
	lda	#%00100000
	sta	$2004		; attributes don't matter
	lda	#253
	sta	$2004		; left side of sprite intersects status bar (ie, top left corner)

	;; initialize the engine
	lda	#state_free		; engine initial state
	sta	state
	lda	#realworld_day & $ff	; engine initial map
	sta	maps
	lda	#realworld_day >> 8
	sta	maps + 1
        lda     #0
        sta     pos

	;; turn the screen back on.
	lda	#%10001000	; vblank enabled; 8x16 sprites
	sta	$2000
	sta	status		; save for later
	lda	#%00011010	; image/sprite mask off/on, sprites/screen on 
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

    	ldx	#24		;; the sprite hits a row early, so spin a little
.spin	dex
	bne	.spin

	;; TODO: incoroprate status loading into the stage/load process so this is less jumpy

	;; Switch to the map chrs after status bar is done
	lda	status
	sta	$2000

	;; And reset the scroll -- nmi will have messed with it
	lda	xscroll
	sta	$2005
	lda	yscroll
	sta	$2005

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

        lda     state

;;; HLOAD STATE: advance the load one more chunk ;;;
	
	;; this is inefficient but will be less so when we opt out the redundant load
        cmp	#STATE_LLOAD
	beq	.hload
	cmp	#STATE_RLOAD
	beq	.hload
	cmp	#STATE_LLOAD2
	beq	.hload
	cmp	#STATE_RLOAD2
	bne	.n_hld	

.hload	jsr     load_next
        lda     step
        lsr
        beq     .n_hld
	lsr
	beq	.n_hld		    ;; ie, only when step/2 is odd, or ever fourth step
        jsr     stage_load_attrs

	;; The scroll gets effed up when we mess with the ppu, so just always reset it
.n_hld	ldx	#$00		    ;; scroll bar is scrolled 1 over (so it doesn't move when we max it)
	lda	status
	ora	#%00010000
	sta	$2000
	lsr 
	bcc	.nswap
	dex			    ;; in the swap table we want maximum scroll (so status stays put)
.nswap	stx     $2005
        lda     yscroll
        sta     $2005

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
	    eor	joypad_prev	;; 0 ^ 1 || 1 ^ 0 => state changed
	    and	joypad_next	;; & 1 => was pressed

	    lsr
	    bcc	.n_right
	    jsr	start_rscroll
	    clv
	    bvc	.done
.n_right    lsr
	    bcc	.n_left
	    jsr	start_lscroll
	    clv
	    bvc .done
.n_left	    lsr
	    bcc	.n_down
.n_down	    lsr
	    bcc	.n_up
.n_up	    lsr
	    bcc	.n_strt
.n_strt	    lsr
	    bcc	.n_sel
.n_sel	    lsr
	    beq	.n_b
.n_b	    lsr
	    beq .done
.done	    rts
;;; }}}

;; Handle STATE_LSTAGE (first pass: stage the current map; TODO: opt this out when we can be sure it's already there) {{{
    code
handle_lstage	jsr	stage_next	;; advancing the staging process is done in the module
		dec	step
		bne	.done
		inc	state		;; state => LLOAD
		jmp	enter_load
.done		rts
;; }}}

;; Handle STATE_LLOAD (first pass: load the staged current map into the swap table and switch view) {{{
    code
handle_lload	dec	step		;; loading is done in nmi, here we just count down
		bne	.done
		inc	state		;; state => LSTAGE2
		dec	pos		;; next phase is to load the new map to the main table
		jsr	toggle_viewtbl
		lda	#NAMETBL_MAIN
		jmp	enter_stage	;; enter_stage sets the nametbl from A
.done		rts
;; }}}

;; Handle STATE_LSTAGE2 (second pass: stage the new map) {{{
    code
handle_lstage2	jsr	stage_next	;; advancing the staging process is done in the module
		dec	step
		bne	.done
		inc	state		;; state => LLOAD2
		jmp	enter_load
.done		rts
;; }}}

;; Handle STATE_LLOAD2 (second pass: load the staged new map into the main table) {{{
    code
handle_lload2	dec	step		;; loading is done in nmi, here we just count down
		beq	.fallthrough
		rts
.fallthrough	inc	state		;; state => LSCROLL
		jsr	toggle_viewtbl	;; scroll starts fully scrolled & counts down, so POV is end (main) table
		;; since fully scrolled is scroll=256=0, fall through to prevent the table jumping
;; }}}

;; Handle STATE_LSCROLL (scroll from the old map in the swap table back to the new map in the main table) {{{
    code
handle_lscroll	lda	xscroll
		sec
		sbc	#SCROLL_DELTA
		sta	xscroll	
		bne	.done		;; scroll left until 0
		lda	#STATE_FREE
		sta	state		;; and we're done
.done		rts
;; }}}

;; Handle STATE_RSTAGE (first pass: stage the new map) {{{
    code
handle_rstage	jsr	stage_next
		dec	step
		bne	.done
		inc	state		;; state => RLOAD
		jmp	enter_load
.done		rts
;; }}}

;; Handle STATE_RLOAD (first pass: load the staged new map into the swap table) {{{
    code
handle_rload	dec	step		;; actual loading is done in the nmi	
		beq	.fallthrough
		rts
.fallthrough	inc	state		;; state => RSCROLL
		;; fallthrough isn't necessary here, but keeps the speed consistent
;; }}}

;; Handle STATE_RSCROLL (scroll from the current map in the main table to the new map in the swap table) {{{
    code
handle_rscroll	lda	#SCROLL_DELTA	
		clc
		adc	xscroll
		sta	xscroll
		bne	.done
		jsr	toggle_viewtbl
		inc	state		;; state => RSTAGE2
		lda	#NAMETBL_MAIN
		jmp	enter_stage	;; expects nametbl target in A
.done		rts
;; }}}

;; Handle STATE_RSTAGE2 (second pass: stage another copy of the new map; TODO: opt out b/c it's already there!) {{{
    code
handle_rstage2	jsr	stage_next
		dec	step
		bne	.done
		inc	state		;; state => RLOAD
		jmp	enter_load
.done		rts
;; }}}

;; Handle STATE_RLOAD2 (second pass: load the new map into the main table and switch the view) {{{
    code
handle_rload2	dec	step		;; actual loading is done in the nmi	
		bne	.done
		jsr	toggle_viewtbl
		lda	#STATE_FREE
		sta	state
.done		rts
;; }}}

;;;;;;;;;;;;;;;;;;;;;;
;;; ENGINE HELPERS ;;;
;;;;;;;;;;;;;;;;;;;;;;

;; Start l/r scrolling {{{ 

start_rscroll	inc     pos		;; right means pos ++
		lda	#STATE_RSTAGE
		bne     .common         ;; will always branch
start_lscroll	lda	#STATE_LSTAGE	
.common	        sta	state
		lda	#NAMETBL_SWAP	;; the first load will happen in the swap table regardless
		;; fallthrough to enter_stage
;;; }}}

;; Enter the stage state (arg A == nametbl target) {{{
enter_stage	sta	dsttbl
		lda     #STAGE_STEPS
		sta     step
		jmp     stage_start	;; opt out the second return
;;; }}}

;; Enter load state {{{
    code
enter_load	lda	#LOAD_STEPS
		sta	step
		jsr	load_start
		rts
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
include	lib/ldmap.s
    
include lib/joypad.s
include lib/load.s
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

	db	$0d, $1a, $20, $04
	db	$0d, $1a, $20, $04
	db	$0d, $1a, $19, $08
	db	$0d, $1a, $19, $08

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
;; }}}

;; Status bar {{{

status_bar=*
include res/status_bar.tbl.s
;; }}}

;;;;;;;;;;;;;;;
;;; VECTORS ;;;
;;;;;;;;;;;;;;;

;; State handler jump table {{{
handlers=*
    dw	handle_seq
    dw	handle_free
    dw	handle_lstage
    dw	handle_lload
    dw	handle_lstage2
    dw	handle_lload2
    dw	handle_lscroll
    dw	handle_rstage
    dw	handle_rload
    dw	handle_rscroll
    dw	handle_rstage2
    dw	handle_rload2
;; }}}

;; Vector table {{{
*=$fffa
	dw	nmi
	dw	reset 
	dw	irq
;;; }}}
