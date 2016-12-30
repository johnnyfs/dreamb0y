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
frames  ds      2               ; 16-bit frame counter

;;
;; Engine interface
;;
;; These values should only be written by top-level code (dreamboy.s).
;; For the library modules, these are read-only/private as noted
;;
nametbl ds      1               ; read-only: high byte of dst table for loads ($20=left/main; $24=right/alt)
maps	ds	2		; read-only: address of current map table
pos     ds      1               ; read-only: index into current world/level map
xscroll	ds	1		; read-only: current x scroll (for maintaining scroll after ppu read/write)
yscroll	ds	1		; read-only: curreny y scroll (same)
state   ds      1               ; private: major engine state
step    ds      1               ; private: counter for state transitions

STATE_SEQ	= 0             ; limited user control (esc only), sequence is playing
STATE_FREE     	= 1             ; normal play
STATE_HSTAGE    = 2             ; staging for horizontal scroll
STATE_HLOAD     = 3             ; loading for horizontal scroll
STATE_HSCROLL   = 4             ; scrolling horizontally
STATE_VSTAGE    = 5             ; staging for vertical scroll
STATE_VLOAD     = 6             ; loading for vertical scroll
STATE_VSCROLL   = 7             ; scrolling vertically

NAMETBL_MAIN    = $20
NAMETBL_SWAP    = $24

SCROLL_DELTA    = 4             ; default abs scroll speed

;;
;; Library interfaces.
;;
;; Unless otherwise noted, the values listed here are private
;; to the modules and should not be read/written to/from by 
;; top-level code and/or other modules.
;;

;;
;; Joypad module
;;
;; Button/bit order 0-7: A B SELECT START UP DOWN LEFT RIGHT
;;
joypad_prev	ds	1               ; public: read-only to acquire state before last call to joypad_strobe
joypad_next	ds	1               ; public: read-only to acquire current state after joypad_strobe

;; Map staging module
stage_src       ds	2               ; private: pointer to compressed map data to stage
stage_dst       ds	2               ; private: pointer to current position in staging area

;; Map loading module
load_src	ds	2		; private: pointer to row of map to be loaded
load_dst        ds	2		; private: PPU address of current load in progress

;; Map scrolling module
scroll_speed	ds	1               ; public: read/write to control scroll speed/direction

