;; Zero page
	dummy
*=$0000
src	ds	2		; generic address src pointer
dst	ds	2		; generic address dst pointer
srci	ds	1		; generic src index
dsti	ds	1		; generic dst index 
count	ds	1		; generic counter
column	ds	1		; generic column counter
row	ds	1		; generic row counter
frames  ds      1               ; generic frame counter

;; Joypad interface
joypad_prev ds	1
joypad_next ds	1
