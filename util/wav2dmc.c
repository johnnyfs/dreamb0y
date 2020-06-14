#include <argp.h>
#include <float.h>
#include <limits.h>
#include <math.h>
#include <stdbool.h>
#include <stdlib.h>

#include <SDL/SDL.h>

#include "to_int.h"

//const double freq_target = 9419.857894736842;
const double freq_target = 4181.71;
#define MIN(a, b) (a < b ? a : b)
#define MAX(a, b) (a > b ? a : b)

const char *source_fn = NULL;
const char *out_fn = NULL;
int rate = (-1);
int trim_left = 0, trim_right = 0;
int window_size = 1;
bool verbose = false;

static error_t
config_parse_opt(int key, char *arg, struct argp_state *state) 
{
    switch (key) {
        case ARGP_KEY_ARG:
            source_fn = arg;
            break;

        case 'L':
            trim_left = to_int(arg);
            break;

        case 'o':
            out_fn = arg;
            break;

        case 'r':
            rate = to_int(arg);
            break;

        case 'R':
            trim_right = to_int(arg);
            break;

        case 'V':
            verbose = true;
            break;

        case 'w':
            window_size = to_int(arg);
            break;

        case ARGP_KEY_FINI:
            if (source_fn == NULL) {
                fprintf(stderr, "you must specify an input file\n");
                argp_usage(state);
            }
            if (out_fn == NULL) {
                fprintf(stderr, "missing required argument -o/--output\n");
                argp_usage(state);
            }
            if (rate == (-1)) {
                fprintf(stderr, "missing required argument -r/--rate\n");
                argp_usage(state);
            }
            if (rate >= 16) {
                fprintf(stderr, "rate must be between 0 and 15, inclusive\n");
                argp_usage(state);
            }
            if (window_size < 1) {
                fprintf(stderr, "window size must be >= 1 (%d)\n", window_size);
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
            .arg = "DMCFILE (required)",
            .flags = 0,
            .doc = "path to output dmc file",
            .group = 0
        },
        {
            .name = "rate",
            .key = 'r',
            .arg = "RATE (0-15, required)",
            .flags = 0,
            .doc = "playback rate for output dmc"
        },
        {
            .name = "trim-left",
            .key = 'L',
            .arg = "FRAMES (0)",
            .flags = 0,
            .doc = "number of leading frames to trim from sample"
        },
        {
            .name = "trim-right",
            .key = 'R',
            .arg = "FRAMES (0)",
            .flags = 0,
            .doc = "number of trailing frames to trim from sample"
        },
        {
            .name = "window",
            .key = 'w',
            .arg = "WIDTH (1)",
            .flags = 0,
            .doc = "width of sliding window used for resampling"
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
        .args_doc = "WAVFILE",
        .doc = "reads WAVFILE, a 16-bit .wav sample, converts it to the specified indexed NES playback rate using an optional window and smoothing strategy, scales it to 7-bit resolution, and converts it to a binary representation of a best-fit delta modulation (1 bit => -/+2 steps, rightmost bit per byte taking precendence)"
    };

    argp_parse(&argp, argc, argv, 0, NULL, NULL);
}

int
main(int argc, char *argv[])
{
    static const int nes_rate_cycles[16] = {
        428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54
    };
    SDL_AudioSpec spec;
    Uint32 length;
    Uint8 *buffer;
    double target_freq;
    double *window = NULL;
    double *smoothed = NULL;
    double *output_samples = NULL;
    bool is_signed, is_big_endian, is_float;
    int bit_size;
    int n_input_samples, n_input_samples_trimmed;
    int n_output_samples, output_size;
    double conv_ratio;
    double len_s, output_len_s;

    config_parse(argc, argv);

    target_freq = 1789773.0 / (double)nes_rate_cycles[rate];

    if (verbose) {
        fprintf(stderr, "target rate: %d => %f\n", rate, target_freq);
        fprintf(stderr, "trim: left: %d, right: %d\n", trim_left, trim_right);
        fprintf(stderr, "window_size: %d\n", window_size);
    }

    if (SDL_LoadWAV(source_fn, &spec, &buffer, &length) == NULL) {
        fprintf(stderr, "could not open wav file %s: %s\n", source_fn, SDL_GetError());
        exit(EXIT_FAILURE);
    }

    if (target_freq > spec.freq) {
        fprintf(stderr, "currently only conv rates < 1.0 are supported\n");
    }

    conv_ratio = target_freq / (double)spec.freq;
    is_signed = (spec.format & 0x8000) > 0;
    is_big_endian = (spec.format & 0x1000) > 0;
    is_float = (spec.format & 0x0100) > 0;
    bit_size = spec.format & 0x00ff;
    n_input_samples = length / spec.channels / (bit_size / 8);
    n_input_samples_trimmed = n_input_samples - trim_left - trim_right;
    len_s = (double)n_input_samples / spec.freq;
    n_output_samples = (int) ceil((double)n_input_samples_trimmed * conv_ratio);
    output_size = n_output_samples / 8 + (n_output_samples % 8 > 0);
    output_len_s = (double)n_output_samples / target_freq;

    if (verbose) {
        fprintf(stderr, "conv_ratio: %f\n", conv_ratio);
        fprintf(stderr, "length: %db (%fs)\n", length, len_s);
        fprintf(stderr, "freq: %d\n", spec.freq);
        fprintf(stderr, "format: %x\n", spec.format);
        fprintf(stderr, "format.signed: %d\n", is_signed);
        fprintf(stderr, "format.bigendian: %d\n", is_big_endian);
        fprintf(stderr, "format.float: %d\n", is_float);
        fprintf(stderr, "format.bit_size: %d\n", bit_size);
        fprintf(stderr, "channels: %d\n", spec.channels);
        fprintf(stderr, "silence: %d\n", spec.silence);
        fprintf(stderr, "samples: %d -> %d\n", n_input_samples, n_output_samples);
        fprintf(stderr, "output_size: %db (%fs)\n", output_size, output_len_s);
    }

    if (spec.channels != 2 || is_big_endian || !is_signed || bit_size != 16) {
        fprintf(stderr, "currently only 16-bit signed stereo (little-endian) is supported\n");
        exit(EXIT_FAILURE);
    }
    
    {
        errno = 0;
        window = calloc(window_size, sizeof (double));
        if (window == NULL) {
            fprintf(stderr, "could not allocate sliding window of %d doubles: %s\n",
                    window_size, strerror(errno));
            exit(EXIT_FAILURE);
        }
    }

    {
        errno = 0;
        smoothed = calloc(n_input_samples_trimmed, sizeof (double));
        if (smoothed == NULL) {
            fprintf(stderr, "could not allocate intermediary smoothing buffer of %d doubles: %s\n",
                    smoothed, strerror(errno));
            exit(EXIT_FAILURE);
        }
    }

    {
        errno = 0;
        output_samples = calloc(n_output_samples, sizeof (double));
        if (output_samples == NULL) {
            fprintf(stderr, "could not allocate intermediary output buffer of %d doubles: %s\n",
                    output_samples, strerror(errno));
            exit(EXIT_FAILURE);
        }
    }

    if (verbose) {
        fprintf(stderr, "converting the wav to a merged & smoothed sample of the input resolution...\n");
    }

    /* Create a merged & smoothed sample. */
    {
        int window_idx = 0, smoothed_idx = 0;
        double last_merged = 0;

        for (int i = trim_left; i < n_input_samples - trim_right; i ++) {
            /* Calculate the merged frame value. */
            Sint16 l = ((Sint16*)buffer)[i * 2];
            Sint16 r = ((Sint16*)buffer)[i * 2 + 1];
            double merged = ((double)l + (double)r) / 2.0;
            double delta = merged - last_merged;
            int window_limit;

            last_merged = merged;

            if (verbose) {
                fprintf(stderr, "L: %d; R: %d => %f merged (%+f)\n",
                        l, r, merged, delta);
            }

            /* Fill the sliding window */
            if (window_idx < window_size) {
                window[window_idx ++] = merged;
                window_limit = window_idx;
            } else {
                for (int j = 1; j < window_size; j ++) {
                    window[j - 1] = window[j];
                }

                window[window_idx - 1] = merged;
                window_limit = window_size;
            }

            {
                double avg = 0;

                for (int j = 0; j < window_limit; j ++) {
                    avg += window[j];
                }

                if (smoothed_idx >= n_input_samples_trimmed) {
                    fprintf(stderr, "generating more than %d smoothed/trimmed samples\n",
                            n_input_samples_trimmed);

                    exit(EXIT_FAILURE);
                }

                avg /= (double)window_limit;
                smoothed[smoothed_idx ++] = avg;

                if (verbose) {
                    fprintf(stderr, "window: %f <= [ ", avg);
                    for (int j = 0; j < window_limit; j ++) {
                        fprintf(stderr, "%f ", window[j]);
                    }
                    fprintf(stderr, "]\n");
                }
            }
        }
    }

    if (verbose) {
        fprintf(stderr, "reducing the smoothed sample to the new target size\n");
    }

    /* Compress the result into the new size. */
    {
        double carry = 0.0;
        int output_idx = 0;
        double step = 0;

        for (int i = 0; i < n_input_samples_trimmed; i ++) {
            double sample = smoothed[i];
            int inc;

            if (output_idx >= n_output_samples) {
                fprintf(stderr, "overran output samples buffer\n");

                exit(EXIT_FAILURE);
            }

            step += conv_ratio;
            if (step > 1.0) {
                double overshoot = step - 1.0;
                double weight = conv_ratio - overshoot;

                carry = sample * overshoot;

                output_samples[output_idx ++] += sample * weight;

                if (verbose) {
                    fprintf(stderr, "step %f (%d): adding %f of sample %f, carrying %f => %f\n",
                            step, output_idx - 1, weight, sample, carry,
                            output_samples[output_idx - 1]);
                }

                step -= 1.0;
            } else {
                double new = output_samples[output_idx] + sample * conv_ratio + carry;

                if (verbose) {
                    fprintf(stderr, "adding %f * %f and carry-over %f to %f (%d) => %f\n",
                            conv_ratio, sample, carry, output_samples[output_idx],
                            output_idx, new);
                }

                output_samples[output_idx] = new;
                carry = 0.0;
            }
        }
    }

    /* Emit the 1-bit deltas. */
    {
        int signal = (int) ((output_samples[0] + 32768.0) * 127.0 / 65535.0);
        int byte = 0, bit = 0;
        FILE *out = NULL;

        if (verbose) {
            fprintf(stderr, "preparing to emit signal deltas to %s\n", out_fn);
        }

        {
            errno = 0;
            out = fopen(out_fn, "wb");
            if (out == NULL) {
                fprintf(stderr, "could not open %s for writing\n", out_fn, strerror(errno));
                exit(EXIT_FAILURE);
            }
        }

        if (verbose) {
            fprintf(stderr, "starting with signal: %f -> %d\n", output_samples[0], signal);
        }

        for (int i = 1; i < n_output_samples; i ++) {
            int scaled = (int) ((output_samples[i] + 32768.0) * 127.0 / 65535.0);

            if (verbose) {
                fprintf(stderr, "target step %d: %f -> %d\n", i, output_samples[i], scaled);
            }

            if (signal < scaled) {
                byte |= (0x01 << bit);
                signal += 2;
                if (verbose) {
                    fprintf(stderr, "emit +2: new signal %d/%d (error %+d)\n",
                            signal, scaled, signal - scaled);
                }
            } else {
                /* Already 0. */
                signal -= 2;
                if (verbose) {
                    fprintf(stderr, "emit -2: new signal %d/%d (error %+d)\n",
                            signal, scaled, signal - scaled);
                }
            }

            bit ++;
            if (bit == 8) {
                fputc(byte, out);
                bit = 0;
                byte = 0;
            }
        }

        fclose(out);
    }

    exit(EXIT_SUCCESS);
}
