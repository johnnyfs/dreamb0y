RLE_LENGTH_MASK=    %00000011
RLE_INDEX_MASK=	    %11111100

;;
;; Initializes the map staging process. The map indexed by 
;; map_pos is decompressed to the staging area at $0280 ($0200-
;; $0280 contain the status bar). Subsequent calls to 
;; map_stage_next will advance the staging process one 16
;; pixel high line at a time (ie, 2 chr rows at a time).
;;
;; Expects that src points to a table of map data addresses
;; indexed by map_pos. After this call src will point to
;; the address of the map data.
;;
	code
stage_start     lda pos
		asl			;; addresses are 2 bytes
		tay
		lda (maps), y		;; get the low byte of the map data
		sta stage_src
		iny
		lda (maps), y		;; get the high byte
		sta stage_src + 1

		lda stage_src
		clc                     ;; skip the attribute bytes here
		adc #48                 ;; (TODO: opt out by just starting the read at y=48 and checking for y>=80?)
		bcc .nv
		inc stage_src + 1
.nv		sta stage_src

		lda #$02	        ;; we always write to the staging area right after status bar
		sta stage_dst + 1
		lda #$80
		sta stage_dst

		rts

;;
;; Advances the map staging process one row of 16 16x16 pixel 
;; tiles (ie, 2 8x8 pixel chrs). Depends on stage_src and stage_dst
;; pointers set by map_stage_start. Each call advances those
;; pointers. A map consists of 12 rows, and calling this more
;; than 12 times will produce undefined behavior.
;;
	code
stage_next	ldy #0
.load_run       ldx #0
                lda (stage_src, x)	; load next run code
		pha
		and #RLE_LENGTH_MASK	; 0-3 meaning 1-4 (ie, length - 1)
		tax
		inx			; x = run length
		pla
		and #RLE_INDEX_MASK	; a = run index (exactly, b/c each tile is made of 4 chrs)

		;; Write the next run of 1-4 tiles
.stage_run	sta (stage_dst), y	; write upper left chr
		iny			; advance dst once chr
		clc
		adc #1			; source_tile ++
		sta (stage_dst), y    	; write upper right chr (TODO: inc A works?)
		pha
		tya
		clc
		adc #31			; advance dst to next row (will never cross page boundary!)
		tay
		pla
		clc
		adc #1			; source_tile ++
		sta (stage_dst), y	; write the lower left corner
		iny			; advance dst once chr
		clc
		adc #1
		sta (stage_dst), y	; write the lower right corner
                pha
		tya
		sec
		sbc #31			; pull pointer back to next tile (+1 +31 +1 -31 = +2 chrs)
		tay
                pla
                sec
                sbc #3
		
		dex
		bne .stage_run		; loop until run is complete

		;; Advance the src ptr
		inc stage_src
		bne .end_run			; we loop back to the beginning b/c ptrs are advanced, so y should reset
		inc stage_src + 1		; can never overflow unless we hit the end of the ROM!
		bne .end_run

		;; Stop if we've hit the end of the row
.end_run	cpy #32
		bmi .load_run

		;; Advance the dst ptr by two 32-chr rows
.done		clc
		lda #64
		adc stage_dst
		sta stage_dst
                bne .exit
                inc stage_dst + 1
.exit		rts
