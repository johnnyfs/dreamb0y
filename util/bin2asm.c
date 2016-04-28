#include <argp.h>
#include <stdlib.h>

#include "files.h"
#include "info.h"
#include "to_int.h"

const char *source_fn = NULL;
const char *out_fn = NULL;
int row_width = 16;

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
        case 'w':
            row_width = to_int(arg);
            break;
        case 'V':
            verbose = true;
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
            .arg = "OUTFILE (stdout)",
            .flags = 0,
            .doc = "path where the assembly will be written",
            .group = 0
        },
        {
            .name = "row-width",
            .key = 'w',
            .arg = "INTEGER (16)",
            .flags = 0,
            .doc = "number of bytes to emit per individual .db statement; this does not effect the meaning of the output, only its organization in the file"
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
        .doc = "reads INFILE as a binary file and emits crasm-compatible assembly describing the bytes contained in the file; if an OUTFILE is not specified, the output is written to stdout; if INFILE is not specified, the input is read from stdin"
    };

    argp_parse(&argp, argc, argv, 0, NULL, NULL);
}

int
main(int argc, char *argv[])
{
    config_parse(argc, argv);

    FILE *in, *out;
    if (source_fn != NULL) {
        info("opening INFILE at %s\n", source_fn);
        in = xfopen(source_fn, "rb");
    } else {
        info("no INFILE specified, using stdin\n");
        in = stdin;
    }
    if (out_fn != NULL) {
        info("opening OUTFILE at %s\n", out_fn);
        out = xfopen(out_fn, "wt");
    } else {
        info("no OUTFILE specified, using stdout\n");
        out = stdout;
    }
    if (verbose) {
        info("int row_width = %d\n", row_width);
    }

    int i = 0;
    for (;;) {
        int b = fgetc(in);
        if (b == EOF) {
            info("hit end-of-file, quitting\n");
            break;
        }
        if (i == 0) {
            fprintf(out, "\tdb\t$%02x", b);
        } else {
            fprintf(out, ", $%02x", b);
        }
        if (++ i == row_width) {
            info("completed row of width %d, starting a new one\n", row_width);
            i = 0;
            fputc('\n', out);
        }
    }

    fclose(out);
    fclose(in);

    exit(EXIT_SUCCESS);
}
