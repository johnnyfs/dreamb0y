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
tmp     ds      1               ; tmp -- testing v scroll

;;
;; Engine interface
;;
;; These values should only be written by top-level code (dreamboy.s).
;; For the library modules, these are read-only/private as noted
;;
dsttbl	ds      1               ; read-only: high byte of target table for loads ($20=left/main; $24=right/alt)
maps	ds	2		; read-only: address of current map table
pos     ds      1               ; read-only: index into current world/level map
status	ds	1		; read-only: current ppu status bits
xscroll	ds	1		; read-only: current x scroll (for maintaining scroll after ppu read/write)
yscroll	ds	1		; read-only: curreny y scroll (same)
state   ds      1               ; private: major engine state
step    ds      1               ; private: counter for state transitions
step2	ds	1		; private: secondary counter (TODO: can opt this into the high bits of step if we run out of zp)

STATE_SEQ	= 0             ; limited user control (esc only), sequence is playing
STATE_FREE     	= 1             ; normal play
STATE_LLOAD     = 2             ; load the staged old map to the swap table (and switch)
STATE_LSTAGE    = 3             ; stage the new map
STATE_LLOAD2    = 4             ; load the new map to the main table
STATE_LSCROLL   = 5             ; scroll left from staged old map to new map
STATE_RSTAGE    = 6             ; stage the new map
STATE_RLOAD     = 7             ; load the staged new map to the swap table
STATE_RSCROLL   = 8             ; scroll right from current old map to new map
STATE_RLOAD2    = 9             ; load the (still staged) new map to the main table (and switch back)
STATE_VLOAD     = 10            ; loading for vertical scroll (first load is current map always, so can be opted out)
STATE_VSTAGE	= 11		; then we stage the alt map
STATE_VLOAD2	= 12		; then we alternate between loading the alt map and scrolling it into view
STATE_VSCROLL   = 13            ; scrolling vertically
STATE_VLOAD3	= 14		; then we load the new map back into the main table

NAMETBL_MAIN    = $20
NAMETBL_SWAP    = $24

SCROLL_STEPS    = 64
SCROLL_DELTA    = 256/SCROLL_STEPS

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
STAGE_STEPS=14

stage_src       ds	2               ; private: pointer to compressed map data to stage
stage_dst       ds	2               ; private: pointer to current position in staging area

;; Map loading module
LOAD_BYTES_PER=64
LOAD_STEPS=18                           ; 12 rows (we don't load the status bar) of 64 chrs each + 6 rows of attr blocks
VLOAD_STEPS=6				; VLOAD/SCROLL alternates in 6 groups of { 3 per load, scroll 10 units of 6 + one 4 at end? }

load_type	ds	1		; public: set before calling load_start

LOAD_TYPE_OVER   = 0			; standard: write over the map in its view position
LOAD_TYPE_AFTER  = 1			; write forward from right after the map, wrapping around (for down scrolling)
LOAD_TYPE_BEFORE = 2			; write backward from one row above the map, wrapping around (for up scrolling)

load_chr_src	ds	2		; private: pointer to row of map to be loaded
load_chr_dst    ds	2		; private: PPU address of current load in progress
load_attr_src	ds	2		; private: pointer to attr to load
load_attr_dst	ds	2		; private: pointer to attr write address in PPU
load_step	ds	1		; private: internal state counter
load_nightmare  ds      1               ; private: attribute off-by one nightmare mode (ugh)

LOAD_NIGHTMARE_UP=-8
LOAD_NIGHTMARE_DOWN=8

;; Map scrolling module
SCROLL_INITY=(248+$28) & $ff
SCROLL_NMIY=248
scroll_speed	ds	1               ; public: read/write to control scroll speed/direction

;; Entity module
ENTITIES=$0600                          ; start of entity page (s)
ENTITY_FACE_DOWN=0
ENTITY_FACE_UP=1
ENTITY_FACE_RIGHT=2
ENTITY_FACE_LEFT=3
ENTITY_FACE_HORIZ=%00000010
ENTITY_FACE_LEFT_IF_HORIZ=%00000001

ENTITY_ATTRS_HFLIP=%01000000		; sprite bit 6 = flip horizontally

;; Prime data (tmp, for testing; will be decomped from ent array to working data later)
entity_face	ds	1               ;; 2 bits (+4 for step counter? +2 for state?)
entity_y	ds	1               ;; byte
entity_x	ds	1	        ;; byte
entity_pal	ds	1               ;; 2 bits
entity_base_chr	ds	1               ;; 256 /2 (for 8x16 mode) /2 (for 16x16 tiles) = 64(6)

;; Working data (while drawing)
entity_spr_y	ds	1 
entity_spr_x	ds	1 
entity_chr_i	ds	1
entity_attrs	ds	1
entity_index	ds	1
entity_hx1	ds	1
entity_hdx	ds	1
entity_nudge	ds	1

;; Sprites module
SPRITES=$0700				; use page 7 for sprite DMA
