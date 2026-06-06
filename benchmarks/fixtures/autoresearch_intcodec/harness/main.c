/* Integer-codec benchmark harness — OFF-LIMITS to the optimizer.
 *
 * The candidate owns an integer-array codec: it implements both codec_encode()
 * and codec_decode() and may choose any on-wire byte format it likes. The
 * harness times DECODE throughput, subject to two hard gates:
 *
 *   1. COMPRESSION GATE: the total encoded size over the corpus must genuinely
 *      compress — at most 7/8 of the raw fixed-width size (4 bytes/value). A
 *      codec that stores the uint32s verbatim (a memcpy "decode", ratio 1.0)
 *      cannot pass; nor can a fixed-width-with-exceptions scheme on this
 *      mixed-magnitude workload. The gate is aggregate (not per-file) because a
 *      single large value needs 4 bytes minimum, so no per-file "< 4n" bound is
 *      satisfiable. Prints COMPRESSION_FAIL and exits non-zero (no METRIC).
 *   2. CORRECTNESS GATE: decode(encode(values)) must round-trip to the exact
 *      input array, value for value. Any mismatch prints CORRECTNESS_FAIL and
 *      exits non-zero (no METRIC). The codec's format is its own, so round-trip
 *      identity is the complete and sufficient correctness condition — there is
 *      no external "true" encoding to compare against.
 *
 * Only when BOTH gates pass for every corpus file does the harness time decode
 * and print METRIC throughput_mbps (decoded payload MB/s, CPU-time, median over
 * a few rounds) and METRIC wall_ms.
 *
 * Corpus files are raw little-endian uint32 arrays (file size is a multiple of
 * 4); the value COUNT per file deliberately varies, including counts that are
 * not multiples of 4 and a few tiny files (< 4 values), so a codec that
 * mishandles the group tail or overfits to TRAIN count structure is exposed on
 * the held-out corpus.
 *
 * Usage: main <corpus_dir> [reps] [rounds]
 */
#include <dirent.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* Provided by the candidate (candidate/codec.c).
 *   codec_encode: write an encoding of in[0..n) to out[]; return bytes written.
 *   codec_decode: decode n values (count is transmitted out-of-band) into out[].
 * out for encode is sized ENC_CAP(n) bytes (see below); out for decode is n
 * uint32. The decoder may over-read up to 16 bytes past the encoded data — the
 * harness zero-pads the encode buffer so a vectorized decode is safe. */
size_t codec_encode(const uint32_t *in, size_t n, uint8_t *out);
void   codec_decode(const uint8_t *in, size_t n, uint32_t *out);

/* Worst-case encoded size budget the harness allocates: 5 bytes/value (LEB128
 * worst case for 32-bit) + a control byte per value of slack + 64B over-read
 * padding. Any reasonable varint-class codec fits comfortably. */
#define ENC_CAP(n) (5 * (n) + (n) + 64)

typedef struct { uint32_t *vals; size_t n; char name[256]; } Arr;

/* Read a raw little-endian uint32 file (size must be a multiple of 4). */
static int load_dir(const char *dir, Arr **out_arrs, size_t *out_n, size_t *out_vals) {
    DIR *d = opendir(dir);
    if (!d) { fprintf(stderr, "cannot open corpus dir: %s\n", dir); return -1; }
    size_t cap = 16, n = 0, totvals = 0;
    Arr *arrs = malloc(cap * sizeof(Arr));
    struct dirent *e;
    while ((e = readdir(d))) {
        if (e->d_name[0] == '.') continue;
        char path[1024];
        snprintf(path, sizeof(path), "%s/%s", dir, e->d_name);
        FILE *f = fopen(path, "rb");
        if (!f) continue;
        fseek(f, 0, SEEK_END);
        long sz = ftell(f);
        fseek(f, 0, SEEK_SET);
        if (sz < 0 || (sz % 4) != 0) { fclose(f); continue; }
        size_t nv = (size_t)sz / 4;
        if (n == cap) { cap *= 2; arrs = realloc(arrs, cap * sizeof(Arr)); }
        uint8_t *raw = malloc((size_t)sz + 4);
        size_t got = fread(raw, 1, (size_t)sz, f);
        fclose(f);
        if (got != (size_t)sz) { free(raw); continue; }
        uint32_t *vals = malloc((nv + 1) * sizeof(uint32_t));
        for (size_t i = 0; i < nv; i++) {
            vals[i] = (uint32_t)raw[4*i] | ((uint32_t)raw[4*i+1] << 8)
                    | ((uint32_t)raw[4*i+2] << 16) | ((uint32_t)raw[4*i+3] << 24);
        }
        free(raw);
        arrs[n].vals = vals; arrs[n].n = nv;
        snprintf(arrs[n].name, sizeof(arrs[n].name), "%s", e->d_name);
        totvals += nv;
        n++;
    }
    closedir(d);
    *out_arrs = arrs; *out_n = n; *out_vals = totvals;
    return 0;
}

