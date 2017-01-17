#include <argp.h>
#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include <SDL/SDL.h>
#include <SDL/SDL_image.h>

#include "fail.h"
#include "files.h"
#include "info.h"
#include "to_int.h"

const char *obs_in_fn = NULL;
const char *obs_out_fn = NULL;
const char *obs_chrs = "#";
const char *clear_chrs = " ";
const char *ignore_chrs = "|-+";
int expected_width = 0;
int expected_height = 0;

/**
 * Parser called by argp while parsing command line arguments. Sets the globals based on the key
 * and enforces the presence of the image file.
 */
static error_t
config_parse_opt(int key, char *arg, struct argp_state *state) {

    switch (key) {
        case ARGP_KEY_ARG:
            obs_in_fn = arg;
            break;
        case 'C':
            clear_chrs = arg;
            break;
        case 'h':
            expected_height = to_int(arg);
            break;
        case 'I':
            ignore_chrs = arg;
            break;
        case 'o':
            obs_out_fn = arg;
            break;
        case 'O':
            obs_chrs = arg;
            break;
        case 'w':
            expected_width = to_int(arg);
            break;
        case 'V':
            verbose = true;
            break;
        default:
            break;
    }

    return EXIT_SUCCESS;
}

/**
 * Parse the command line arguments.
 */
void
config_parse(int argc, char *argv[])
{
    const struct argp_option options[] = {
        {
            .name = "clear-chrs",
            .key = 'C',
            .arg = "STRING (\" \")",
            .flags = 0,
            .doc = "string of chrs which will be read as unobstructed in the input file",
            .group = 0
        },
        {
            .name = "expected-height",
            .key = 'h',
            .arg = "ROWS (none)",
            .flags = 0,
            .doc = "the expected total number of rows in the file",
            .group = 0
        },
        {
            .name = "ignore-chrs",
            .key = 'I',
            .arg = "STRING (\"|-+\")",
            .flags = 0,
            .doc = "string of chrs which will ignored in the input file, read as neither obstructed nor clear, and not counting toward the total row or column count (this is mainly to allow for convenience framing)",
            .group = 0
        },
        {
            .name = "obstructions-out",
            .key = 'o',
            .arg = "FILEPATH",
            .flags = 0,
            .doc = "path to which an obstruction map of 1 byte per eight tiles will be written (arranged horizontally, 0 meaning clear and 1 obstructed, with the earlier tiles positioned in the higher bits)",
            .group = 0
        },
        {
            .name = "obstruction-chrs",
            .key = 'O',
            .arg = "STRING (\"#\")",
            .flags = 0,
            .doc = "string of chrs which will be read as obstructed in the input file",
            .group = 0
        },
        {
            .name = "expected-width",
            .key = 'w',
            .arg = "COLUMNS (none)",
            .flags = 0,
            .doc = "",
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
        .args_doc = "TXT_FILE_IN",
        .doc = "reads a text file representing the obstructed cells in a grid; cells may either be obstructed or unobstructed; inputs chrs must be specified to represent one or the other, or else specifically to be ignored; the output is written such that one byte represents a horizontal run of 8 cells, one bit per cell, where 1 signifies obstructed and 0 unobstructed, and the higher bits represent the leftmost or earlier cells"
    };

    argp_parse(&argp, argc, argv, 0, NULL, NULL);
}

bool
contains(const char *s, char c)
{

    for (int i = 0; s[i] != '\0'; i ++) {
        if (s[i] == c) {
            return true;
        }
    }

    return false;
}

int
main(int argc, char *argv[])
{
    FILE *obs_in = stdin;
    FILE *obs_out = stdout;
    int c;
    char c1;
    int run = 0;
    int run_length = 0;
    int cols = 0;
    int rows = 0;

    config_parse(argc, argv);

    if (verbose) {
        fprintf(stdout, "obs_in_fn = %s\n", obs_in_fn);
        fprintf(stdout, "obs_out_fn = %s\n", obs_out_fn);
        fprintf(stdout, "obs_chrs = %s\n", obs_chrs);
        fprintf(stdout, "clear_chrs = %s\n", clear_chrs);
        fprintf(stdout, "ignore_chrs = %s\n", ignore_chrs);
        fprintf(stdout, "expected_width = %d\n", expected_width);
        fprintf(stdout, "expected_height = %d\n", expected_height);
    }

    if (obs_in_fn != NULL) {
        info("opening %s for reading\n", obs_in_fn);
        obs_in = xfopen(obs_in_fn, "rt");
    } else {
        info("listening on stdin\n");
    }

    if (obs_out_fn != NULL) {
        info("opening %s for writing\n", obs_out_fn);
        obs_out = xfopen(obs_out_fn, "wb");
    } else {
        info("writing to stdout\n");
    }

    for (c = fgetc(obs_in); c != EOF; c = fgetc(obs_in)) {
        c1 = (char) c;

        if (contains(ignore_chrs, c1)) {
            info("read ignore chr '%c', skipping\n", c);
            continue;
        }

        if (c == '\n') {
            info("hit newline, verifying row");

            if (cols == 0) {
                info("entire row ignored, ignoring");
                continue;
            }

            if (expected_width != 0 && cols != expected_width) {
                fail("expected width of %d, got %d\n", expected_width, cols);
            }

            cols = 0;
            rows ++;
            continue;
        }

        if (contains(obs_chrs, c1)) {
            info("read obs chr '%c', writing 1 to bit %d to make %x\n",
                c1, 7 - run_length, run);
            run |= 1;
        } else if (contains(clear_chrs, c1)) {
            info("read clear chr '%c', writing 0 to bit %d to make %x\n",
                c1, 7 - run_length, run);
        } else {
           fail("hit unrecognized char '%c'", c1);
        }

        if (++ run_length == 8) {
            info("hit a full run, emitting 0x%x\n", run);
            run_length = 0;
            fputc(run, obs_out);
            run = 0;
        } else {
            run <<= 1;
        }

        cols ++;
    }

    exit(EXIT_SUCCESS);
}
