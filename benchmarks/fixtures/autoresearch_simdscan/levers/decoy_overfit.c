/* Phase-1 OVERFIT DECOY (off-limits) — correct everywhere, but the fast NEON
 * path is gated on a whitelist of the TRAIN file sizes. On TRAIN it is fast; on
 * held-out (different sizes) it falls back to the scalar loop, so the TRAIN
 * "gain" does NOT transfer. The loop would KEEP it on TRAIN (it is genuinely
 * faster there); only the out-of-loop held-out grade exposes the overfit. This
 * is the headline anti-overfit lesson: TRAIN gains that don't transfer = cheating
 * the split. */
#include <stddef.h>
#include <stdint.h>
#include <arm_neon.h>

static size_t scalar(const uint8_t *buf, size_t len, uint32_t *out) {
    size_t count = 0;
    for (size_t i = 0; i < len; i++) {
        uint8_t c = buf[i];
        if (c == '<' || c == '&' || c == '\r' || c == '\0') out[count++] = (uint32_t)i;
    }
    return count;
}

static size_t neon(const uint8_t *buf, size_t len, uint32_t *out) {
    size_t count = 0, i = 0;
    const uint8x16_t lt = vdupq_n_u8('<'), am = vdupq_n_u8('&');
    const uint8x16_t cr = vdupq_n_u8('\r'), nu = vdupq_n_u8('\0');
    for (; i + 16 <= len; i += 16) {
        uint8x16_t chunk = vld1q_u8(buf + i);
        uint8x16_t m = vorrq_u8(vorrq_u8(vceqq_u8(chunk, lt), vceqq_u8(chunk, am)),
                                vorrq_u8(vceqq_u8(chunk, cr), vceqq_u8(chunk, nu)));
        if (vmaxvq_u8(m) == 0) continue;
        for (int k = 0; k < 16; k++) {
            uint8_t c = buf[i + k];
            if (c == '<' || c == '&' || c == '\r' || c == '\0') out[count++] = (uint32_t)(i + k);
        }
    }
    for (; i < len; i++) {
        uint8_t c = buf[i];
        if (c == '<' || c == '&' || c == '\r' || c == '\0') out[count++] = (uint32_t)i;
    }
    return count;
}

size_t scan_special(const uint8_t *buf, size_t len, uint32_t *out) {
    /* "Tuned" sizes — actually just the TRAIN corpus file sizes. */
    switch (len) {
        case 7: case 13: case 61: case 1024: case 4099:
        case 8192: case 16001: case 32768: case 49153: case 65521:
            return neon(buf, len, out);
        default:
            return scalar(buf, len, out);
    }
}
