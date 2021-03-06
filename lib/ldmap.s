RLE_LENGTH_MASK=    %00000011
RLE_INDEX_MASK=	    %11111100

;;
;; decompresses the map data pointed to by <src> to $0280,
;; with attributes (starts right after the status bar)
;;
	code
ldmap	lda #$02
	sta dst + 1
	lda #$80
	sta dst			; dst = $0280

        lda #0
	sta srci
	sta dsti
	tay			; srci = dsti = y = 0

	lda #3
	sta count
.newblk	lda #4
	sta row			
.newrow	lda #16
	sta column		; read 12 rows of 16 cols in 3 chunks
	
	tya
	pha			; save the src index

	;; decompress the top half of the row
.ldrun	lda (src), y
	and #RLE_LENGTH_MASK
	tax
	inx			; x = run length
	lda (src), y
	and #RLE_INDEX_MASK	; a = run index

	iny
	sty srci		; srci ++
	ldy dsti		; switch to writing
.strun	sta (dst), y
	iny
	clc 
	adc #1			; add 1 to get upper right corner
	sta (dst), y
	iny
	sec
	sbc #1
	dec column
	beq .endrow
	dex
	bne .strun
	sty dsti
	ldy srci
	jmp .ldrun

.endrow lda #16			; repeat row w/ bottom half
	sta column

	sty dsti
	pla 
	tay			; restore src index to start of row

	;; decompress the bottom have of the row
.ldrun2	lda (src), y
	and #RLE_LENGTH_MASK
	tax
	inx			; x = run length
	lda (src), y
	and #RLE_INDEX_MASK	; a = run index

	iny
	sty srci		; srci ++
	ldy dsti		; switch to writing

	clc
	adc #2			; add 2 to get lower left corner
.strun2 sta (dst), y
	iny
	clc
	adc #1
	sta (dst), y		; add 1 more to get lower right corner
	iny
	sec
	sbc #1
	dec column
	beq .endro2
	dex
	bne .strun2
	sty dsti
	ldy srci
	jmp .ldrun2

.endro2	sty dsti
	ldy srci
	dec row
	bne .newrow
	inc dst + 1	    ; each chunk is a new page
	dec count
	bne .newblk

        ;; write 8 status attribute bytes
        ldx #8
        ldy #0
        lda #$ff
.statr  sta $05C0, y
        iny
        dex
        bne .statr

	;; decompress the attributes
        ldy srci
        ldx #0
.attrs  lda (src), y
        sta $05C8, x
        iny
        inx
        cpx #64
        bne .attrs

.done	rts
