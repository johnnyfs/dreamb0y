#ifndef INFO_H
#define INFO_H

#include <stdbool.h>
#include <stdio.h>

bool verbose = false;

#define info(...) do { \
    if (verbose) { \
        fprintf(stdout, __VA_ARGS__); \
    } \
} while(0)

#endif
