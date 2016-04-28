#ifndef FAIL_H
#define FAIL_H

#include <stdio.h>
#include <stdlib.h>

#define fail(...) do { \
    fprintf(stderr, __VA_ARGS__); \
    exit(EXIT_FAILURE); \
} while(0)

#endif
