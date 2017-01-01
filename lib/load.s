;;
;; start a map load from the staging area at $2080 to the
;; ppu at $2[04]80, depending on how the target in dsttbl
;;
;; also prepares to load the attributes
;;
	code
load_start	lda #$02
		sta load_chr_src + 1
		ldx #$80		    ;; start loading (skipping the status bar)
		stx load_chr_src	    ;; save x=$80

		lda dsttbl
		sta load_chr_dst + 1
		stx load_chr_dst	    ;; x=$80

		clc
		adc #$03		    ;; A was dsttbl high byte
		sta load_attr_dst + 1	    ;; attrs start at nametbl + $03C0 (+8 for status bar)
		lda #$C8
		sta load_attr_dst

		lda pos
		asl
		tay
		lda (maps), y		;; each map starts with 48 attribute bytes
		sta load_attr_src
		iny
                lda (maps), y
		sta load_attr_src + 1

		lda #3
		sta load_step

		rts

;;
;; Either load another row of 16 16x16 tiles (or 64 chrs) from the 
;; staging area to the PPU or, if two rows have been loaded, load
;; the attributes for those two rows to the PPU.
;;
;; This means that after every third call, two rows and their colors
;; will be available (and that one each first and second out of third,
;; the rows synced will not have the correct colors).
;;
;; Syncs a total of 12 rows, requiring 18 calls total.
;;
	code
load_next	dec load_step
		beq .load_attrs		;; every third call, sync attrs instead

		;; Load chrs
		lda load_chr_dst + 1	;; point the ppu at our saved place
		sta $2006
		lda load_chr_dst
		sta $2006

		ldy #0
		ldx #LOAD_BYTES_PER
.chr_loop	lda (load_chr_src), y	;; read from current source
		sta $2007		;; write to ppu
		iny
		dex			;; write 64 bytes
		bne .chr_loop

		;; Advance the chr pointers
		tya			;; (y == 64 now)
		clc
		adc load_chr_src		;; inc src by 64
                sta load_chr_src
		bne .nv
		inc load_chr_src + 1

.nv		tya
		clc
		adc load_chr_dst		;; inc dst by 64
                sta load_chr_dst
		bne .nv2
		inc load_chr_dst + 1
.nv2		rts

		;; Load attributes
.load_attrs	lda load_attr_dst + 1
		sta $2006
		lda load_attr_dst
		sta $2006

		ldx #8
		ldy #0
.attr_loop	lda (load_attr_src), y
		sta $2007
		iny
		dex
		bne .attr_loop

		;; Advance the pointers
		tya
		clc
		adc load_attr_src
		sta load_attr_src
		bcc .nv3
		inc load_attr_src + 1

.nv3		tya
		clc
		adc load_attr_dst
		sta load_attr_dst	;; this should never roll over b/c $3C8 + $30 < $400

		;; Reset the step counter
		lda #3
		sta load_step

		rts
