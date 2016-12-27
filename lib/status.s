;;
;; draw whatever is at the label status_bar to
;; load position at $0500 
;;
;; TODO: pre shift these values before saving (util?)
;;

    code
status_load ldx	#0
	    ldy	#0
	    lda	#2
	    sta	row
.ldrow	    lda	#16
	    sta	column
.ldcol	    lda status_bar, x
	    asl
	    asl
	    sta $0200, y
	    clc
	    adc	#1
	    sta	$0201, y
	    clc
	    adc	#1
	    sta	$0220, y
	    clc
	    adc #1
	    sta	$0221, y
	    iny
	    iny
	    inx
	    dec	column
	    bne	.ldcol
	    tya
	    clc
	    adc	#32
	    tay
	    dec	row
	    bne	.ldrow
    	    rts
