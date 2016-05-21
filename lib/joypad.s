;;
;; Queries the joypad and shifts the results into
;; joypad_next, where each bit corresponds to the
;; state of the buttons according to the masks below.
;;
;; The previous state is copied to joypad_prev. Thus
;; it is possible to query changes in state by:
;;
;; joypad_next & ~joypad_prev = buttons just pressed
;; joypad_prev & ~joypad_next = buttons just released
;;

JOYPAD_A=	%10000000
JOYPAD_B=	%01000000
JOYPAD_START=	%00100000
JOYPAD_SELECT=	%00010000
JOYPAD_UP=	%00001000
JOYPAD_DOWN=	%00000100
JOYPAY_RIGHT=	%00000010
JOYPAY_LEFT=	%00000001

;;
;; query the joypad; clobbers X
;;
		code
joypad_strobe   lda joypad_next
		sta joypad_prev
		ldx #8
		lda #1
		sta $4016
		lda #0
		sta $4016
.next		lda $4016
		ror             ;; shift bit into carry
                rol joypad_next ;; shift carry into buttons
		dex
		bne .next
		rts
