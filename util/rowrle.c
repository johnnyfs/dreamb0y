#include <argp.h>
#include <math.h>
#include <stdlib.h>

#include "files.h"
#include "info.h"
#include "to_int.h"

const char *source_fn = NULL;
const char *out_fn = NULL;
int chunk_size = 16;
int max_run_length = 4;
int max_index = 63;
int index_shift;

static error_t
config_parse_opt(int key, char *arg, struct argp_state *state) 
{
    switch (key) {
        case ARGP_KEY_ARG:
            source_fn = arg;
            break;
        case 'o':
            out_fn = arg;
            break;
        case 's':
            chunk_size = to_int(arg);
            break;
        case 'I':
            max_index = to_int(arg);
            break;
        case 'L':
            max_run_length = to_int(arg);
            break;
        case 'V':
            verbose = true;
            break;
        case ARGP_KEY_FINI:
            if (source_fn == NULL) {
                fprintf(stderr, "you must specify an output pattern\n");
                argp_usage(state);
            }
            if (out_fn == NULL) {
                fprintf(stderr, "missing required argument \"output\"\n");
                argp_usage(state);
            }
            if (chunk_size < 0) {
                fprintf(stderr, "chunk-size must be positive (got %d)\n", chunk_size);
                argp_usage(state);
            }
            if (max_index <= 0 || max_run_length <= 0) {
                fprintf(stderr, "both max-index and max-run-length must be greater than 0 (got %d, %d)\n", max_index, max_run_length);
                argp_usage(state);
            }
            int ibits = (int) ceil(log2((double) max_index + 1));
            int lbits = (int) ceil(log2((double) max_run_length));
            if (ibits + lbits > 8) {
                fprintf(stderr, "the sum of the bits required for a max-run-length of %d (%d) and a max-index of %d (%d) are > 8\n", max_run_length, lbits, max_index, ibits);
                argp_usage(state);
            }
            index_shift = lbits;
            break;
        default:
            break;
    }

    return EXIT_SUCCESS;
}

void
config_parse(int argc, char *argv[])
{
    const struct argp_option options[] = {
        {
            .name = "chunk-size",
            .key = 's',
            .arg = "bytes (16)",
            .flags = 0,
            .doc = "the size of the \"rows\" of the input; if specified, only that many bytes at a time will be compressed (ie, runs that continue across chunks will be broken up at the chunk boundaries)",
            .group = 0
        },
        {
            .name = "max-index",
            .key = 'I',
            .arg = "byte (63)",
            .flags = 0,
            .doc = "the largest index acceptable for compression; the run length (-1, since 0 is meaningless) will be packed into the first ceil(log2(<max-run-length>)) bits, the index into the last ceil(log2(<max-index> + 1)) bits; if an index is encountered larger than the max index, the application will fail",
            .group = 0
        },
        {
            .name = "max-run-length",
            .key = 'L',
            .arg = "byte (4)",
            .flags = 0,
            .doc = "the largest run length that will be compressed; the run length (-1, since 0 is meaningless) will be packed into the first log2(<max-run-length>) bits, the index into the last log2(<max-index> + 1) bits; if a run larger than this is encountered, a new run will be started",
            .group = 0
        },
        {
            .name = "output",
            .key = 'o',
            .arg = "OUTFILE",
            .flags = 0,
            .doc = "path where the compressed output will be written",
            .group = 0
        },
        {
            .name = "verbose",
            .key = 'V',
            .arg = 0,
            .flags = 0,
            .doc = "show your work",
            .group = 0
        },
        {
            0
        }
    };
    struct argp argp = {
        .argp_domain = 0,
        .help_filter = 0,
        .children = 0,
        .parser = config_parse_opt,
        .options = options,
        .args_doc = "INFILE",
        .doc = "reads an input file w/ \"rows\" or chunks of <chunk-size> bytes each and run-length encodes each chunk independently (this is to simplify the process of retrieval during vertical scrolling, where rows have to be blitted one at a time); the encoding must fit in a single byte, where each byte is formed by (<index> << <length_bits> | length)"
    };

    argp_parse(&argp, argc, argv, 0, NULL, NULL);
}

int
main(int argc, char *argv[])
{
    config_parse(argc, argv); 
    if (verbose) {
        printf("const char *source_fn = %s\n", source_fn);
        printf("const char *out_fn = %s\n", out_fn);
        printf("int chunk_size = %d\n", chunk_size);
        printf("int max_index = %d\n", max_index);
        printf("int max_run_length = %d\n", max_run_length);
        printf("int index_shift (inferred) = %d\n", index_shift);
    }
    info("opening source file %s\n", source_fn);
    FILE *in = xfopen(source_fn, "rb");

    info("creating output file %s\n", out_fn);
    FILE *out = xfopen(out_fn, "wb");

    int last_b = EOF;
    int index = 0;
    int row = 0;
    int column = 0;
    int run_length = 0;
    for (;;) {
        int b = fgetc(in);
        info("index %d (b=0x%02x): row: %d; column %d/%d; run: %d/%d\n", index, b, row, column, chunk_size, run_length, max_run_length);
        bool end = false;

        // There are multiple reasons we might stop a run. Check them all and echo feedback.
        if (b != last_b) {
            info("stopping run because encountered new value (0x%x)\n", b);
            end = true;
        } else if (run_length == max_run_length) {
            info("stopping run because hit max run length of %d\n", max_run_length);
            end = true;
        } else if (chunk_size != 0 && column == 0) {
            info("stopping run because hit end of row\n");
            end = true;
        }

        if (end) {
            // Handle an end of run.
            if (last_b != EOF) {
                int compressed = (last_b << index_shift) | (run_length - 1);
                info("emitting run of %d 0x%02x's (compressed to 0x%02x)\n", run_length, last_b, compressed);
                fputc(compressed, out);
            }

            // Done at end of file.
            if (b == EOF) {
                if (chunk_size != 0 && column != 0) {
                    fail("hit EOF in the middle of a row (%d/%d)\n", row, chunk_size);
                }
                info("hit EOF, stopping\n");
                break;
            }

            // Otherwise, start a new run.
            info("starting new run on 0x%02x\n", b);
            if (b > max_index) {
                fail("encountered a value greater than the specified max index of %d (%d)\n", max_index, b);
            }
            last_b = b;
            run_length = 1;
        } else {
            // If we're continuing the run, just advance.
            run_length ++;
        }

        // Rotate the row count around the chunk size.
        index ++;
        column ++;
        if (chunk_size != 0 && column == chunk_size) {
            info("looping row\n");
            column = 0;
            row ++;
        }
    }

    fclose(out);
    fclose(in);
    
    exit(EXIT_SUCCESS);
}
