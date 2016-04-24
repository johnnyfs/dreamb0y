;;;;;;;;;;;;;;;;;;;;;;;
;; DREAMBOY          ;;
;; (c) 2015 johnnygp ;;
;;;;;;;;;;;;;;;;;;;;;;;

	cpu	6502

;; Zero page
	dummy
*=$0000
vector	ds	2		; generic address pointer

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
	sta	vector		; redundant
.incram	inc	vector + 1	; start at page 1
.clrram	sta	(vector), y	; clear byte y of page
	iny
	bne	.clrram		; loop until 256 bytes/page
	dex
	bne	.incram		; loop until we've cleared 8 pages

	;; clear the sprite mem
	lda	#$00		; redundant
	sta	$4014		; will write blank page 0 to ppu

	;; clear the ppu ram
	lda	#$20		; start at $20xx
	lsr
	tay			; y = 16 pages to clear
	sta	$2006
	lda	#0
	sta	$2006		; start at $2000
	tax			; x = 0 (byte to clear)
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

	;; Turn the screen back on.
	lda	#%10100000	; vblank enabled; 8x16 sprites
	sta	$2000
	lda	#%00011010	; image/sprite mask off/on, sprites/screen on 
	sta	$2001

.forevs	jmp	.forevs 

;; Nmi handler
nmi	rti

;; Irq handler
irq	rti

;; Test palette

palette	db	$1a, $27, $18, $0d	
	db	$1a, $0a, $08, $0d	
	db	$1a, $32, $22, $0d	
	db	$1a, $1b, $39, $34

	db	$1a, $20, $04, $0d	
	db	$1a, $20, $04, $0d	
	db	$1a, $19, $08, $0d	
	db	$1a, $19, $08, $0d	

;; Vector table
*=$fffa
	dw	nmi
	dw	reset 
	dw	irq
