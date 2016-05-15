    cpu    6502
    output scode

STDIO=$4016
EXIT=$0000

	code
*=$8000
reset   lda	#write_left
	sta	joypad_left
	lda	#write_left >> 8
	sta	joypad_left + 1

        lda	#write_right
	sta	joypad_right
	lda	#write_right >> 8
	sta	joypad_right + 1

        lda	#write_down
	sta	joypad_down
	lda	#write_down >> 8
	sta	joypad_down + 1

        lda	#write_up
	sta	joypad_up
	lda	#write_up >> 8
	sta	joypad_up + 1

        lda	#write_start
	sta	joypad_start
	lda	#write_start >> 8
	sta	joypad_start + 1
	
        lda	#write_select
	sta	joypad_select
	lda	#write_select >> 8
	sta	joypad_select + 1

        lda	#write_b
	sta	joypad_b
	lda	#write_b >> 8
	sta	joypad_b + 1

        lda	#write_a
	sta	joypad_a
	lda	#write_a >> 8
	sta	joypad_a + 1
	
	ldx	#15
.read	jsr	write_read
	jsr	joypad_strobe
	lda	#'\n'
	sta	STDIO
	dex
	bne	.read
	jmp	EXIT

	code
write_read  ldy	#0
.loop	    lda	read, y
	    beq	.done
	    sta	STDIO
	    iny
	    bne	.loop
.done	    rts

	code
write_left  ldy	#0
.loop	    lda	left, y
	    beq	.done
	    sta	STDIO
	    iny
	    bne	.loop
.done	    rts

	code
write_right  ldy	#0
.loop	    lda	right, y
	    beq	.done
	    sta	STDIO
	    iny
	    bne	.loop
.done	    rts

	code
write_down  ldy	#0
.loop	    lda	down, y
	    beq	.done
	    sta	STDIO
	    iny
	    bne	.loop
.done	    rts

	code
write_up    ldy	#0
.loop	    lda	up, y
	    beq	.done
	    sta	STDIO
	    iny
	    bne	.loop
.done	    rts

	code
write_start ldy	#0
.loop	    lda	start, y
	    beq	.done
	    sta	STDIO
	    iny
	    bne	.loop
.done	    rts

	code
write_select ldy	#0
.loop	    lda	select, y
	    beq	.done
	    sta	STDIO
	    iny
	    bne	.loop
.done	    rts

	code
write_a	    ldy	#0
.loop	    lda	a_, y
	    beq	.done
	    sta	STDIO
	    iny
	    bne	.loop
.done	    rts

	code
write_b	    ldy	#0
.loop	    lda	b_, y
	    beq	.done
	    sta	STDIO
	    iny
	    bne	.loop
.done	    rts

read	    asc	    "READ: \0"
b_	    asc	    "B \0"
a_	    asc	    "A \0"
select	    asc	    "SELECT \0"
start	    asc	    "START \0"
down	    asc	    "DOWN \0"
up	    asc	    "UP \0"
right	    asc	    "RIGHT \0"
left	    asc	    "LEFT \0"

include	lib/joypad.s

*=$fffa
    dw  $0000
    dw	reset
    dw	$0000
