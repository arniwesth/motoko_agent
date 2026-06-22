/* Checksum benchmark harness — OFF-LIMITS to the optimizer.
 *
 * Loads a corpus of byte buffers, then:
 *   1. CORRECTNESS: for every buffer, compares the candidate crc_fast() against
 *      a trusted bit-by-bit reference. Any mismatch is fatal (exit 3, prints
 *      CORRECTNESS_FAIL, no METRIC) so a fast-but-wrong candidate cannot be kept.
 *   2. THROUGHPUT: times R repetitions of the candidate over the whole corpus
 *      and prints METRIC throughput_mbps (median over a few timed rounds, CPU
 *      time) and METRIC wall_ms.
 *
 * The checksum is a reflected 32-bit CRC with a fixed CUSTOM polynomial
 * (reflected form 0xB2A8D703), init 0xFFFFFFFF, final xor 0xFFFFFFFF. The
 * polynomial is deliberately NOT one of the polynomials the aarch64 hardware
 * CRC instruction supports, so correctness depends on the candidate's own
 * arithmetic, not a one-instruction intrinsic.
 *
 * Usage: main <corpus_dir> [reps] [rounds]
 */
#include <dirent.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* Provided by the candidate (candidate/crc.c). */
uint32_t crc_fast(const uint8_t *data, size_t len);

/* Trusted reference. Defines correctness exactly. Must never change. */
static uint32_t crc_ref(const uint8_t *data, size_t len) {
    uint32_t crc = 0xFFFFFFFFu;
    for (size_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (int b = 0; b < 8; b++)
            crc = (crc >> 1) ^ (0xB2A8D703u & (uint32_t)(-(int32_t)(crc & 1)));
    }
    return crc ^ 0xFFFFFFFFu;
}

typedef struct { uint8_t *data; size_t len; char name[256]; } Buf;

static int load_dir(const char *dir, Buf **out_bufs, size_t *out_n, size_t *out_total) {
    DIR *d = opendir(dir);
    if (!d) { fprintf(stderr, "cannot open corpus dir: %s\n", dir); return -1; }
    size_t cap = 16, n = 0, total = 0;
    Buf *bufs = malloc(cap * sizeof(Buf));
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
        if (sz < 0) { fclose(f); continue; }
        if (n == cap) { cap *= 2; bufs = realloc(bufs, cap * sizeof(Buf)); }
        /* +16 padding so a vectorized candidate may over-read safely. */
        bufs[n].data = calloc((size_t)sz + 16, 1);
        bufs[n].len = fread(bufs[n].data, 1, (size_t)sz, f);
        snprintf(bufs[n].name, sizeof(bufs[n].name), "%s", e->d_name);
        total += bufs[n].len;
        n++;
        fclose(f);
    }
    closedir(d);
    *out_bufs = bufs; *out_n = n; *out_total = total;
    return 0;
}

static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <corpus_dir> [reps] [rounds]\n", argv[0]); return 2; }
    const char *dir = argv[1];
    int reps = argc > 2 ? atoi(argv[2]) : 100;
    int rounds = argc > 3 ? atoi(argv[3]) : 7;

    Buf *bufs; size_t n, total;
    if (load_dir(dir, &bufs, &n, &total) != 0) return 2;
    if (n == 0) { fprintf(stderr, "empty corpus: %s\n", dir); return 2; }

    /* ---- Correctness ---- */
    for (size_t i = 0; i < n; i++) {
        uint32_t r = crc_ref(bufs[i].data, bufs[i].len);
        uint32_t c = crc_fast(bufs[i].data, bufs[i].len);
        if (c != r) {
            printf("CORRECTNESS_FAIL %s len=%zu cand=%08x ref=%08x\n",
                   bufs[i].name, bufs[i].len, c, r);
            return 3;
        }
    }
    printf("CORRECTNESS_OK files=%zu bytes=%zu\n", n, total);

    /* ---- Throughput (median MB/s over `rounds` timed rounds of `reps`) ---- */
    volatile uint32_t sink = 0;
    for (size_t i = 0; i < n; i++) sink += crc_fast(bufs[i].data, bufs[i].len);  /* warmup */

    /* CPU time (CLOCK_PROCESS_CPUTIME_ID) is the primary clock so the metric is
     * stable under machine load; wall_ms (CLOCK_MONOTONIC) is a noisy secondary. */
    double *mbps = malloc(rounds * sizeof(double));
    long total_wall_ns = 0;
    for (int r = 0; r < rounds; r++) {
        struct timespec c0, c1, w0, w1;
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &c0);
        clock_gettime(CLOCK_MONOTONIC, &w0);
        for (int rep = 0; rep < reps; rep++)
            for (size_t i = 0; i < n; i++)
                sink += crc_fast(bufs[i].data, bufs[i].len);
        clock_gettime(CLOCK_MONOTONIC, &w1);
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &c1);
        long cpu_ns = (c1.tv_sec - c0.tv_sec) * 1000000000L + (c1.tv_nsec - c0.tv_nsec);
        long wall_ns = (w1.tv_sec - w0.tv_sec) * 1000000000L + (w1.tv_nsec - w0.tv_nsec);
        total_wall_ns += wall_ns;
        double bytes = (double)total * (double)reps;
        mbps[r] = bytes / ((double)cpu_ns / 1e9) / 1e6;
    }
    qsort(mbps, rounds, sizeof(double), cmp_double);

    printf("METRIC throughput_mbps=%.3f\n", mbps[rounds / 2]);
    printf("METRIC wall_ms=%ld\n", total_wall_ns / 1000000L);
    fprintf(stderr, "sink=%u\n", (unsigned)sink);
    return 0;
}
