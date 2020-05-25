.PHONY: all
all: dreamboy.nes

dreamboy.nes: header.bin dreamboy.bin realworld_day_tileset_padded.bin
	cat header.bin dreamboy.bin realworld_day_tileset_padded.bin > dreamboy.nes

%_tileset_padded.bin: %_tileset.bin
	objcopy -F binary --pad-to 8192 $< $@

%.bin: %.srec
	objcopy -I srec -O binary $< $@

%.srec: %.s resources
	crasm $< -o $@ > $*.lst

#############
# RESOURCES #
#############

.PHONY: resources
resources: utils
	PATH=$$PATH:../util $(MAKE) -C res

#############
# UTILITIES #
#############

.PHONY: utils
utils: 
	$(MAKE) -C util	

#####################
# RECURSIVELY CLEAN #
#####################

.PHONY: clean
clean:
	-rm -f dreamboy.nes
	-rm -f *.bin
	-rm -f *.lst
	-rm -f *.srec
	$(MAKE) -C util clean
	$(MAKE) -C res clean
	-rm -f test/util/actual_*
	-rm -f test/lib/actual_*
	-rm -f test/lib/expected_joypad_out.bin # special case: generated expected output for joypad test

##############################################
# TODO: Move test makefile(s) to test dir(s) #
##############################################

.PHONY: test
test: test_utils test_lib

.PHONY: test_utils
test_utils: utils
	# Test that util/uniques correctly extracts the unique tiles from a test map
	util/uniques test/util/test_map.png -p test/util/test_palettes.png -P test/util/test_grayscale.png -o test/util/actual_uniques.bmp -t test/util/actual_indeces.tbl -a test/util/actual_palettes.tbl && diff test/util/expected_uniques.bmp test/util/actual_uniques.bmp && diff test/util/expected_indeces.tbl test/util/actual_indeces.tbl && diff test/util/expected_palettes.tbl test/util/actual_palettes.tbl
	# Test that util/tblcut correctly cuts a large test map into screen-sized pieces
	util/tblcut test/util/test_indeces.tbl -w 16 -h 12 -W 8 -H 6 -o test/util/actual_indeces_%x_%y.tbl && diff test/util/expected_indeces_0_0.tbl test/util/actual_indeces_0_0.tbl && diff test/util/expected_indeces_0_1.tbl test/util/actual_indeces_0_1.tbl && diff test/util/expected_indeces_1_0.tbl test/util/actual_indeces_1_0.tbl && diff test/util/expected_indeces_1_1.tbl test/util/actual_indeces_1_1.tbl
	# Test that util/rowrle correctly rle-compresses a test tbl
	util/rowrle test/util/test_indeces.tbl -o test/util/actual_indeces.tbl.rle && diff test/util/expected_indeces.tbl.rle test/util/actual_indeces.tbl.rle
	# Test that img2chr correctly turns a test bitmap of uniques into NES-compatible CHRs
	util/img2chr test/util/test_uniques.bmp -p test/util/test_grayscale.png -o test/util/actual_uniques.chr && diff test/util/expected_uniques.chr test/util/actual_uniques.chr
	# Test that tbl2attr correctly turns a test tbl of attributes into NES-compatible ATTRs
	util/tbl2attr test/util/test_palettes.tbl -o test/util/actual_palettes.attr && diff test/util/expected_palettes.attr test/util/actual_palettes.attr
	# Test that bin2asm correctly turns raw test bytes into 6502 asm static data declarations
	util/bin2asm test/util/test_raw.bin -w 8 -o test/util/actual_raw.bin.s && diff test/util/expected_raw.bin.s test/util/actual_raw.bin.s

.PHONY: test_lib
test_lib:
	#crasm test/lib/test_ldmap.s -o test/lib/test_ldmap.srec > test/lib/test_ldmap.lst && objcopy -I srec -O binary test/lib/test_ldmap.srec test/lib/test_ldmap.bin && run6502 -l 8000 test/lib/test_ldmap.bin -M fff9 -X 0 > test/lib/actual_ldmap.bin && diff test/lib/expected_ldmap.bin test/lib/actual_ldmap.bin
	#crasm test/lib/test_status.s -o test/lib/test_status.srec > test/lib/test_status.lst && objcopy -I srec -O binary test/lib/test_status.srec test/lib/test_status.bin && run6502 -l 8000 test/lib/test_status.bin -M fff9 -X 0 > test/lib/actual_status.bin && diff test/lib/expected_status.bin test/lib/actual_status.bin
	crasm test/lib/test_joypad.s -o test/lib/test_joypad.srec > test/lib/test_joypad.lst && objcopy -I srec -O binary test/lib/test_joypad.srec test/lib/test_joypad.bin && xxd -r -p test/lib/expected_joypad_out.hex > test/lib/expected_joypad_out.bin && xxd -r -p test/lib/test_joypad_in.hex | run6502 -l 8000 test/lib/test_joypad.bin -M 4016 -X 0 > test/lib/actual_joypad_out.bin && diff test/lib/expected_joypad_out.bin test/lib/actual_joypad_out.bin
	crasm test/lib/test_stage.s -o test/lib/test_stage.srec > test/lib/test_stage.lst && objcopy -I srec -O binary test/lib/test_stage.srec test/lib/test_stage.bin && run6502 -l 8000 test/lib/test_stage.bin -M fff9 -X 0 > test/lib/actual_stage_out.bin && diff test/lib/expected_stage_out.bin test/lib/actual_stage_out.bin 
	crasm test/lib/test_sound.s -o test/lib/test_sound.srec > test/lib/test_sound.lst && objcopy -I srec -O binary test/lib/test_sound.srec test/lib/test_sound.bin && run6502 -l 8000 test/lib/test_sound.bin -M fff9 -X 0 > test/lib/actual_sound_out.bin && diff test/lib/expected_sound_out.bin test/lib/actual_sound_out.bin
