;;
;; start a map load from the staging area at $2080 to the
;; ppu at $2[04]80, depending on how the target in dsttbl
;;
;; also prepares to load the attributes
;;
	code
		;; find start of attribute data
load_start      lda #0
                sta load_nightmare      ;; clear nightmare flag

                lda pos			;; pos is index of map we're using
		asl
		tay
		lda (maps), y		;; each map starts with 48 attribute bytes

		;; tentatively set attr src ptr to start of data (if reverse we'll advance later)
		sta load_attr_src
		iny
                lda (maps), y
		sta load_attr_src + 1

		;; switch on whether we're reversing
		lda load_type
		cmp #LOAD_TYPE_BEFORE
		beq .setup_reverse

		;; setup chr src ptr for a forward load
		lda #$02
		sta load_chr_src + 1
		ldx #$80		    ;; start loading (skipping the status bar)
		stx load_chr_src	    ;; save x=$80

		;; dst pointer for forward depends on whether its overwrite or after
		lda load_type
		cmp #LOAD_TYPE_OVER
		bne .setup_aft_dst

		;; setup dst ptrs for overwrite
		lda dsttbl
		sta load_chr_dst + 1
		stx load_chr_dst	    ;; x = 80

		clc
		adc #$03		    ;; A was dsttbl high byte
		sta load_attr_dst + 1	    ;; attrs start at nametbl + $03C0 (+8 for status bar)
		lda #$C8
		sta load_attr_dst
		bne .done

		;; setup dst ptrs for an AFTER write
.setup_aft_dst	lda dsttbl
		clc
		adc #$03
		sta load_chr_dst + 1	    ;; the row after the map is $0380
		sta load_attr_dst + 1	    ;; attributes are $03F8
		stx load_chr_dst	    ;; x = 80
		lda #$F8
		sta load_attr_dst
		bne .done

		;; setup ptrs for a reverse load
.setup_reverse	lda #$05
		sta load_chr_src + 1
		lda #$40		    ;; ie, one row before the end
		sta load_chr_src

		;; we'll start on the last attr row (48 - 8 or + 40)
		lda load_attr_src
		clc
		adc #$28
		sta load_attr_src
		bcc .setup_rev_dst
		inc load_attr_src + 1

		;; setup the dst ptrs for a reverse load
.setup_rev_dst	lda dsttbl
		sta load_chr_dst + 1	    ;; dst starts right before map in status bar $2X40
		clc
		adc #$03
		sta load_attr_dst + 1	    ;; attrs start at nametbl + $03C0 (whole status bar is one row)
		lda #$40
		sta load_chr_dst	    ;; load into second row of status bar first

		lda #$C0		    ;; reverse load starts where status would be
		sta load_attr_dst

.done		lda #3
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

;;; MAJOR PHASE 1: LOAD CHRS ;;;

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

		;; Check whether we're reverse loading
		lda load_type
		cmp #LOAD_TYPE_BEFORE
		beq .reverse_chr

		;; Advance the chr pointers
		tya			;; (y == 64 now)
		clc
		adc load_chr_src	;; inc src by 64
                sta load_chr_src
		bcc .no_carry
		inc load_chr_src + 1	;; no need to check for overflow, we go from beginning to end

.no_carry	tya
		clc
		adc load_chr_dst	;; inc dst by 64
                sta load_chr_dst
		bcc .no_carry2
		inc load_chr_dst + 1

		;; Check for overflow (which *will* happen in LOAD_TYPE_AFTER)
.no_carry2	lda load_chr_dst + 1
		cmp load_attr_dst + 1	;; ie, 23 for MAIN, 27 for SWAP
		bne .no_overflow
                lda #$C0                ;; so, have we hit 2[37]C0?
		cmp load_chr_dst
		bne .no_overflow
		lda dsttbl
		sta load_chr_dst + 1	;; ie, wrap chr high byte to 20 for MAIN, 24 for SWAP
                lda #0
                sta load_chr_dst        ;; roll over chr to 0
.no_overflow	rts

		;; Reverse the chr pointers
.reverse_chr	lda load_chr_src
		sec
		sbc #LOAD_BYTES_PER
		sta load_chr_src
		bcs .no_borrow
		dec load_chr_src + 1	;; no need to check for underflow, we go from end to beginning

		;; Check for underrun
.no_borrow	lda load_chr_dst
		sec
		sbc #LOAD_BYTES_PER
		sta load_chr_dst
		bcs .no_borrow2
		dec load_chr_dst + 1
		lda load_chr_dst + 1
		cmp dsttbl		;; check if we've underrun (less than 20 for MAIN, 24 for SWAP)
		bcs .no_chr_under
		
		;; Underrun to 2[37]80
		lda load_attr_dst + 1	;; ie, 23 for MAIN, 27 for SWAP
		sta load_chr_dst + 1
		lda #$80
		sta load_chr_dst
		
.no_chr_under=*
.no_borrow2	rts

;;; MAJOR PHASE 2: Load attributes ;;;

.load_attrs     lda load_attr_dst + 1
		sta $2006
		lda load_attr_dst
		sta $2006

                ;; Check for nightmare mode
                lda load_nightmare
                beq .phew

                ldx #8
                ldy #0
.nm_attr_loop   lda (load_attr_src), y
                lsr
                lsr
                lsr
                lsr                     ;; now the bottom bits are in the "top" position
                sta tmp
                lda load_attr_src
                tya
                clc
                adc load_nightmare	;; use prev row for rev load, next row for forward
                tay
                lda (load_attr_src), y  ;; load the next row byte (should never wrap b/c we get here by overflowing)
                asl
                asl
                asl
                asl                     ;; now the top bits from the next row are in the "bottom" position
                ora tmp                 ;; now the bottom of this row is merged with the top of the next (shifted up)
                sta $2007               ;; hopefully this works...
                tya
                sec
                sbc #8
                tay
                iny
                dex
                bne .nm_attr_loop
                beq .attr_adv

.phew		ldx #8
		ldy #0
.attr_loop	lda (load_attr_src), y
		sta $2007
		iny
		dex
		bne .attr_loop

		;; Check whether we're reverse loading
.attr_adv	lda load_type
		cmp #LOAD_TYPE_BEFORE
		beq .reverse_attr

		;; Advance the attr pointers
                tya
		clc
		adc load_attr_dst
		sta load_attr_dst

		;; Check for overrun (will happen on LOAD_TYPE_AFTER)
		bcc .no_overattr
		lda #$C0
		sta load_attr_dst	;; never need to advance the high byte, whole table is 2[37]C0 - 2[37]FF
		lda #LOAD_NIGHTMARE_DOWN
                sta load_nightmare      ;; now we're in off-by-one nightmare mode
                bne .load_attrs         ;; and we repeat this row (but don't inc the src ptr)

                ;; Only advance if we didn't wrap around (nightmare means repeat one row)
.no_overattr	tya
		clc
		adc load_attr_src
		sta load_attr_src
		bcc .done_attr
		inc load_attr_src + 1	;; no chance of overrun here, we go from beginning to end


		;; Reset the step counter
.done_attr	lda #3
		sta load_step

		rts

		;; Reverse the attr pointers
.reverse_attr	lda load_attr_src
		sec
		sbc #8
		sta load_attr_src
		bcs .no_borrow3
		dec load_attr_src + 1	;; no need to check for underrun -- we go from end to beginning

.no_borrow3	lda load_attr_dst
		sec
		sbc #8
		sta load_attr_dst

		;; check for underrun
		cmp #$C0
		bcs .done_attr
		lda #$F8
		sta load_attr_dst
		lda #LOAD_NIGHTMARE_DOWN
		sta load_nightmare
		jmp .load_attrs		;; immediately rerun?