static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <corpus_dir> [reps] [rounds]\n", argv[0]); return 2; }
    const char *dir = argv[1];
    int reps = argc > 2 ? atoi(argv[2]) : 200;
    int rounds = argc > 3 ? atoi(argv[3]) : 5;

    Arr *arrs; size_t n, totvals;
    if (load_dir(dir, &arrs, &n, &totvals) != 0) return 2;
    if (n == 0) { fprintf(stderr, "empty corpus: %s\n", dir); return 2; }

    /* Per-file encode buffers (zero-padded) and a decode scratch sized to the
     * largest file. Encode once up front; decode is what we time. */
    uint8_t **enc = malloc(n * sizeof(uint8_t *));
    size_t  *enclen = malloc(n * sizeof(size_t));
    size_t maxn = 0;
    for (size_t i = 0; i < n; i++) if (arrs[i].n > maxn) maxn = arrs[i].n;
    uint32_t *dec_out = malloc((maxn + 4) * sizeof(uint32_t));

    /* ---- Encode + gates ---- */
    size_t total_raw = 0, total_enc = 0;
    for (size_t i = 0; i < n; i++) {
        size_t nv = arrs[i].n;
        size_t cap = ENC_CAP(nv);
        enc[i] = calloc(cap, 1);                 /* zeroed -> safe over-read */
        size_t el = codec_encode(arrs[i].vals, nv, enc[i]);
        enclen[i] = el;
        if (el > cap) {                          /* buffer overflow = disqualified */
            printf("ENCODE_OVERFLOW %s wrote=%zu cap=%zu\n", arrs[i].name, el, cap);
            return 3;
        }
        /* CORRECTNESS GATE: round-trip identity. */
        memset(dec_out, 0xCD, (maxn + 4) * sizeof(uint32_t));
        codec_decode(enc[i], nv, dec_out);
        for (size_t k = 0; k < nv; k++) {
            if (dec_out[k] != arrs[i].vals[k]) {
                printf("CORRECTNESS_FAIL %s val[%zu] dec=%u ref=%u\n",
                       arrs[i].name, k, dec_out[k], arrs[i].vals[k]);
                return 3;
            }
        }
        total_raw += 4 * nv;
        total_enc += el;
    }
    /* COMPRESSION GATE (aggregate): require total_enc <= (7/8) * total_raw. */
    if (8 * total_enc > 7 * total_raw) {
        printf("COMPRESSION_FAIL enc=%zu raw=%zu ratio=%.3f (need <= 0.875)\n",
               total_enc, total_raw, (double)total_enc / (double)total_raw);
        return 4;
    }
    printf("CORRECTNESS_OK files=%zu values=%zu enc_bytes=%zu raw_bytes=%zu ratio=%.3f\n",
           n, totvals, total_enc, total_raw, (double)total_enc / (double)total_raw);

    /* ---- Throughput (median decoded-MB/s over `rounds` rounds of `reps`) ---- */
    for (size_t i = 0; i < n; i++) codec_decode(enc[i], arrs[i].n, dec_out);   /* warmup */

    /* CPU time (CLOCK_PROCESS_CPUTIME_ID) is the primary clock so the metric is
     * stable under machine load; wall_ms (CLOCK_MONOTONIC) is a noisy secondary.
     * Payload = decoded bytes (4 per value), independent of the chosen format,
     * so throughput is comparable across encodings. */
    double *mbps = malloc(rounds * sizeof(double));
    volatile uint32_t sink = 0;
    long total_wall_ns = 0;
    for (int r = 0; r < rounds; r++) {
        struct timespec c0, c1, w0, w1;
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &c0);
        clock_gettime(CLOCK_MONOTONIC, &w0);
        for (int rep = 0; rep < reps; rep++)
            for (size_t i = 0; i < n; i++) {
                codec_decode(enc[i], arrs[i].n, dec_out);
                sink += dec_out[arrs[i].n ? arrs[i].n - 1 : 0];
            }
        clock_gettime(CLOCK_MONOTONIC, &w1);
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &c1);
        long cpu_ns = (c1.tv_sec - c0.tv_sec) * 1000000000L + (c1.tv_nsec - c0.tv_nsec);
        long wall_ns = (w1.tv_sec - w0.tv_sec) * 1000000000L + (w1.tv_nsec - w0.tv_nsec);
        total_wall_ns += wall_ns;
        double bytes = (double)total_raw * (double)reps;
        mbps[r] = bytes / ((double)cpu_ns / 1e9) / 1e6;
    }
    qsort(mbps, rounds, sizeof(double), cmp_double);
    double median = mbps[rounds / 2];

    printf("METRIC throughput_mbps=%.3f\n", median);
    printf("METRIC wall_ms=%ld\n", total_wall_ns / 1000000L);
    fprintf(stderr, "sink=%u\n", (unsigned)sink);
    return 0;
}
