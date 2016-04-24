;;;;;;;;;;;;;;;;;;;;;;;
;; DREAMBOY          ;;
;; (c) 2015 johnnygp ;;
;;;;;;;;;;;;;;;;;;;;;;;

	cpu	6502

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

.forevs	jmp	.forevs 

;; Nmi handler
nmi	rti

;; Irq handler
irq	rti

;; Vector table
*=$fffa
	dw	nmi
	dw	reset 
	dw	irq
