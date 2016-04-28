#include <argp.h>
#include <stdlib.h>

#include <SDL/SDL.h>
#include <SDL/SDL_image.h>

#include "fail.h"
#include "files.h"
#include "info.h"
#include "pixels.h"
#include "to_int.h"

const char *source_fn = NULL;
const char *out_fn = NULL;
int group_width = 2;
int group_height = 2;
const char *palette_fn = NULL;

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
        case 'h':
            group_height = to_int(arg);
            break;
        case 'w':
            group_width = to_int(arg);
            break;
        case 'p':
            palette_fn = arg;
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
                fprintf(stderr, "you must specify an output file\n");
                argp_usage(state);
            }
            if (palette_fn == NULL) {
                fprintf(stderr, "you must specify a reference palette\n");
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
            .arg = "OUTFILE (stdout)",
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
            .name = "group-height",
            .key = 'h',
            .arg = "INTEGER (2)",
            .flags = 0,
            .doc = "number of 8x8 tiles per tile group row in the source image"
        },
        {
            .name = "group-width",
            .key = 'w',
            .arg = "INTEGER (2)",
            .flags = 0,
            .doc = "number of 8x8 tiles per tile group column in the source image"
        },
        {
            .name = "palette",
            .key = 'p',
            .arg = "IMAGEFILE",
            .flags = 0,
            .doc = "a 4x1 image containing 4 distinct colors that will be used to determine the indeces emitted when scanning the source image (ie, the first color will result in 0, the second in 1, etc); if the source image contains colors not in the reference palette, the application will fail"
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
        .args_doc = "IMAGEFILE",
        .doc = "reads an image file as a representation of some number of 8x8 tiles organized into groups of <group-width>x<group_height> tiles each; the tiles in each tile group are converted into NES-compatible CHR's in row-major order, and each tile group is itself processed in row-major order.\n\nFor example, the default of 2x2 implies that the image will be processed as a set of 16x16 tile groups, where each tile group is composed of 4 8x8 tiles; thus each 16x16 tile would be processed in order, left-to-right, top-to-bottom, and during processing each would be converted into 4 NES-compatible chrs, which would be emitted in the order { upper-left, upper-right, lower-left, lower-right }.\n\nNOTE: The input image is expected to contain no more than 4 colors. The indeces emitted will be in the range 0-3, as inferred from the specfied reference palette."
    };

    argp_parse(&argp, argc, argv, 0, NULL, NULL);
}

int
dereference(SDL_Surface *input, int x, int y, Uint8 colors[4][3]) {
    Uint8 r, g, b;
    pixels_get(input, x, y, &r, &g, &b);
    for (int i = 0; i < 4; i ++) {
        if (colors[i][0] == r && colors[i][1] == g && colors[i][2] == b) {
            return i;
        }
    }
    fail("could not find color (%x, %x, %x) in reference palette\n", r, g, b);
}

int
main(int argc, char *argv[])
{
    config_parse(argc, argv);

    if (verbose) {
        printf("const char *source_fn = %s;\n", source_fn);
        printf("const char *out_fn = %s;\n", out_fn);
        printf("int group_width = %d;\n", group_width);
        printf("int group_height = %d;\n", group_height);
        printf("const char *palette_fn = %s;\n", palette_fn);
    }

    info("loading the tiles groups image from %s\n", source_fn);
    SDL_Surface *groups = IMG_Load(source_fn);
    if (groups == NULL) {
        fail("could not load source image from %s: %s\n", source_fn, SDL_GetError());
    }
    if (groups->w % (8 * group_width) != 0 || groups->h % (8 * group_height) != 0) {
        fail("source image dimensions (got %dx%d) must be divisible by the size of the tile groups (inferred %dx%d)\n", groups->w, groups->h, 8 * group_width, 8 * group_height);
    }
    info("inferring %dx%d tile groups\n", groups->w / group_width / 8, groups->h / group_height / 8);

    info("loading the reference palette from %s\n", palette_fn);
    SDL_Surface *palette = IMG_Load(palette_fn);
    if (palette == NULL) {
        fail("could not load reference palette from %s: %s\n", palette_fn, SDL_GetError());
    }

    Uint8 colors[4][3];
    SDL_LockSurface(palette);
    info("getting colors from palette (converting into tile groups color format):\n");
    for (int i = 0; i < 4; i ++) {
        pixels_get(palette, i, 0, &colors[i][0], &colors[i][1], &colors[i][2]);
        info("got color (%x, %x, %x)\n", colors[i][0], colors[i][1], colors[i][2]);
    }
    SDL_UnlockSurface(palette);
    SDL_FreeSurface(palette);

    info("opening %s for writing\n", out_fn);
    FILE *out = xfopen(out_fn, "wb");

    SDL_LockSurface(groups);
    for (int gy = 0; gy < groups->h; gy += group_height * 8) {
        for (int gx = 0; gx < groups->w; gx += group_width * 8) {
            info("processing group at (%d, %d)\n", gx, gy);

            for (int ty = 0; ty < group_height * 8; ty += 8) {
                for (int tx = 0; tx < group_width * 8; tx += 8) {

                    info("\tprocessing first pass of tile at (%d, %d)\n", gx + tx, gy + ty);
                    for (int cy = 0; cy < 8; cy ++) {
                        int b = 0, shift = 8;
                        for (int cx = 0; cx < 8; cx ++) {
                            int color = dereference(groups, gx + tx + cx, gy + ty + cy, colors);
                            info("\t\temitting color %d at position %d\n", color, shift);
                            b |= ((color & 0x01) << -- shift);
                        }
                        fputc(b, out);
                    }

                    info("\tprocessing second pass of tile at (%d, %d)\n", gx + tx, gy + ty);
                    for (int cy = 0; cy < 8; cy ++) {
                        int b = 0, shift = 8;
                        for (int cx = 0; cx < 8; cx ++) {
                            int color = dereference(groups, gx + tx + cx, gy + ty + cy, colors);
                            info("\t\temitting color %d at position %d\n", color, shift);
                            b |= (((color & 0x02) >> 1) << -- shift);
                        }
                        fputc(b, out);
                    }
                }
            }
        }
    }

    exit(EXIT_SUCCESS);
}
