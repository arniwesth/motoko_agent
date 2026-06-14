/* candidate/crc.c — the ONLY file the optimizer edits.
 *
 * Implements:
 *   uint32_t crc_fast(const uint8_t *data, size_t len);
 *
 * Contract (enforced by the off-limits harness):
 *   - crc_fast MUST return the same value as the trusted reference for every
 *     input (a reflected 32-bit CRC, custom polynomial 0xB2A8D703, init
 *     0xFFFFFFFF, final xor 0xFFFFFFFF). Any mismatch is rejected
 *     (CORRECTNESS_FAIL, no score).
 *   - the objective is to MAXIMIZE throughput (METRIC throughput_mbps) on the
 *     workload (large buffers), keeping exact correctness.
 *
 * Platform: aarch64, build gcc -O2 -march=armv8-a+crypto — NEON and the full
 * ARMv8 crypto extensions are available via <arm_neon.h>.
 *
 * Baseline below: a correct single-byte table CRC (table built once at first
 * call from the polynomial recurrence, so it is correct by construction).
 */
#include <stddef.h>
#include <stdint.h>

#define POLY 0xB2A8D703u

static uint32_t table[256];
static int table_ready = 0;

static void build_table(void) {
    for (int b = 0; b < 256; b++) {
        uint32_t c = (uint32_t)b;
        for (int i = 0; i < 8; i++)
            c = (c >> 1) ^ (POLY & (uint32_t)(-(int32_t)(c & 1)));
        table[b] = c;
    }
    table_ready = 1;
}

uint32_t crc_fast(const uint8_t *data, size_t len) {
    if (!table_ready) build_table();
    uint32_t crc = 0xFFFFFFFFu;
    for (size_t i = 0; i < len; i++)
        crc = (crc >> 8) ^ table[(crc ^ data[i]) & 0xFF];
    return crc ^ 0xFFFFFFFFu;
}
