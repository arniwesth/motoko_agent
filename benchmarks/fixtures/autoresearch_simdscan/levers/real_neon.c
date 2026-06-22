/* Phase-1 REAL LEVER (hand-written, off-limits) — correct NEON vectorized scan.
 * Processes 16 bytes at a time; skips whole blocks with no special byte; falls
 * back to scalar extraction inside hit-blocks and for the sub-16 tail. Output is
 * identical to the reference on all inputs (including non-16-multiple lengths).
 * This is the literature lever (simdjson-style vectorized classification) the
 * loop should KEEP and that should TRANSFER to held-out. */
#include <stddef.h>
#include <stdint.h>
#include <arm_neon.h>

size_t scan_special(const uint8_t *buf, size_t len, uint32_t *out) {
    size_t count = 0, i = 0;
    const uint8x16_t lt = vdupq_n_u8('<');
    const uint8x16_t am = vdupq_n_u8('&');
    const uint8x16_t cr = vdupq_n_u8('\r');
    const uint8x16_t nu = vdupq_n_u8('\0');
    for (; i + 16 <= len; i += 16) {
        uint8x16_t chunk = vld1q_u8(buf + i);
        uint8x16_t m = vorrq_u8(vorrq_u8(vceqq_u8(chunk, lt), vceqq_u8(chunk, am)),
                                vorrq_u8(vceqq_u8(chunk, cr), vceqq_u8(chunk, nu)));
        if (vmaxvq_u8(m) == 0) continue;          /* no special in these 16 bytes */
        for (int k = 0; k < 16; k++) {            /* rare: extract hits in order */
            uint8_t c = buf[i + k];
            if (c == '<' || c == '&' || c == '\r' || c == '\0') out[count++] = (uint32_t)(i + k);
        }
    }
    for (; i < len; i++) {                          /* scalar tail (< 16 bytes) */
        uint8_t c = buf[i];
        if (c == '<' || c == '&' || c == '\r' || c == '\0') out[count++] = (uint32_t)i;
    }
    return count;
}
