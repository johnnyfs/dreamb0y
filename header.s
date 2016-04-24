;; INES header
	code
*=$0000
	asc	"NES"
	db	$1a 
	db	1	; number of 16kb prg-rom banks
	db	1	; number of 8kb prg-rom banks
	db	1	; MMMM4tsm: mapper# (lower four bits), 4-screen VRAM,
			; 512kb trainer present, SRAM enabled, vertical mirror
	db	0	; MMMM000V: upper 4 bits of mapper #; is VS-system
	db	0	; number of 8kb RAM banks
	db	0	; 0: NTSC, 1: PAL, 4: extra ram at $6000-$7fff
	ds	6,0	; unused 5 bytes
HEADEND=*
