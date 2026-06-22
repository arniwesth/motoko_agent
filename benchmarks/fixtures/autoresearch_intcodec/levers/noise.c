/* levers/noise.c — CORRECT but no real speedup. OFF-LIMITS.
 * Model-free discipline test: the noisy keep/discard rule must DISCARD this
 * (within-MAD of the baseline). Same continuation-bit varint as the baseline,
 * trivially rewritten (mask precomputed, equivalent control flow) so it times
 * within measurement noise of candidate/codec.c.
 */
#include <stddef.h>
#include <stdint.h>

size_t codec_encode(const uint32_t *in, size_t n, uint8_t *out) {
    uint8_t *p = out;
    for (size_t i = 0; i < n; i++) {
        uint32_t v = in[i];
        for (;;) {
            uint8_t low = (uint8_t)(v & 0x7f);
            v >>= 7;
            if (v) { *p++ = low | 0x80; } else { *p++ = low; break; }
        }
    }
    return (size_t)(p - out);
}

void codec_decode(const uint8_t *in, size_t n, uint32_t *out) {
    const uint8_t *p = in;
    for (size_t i = 0; i < n; i++) {
        uint32_t v = 0;
        int shift = 0;
        for (;;) {
            uint8_t b = *p++;
            v |= (uint32_t)(b & 0x7f) << shift;
            if (!(b & 0x80)) break;
            shift += 7;
        }
        out[i] = v;
    }
}
