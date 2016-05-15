;;
;; queries the joystick and calls one of the
;; specified callbacks if the button is in
;; the down state; the default value of each
;; callback is joypad_nothing, which does
;; what is says
;; 
;;  joypad_a
;;  joypad_b
;;  joypad_select
;;  joypad_start
;;  joypad_up
;;  joypad_down
;;  joypad_left
;;  joypad_right
;;

joypad_strobe	lda #1
		sta $4016
		lda #0
		sta $4016
		lda $4016
		ror A
		bcc .not_a
		jsr joypad_call_a
.not_a		lda $4016
		ror A
		bcc .not_b
		jsr joypad_call_b
.not_b		lda $4016
		ror A
		bcc .not_select
		jsr joypad_call_select
.not_select	lda $4016
		ror A
		bcc .not_start
		jsr joypad_call_start
.not_start	lda $4016
		ror A
		bcc .not_up
		jsr joypad_call_up
.not_up		lda $4016
		ror A
		bcc .not_down
		jsr joypad_call_down
.not_down	lda $4016
		ror A
		bcc .not_left
		jsr joypad_call_left
.not_left	lda $4016
		ror A
		bcc .not_right
		jsr joypad_call_right
.not_right	rts

joypad_call_a	    jmp (joypad_a)
joypad_call_b	    jmp (joypad_b)
joypad_call_select  jmp (joypad_select)
joypad_call_start   jmp (joypad_start)
joypad_call_up	    jmp (joypad_up)
joypad_call_down    jmp (joypad_down)
joypad_call_left    jmp (joypad_left)
joypad_call_right   jmp (joypad_right)

joypad_a	dw  joypad_nothing
joypad_b	dw  joypad_nothing
joypad_select	dw  joypad_nothing
joypad_start	dw  joypad_nothing
joypad_up	dw  joypad_nothing
joypad_down	dw  joypad_nothing
joypad_left	dw  joypad_nothing
joypad_right	dw  joypad_nothing

joypad_nothing	rts
