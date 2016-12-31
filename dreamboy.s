;;;;;;;;;;;;;;;;;;;;;;;
;; dreamboy          ;;
;; (c) 2015 johnnygp ;;
;;;;;;;;;;;;;;;;;;;;;;;

	cpu	6502
	output	scode

include lib/zero.s

;; prg-rom bank 1
*=$c000

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

;; fall-through to main here.

;; main loop {{{
main	lda	frames
.wait	cmp	frames
	beq	.wait		;; loop until the frame counter changes


;;; FREE PLAY STATE ;;;

	lda	state
	cmp	#STATE_FREE
	bne	.n_free

	;; handle input: for now, switch the screen
	jsr	joypad_strobe
	lda	joypad_next
	eor	joypad_prev	;; 0 ^ 1 || 1 ^ 0 => state changed
	and	joypad_next	;; & 1 => was pressed

	lsr
	bcc	.n_rght
	jsr	mvright
        jmp     .waitn0

.n_rght	lsr
	bcc	.n_left
	jsr	mvleft
        jmp     .waitn0

.n_left	lsr
	bcc	.n_down

.n_down	lsr
	bcc	.n_up

.n_up	lsr
	bcc	.n_strt

.n_strt	lsr
	bcc	.n_sel

.n_sel	lsr
        beq	.n_b

.n_b	lsr
        beq     .n_a
        
.n_a    jmp     .waitn0


;;; HSTAGE STATE ;;;

.n_free cmp	#STATE_HSTAGE
	bne	.n_hstg

	;; Stage the entire table for hstaging
	jsr	stage_next
	dec	step
	bne	.n_a	    ;; watch this hack -- branch is too long

	;; Prepare to load the map to the current target table
	ldx	#LOAD_STEPS
	stx	step
	ldx	#STATE_HLOAD
	stx	state
	jsr	load_start
	bne	.waitn0


;;; HLOAD STATE ;;;

.n_hstg	cmp	#STATE_HLOAD
	bne	.n_hld

        dec     step		;; just count -- all the work is done in nmi
        bne     .waitn0

	lda	scroll_speed	
	bpl	.do_r

	lda	status
	eor	#%00000001
	sta	status
	lsr
	bcc	.to_scr		;; we just finished the new map, so it's time to scroll back

	;; otherwise, stage the new map
	;; TODO: pull this out into a dostage subroutine
	dec	pos
	lda	#STATE_HSTAGE
	sta	state
	lda	#STAGE_STEPS
	sta	step
	lda	#NAMETBL_MAIN
	sta	nametbl
	jsr	stage_start
	jmp	.waitn0		

	;; if we're scrolling right, we stage the new map, scroll, then stage the new again
.do_r	lda	status
	lsr
	bcc	.to_scr		;; if we're still looking at the main table, time to scroll

	;; otherwise, we're done scrolling, and it's time to switch back
	asl			;; this will clear the 0 bit :)
	sta	status
	lda	#STATE_FREE	;; player can play again!
	sta	state
	bne	.waitn0

.to_scr	lda     #STATE_HSCROLL
	sta     state
	lda	#SCROLL_STEPS
	sta	step

	;; fall through and start scrolling right away


;;; HSCROLL STATE ;;;

.n_hld	cmp	#STATE_HSCROLL
	bne	.waitn0

	;; actually scroll
	lda	scroll_speed
	clc
	adc	xscroll
	sta	xscroll

	;; count down scroll steps
	dec	step
	bne	.waitn0

	;; onl flip and stage if we're scrolling right
	lda	scroll_speed
	bmi	.do_fre

	lda	status
	eor	#%00000001
	sta	status

	;; if we're scrolling right, prepare to stage the map in the main table
	lda	#STATE_HSTAGE
	sta	state
	lda	#STAGE_STEPS
	sta	step
	lda	#NAMETBL_MAIN
	sta	nametbl
	jsr	stage_start
	bne	.waitn0		;; will always branch

	;; if we're scrolling left, we're done here
.do_fre	lda	#STATE_FREE
	sta	state

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

	;;  Switch to the map chrs after status bar is done
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


;; mvright/left: state transition for map switching {{{ 

mvright inc     pos		;; right means pos ++
        lda     #SCROLL_DELTA	;; right means positive scroll speed
        bne     mvh             ;; will always branch
mvleft  lda     #-SCROLL_DELTA	;; left means negative scroll speed (we don't dec pos until later!)
mvh     sta     scroll_speed	;; code common to left/right from here down
        lda     #STATE_HSTAGE
        sta     state
	lda	#NAMETBL_SWAP	;; the first load will happen in the swap table
	sta	nametbl
        lda     #14		;; the map is 14 16x16 rows
        sta     step
        jmp     stage_start	;; opt out the second return

;;; }}}

;; Nmi and Irq handlers {{{
	code
nmi	pha
        txa
        pha
        tya
        pha

        lda     state

;;; HLOAD STATE: advance the load one more chunk ;;;
	
        cmp	#STATE_HLOAD
        bne     .n_hld
        jsr     load_next
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


;; Modules {{{
    ;; test modules
include	lib/ldmap.s
    
include lib/joypad.s
include lib/load.s
include lib/stage.s
include lib/status.s
;; }}}


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

;; Compressed map data (TODO: attributes come first!)
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

status_bar=*
include res/status_bar.tbl.s
;; }}}


;; Vector table {{{
*=$fffa
	dw	nmi
	dw	reset 
	dw	irq
;;; }}}
