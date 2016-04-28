#ifndef FILES_H
#define FILES_H

#include <errno.h>
#include <stdio.h>
#include <string.h>

#include "fail.h"

static inline FILE*
xfopen(const char *fn, const char *method) {
    FILE *rval = fopen(fn, method); 
    if (rval == NULL) {
        fail("could not open file at %s (%s): %s\n", fn, method, strerror(errno));
    }
    return rval;
}

static inline void
xfclose(FILE *stream) {
    if (stream != NULL) {
        fclose(stream);
    }
}

#endif
