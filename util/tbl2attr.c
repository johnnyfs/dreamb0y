#include <argp.h>
#include <stdint.h>
#include <stdlib.h>

#include "files.h"
#include "info.h"

const char *source_fn = NULL;
const char *out_fn = NULL;

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
        case 'V':
            verbose = true;
            break;
        case ARGP_KEY_FINI:
            if (source_fn == NULL) {
                fprintf(stderr, "you must specify an input file\n");
                argp_usage(state);
            }
            if (out_fn == NULL) {
                fprintf(stderr, "missing required argument \"output\"\n");
                argp_usage(state);
            }
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
            .name = "output",
            .key = 'o',
            .arg = "OUTFILE",
            .flags = 0,
            .doc = "path where the attributes will be written",
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
        .doc = "reads an input file containing a table of 16x12 palette indeces in the range 0-3 (describing the palettes meant to be applied to 16x16 pixel areas, arranged in row major order) and emits them in the attribute format used by the NES"
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
    }

    info("opening the file at %s\n", source_fn);
    FILE *in = xfopen(source_fn, "rb");
    const size_t size = 16 * 12;
    uint8_t *table = calloc(size, sizeof (uint8_t));
    if (table == NULL) {
        fail("could not allocate a table of %lu bytes: %s\n", size, strerror(errno));
    }
    info("reading %lu bytes\n", size);
    int n = fread(table, sizeof (uint8_t), size, in);
    if (n != size) {
        fail("file at path %s did not contain enough data to fill a table of %lu bytes\n", source_fn, size);
    }
    fclose(in);
    info("validating that all entries in the table are >= 0 && < 4\n");
    for (int i = 0; i < size; i ++) {
        if (table[i] < 0 || table[i] >= 4) {
            fail("entry at index %d is out of range; expected >= 0 && < 4, got %d\n", i, table[i]);
        }
    }

    info("writing the table to %s\n", out_fn);
    FILE *out = xfopen(out_fn, "wb");

    // Compress each 2x2 square of the table into a single byte as follows:
    // +--+--+
    // |AA|BB|
    // +--+--+ => DDCCBBAA
    // |CC|DD|
    // +--+--+
    for (int y = 0; y < 12; y += 2) {
        for (int x = 0; x < 16; x += 2) {
            const int i = (y * 16) + x;                
            int b = table[i] | (table[i + 1] << 2) | (table[i + 16] << 4) | (table[i + 16 + 1] << 6);
            fputc(b, out);
        }
    }

    fclose(out);

    exit(EXIT_SUCCESS);
}
