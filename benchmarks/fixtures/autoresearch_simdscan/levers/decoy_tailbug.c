/* Phase-1 CORRECTNESS DECOY (off-limits) — NEON scan that OMITS the scalar tail
 * and the per-block extraction is fine, but buffers shorter than 16 bytes and
 * the final partial block are never scanned. It is fast, but misses special
 * bytes in the tail, so the correctness oracle must reject it (CHECK fails ->
 * keep blocked). Tests the behavioral verifier, not the metric. */
#include <stddef.h>
#include <stdint.h>
#include <arm_neon.h>

size_t scan_special(const uint8_t *buf, size_t len, uint32_t *out) {
    size_t count = 0, i = 0;
    const uint8x16_t lt = vdupq_n_u8('<'), am = vdupq_n_u8('&');
    const uint8x16_t cr = vdupq_n_u8('\r'), nu = vdupq_n_u8('\0');
    for (; i + 16 <= len; i += 16) {                 /* main blocks only */
        uint8x16_t chunk = vld1q_u8(buf + i);
        uint8x16_t m = vorrq_u8(vorrq_u8(vceqq_u8(chunk, lt), vceqq_u8(chunk, am)),
                                vorrq_u8(vceqq_u8(chunk, cr), vceqq_u8(chunk, nu)));
        if (vmaxvq_u8(m) == 0) continue;
        for (int k = 0; k < 16; k++) {
            uint8_t c = buf[i + k];
            if (c == '<' || c == '&' || c == '\r' || c == '\0') out[count++] = (uint32_t)(i + k);
        }
    }
    /* BUG: no scalar tail — bytes in buf[i..len) are never scanned. */
    return count;
}
