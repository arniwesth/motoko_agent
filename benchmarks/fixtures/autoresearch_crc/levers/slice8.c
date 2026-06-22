/* levers/slice8.c — slicing-by-8 table CRC. OFF-LIMITS.
 * The strong "model-known plateau": a standard, well-documented technique a
 * frontier model produces readily. Correct and several times faster than the
 * single-byte baseline, but well below what the hardware can achieve. Used by
 * the model-free discipline test as a keep+transfers candidate that is NOT the
 * ceiling. (The ceiling technique is documented only in the operator notes.)
 */
#include <stddef.h>
#include <stdint.h>

#define POLY 0xB2A8D703u

static uint32_t t[8][256];
static int ready = 0;

static void build(void) {
    for (int b = 0; b < 256; b++) {
        uint32_t c = (uint32_t)b;
        for (int i = 0; i < 8; i++) c = (c >> 1) ^ (POLY & (uint32_t)(-(int32_t)(c & 1)));
        t[0][b] = c;
    }
    for (int b = 0; b < 256; b++)
        for (int k = 1; k < 8; k++)
            t[k][b] = (t[k-1][b] >> 8) ^ t[0][t[k-1][b] & 0xFF];
    ready = 1;
}

static inline uint32_t ld32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

uint32_t crc_fast(const uint8_t *data, size_t len) {
    if (!ready) build();
    uint32_t crc = 0xFFFFFFFFu;
    const uint8_t *p = data;
    while (len >= 8) {
        crc ^= ld32(p);
        uint32_t hi = ld32(p + 4);
        crc = t[7][crc & 0xff] ^ t[6][(crc >> 8) & 0xff] ^ t[5][(crc >> 16) & 0xff] ^ t[4][(crc >> 24) & 0xff]
            ^ t[3][hi & 0xff]  ^ t[2][(hi >> 8) & 0xff] ^ t[1][(hi >> 16) & 0xff] ^ t[0][(hi >> 24) & 0xff];
        p += 8; len -= 8;
    }
    while (len--) crc = (crc >> 8) ^ t[0][(crc ^ *p++) & 0xff];
    return crc ^ 0xFFFFFFFFu;
}
