.PHONY: all
all: 
	tup upd

.PHONY: clean
clean:
	-rm -f dreamboy.nes
	-rm -f *.bin
	-rm -f *.lst
	-rm -f *.srec
	-rm -f res/*.attr
	-rm -f res/*.attr.s
	-rm -f res/*.bmp
	-rm -f res/*.chr
	-rm -f res/*.chr.s
	-rm -f res/*.rle
	-rm -f res/*.rle.s
	-rm -f res/*.tbl
	-rm -f res/*.tbl.s
	-rm -f test/util/actual_*
	-rm -f test/lib/actual_*
	-rm -f test/lib/expected_joypad_out.bin # special case: generated expected output for joypad test

.PHONY: test
test: test_utils test_lib

UTIL_TEST_DATA = $(wildcard test/util/test*) $(wildcard test/util/expected*)
.PHONY: test_utils
test_utils: all $(UTIL_TEST_DATA)
	util/uniques test/util/test_map.png -p test/util/test_palettes.png -P test/util/test_grayscale.png -o test/util/actual_uniques.bmp -t test/util/actual_indeces.tbl -a test/util/actual_palettes.tbl && diff test/util/expected_uniques.bmp test/util/actual_uniques.bmp && diff test/util/expected_indeces.tbl test/util/actual_indeces.tbl && diff test/util/expected_palettes.tbl test/util/actual_palettes.tbl
	util/tblcut test/util/test_indeces.tbl -w 16 -h 12 -W 8 -H 6 -o test/util/actual_indeces_%x_%y.tbl && diff test/util/expected_indeces_0_0.tbl test/util/actual_indeces_0_0.tbl && diff test/util/expected_indeces_0_1.tbl test/util/actual_indeces_0_1.tbl && diff test/util/expected_indeces_1_0.tbl test/util/actual_indeces_1_0.tbl && diff test/util/expected_indeces_1_1.tbl test/util/actual_indeces_1_1.tbl
	util/rowrle test/util/test_indeces.tbl -o test/util/actual_indeces.tbl.rle && diff test/util/expected_indeces.tbl.rle test/util/actual_indeces.tbl.rle
	util/img2chr test/util/test_uniques.bmp -p test/util/test_grayscale.png -o test/util/actual_uniques.chr && diff test/util/expected_uniques.chr test/util/actual_uniques.chr
	util/tbl2attr test/util/test_palettes.tbl -o test/util/actual_palettes.attr && diff test/util/expected_palettes.attr test/util/actual_palettes.attr
	util/bin2asm test/util/test_raw.bin -w 8 -o test/util/actual_raw.bin.s && diff test/util/expected_raw.bin.s test/util/actual_raw.bin.s

LIB_TEST_DATA = $(wildcard test/lib/test*) $(wildcard test/util/expected*)
.PHONY: test_lib
test_lib: all $(LIB_TEST_DATA)
	#crasm test/lib/test_ldmap.s -o test/lib/test_ldmap.srec > test/lib/test_ldmap.lst && objcopy -I srec -O binary test/lib/test_ldmap.srec test/lib/test_ldmap.bin && run6502 -l 8000 test/lib/test_ldmap.bin -M fff9 -X 0 > test/lib/actual_ldmap.bin && diff test/lib/expected_ldmap.bin test/lib/actual_ldmap.bin
	#crasm test/lib/test_status.s -o test/lib/test_status.srec > test/lib/test_status.lst && objcopy -I srec -O binary test/lib/test_status.srec test/lib/test_status.bin && run6502 -l 8000 test/lib/test_status.bin -M fff9 -X 0 > test/lib/actual_status.bin && diff test/lib/expected_status.bin test/lib/actual_status.bin
	crasm test/lib/test_joypad.s -o test/lib/test_joypad.srec > test/lib/test_joypad.lst && objcopy -I srec -O binary test/lib/test_joypad.srec test/lib/test_joypad.bin && xxd -r -p test/lib/expected_joypad_out.hex > test/lib/expected_joypad_out.bin && xxd -r -p test/lib/test_joypad_in.hex | run6502 -l 8000 test/lib/test_joypad.bin -M 4016 -X 0 > test/lib/actual_joypad_out.bin && diff test/lib/expected_joypad_out.bin test/lib/actual_joypad_out.bin
	crasm test/lib/test_stage.s -o test/lib/test_stage.srec > test/lib/test_stage.lst && objcopy -I srec -O binary test/lib/test_stage.srec test/lib/test_stage.bin && run6502 -l 8000 test/lib/test_stage.bin -M fff9 -X 0 > test/lib/actual_stage_out.bin && diff test/lib/expected_stage_out.bin test/lib/actual_stage_out.bin 
