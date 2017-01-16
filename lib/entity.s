;; glossary
;;  entity: abstract representation of a moving object on the screen
;;  state: discrete behavior mode (eg, STANDING or WALKING)
;;  direction: compass direction (N, NE, S, SE, etc))
;;  face: the direction an entity is facing (UP DOWN LEFT RIGHT)
;;  pane: 16x16 piece of the visual representation of an entity (eg, face or legs)
;;  sprite: the 8x16 graphics units of which a pane is composed
;;  pal: the sprite palette (0-3) to use for this sprite
;;  flip: whether a sprite should be drawn flipped (eg, the right head flipped is the left)
;;  chr: 8x8 tile starting an 8x16 unit; index into the tile bank that id's a sprite/pane
;;  base chr: start of all panes associated with this entity
;;  key: discrete stage in an animation cycle; lasts some # of steps; 4 total
;;  phase: first or second time a series of keys are repeated (right leg, left leg, etc)
;;  step: 1 frame/tick's worth of animation
;;  bounce: y offset for drawing an entity at this key in its animation cycle
;;  d[xy]: how much an entity moves at this key in its animation cycle
;;  draw_dx: direction of progress for the draw

;; Data model
;;  - entities sit compressed at $0580
;;  - entities are decompressed one at a time to the zero page
;;  - there they are drawn, then updated
;;  - updated entities are compressed to the second ent area at $0640
;;  - updated entities are sorted by y coordinate, highest to lowest, back to the $0580 area

ENTITY_PLOT_SPRITE1 MACRO
		    lda	entity_draw_y
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_chr_i
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_draw_attrs
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_draw_x1
		    sta	SPRITES + 4, x
		    inx
		    ENDM

ENTITY_PLOT_SPRITE2 MACRO
		    lda	entity_draw_y
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_chr_i
		    clc
		    adc	#2
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_draw_attrs
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_draw_x2
		    sta	SPRITES + 4, x
		    inx
		    ENDM

ENTITY_CALC_X_FROM_FLIP	MACRO
			lda	entity_draw_dx1_by_flip, y
			clc
			adc	entity_x
			sta	entity_draw_x1
			lda	entity_draw_dx2_by_flip, y
			clc
			adc	entity_x
			sta	entity_draw_x2
			ENDM

;; tmp: copy a fake player to the zero page staging area for now
entity_spawn_player lda #ENTITY_STATE_STANDING
                    sta entity_state
		    lda	#ENTITY_FACE_DOWN
		    sta	entity_face
		    lda	#150
		    sta	entity_y
		    lda	#122
		    sta	entity_x
		    lda	#0
		    sta	entity_pal	    ;; player uses pal 0 always
		    lda	#player_chrs
		    sta	entity_base_chr
		    rts


;; draw the player standing/walking
entity_draw_player  ldx	#0		    ;; sprite draw offset (right after sprite 0)

		    ;; Precalc starting draw y for all states
		    lda	entity_y
		    sec
		    sbc	#32
		    sta	entity_draw_y
                    lda entity_state
                    beq .no_draw_dy	    ;; no bounce for standing state
                    ldy entity_key
                    lda entity_draw_dy_by_key, y
                    clc
                    adc entity_draw_y
                    sta entity_draw_y

		    ;; Get flip and build attrs for head/skin
.no_draw_dy	    ldy	entity_face
		    lda	entity_head_and_standing_leg_flip_by_face, y
		    tay
		    lda	entity_attrs_flag_by_flip, y
		    ora	entity_pal
		    sta	entity_draw_attrs

		    ;; Use flip to pre-calc x position for head
		    ENTITY_CALC_X_FROM_FLIP

		    ;; Special case: draw a black square over the head if we're too high
		    lda	entity_draw_y
		    cmp	#38
		    bcs	.no_blackout

		    lda	#24
		    sta	SPRITES + 4, x
		    inx
		    lda	#widget_chrs + 4
		    sta	SPRITES + 4, x
		    inx
		    lda	#00100000
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_draw_x1
		    sta	SPRITES + 4, x
		    inx

		    lda	#24
		    sta	SPRITES + 4, x
		    inx
		    lda	#widget_chrs + 4
		    sta	SPRITES + 4, x
		    inx
		    lda	#00100000
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_draw_x2
		    sta	SPRITES + 4, x
		    inx

		    ;; Get skin widget sprite
