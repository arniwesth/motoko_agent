/* SIMD-scan benchmark harness — OFF-LIMITS to the optimizer.
 *
 * Loads a corpus directory of files, then:
 *   1. CORRECTNESS: for every file, compares the candidate scan_special()
 *      against a trusted reference scalar scan (count + every index). Any
 *      mismatch is fatal (exit 3) and prints CORRECTNESS_FAIL.
 *   2. THROUGHPUT: times R repetitions of the candidate scanning the whole
 *      corpus and prints METRIC throughput_mbps (median over a few timed
 *      rounds) and METRIC wall_ms.
 *
 * Usage: main <corpus_dir> [reps] [rounds]
 */
#include <dirent.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* Provided by the candidate (candidate/scan.c). */
size_t scan_special(const uint8_t *buf, size_t len, uint32_t *out);

/* Trusted reference. Must never be changed by the candidate. */
static size_t ref_scan(const uint8_t *buf, size_t len, uint32_t *out) {
    size_t count = 0;
    for (size_t i = 0; i < len; i++) {
        uint8_t c = buf[i];
        if (c == '<' || c == '&' || c == '\r' || c == '\0') out[count++] = (uint32_t)i;
    }
    return count;
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
        bufs[n].data = malloc((size_t)sz + 1);
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
    int reps = argc > 2 ? atoi(argv[2]) : 200;
    int rounds = argc > 3 ? atoi(argv[3]) : 5;

    Buf *bufs; size_t n, total;
    if (load_dir(dir, &bufs, &n, &total) != 0) return 2;
    if (n == 0) { fprintf(stderr, "empty corpus: %s\n", dir); return 2; }

    /* Scratch output buffers sized to the largest file. */
    size_t maxlen = 0;
    for (size_t i = 0; i < n; i++) if (bufs[i].len > maxlen) maxlen = bufs[i].len;
    uint32_t *cand_out = malloc((maxlen + 1) * sizeof(uint32_t));
    uint32_t *ref_out  = malloc((maxlen + 1) * sizeof(uint32_t));

    /* ---- Correctness ---- */
    for (size_t i = 0; i < n; i++) {
        size_t rc = ref_scan(bufs[i].data, bufs[i].len, ref_out);
        size_t cc = scan_special(bufs[i].data, bufs[i].len, cand_out);
        if (cc != rc) {
            printf("CORRECTNESS_FAIL %s count cand=%zu ref=%zu\n", bufs[i].name, cc, rc);
            return 3;
        }
        for (size_t k = 0; k < rc; k++) {
            if (cand_out[k] != ref_out[k]) {
                printf("CORRECTNESS_FAIL %s idx[%zu] cand=%u ref=%u\n",
                       bufs[i].name, k, cand_out[k], ref_out[k]);
                return 3;
            }
        }
    }
    printf("CORRECTNESS_OK files=%zu bytes=%zu\n", n, total);

    /* ---- Throughput (median MB/s over `rounds` timed rounds of `reps`) ---- */
    /* warmup */
    for (size_t i = 0; i < n; i++) (void)scan_special(bufs[i].data, bufs[i].len, cand_out);

    /* Throughput is measured in CPU time (CLOCK_PROCESS_CPUTIME_ID) so the
     * primary metric is stable under machine load — wall-clock timing on a
     * shared container swings wildly and would let a no-op look like a win.
     * wall_ms (CLOCK_MONOTONIC) is reported as a noisy secondary. */
    double *mbps = malloc(rounds * sizeof(double));
    volatile size_t sink = 0;
    long total_wall_ns = 0;
    for (int r = 0; r < rounds; r++) {
        struct timespec c0, c1, w0, w1;
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &c0);
        clock_gettime(CLOCK_MONOTONIC, &w0);
        for (int rep = 0; rep < reps; rep++)
            for (size_t i = 0; i < n; i++)
                sink += scan_special(bufs[i].data, bufs[i].len, cand_out);
        clock_gettime(CLOCK_MONOTONIC, &w1);
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &c1);
        long cpu_ns = (c1.tv_sec - c0.tv_sec) * 1000000000L + (c1.tv_nsec - c0.tv_nsec);
        long wall_ns = (w1.tv_sec - w0.tv_sec) * 1000000000L + (w1.tv_nsec - w0.tv_nsec);
        total_wall_ns += wall_ns;
        double bytes = (double)total * (double)reps;
        mbps[r] = bytes / ((double)cpu_ns / 1e9) / 1e6;
    }
    qsort(mbps, rounds, sizeof(double), cmp_double);
    double median = mbps[rounds / 2];

    printf("METRIC throughput_mbps=%.3f\n", median);
    printf("METRIC wall_ms=%ld\n", total_wall_ns / 1000000L);
    fprintf(stderr, "sink=%zu\n", (size_t)sink);
    return 0;
}
