/* levers/noise.c — CORRECT but no real speedup. OFF-LIMITS.
 * Model-free discipline test: the noisy keep/discard rule must DISCARD this
 * (within-MAD of the baseline). Same single-byte table CRC, trivially
 * restructured so it times within measurement noise of candidate/crc.c.
 */
#include <stddef.h>
#include <stdint.h>

#define POLY 0xB2A8D703u

static uint32_t table[256];
static int ready = 0;

static void build(void) {
    for (int b = 0; b < 256; b++) {
        uint32_t c = (uint32_t)b;
        int i = 8;
        while (i--) c = (c >> 1) ^ (POLY & (uint32_t)(-(int32_t)(c & 1)));
        table[b] = c;
    }
    ready = 1;
}

uint32_t crc_fast(const uint8_t *data, size_t len) {
    if (!ready) build();
    uint32_t crc = ~0u;
    for (const uint8_t *p = data, *end = data + len; p != end; ++p)
        crc = (crc >> 8) ^ table[(uint8_t)(crc ^ *p)];
    return ~crc;
}
