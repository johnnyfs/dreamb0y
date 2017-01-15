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

int n_colors_per_palette = 4;
const char *table_out_fn = NULL;
const char *image_fn = NULL;
int max_palettes = 4;
const char *palettes_fn = NULL;
const char *uniques_palette_fn = NULL;
const char *attr_out_fn = NULL;
int tile_width = 16;
int tile_height = 16;
int max_uniques = 64;
const char *uniques_out_fn = NULL;
int uniques_out_tile_width = 8;

/**
 * Parser called by argp while parsing command line arguments. Sets the globals based on the key
 * and enforces the presence of the image file.
 */
static error_t
config_parse_opt(int key, char *arg, struct argp_state *state) {

    switch (key) {
        case ARGP_KEY_ARG:
            image_fn = arg;
            break;
        case 'c':
            n_colors_per_palette = to_int(arg);
            break;
        case 't':
            table_out_fn = arg;
            break;
        case 'C':
            max_palettes = to_int(arg);
            break;
        case 'U':
            max_uniques = to_int(arg);
            break;
        case 'p':
            palettes_fn = arg;
            break;
        case 'P':
            uniques_palette_fn = arg;
            break;
        case 'a':
            attr_out_fn = arg;
            break;
        case 'h':
            tile_height = to_int(arg);
            break;
        case 'w':
            tile_width = to_int(arg);
            break;
        case 'o':
            uniques_out_fn = arg;
            break;
        case 'W':
            uniques_out_tile_width = to_int(arg);
            break;
        case 'V':
            verbose = true;
            break;
        case ARGP_KEY_FINI:
            if (image_fn == NULL) {
                fprintf(stderr, "you must specify an image file\n");
                argp_usage(state);
            }
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
            .name = "colors-per-palette",
            .key = 'c',
            .arg = "N_COLORS (4)",
            .flags = 0,
            .doc = "the number of colors per individual palette in the provided palettes image; if the palettes image is not of a length such that length % <colors-per-palette> = 0, then an error will be thrown (the defualt of 4 is what's required for NES compatibility)",
            .group = 0
        },
        {
            .name = "indeces-out",
            .key = 't',
            .arg = "FILEPATH",
            .flags = 0,
            .doc = "path to a binary file to which will be written the index of each tile in the generated uniques image, in row-major order; for example, if the image is 16x16 tiles, the resulting file will be 256 bytes; if the tile at (10, 14) matches the 7th unique tile discovered, then a 6 will be written to position (14 * 16 + 10 = 234) in the resulting file",
            .group = 0
        },
        {
            .name = "max-palettes",
            .key = 'C',
            .arg = "N_PALETTES (4)",
            .flags = 0,
            .doc = "the maximum number of <colors-per-palette> sized palettes that may be in the provided palettes image (the default of 4 is what's required for NES compatibility)",
            .group = 0
        },
        {
            .name = "max-uniques",
            .key = 'U',
            .arg = "N_UNIQUES (64)",
            .flags = 0,
            .doc = "the maximum number of unique <tile-width> x <tile-height> tiles that may be in the provided image; if more than this are generated the application will fail (but the output image will still be generated for debugging purposes (the default of 64 and the default tile widths and heights of 16 are what is required for NES compatibility -- ie, 64 unique tiles each composed of 4 8x8 subtiles, or 256 8x8 \"chrs\" total)"
        },
        {
            .name = "palettes",
            .key = 'p',
            .arg = "PNGFILE",
            .flags = 0,
            .doc = "a <colors-per-palette> * <n_palettes> x 1 pixel png image containing a series of uniformly-sized palettes, which will be used A) to desaturate the input image in order to detect uniques and B) to generate an output file containing the palette indeces of each tile (if not provided, the image will be cut into non-desaturated uniques)",
            .group = 0
        },
        {
            .name = "uniques-palette",
            .key = 'P',
            .arg = "PNGFILE (generated grayscale)",
            .flags = 0,
            .doc = "a <colors-per-palette> x 1 pixel png image containing four separate colors, which will be used to represent the unique tiles in the <uniques-out> output; for example, if a pixel in a unique tile was only ever represented by the 2nd color in one of the reference palettes, the unique will be drawn with the 2nd color in the <uniques-palette>; if this value is not present, a generated grayscale will be used",
            .group = 0
        },
        {
            .name = "palette-indeces-out",
            .key = 'a',
            .arg = "FILEPATH",
            .flags = 0,
            .doc = "path to a binary file to which will be written the index of the <colors-per-palette> sized palette in the provided palette image; for example, if the palette image contains 4 4-color palettes, the output will consist of bytes in the range 0-3, in row-major order",
            .group = 0
        },
        {
            .name = "tile-height",
            .key = 'h',
            .arg = "N_PIXELS (16)",
            .flags = 0,
            .doc = "the height of the tiles of which the input image is composed, in pixels; if the provided image is of a height such that <height> % <tile-height> != 0, an error will be thrown",
            .group = 0
        },
        {
            .name = "tile-width",
            .key = 'w',
            .arg = "N_PIXELS (16)",
            .flags = 0,
            .doc = "the width of the tiles of which the input image is composed, in pixels; if the provided image is of a height such that <width> % <tile-width> != 0, an error will be thrown",
            .group = 0
        },
        {
            .name = "uniques-out",
            .key = 'o',
            .arg = "FILEPATH",
            .flags = 0,
            .doc = "path to which a <tile-width> * <n_uniques_generated> x <tile-height> BMP file will be written containing every unique <tile-width> x <tile-height> tile in the image (desaturated to a uniform grayscale representing each pixel's index in its respective palette; for example, if each palette contains four colors, then the unique tile will be composed of four shades of gray, where full white is the first index and full black the last)",
            .group = 0
        },
        {
            .name = "uniques-out-width",
            .key = 'W',
            .arg = "N_TILES (8)",
            .flags = 0,
            .doc = "the width in tiles of the unique image bank; for example, if <max-uniques> is 64 then a value of 8 will result in an image that is 8x8 tiles; any excess tiles will be left blank",
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
        .args_doc = "IMAGE_IN",
        .doc = "\nextracts unique tiles from the input image IMAGE_IN, using an optional reference palette and optionally producing files containing tile and/or palette indeces.\n\nIMAGE_IN must be composed of some number of <tile-width> x <tile-height> tiles, where each tile is composed of no more than <colors-per-palette> different colors, and where each color must be from the same palette. Specifically, each color must be from a consecutive range in the source palette beginning at <inferred_palette_index> * <colors-per-palette> and ending at (<inferred_palette_index> + 1) * <color-per-palette> - 1; for example, if the provided palettes image contains 4 4-color palettes, then each tile must consist of only 4 colors from one the ranges { 0-3, 4-7, 8-11, 12-15 }, where the <inferred_palette_index> of each will be 0, 1, 2, and 3, respectively.\n\nNOTE: wherever default values are provided in parentheses below, they are the values required for NES compatibility and in most cases will not need to be specified."
    };

    argp_parse(&argp, argc, argv, 0, NULL, NULL);
}

