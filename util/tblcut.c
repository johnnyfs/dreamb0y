#include <argp.h>
#include <stdint.h>
#include <stdlib.h>

#include "files.h"
#include "info.h"
#include "to_int.h"

#define MAX_FN_LENGTH 256

const char *table_fn = NULL;
int input_height = 48;
int input_width = 64;
int output_height = 12;
int output_width = 16;
const char *output_pattern = NULL;

static error_t
config_parse_opt(int key, char *arg, struct argp_state *state) 
{
    switch (key) {
        case ARGP_KEY_ARG:
            table_fn = arg;
            break;
        case 'h':
            input_height = to_int(arg);
            break;
        case 'w':
            input_width = to_int(arg);
            break;
        case 'H':
            output_height = to_int(arg);
            break;
        case 'o':
            output_pattern = arg;
            break;
        case 'W':
            output_width = to_int(arg);
            break;
        case 'V':
            verbose = true;
            break;
        case ARGP_KEY_FINI:
            if (output_pattern == NULL) {
                fprintf(stderr, "you must specify an output pattern\n");
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
            .name = "input-height",
            .key = 'h',
            .arg = "ROWS (48)",
            .flags = 0,
            .doc = "the height of the input table in rows",
            .group = 0
        },
        {
            .name = "input-width",
            .key = 'w',
            .arg = "COLUMNS (64)",
            .flags = 0,
            .doc = "the width of the input table in columns",
            .group = 0
        },
        {
            .name = "output-height",
            .key = 'H',
            .arg = "ROWS (12)",
            .flags = 0,
            .doc = "the height of the output table(s) in rows",
            .group = 0
        },
        {
            .name = "output-pattern",
            .key = 'o',
            .arg = "PATH-PATTERN",
            .flags = 0,
            .doc = "output for each cut table will be written to a path defined by this pattern, where %x will be replaced with the x coordinate and %y with the y coordinate",
            .group = 0
        },
        {
            .name = "output-width",
            .key = 'W',
            .arg = "COLUMNS (16)",
            .flags = 0,
            .doc = "the width of the output table(s) in columns",
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
        .args_doc = "TABLE_IN",
        .doc = "reads a file containing a table of <input-width>x<input-height> bytes and cuts that table into some smaller number of subtables of <output-width>x<output-height> in size, writing the results to some number of file(s) in the pattern <output-pattern>, one file per subtable, with the relative x and y coordinate of the subtable subtituted into the %x and %y elements of the pattern."
    };

    argp_parse(&argp, argc, argv, 0, NULL, NULL);
}

char *
make_fn(int x, int y)
{
    char *fn = calloc(1, MAX_FN_LENGTH);    
    for (int i = 0, j = 0; output_pattern[i] != '\0'; i ++) {
        if (output_pattern[i] == '%') {
            int n;
            switch (output_pattern[++ i]) {
                case 'x':
                    n = snprintf(&fn[j], MAX_FN_LENGTH, "%d", x);
                    j += n;
                    break;
                case 'y':
                    n = snprintf(&fn[j], MAX_FN_LENGTH, "%d", y);
                    j += n;
                    break;
                default:
                    fn[j ++] = '%';
                    fn[j ++] = output_pattern[i + 1];
                   break;
            }
        } else {
            fn[j ++] = output_pattern[i];
        }
        if (j >= MAX_FN_LENGTH - 1) {
            fail("length of interpreted output file pattern (%s: %d) greater than the maximum allowed length: %d\n", fn, j, MAX_FN_LENGTH);
        }
    }

    return fn;
}

int
main(int argc, char *argv[])
{
    config_parse(argc, argv);
    if (verbose) {
        printf("const char *table_fn = %s\n", table_fn);
        printf("int input_height = %d\n", input_height);
        printf("int input_width = %d\n", input_width);
        printf("int output_height = %d\n", output_height);
        printf("int output_width = %d\n", output_width);
        printf("const char *output_pattern = %s\n", output_pattern);
    }

    FILE *in = xfopen(table_fn, "rb");
    if (input_width < output_width ||
            output_width <= 0 ||
            input_width % output_width != 0 ||
            input_height < output_height ||
            output_height <= 0 ||
            input_height % output_height != 0) {
        fail("ouput size (got %dx%d) must be <= and a multiple of the input size (got %dx%d)\n", input_width, input_height, output_width, output_height);
    }

    size_t size = input_width * input_height;
    uint8_t *table = calloc(1, size);
    if (table == NULL) {
        fail("could not allocate %lu bytes to hold the input table\n", size);
    }
    info("reading %lu bytes from the input table %s\n", size, table_fn);
    size_t n = fread(table, 1, size, in);
    info("read %lu bytes\n", n);
    if (n != size) {
        fail("input file %s was not large enough (%lu) to populate a table of %dx%d (%lu) bytes\n", table_fn, n, input_width, input_height, size);
    }

    info("copying table to requested subtables\n");
    for (int sy = 0; sy < input_height; sy += output_height) {
        for (int sx = 0; sx < input_width; sx += output_width) {
            const int tx = sx / output_width;
            const int ty = sy / output_height;
            char *out_fn = make_fn(tx, ty);
            info("beginning output file %s\n", out_fn);
            FILE *out = xfopen(out_fn, "wb");
            for (int dy = 0; dy < output_height; dy ++) {
                for (int dx = 0; dx < output_width; dx ++) {
                    const int y = sy + dy;
                    const int x = sx + dx;
                    const int i = y * input_width + x; 
                    const int b = table[i];
                    info("writing byte 0x%x from (%d, %d) in the source table to (%d, %d) in output table (%d, %d)\n", b, x, y, dx, dy, tx, ty);
                    fputc(b, out);
                }
            }
            info("finished output file %s\n", out_fn);
            fclose(out);
            free(out_fn);
        }
    }

    fclose(in);
    free(table);

    exit(EXIT_SUCCESS);
}
