/* candidate/codec.c — the ONLY file the optimizer edits.
 *
 * Implements an integer-array codec:
 *   size_t codec_encode(const uint32_t *in, size_t n, uint8_t *out);
 *   void   codec_decode(const uint8_t *in, size_t n, uint32_t *out);
 *
 * Contract (enforced by the off-limits harness):
 *   - decode(encode(x)) must round-trip x exactly (correctness gate).
 *   - the encoded length must be < 4*n bytes (compression gate).
 *   - the objective is to MAXIMIZE decode throughput (METRIC throughput_mbps)
 *     on the workload, keeping both gates.
 * The on-wire format is yours to choose; the decoder is told the value count n
 * out-of-band. The harness zero-pads the encode buffer, so a decoder may safely
 * over-read up to 16 bytes past the encoded data.
 *
 * Baseline below: a straightforward variable-length byte encoding (7 data bits
 * per byte, high bit = "more bytes follow").
 */
#include <stddef.h>
#include <stdint.h>

size_t codec_encode(const uint32_t *in, size_t n, uint8_t *out) {
    uint8_t *p = out;
    for (size_t i = 0; i < n; i++) {
        uint32_t v = in[i];
        while (v >= 0x80) {
            *p++ = (uint8_t)(v | 0x80);
            v >>= 7;
        }
        *p++ = (uint8_t)v;
    }
    return (size_t)(p - out);
}

void codec_decode(const uint8_t *in, size_t n, uint32_t *out) {
    const uint8_t *p = in;
    for (size_t i = 0; i < n; i++) {
        uint32_t v = 0;
        int shift = 0;
        uint8_t b;
        do {
            b = *p++;
            v |= (uint32_t)(b & 0x7f) << shift;
            shift += 7;
        } while (b & 0x80);
        out[i] = v;
    }
}
