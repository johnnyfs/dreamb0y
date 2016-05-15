.PHONY: all
all: 
	tup upd

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
	crasm test/lib/test_ldmap.s -o test/lib/test_ldmap.srec > test_ldmap.lst && objcopy -I srec -O binary test/lib/test_ldmap.srec test/lib/test_ldmap.bin && run6502 -l 8000 test/lib/test_ldmap.bin -M fff9 -X 0 > test/lib/actual_ldmap.bin && diff test/lib/expected_ldmap.bin test/lib/actual_ldmap.bin