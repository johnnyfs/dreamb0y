;;
;; start a map load from the staging area at $2000 to the
;; ppu at $2[04]C0, depending on how the target in nametbl
;;
	code
load_start	ldx #$02
		stx load_src + 1
		ldx #$00	    ;; start loading (including the status bar)
		stx load_src

		ldx nametbl
		stx load_dst + 1
		ldx #$00	    ;; leave space (including the status bar)
		stx load_dst

		rts

;;
;; Load the next 64 bytes of the map into the target name table. Client
;; should call it 14 times after first calling load_start. Calls after
;; the 14th are undefined.
;;
	code
load_next	lda load_dst + 1	;; point the ppu at our saved place
		sta $2006
		lda load_dst
		sta $2006

		ldy #0
		ldx #LOAD_BYTES_PER
.loop		lda (load_src), y	;; read from current source
		sta $2007		;; write to ppu
		iny
		dex			;; write 64 bytes
		bne .loop

		tya			;; (y == 64 now)
		clc
		adc load_src		;; inc src by 64
                sta load_src
		bne .nv
		inc load_src + 1

.nv		tya
		clc
		adc load_dst		;; inc dst by 64
                sta load_dst
		bne .nv2
		inc load_dst + 1
	
.nv2		rts
