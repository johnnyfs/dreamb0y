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
emulators possible, as well as the NES itself, via [adapted cartridge
hardware][retro_usb]. As much as possible it incorporates automated testing via
[run6502][lib6502] and forked versions of the targeted emulators (see [targeted
emulators](#targets)).

6502 code is compiled with [crasm][crasm] into motorola SREC files, then
structured into [INES][ines] format with linux's [objcopy][objcopy]. Images and
other assets are assembled with custom tools into formats compatible with crasm.
Custom tools are incorporated into the make chain, written in clang-compatible C
and are re-run automatically whenever an asset is edited.

The project is assembled with [tup][tup], because it is fast and easy, and because it
is the best system for extremely generic and frankensteined multi-language build
paths.

  [retro_usb]: http://www.retrousb.com/product_info.php?products_id=34
  [lib6502]: http://piumarta.com/software/lib6502/
  [crasm]: http://crasm.sourceforge.net/crasm.html 
  [ines]: http://wiki.nesdev.com/w/index.php/INES
  [objcopy]: http://linux.die.net/man/1/objcopy
  [tup]: http://gittup.org/tup/ 

## <a name="targets">Targeted Emulators</a>

Due to the lack of available runtime debugging tools (with the notable exception
of fceux on windows), the best strategy for maintaining compatibility is
continuous testing on each platform. Where possible, this testing is automated
through forked versions of the relevant source.

*Note: most of this table is empty pending investigation of feasibility for each
platform.*

```
|Emulator|Platform|Supported|Automatically tested|  
|--------|--------|---------|--------------------|  
|fceux   |linux   |yes      |no                  |  
|fceux   |windows |yes      |maybe               |  
|nestopia|linux   |yes      |no                  |  
|fakenes |        |         |                    |  
|ines    |        |         |                    |  
|rocknes |        |         |                    |  
|--------|--------|---------|--------------------|  
```

## Prerequisites for building

* tup - build system
* crasm - 6502 assembler
* objcopy - for srec conversion/file padding

## Current goals

Versions of the initial steps of this project exist in multiple locations, the initial goal is to
port them into a coherently organized project. This will be done in stages.

1. Blank rom - Done!

    * basic framework of cmake toolchain in place
    * empty rom compiled into a form that loads on all target emulators

2. Test rom - Done!

    * load a test tile & palette
    * confirm screen displays correctly on all target emulators
