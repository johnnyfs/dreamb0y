SOURCES=$(wildcard *.c)
TARGETS=$(patsubst %.c, %.out, ${SOURCES})
LIBS=$(shell pkg-config sdl --libs) -lSDL_image -lm
CFLAGS=$(shell pkg-config sdl --cflags)

.PHONY: all
all: ${TARGETS}
	bash strip.sh

%.o: %.c
	gcc --std=c99 -c $< -o $@ ${CFLAGS}

%.out: %.o
	gcc $< -o $@ ${LIBS}	
