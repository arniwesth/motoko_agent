/* Phase-1 NOISE candidate (off-limits) — a cosmetic rewrite of the scalar scan
 * (conditions reordered, equivalent behavior and ~equal speed). The loop should
 * see no improvement beyond the MAD band and DISCARD it. */
#include <stddef.h>
#include <stdint.h>

size_t scan_special(const uint8_t *buf, size_t len, uint32_t *out) {
    size_t count = 0;
    for (size_t i = 0; i < len; i++) {
        uint8_t c = buf[i];
        if (c == '\0' || c == '\r' || c == '&' || c == '<') {
            out[count++] = (uint32_t)i;
        }
    }
    return count;
}