/**
 * Find the first pixel matching color in palettes. Treat is as the Nth index in 0-M palettes of <colors-per-palette>
 * colors each. Return the matching Nth value in the provided output palette.
 */
Uint32
dereference_from_palettes(Uint32 color, SDL_Surface *palettes, int *palette_index, Uint32 *out_pal) {
    Uint32 *p = palettes->pixels;
    for (int i = 0; i < palettes->w; i ++) {
        info("checking color 0x%08x against palette color 0x%08x\n", color, p[i]);
        if (p[i] == color) {
            *palette_index = i / n_colors_per_palette;
            return out_pal[i % n_colors_per_palette];
        }
    }
    fail("color 0x%08x from source image did not match any color in the reference palettes\n", color);
}

/**
 * Compare from (0, 0) to (s1->w, s1->h) in s1 to from (x2, y2) to (x2 + s1->w, y2 + s2->h) in s2.
 *
 * Returns true if the images match completely.
 */
bool
image_compare(SDL_Surface *s1, SDL_Surface *s2, int x2, int y2) {
    const int w = s1->w;
    const int h = s1->h;
    Uint32 *p1 = s1->pixels;
    Uint32 *p2 = s2->pixels;
    for (int y = 0; y < h; y ++) {
        for (int x = 0; x < w; x ++) {
            Uint32 c1 = p1[y * w + x];
            Uint32 c2 = p2[(y2 + y) * s2->w + x2 + x];
            if (c1 != c2) {
                return false;
            }
        }
    }
    return true;
}

