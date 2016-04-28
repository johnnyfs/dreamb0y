#ifndef TO_INT_H
#define TO_INT_H

#include <errno.h>
#include <string.h>

#include "fail.h"

int to_int(const char *s) {
    errno = 0;
    int rval = strtol(s, NULL, 10);
    if (errno != 0) {
        fail("could not convert %s into an integer\n", strerror(errno));
    }

    return rval;
}

#endif
