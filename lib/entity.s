entity_spawn_player lda	#ENTITY_FACE_DOWN
		    sta	entity_face
		    lda	#128
		    sta	entity_y
		    sta	entity_x
		    lda	#0
		    sta	entity_pal	    ;; player uses pal 0 always
		    lda	#player_chrs
		    sta	entity_base_chr
		    rts

entity_draw_player  ldx	#0		    ;; sprite draw offset (right after sprite 0)

		    ;; Precalc start y
		    lda	entity_y
		    sec
		    sbc	#32
		    sta	entity_spr_y

                    lda #0
                    sta entity_nudge

		    ;; Precalc attrs for horizontal writes (flip if facing left)
                    lda entity_face
                    and #ENTITY_FACE_HORIZ
		    beq	.not_horiz          

                    ;; Do common horizontal stuff
                    ldy #widget_chrs
                    iny
                    iny
                    sty entity_chr_i        ;; side face is widget + 2
                    lda #1
                    sta entity_nudge

		    lda	entity_face
		    and	#ENTITY_FACE_LEFT_IF_HORIZ
		    beq	.no_flip            ;; b/c facing right
                    lda #2
		    sta	entity_index	    ;; entity index is 2 for left (right flipped)
		    lda	#ENTITY_ATTRS_HFLIP
	    	    ora	entity_pal
		    sta	entity_attrs	    ;; we use this when flipping might happen
		    lda	entity_x
		    sta	entity_hx1	    ;; start at x (middle)
		    lda	#-8		    ;; and work back
		    sta	entity_hdx
                    lda #-1
                    sta entity_nudge
		    bne	.draw_face

.not_horiz          lda #widget_chrs
                    sta entity_chr_i        ;; front face is widget + 0

		    ;; Init h vars for non-flipped
.no_flip	    lda entity_face 
                    sta	entity_index	    ;; index = facing if not flipped
		    lda	entity_pal
		    sta	entity_attrs       ;; no flip, just palette
		    lda	entity_x
		    sec
		    sbc	#8		    ;; start at x - 8 (left side)
		    sta	entity_hx1
		    lda	#8		    ;; and work forward
		    sta	entity_hdx

		    ;; Do we need to draw a face?
.draw_face	    lda	entity_face
		    cmp	#ENTITY_FACE_UP
		    beq	.draw_head

		    ;; draw the skin
		    lda	entity_spr_y	    ;; top of ent
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_chr_i	    ;; whichever face we chose earlier
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_attrs
                    ora #1                  ;; bump the palette to the skin pal
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_x
                    sec
		    sbc	#4		    ;; center the face
                    clc
                    adc entity_nudge        ;; face needs a little help :(
		    sta	SPRITES + 4, x
                    inx

		    ;; draw the actual head
.draw_head	    lda	entity_spr_y
		    sta	SPRITES + 4, x	    ;; restore the y we used for the face
		    inx
		    lda	entity_index
		    asl
                    asl
		    clc
		    adc	entity_base_chr	    ;; base chr + facing * 4 = chr index of left head
		    sta	entity_chr_i	    ;; save working base index
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_attrs
		    sta	SPRITES + 4, x	    ;; head will be flipped if facing left
		    inx
		    lda	entity_hx1	    ;; left side (or middle if flipped)
		    sta	SPRITES + 4, x
                    inx

		    lda	entity_spr_y	    ;; restore y we used for face/first head
		    sta	SPRITES + 4, x
		    inx
		    ldy	entity_chr_i
		    iny
		    iny			    ;; advance chr + 2 (to next sprite in 8x16 mode)
                    sty entity_chr_i        ;; (easy to get standing legs by adding pitch-1)
                    tya
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_attrs	    ;; flipped if facing left
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_hx1
		    clc
		    adc	entity_hdx	    ;; +8 to middle if not flipped, else -8 to left
		    sta	SPRITES + 4, x
                    inx

                    ;; TODO: check if we're standing

                    ;; load the legs
                    lda entity_spr_y
                    clc
                    adc #16
                    sta entity_spr_y
                    sta SPRITES + 4, x
                    inx
                    lda entity_chr_i
                    clc
                    adc #10                 ;; += (pitch -1) * 2
                    sta entity_chr_i
                    sta SPRITES + 4, x
                    inx
                    lda entity_attrs
                    sta SPRITES + 4, x
                    inx
                    lda entity_hx1
                    sta SPRITES + 4, x
                    inx

                    lda entity_spr_y
                    sta SPRITES + 4, x
                    inx
                    ldy entity_chr_i
                    iny
                    iny
                    tya
                    sta SPRITES + 4, x
                    inx
                    lda entity_attrs
                    sta SPRITES + 4, x
                    inx
                    lda entity_hx1
                    clc
                    adc entity_hdx
                    sta SPRITES + 4, x
                    inx
		    
		    rts

entity_player_face_left     lda #ENTITY_FACE_LEFT
                            sta entity_face
                            rts

entity_player_face_right    lda #ENTITY_FACE_RIGHT 
                            sta entity_face
                            rts

entity_player_face_up       lda #ENTITY_FACE_UP
                            sta entity_face
                            rts

entity_player_face_down     lda #ENTITY_FACE_DOWN
                            sta entity_face
                            rts
