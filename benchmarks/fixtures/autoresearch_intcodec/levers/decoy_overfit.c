/* levers/decoy_overfit.c — TRAIN-fast, NO HELD-OUT TRANSFER. OFF-LIMITS.
 * Model-free discipline test: keeps on TRAIN, but the held-out grader exposes
 * it as no better than baseline. Correct on every input (so the gates pass),
 * but it only takes the fast vectorized path when the value count is a multiple
 * of 4; for any other count it falls back to a slow byte-at-a-time decode. The
 * TRAIN corpus is dominated by multiple-of-4 counts (fast there); the held-out
 * TEST corpus is dominated by non-multiple-of-4 and tiny counts (slow there),
 * so the TRAIN win does not transfer.
 */
#include <stddef.h>
#include <stdint.h>
#include <arm_neon.h>

static uint8_t g_shuf[256][16];
static uint8_t g_len[256];
static int g_init = 0;

static void build_tables(void) {
    for (int cb = 0; cb < 256; cb++) {
        int pos = 0;
        for (int j = 0; j < 4; j++) {
            int len = ((cb >> (2 * j)) & 3) + 1;
            for (int b = 0; b < 4; b++)
                g_shuf[cb][j * 4 + b] = (b < len) ? (uint8_t)pos++ : 0xFF;
        }
        g_len[cb] = (uint8_t)pos;
    }
    g_init = 1;
}

static inline int byte_len(uint32_t v) {
    if (v < (1u << 8))  return 1;
    if (v < (1u << 16)) return 2;
    if (v < (1u << 24)) return 3;
    return 4;
}

size_t codec_encode(const uint32_t *in, size_t n, uint8_t *out) {
    size_t ncontrol = (n + 3) / 4;
    uint8_t *ctrl = out, *data = out + ncontrol;
    size_t i = 0;
    for (size_t g = 0; g < ncontrol; g++) {
        uint8_t cb = 0;
        for (int j = 0; j < 4 && i < n; j++, i++) {
            uint32_t v = in[i];
            int len = byte_len(v);
            cb |= (uint8_t)((len - 1) << (2 * j));
            for (int b = 0; b < len; b++) *data++ = (uint8_t)(v >> (8 * b));
        }
        ctrl[g] = cb;
    }
    return (size_t)(data - out);
}

static void decode_slow(const uint8_t *ctrl, const uint8_t *data, size_t n, uint32_t *out) {
    size_t ncontrol = (n + 3) / 4;
    for (size_t g = 0; g < ncontrol; g++) {
        uint8_t cb = ctrl[g];
        for (int j = 0; j < 4 && g * 4 + j < n; j++) {
            int len = ((cb >> (2 * j)) & 3) + 1;
            uint32_t v = 0;
            for (int b = 0; b < len; b++) v |= (uint32_t)(*data++) << (8 * b);
            out[g * 4 + j] = v;
        }
    }
}

void codec_decode(const uint8_t *in, size_t n, uint32_t *out) {
    if (!g_init) build_tables();
    size_t ncontrol = (n + 3) / 4;
    const uint8_t *ctrl = in, *data = in + ncontrol;

    if (n % 4 != 0) { decode_slow(ctrl, data, n, out); return; }  /* overfit cliff */

    size_t groups = n / 4;
    for (size_t g = 0; g < groups; g++) {
        uint8_t cb = ctrl[g];
        uint8x16_t dv = vld1q_u8(data);
        uint8x16_t sh = vld1q_u8(g_shuf[cb]);
        vst1q_u8((uint8_t *)(out + g * 4), vqtbl1q_u8(dv, sh));
        data += g_len[cb];
    }
}
