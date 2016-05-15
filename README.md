# DREAMBOY NES

An 8-bit adventure in the classic style, for the NES and its emulators.

## Story

You are Dreamboy! You are a weird kid from a sleepy little village called
Skroetensmitten, where everyone works in the asbestos mines. One day your dad
hides all your toys and won't give them back until you go out and get a damn
job. Fortunately, you suddenly develop the power to enter the dreams of the
townspeople! Even better, they're all interconnected into one big dream world
full of nightmare bosses and magical creatures! Maybe they'll help you get your
toys back, and possibly also avoid work forever!

## Project Overview

The game is written in 6502 assembly targeting the widest variety of popular
emulators possible, as well as the NES itself via [adapted cartridge
hardware][retro_usb]. As much as possible it incorporates automated testing of
the actual catridge source via [run6502][lib6502].

6502 code is compiled with [crasm][crasm] into motorola SREC files, then
structured into [INES][ines] format with linux's [objcopy][objcopy]. Images and
other assets are assembled with custom tools into formats compatible with crasm.
Custom tools are incorporated into the make chain, written in clang-compatible C
and are re-run automatically whenever an asset is edited.

The project is assembled with [tup][tup], because it is fast and easy, and because it
is the best system for extremely generic and frankensteined multi-language build
paths. It uses gnu's [make][make] at the top level to maintain separate targets.

  [retro_usb]: http://www.retrousb.com/product_info.php?products_id=34
  [lib6502]: http://piumarta.com/software/lib6502/
  [crasm]: http://crasm.sourceforge.net/crasm.html 
  [ines]: http://wiki.nesdev.com/w/index.php/INES
  [objcopy]: http://linux.die.net/man/1/objcopy
  [tup]: http://gittup.org/tup/ 
  [make]: https://www.gnu.org/software/make/

## <a name="targets">Targeted Emulators</a>

Due to the lack of available runtime debugging tools (with the notable exception
of fceux on windows), the best strategy for maintaining compatibility is
continuous testing on each platform.

*Note: most of this table is empty pending investigation of feasibility for each
platform.*

```
|Emulator|Platform|Supported|  
|--------|--------|---------|   
|fceux   |linux   |yes      |   
|fceux   |windows |yes      |   
|nestopia|linux   |yes      |   
|fakenes |        |         |   
|ines    |        |         |   
|rocknes |        |         |   
|--------|--------|---------|  
```

## Prerequisites for building

* make - build system
* tup - build system
* crasm - 6502 assembler
* objcopy - for srec conversion/file padding
* gcc - for building the custom utilities
* run6502 - for automated testing of 6502 assembly

## Directory structure

* . - top-level 6502 assembly components (header, cart, tilesets)
* lib - included 6502 assembly modules
* res - assets (currently maps and color palettes)
* util - custom utilities (see [build chain][chain])
* test - automated tests
    * test/lib - test source and output for run6502 tests
    * test/util - test inputs and outputs for custom utilities

## <a name="chain">Build Chain</a>

These are the custom utilties:

* uniques: extracts tilesets from an image using a reference palette
    (*also generates tables of tile and palette indeces!)
* tblcut: cuts big tables into little tables
* rowrle: custom compression for the map tables
* tbl2attr: converts palette tables into NES attribute format
* img2chr: converts 4-color tilesets into NES chr format
* bin2asm: converts binary tables into assembly declarations

Here's how they're used:

big maps + palettes => uniques => tilesets + tile map + palette map

`tilesets => *img2chr* => chr rom binary`
`tile map => *tblcut* => screen-sized tile maps`
`palettes => *tblcut* => screen-size palette maps`

`chr rom binary => *bin2asm* => chr rom assembly declartions`
`tile maps => *bin2asm* => map assembly declarations`
`palette maps => *bin2asm* => attribute assembly declarations`

`prg-rom source includes map and attribute assembly`
`chr-rom source includes chr rom assembly`

`header + prg-rom source + chr-rom source => *crasm* => cart srec`
`cart srec => *objcopy* => cart rom`

`cart rom => *nintendo* => fun`

Later we'll also have tools for sound!

## Checklist for tech demo

```
☑  map loads  
☑  status bar  
☐  screen changes with arrows  
☐  screen scrolls instead of changing  
☐  animated dreamboy walker   
☐  screen scrolls on edges  
☐  obstructions  
☐  music  
☐  other character sprites  
☐  interactions  
☐  doors  
☐  sound effects (door opening)  
☐  room interiors  
☐  music switches for interior  
☐  day/night cycle (pressing A)  
☐  day/night cycle controlled by bed interaction  
☐  animation + tune + music switch for day/night  
☐  dog sprite sleeping with enterable bubble  
☐  bubble triggers dream world transition (A returns)  
☐  return from dream world through portal  
☐  enterable cave in dw screen 1 (dangerous, no one likes you)  
☐  possible to reach treasure chest  
☐  mailbox alive; interaction & it runs away, possible to follow  
☐  mailbox eats rock, burbs, explodes  
☐  can reach chest in day world, get sword (music)  
☐  sword appears in status/ swingable/ sound effect  
☐  trash talk from people you hit with sword  
☐  animals challenge you at opening of squirrel forest in dream world  
☐  possible to enter dream of nut farmer (after you get sword); enter forest  
☐  real sword in dream world, can fight squirrels!  
☐  you can take damage and die  
☐  other creatures, fully fleshed out forest  
☐  forest dungeon  
☐  forest dungeon boss  
☐  destruction of nut farm, possible to get (what?) from treasure chest?  
☐  possible to enter other dreams, but blocked by construction squirrel  
☐  clean up graphics, sound
☐  playable w/o an emulator (either wrapped or in a browser/app?)  
```
