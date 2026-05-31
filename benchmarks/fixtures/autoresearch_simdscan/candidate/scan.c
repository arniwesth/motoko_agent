/* CANDIDATE ARTIFACT — this is the only file the optimizer may edit.
 *
 * Task: record the index of every "special" byte in buf[0..len) into out[],
 * and return the count. The special bytes are:
 *     '<' (0x3C)   '&' (0x26)   '\r' (0x0D)   '\0' (0x00)
 *
 * Contract:
 *   - out[] has capacity for at least `len` indices.
 *   - Indices must be recorded in strictly increasing order.
 *   - The result must match the reference scalar scan EXACTLY on every input,
 *     including the final partial block of any buffer whose length is not a
 *     multiple of a vector width.
 *
 * Baseline: a simple scalar loop (~1.4 GB/s on this class of ARM core). The
 * harness measures throughput; faster, still-correct implementations score
 * higher. See the simdjson paper (arXiv:1902.08318) for the vectorized
 * structural-character classification technique.
 */
#include <stddef.h>
#include <stdint.h>

size_t scan_special(const uint8_t *buf, size_t len, uint32_t *out) {
    size_t count = 0;
    for (size_t i = 0; i < len; i++) {
        uint8_t c = buf[i];
        if (c == '<' || c == '&' || c == '\r' || c == '\0') {
            out[count++] = (uint32_t)i;
        }
    }
    return count;
}
