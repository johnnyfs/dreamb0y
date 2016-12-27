;;;;;;;;;;;;;;;;;;;;;;;
;; DREAMBOY          ;;
;; (c) 2015 johnnygp ;;
;;;;;;;;;;;;;;;;;;;;;;;

	cpu	6502
	output	SCODE

include lib/zero.s

;; PRG-ROM bank 1
*=$C000

;; Reset handler {{{
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

	;; Load the status bar
	jsr	status_load

        ;; Load the test map.
        lda     #(testmap >> 8) & 0xff
        sta     src + 1
        lda     #(testmap & 0xff)
        sta     src
        jsr     ldmap

	;; Copy the test map to the screen
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
	sta	$2005
	lda	#248
	sta	$2005

	;; write the magic sprite 0
	ldx	#0
	stx	$2003
	lda	#39
	sta	$2004		; top line of sprite intersects status bar
	stx	$2004		; use chr 0 (ie, top left of status bar, which must have solid pixel at 1,1)
	stx	$2004		; attributes don't matter
	dex			; x = 255
	dex
	stx	$2004		; left side of sprite intersects status bar (ie, top left corner)

	;; Turn the screen back on.
	lda	#%10110000	; vblank enabled; 8x16 sprites
	sta	$2000
	lda	#%00011010	; image/sprite mask off/on, sprites/screen on 
	sta	$2001
;; }}}


;; Main loop {{{
main	lda	frames
.wait	cmp	frames
	beq	.wait		;; loop until the frame counter changes

	;; Wait for the sprite 0 flag to clear
.waitn0	lda	$2002
	and	#%01000000
	bne	.waitn0

	;; Wait on sprite 0
.wait0	lda	$2002
	and	#%01000000
	beq	.wait0

	;;  Switch to the map chrs after status bar is done
	lda	#%10100000
	sta	$2000

	;; Loop (main will wait on frame ctr -- ie, until after status is drawn)
	jmp	main
;; }}}


;; Nmi and Irq handlers {{{
	code
nmi	pha
	lda     #%10110000  ;; switch to status chrs during vblank
	sta	$2000

	;; Increment the frame counter
	inc	frames
	bne	.not0
	inc	frames + 1
.not0   pla
irq	rti		    ;; so 12 this path also + 6 for rti
;; }}}


;; Modules {{{
include	lib/ldmap.s
include lib/joypad.s
include lib/status.s
;; }}}


;; Test data {{{
;; Test palette

palette	db	$0d, $1a, $27, $18
	db	$0d, $1a, $0a, $08
	db	$0d, $1a, $32, $22
        db      $0d, $20, $04, $18

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
status_bar=*
include res/status_bar.tbl.s
;; }}}


;; Vector table {{{
*=$fffa
	dw	nmi
	dw	reset 
	dw	irq
;;; }}}