.no_blackout	    lda entity_x 
                    cmp #8
                    bcc .no_skin            ;; don't draw it if we're slightly off the screen
                    ldy	entity_face
		    lda	entity_skin_widget_sprite_by_face, y
		    bmi	.no_skin	    ;; (-1) == no skin (ie, we're facing up)
		    clc
		    adc #widget_chrs
		    sta	entity_draw_chr_i

		    ;; Draw the skin sprite
		    lda	entity_draw_y
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_draw_chr_i
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_draw_attrs
		    ora	#%00000001	    ;; use skin palette
		    sta	SPRITES + 4, x
		    inx
		    lda	entity_x
		    ldy	entity_face
		    lda	entity_skin_dx_by_face, y
		    clc
		    adc	entity_x
		    sta	SPRITES + 4, x
		    inx

		    ;; Get the index of the first head sprite
.no_skin	    ldy	entity_face
		    lda	entity_head_pane_index_by_face, y
		    clc
		    adc	entity_base_chr
		    sta	entity_chr_i

		    ;; Draw the head
		    ENTITY_PLOT_SPRITE1
		    ENTITY_PLOT_SPRITE2

		    ;; Calculate y pos for legs
		    lda	entity_draw_y
		    clc
		    adc	#16
		    sta	entity_draw_y

		    ;; Switch by STANDING v WALKING
		    lda	entity_state
		    bne	.draw_walking

		    ;; Load the standing legs
		    ldy	entity_face
		    lda	entity_standing_leg_pane_by_face, y
		    clc
		    adc	entity_base_chr
		    sta	entity_chr_i

		    ;; Nothing else changes for the standing frame
		    ENTITY_PLOT_SPRITE1
		    ENTITY_PLOT_SPRITE2

                    rts

		    ;; Walking uses a different flip
.draw_walking	    lda	entity_face
		    asl
		    clc
		    adc	entity_phase	;; = face * 2 + phase
		    tay
		    lda	entity_walking_leg_flip_by_face_and_phase, y
		    tay
		    lda	entity_attrs_flag_by_flip, y
		    ora	entity_pal
		    sta	entity_draw_attrs

		    ;; Calc the new x's for the legs
		    ENTITY_CALC_X_FROM_FLIP

		    ;; Find the correct walking leg pane
		    lda	entity_face
		    asl
		    asl
		    asl		;; * 8
		    clc
		    adc	entity_key_n
		    tay
		    lda	entity_walking_leg_pane_by_face_and_key_w_phase, y
		    clc
		    adc	entity_base_chr
		    sta	entity_chr_i

		    ;; Actually draw the legs
		    ENTITY_PLOT_SPRITE1
		    ENTITY_PLOT_SPRITE2

		    ;; emit two blank sprites
		    ldy	#8
		    lda	#0
.emit_blank	    sta	SPRITES + 4, x
		    inx
		    dey
		    bne	.emit_blank

		    rts

    code
;; update state based on controls; advance based on state
entity_update_player	lda entity_state
			bne .update_walking

			;; Check if a direction is currently pressed
			lda joypad_next
			and #%00001111	    ;; mask off just the directions UDLR
			tay
			lda entity_buttons_to_dir, y
			bmi .standing_done  ;; -1 == DIR_NONE (ie, no directions pressed)

			;; Turn the movement direction into a facing direction
			tay
			lda entity_dir_to_face, y
			sta entity_face

			;; Reset key and phase
			ldy #0
			sty entity_key
			sty entity_phase
			sty entity_key_n

			;; Set the step counter for the first key
			lda entity_wait_by_key, y
			sta entity_step

			;; Enter walking state
			lda #ENTITY_STATE_WALKING
			sta entity_state

.standing_done		rts

			;; Check if a direction is currently pressed
.update_walking		lda joypad_next
			and #%00001111
			tay
			lda entity_buttons_to_dir, y
			bpl .advance_walking

			;; Otherwise, we've halted; switch to STANDING
			lda #ENTITY_STATE_STANDING
			sta entity_state
			
			;; Face remains what it was; no other values matter
			rts

			;; Direction might have changed, but don't reset cycle (overkill)
.advance_walking	tay
			lda entity_dir_to_face, y
			sta entity_face

			;; Update position
			tya
			asl
			asl
			clc
			adc entity_key	;; = dir * 4 + key
			tay
			lda entity_dir_to_dx_by_key, y
			clc
			adc entity_x
			sta entity_x
			lda entity_dir_to_dy_by_key, y
			clc
			adc entity_y
			sta entity_y

			;; Advance cycle (TODO: improve this by reversing order?)
			dec entity_step
			bne .advance_done   ;; step isn't exhausted, we're done here
			inc entity_key
			inc entity_key_n    ;; TODO: only one value, separated during decomp
		   	ldy entity_key
			cpy #4		    ;; has key rolled over?
			bne .set_step
			ldy #0
			sty entity_key	    ;; reset key
			inc entity_phase
			lda entity_phase
			cmp #2		    ;; has phase rolled over?
			bne .set_step
			lda #0
			sta entity_phase
			sta entity_key_n    ;; TODO: only one value

			;; Reset the step counter as needed
.set_step		lda entity_wait_by_key, y
			sta entity_step

.advance_done		rts

    ;; Lookup tables for drawing
entity_draw_dy_by_key=*		    ;; bounce for walking anim
    db	0, 1, 1, -1

entity_skin_dx_by_face=*	    ;; skin adjustment
    db	-4, -4, -3, -5

entity_head_and_standing_leg_flip_by_face=*
    db	0   ;; DOWN
    db	0   ;; UP
    db	0   ;; RIGHT
    db	1   ;; LEFT

entity_attrs_flag_by_flip=*
    db	0
    db	ENTITY_ATTRS_HFLIP

entity_skin_widget_sprite_by_face=*
    db	0   ;; DOWN
    db	-1  ;; UP
    db	2   ;; RIGHT
    db	2   ;; LEFT

entity_head_pane_index_by_face=*
    db	0   ;; DOWN
    db	4   ;; UP
    db	8   ;; RIGHT
    db	8   ;; LEFT

entity_draw_dx1_by_flip=*
    db	-8  ;; no flip: start on left side
    db	0   ;; flip: start in middle
    
entity_draw_dx2_by_flip=*
    db	0   ;; no flip: draw middle second
    db	-8  ;; flip: draw left side second
    
entity_standing_leg_pane_by_face=*
    db	12  ;; DOWN
    db	16  ;; UP
    db	20  ;; RIGHT
    db	20  ;; LEFT

entity_walking_leg_flip_by_face_and_phase=*
    db	 0,  1	;; DOWN
    db	 0,  1	;; UP
    db	 0,  0	;; RIGHT
    db	 1,  1	;; LEFT

entity_walking_leg_pane_by_face_and_key_w_phase=*
    db	24, 28, 28, 32, 24, 28, 28, 32
    db	36, 40, 40, 44, 36, 40, 40, 44
    db	48, 52, 52, 56, 60, 64, 64, 68
    db	48, 52, 52, 56, 60, 64, 64, 68

    ;; Lookup tables for update
entity_buttons_to_dir=*	    ;; UDLR
    db	DIR_NONE	    ;; 0000
    db	DIR_E		    ;; 0001
    db	DIR_W		    ;; 0010
    db	DIR_NONE	    ;; 0011
    db	DIR_S		    ;; 0100
    db	DIR_SE		    ;; 0101
    db	DIR_SW		    ;; 0110
    db	DIR_S		    ;; 0111
    db	DIR_N		    ;; 1000
    db	DIR_NE		    ;; 1001
    db	DIR_NW		    ;; 1010
    db	DIR_N		    ;; 1011
    db	DIR_NONE	    ;; 1100
    db	DIR_E		    ;; 1101
    db	DIR_W		    ;; 1110
    db	DIR_NONE	    ;; 1111

entity_wait_by_key=*
    db	4, 5, 5, 6

entity_dir_to_face=*
    db	ENTITY_FACE_UP		    ;; N
    db	ENTITY_FACE_RIGHT	    ;; NE
    db	ENTITY_FACE_RIGHT	    ;; E
    db	ENTITY_FACE_DOWN	    ;; SE
    db	ENTITY_FACE_DOWN	    ;; S
    db	ENTITY_FACE_DOWN	    ;; SW
    db	ENTITY_FACE_LEFT	    ;; W
    db	ENTITY_FACE_LEFT	    ;; NW

entity_dir_to_dx_by_key=*
    db	0, 0, 0, 0
    db	1, 1, 1, 1
    db	1, 1, 1, 1
    db	1, 1, 1, 1
    db	0, 0, 0, 0
    db	-1, -1, -1, -1
    db	-1, -1, -1, -1
    db	-1, -1, -1, -1

entity_dir_to_dy_by_key=*
    db	-1, -1, -1, -1
    db	-1, -1, -1, -1
    db	0, 0, 0, 0
    db	1, 1, 1, 1
    db	1, 1, 1, 1
    db	1, 1, 1, 1
    db	0, 0, 0, 0
    db	-1, -1, -1, -1