int
main(int argc, char *argv[])
{
    config_parse(argc, argv);

    if (verbose) {
        printf("int n_colors_per_palette = %d\n", n_colors_per_palette);
        printf("const char *table_out_fn = %s\n", table_out_fn);
        printf("const char *image_fn = %s\n", image_fn);
        printf("int max_palettes = %d\n", max_palettes);;
        printf("const char *palettes_fn = %s\n", palettes_fn);
        printf("const char *uniques_palette_fn = %s\n", palettes_fn);
        printf("const char *attr_out_fn = %s\n", attr_out_fn);
        printf("int tile_width = %d\n", tile_width);
        printf("int tile_height = %d\n", tile_height);
        printf("int max_uniques = %d\n", max_uniques);
        printf("const char *uniques_out_fn = %s\n", uniques_out_fn);
        printf("int uniques_out_tile_width = %d\n", uniques_out_tile_width);
        printf("bool verbose = %d\n", verbose);
    }

    // Load and validate image file.
    info("loading image file from %s\n", image_fn);
    SDL_Surface *src = IMG_Load(image_fn);
    if (src == NULL) {
        fail("could not load image from %s: %s\n", image_fn, SDL_GetError());
    }
    info("successfully loaded %dx%dx%d image from %s\n", src->w, src->h, src->format->BitsPerPixel, image_fn);
    if (src->w % tile_width != 0 || src->h % tile_height != 0) {
        fail("image size(%dx%d) must be a multiple of tile size(%dx%d)\n", src->w, src->h, tile_width, tile_height);
    }
    SDL_PixelFormat *src_format = src->format;

    // Load and validate optional reference palettes.
    SDL_Surface *palettes = NULL;
    Uint32 *uniques_palette;
    if (palettes_fn != NULL) {
        info("loading reference palette from %s\n", palettes_fn);
        SDL_Surface *tmp = IMG_Load(palettes_fn);
        if (tmp == NULL) {
            fail("could not load reference palettes from %s: %s\n", palettes_fn, SDL_GetError());
        }
        palettes = SDL_ConvertSurface(tmp, src_format, 0);
        info("palettes bpp: %d versus source bpp: %d\n", palettes->format->BytesPerPixel, src_format->BytesPerPixel);
        SDL_FreeSurface(tmp);
        SDL_LockSurface(palettes);
        if (palettes == NULL) {
            fail("could not convert palettes to source image format: %s", SDL_GetError());
        }
        info("loaded %dx%dx%d palette image from %s\n", palettes->w, palettes->h, src->format->BitsPerPixel, palettes_fn);
        if (palettes->w % n_colors_per_palette != 0) {
            fail("reference palettes image width(%d) must be a multiple of <colors-per-palette>(%d)\n", palettes->w, n_colors_per_palette);
        }
        if (palettes->w / n_colors_per_palette > max_palettes) {
            fail("reference palettes image may contain no more than %d palettes (got %d)\n", max_palettes, palettes->w / n_colors_per_palette);
        }
        if (palettes->h != 1) {
            fail("reference palettes image height(%d) must be 1\n", palettes->h);
        }
        info("allocating %d colors for the uniques output palette\n", n_colors_per_palette);

        // Load the output palette, or generate one if it wasn't specified.
        uniques_palette = calloc(sizeof (Uint32), n_colors_per_palette);
        if (uniques_palette == NULL) {
            fail("could not allocate %d colors for a uniques output palette\n", n_colors_per_palette);
        }
        if (uniques_palette_fn != NULL) {
            info("a uniques palette image was specified at %s, loading\n", uniques_palette_fn);
            SDL_Surface *tmp = IMG_Load(uniques_palette_fn);
            if (tmp == NULL) {
                fail("could not load uniques palette from %s: %s\n", uniques_palette_fn, SDL_GetError());
            }
            SDL_Surface *surface = SDL_ConvertSurface(tmp, src_format, 0);
            if (surface == NULL) {
                fail("could not convert the uniques palette into the input format\n");
            }
            SDL_FreeSurface(tmp);
            if (surface->w != n_colors_per_palette || surface->h != 1) {
                fail("expected a %dx1 unique palette surface, got %dx%d\n", n_colors_per_palette, surface->w, surface->h);
            }
            SDL_LockSurface(surface);
            for (int i = 0; i < n_colors_per_palette; i ++) {
                uniques_palette[i] = ((Uint32 *) surface->pixels)[i];
            }
            SDL_UnlockSurface(surface);
            SDL_FreeSurface(surface);
        } else {
            // Generate a grayscale to represent the dereferenced colors.
            const int unit = 255 / n_colors_per_palette;
            info("no uniques palette was specified, generating grayscale: ");
            for (int i = 0; i < n_colors_per_palette; i ++) {
                Uint8 shade = (255 - i * unit);
                uniques_palette[i] = SDL_MapRGBA(src_format, shade, shade, shade, 0);
                info("%d (%x); ", shade, uniques_palette[i]);
            }
            info("\n");
        }
    } else {
        info("not loading reference palettes because no image was specified\n");
    }

    // Open the output files if they're wanted.
    FILE *table_out = NULL;
    if (table_out_fn != NULL) {
        info("opening tile index file for writing at %s\n", table_out_fn);
        table_out = xfopen(table_out_fn, "wb");
    }

    FILE *attr_out = NULL;
    if (attr_out_fn != NULL) {
        if (palettes == NULL) {
            fail("cannot write palette indeces to file %s without a reference palettes image\n", attr_out_fn);
        }
        info("opening palette index file for writing at %s\n", attr_out_fn);
        attr_out = xfopen(attr_out_fn, "wb");
    }

    // Create the output tiles.
    int tiles_width = tile_width * uniques_out_tile_width;
    int tiles_height = tile_height * ((max_uniques / uniques_out_tile_width) + ((max_uniques % uniques_out_tile_width > 0) ? 1 : 0));
    info("creating %dx%d output tile image for %d %dx%d tiles\n", tiles_width, tiles_height, max_uniques,
            tile_width, tile_height);
    SDL_Surface *tiles = SDL_CreateRGBSurface(0, tiles_width, tiles_height, src_format->BitsPerPixel,
            src_format->Rmask, src_format->Gmask, src_format->Bmask, 0);
    if (tiles == NULL) {
        fail("could not create a tile bank for %d unique tiles: %s\n", max_uniques, SDL_GetError());
    }
    SDL_FillRect(tiles, NULL, uniques_palette[0]);

    // Iterate over the image and extract the uniques.
    int n_uniques = 0;
    int n_tiles_x = src->w / tile_width;
    int n_tiles_y = src->h / tile_height;
    SDL_LockSurface(src);
    Uint32 *p = src->pixels;
    for (int ty = 0; ty < n_tiles_y; ty ++) {
        for (int tx = 0; tx < n_tiles_x; tx ++) {
            
            // First dereference the tile against the src palettes and create a desaturated unique.
            info("creating a temporary tile image to test the tile at (%d, %d)\n", tx, ty);
            SDL_Surface *tile = SDL_CreateRGBSurface(0, tile_width, tile_height, src_format->BitsPerPixel,
                    src_format->Rmask, src_format->Gmask, src_format->Bmask, 0);
            if (tile == NULL) {
                fail("could not create a new %dx%d tile image: %s\n", tile_width, tile_height, SDL_GetError());
            }
            SDL_LockSurface(tile);
            Uint32 *tp = tile->pixels;
            int max_palette_index = -1;
            if (palettes != NULL) {
                info("dereferencing against the reference palettes\n");
            }
            for (int py = 0; py < tile_height; py ++) {
                for (int px = 0; px < tile_width; px ++) {
                    const int x = tx * tile_width + px;
                    const int y = ty * tile_height + py;
                    Uint32 color = p[y * src->w + x];
                    int palette_index; 
                    if (palettes != NULL) { 
                        color = dereference_from_palettes(color, palettes, &palette_index, uniques_palette); 
                    }
                    if (palette_index > max_palette_index) {
                        info("choosing new highest palette index seen so far %d\n", palette_index);
                        max_palette_index = palette_index;
                    }
                    tp[py * tile_width + px] = color; 
                }
            }
            
            // Write out the palette index as requested.
            if (attr_out != NULL) {
                info("writing palette index %d to attribute table\n", max_palette_index);
                fputc(max_palette_index, attr_out);
            }
            
            // Attempt to match this tile against the accumulated uniques.
            bool matched = false;
            int unique_index = 0;
            for (unique_index = 0; unique_index < n_uniques && unique_index < max_uniques; unique_index ++) {
                int uniques_x = (unique_index % uniques_out_tile_width) * tile_width;
                int uniques_y = (unique_index / uniques_out_tile_width) * tile_height;
                info("comparing to previously extracted unique at index %d ((%d, %d) in bank)\n", unique_index, uniques_x, uniques_y);
                matched = image_compare(tile, tiles, uniques_x, uniques_y);
                if (matched) {
                    break;
                }
            }
           
            // If it's a unique, add it to the list.
            SDL_UnlockSurface(tile);
            if (!matched) {
                if (unique_index >= max_uniques) {
                    info("no match but not adding new unique at index %d because it is >= than the max %d\n", n_uniques, max_uniques);
                } else {
                    SDL_Rect dst_rect = { 
                        (unique_index % uniques_out_tile_width) * tile_width, 
                        (unique_index / uniques_out_tile_width) * tile_height
                    };
                    int rval = SDL_BlitSurface(tile, NULL, tiles, &dst_rect);
                    if (rval != 0) {
                        fail("blitting tile to unique bank failed: %s\n", SDL_GetError());
                    }
                    info("no match: new unique at index %d; adding to bank at %d, %d\n", unique_index, dst_rect.x, dst_rect.y);
                }
                n_uniques ++;
            } else {
                info("matched tile to unique index %d\n", unique_index);
            }
            SDL_LockSurface(tile);

            // Write out the tile's index.
            if (table_out != NULL) {
                info("writing tile index %d to the name table\n", unique_index);
                fputc(unique_index, table_out);
            }

            // Clean up this iteration.
            SDL_FreeSurface(tile);
        }
    }
    info("detected %d unique tiles\n", n_uniques);

    if (uniques_out_fn != NULL) {
        info("writing uniques to %s\n", uniques_out_fn);
        SDL_SaveBMP(tiles, uniques_out_fn);
    }

    // Clean up.
    free(uniques_palette);
    xfclose(attr_out);
    xfclose(table_out);
    if (palettes != NULL) {
        SDL_UnlockSurface(palettes);
        SDL_FreeSurface(palettes);
    }
    SDL_FreeSurface(src);

    exit(EXIT_SUCCESS);
}
