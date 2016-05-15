;;;;;;;;;;;;;;;;;;;;;;;
;; DREAMBOY          ;;
;; (c) 2015 johnnygp ;;
;;;;;;;;;;;;;;;;;;;;;;;

	cpu	6502
	output	SCODE

include lib/zero.s

;; PRG-ROM bank 1
*=$C000

;;  Reset handler
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

        ;; Load the test map.
        lda     #(testmap >> 8) & 0xff
        sta     src + 1
        lda     #(testmap & 0xff)
        sta     src
        jsr     ldmap

	;; Load the status bar
	jsr	status_load

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

	;; Turn the screen back on.
	lda	#%10100000	; vblank enabled; 8x16 sprites
	sta	$2000
	lda	#%00011010	; image/sprite mask off/on, sprites/screen on 
	sta	$2001


.main	lda	frames
.wait	cmp	frames
	bne	.wait
	bne	.main


;; Nmi handler
	code
nmi  	inc	frames
	ldy	#19
	ldx	#0
.spin	dex
	bne	.spin
	dey
	bne	.spin
	ldx	#136
.tail	dex
	bne	.tail
    
        ;; yyyVHYYYYYXXXXXxxx
        ;;   
        ;; Switch off the screen during retrace
        stx     $2001

        ;; Turn the screen back on
	lda     #%10110000	
	sta	$2000
	lda	#%00011010	; image/sprite mask off/on, sprites/screen on 
        sta     $2001

	ldy	#3
	ldx	#0
.spin2	dex
	bne	.spin2
	dey
	bne	.spin2
	lda     #%10100000	
	sta	$2000
	rti

;; Irq handler
irq	rti

include	lib/ldmap.s
include lib/status.s

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

;; Vector table
*=$fffa
	dw	nmi
	dw	reset 
	dw	irq
