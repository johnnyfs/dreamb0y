#ifndef PIXELS_H
#define PIXELS_H

#include <SDL/SDL.h>

/* Extracting color components from a 32-bit color value */
static inline void
pixels_get(SDL_Surface *surface, int x, int y, Uint8 *r, Uint8 *g, Uint8 *b) {
    SDL_PixelFormat *fmt = surface->format;
    Uint32 temp, pixel;

    Uint8 *p = &((Uint8 *)surface->pixels)[y * surface->pitch + x * fmt->BytesPerPixel];
    pixel = *((Uint32 *) p);

    /* Get Red component */
    temp = pixel & fmt->Rmask;  /* Isolate red component */
    temp = temp >> fmt->Rshift; /* Shift it down to 8-bit */
    temp = temp << fmt->Rloss;  /* Expand to a full 8-bit number */
    *r = (Uint8)temp;

    /* Get Green component */
    temp = pixel & fmt->Gmask;  /* Isolate green component */
    temp = temp >> fmt->Gshift; /* Shift it down to 8-bit */
    temp = temp << fmt->Gloss;  /* Expand to a full 8-bit number */
    *g = (Uint8)temp;

    /* Get Blue component */
    temp = pixel & fmt->Bmask;  /* Isolate blue component */
    temp = temp >> fmt->Bshift; /* Shift it down to 8-bit */
    temp = temp << fmt->Bloss;  /* Expand to a full 8-bit number */
    *b = (Uint8)temp;
}
#endif
