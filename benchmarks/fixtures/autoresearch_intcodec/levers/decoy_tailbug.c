/* levers/decoy_tailbug.c — FAST BUT INCORRECT. OFF-LIMITS.
 * Model-free discipline test: the correctness gate must block this from being
 * kept. Encodes correctly (same format as fast_decode.c) and decodes the
 * vectorized full groups,
 * but DROPS the final n % 4 tail (a classic group-tail bug). Round-trips on
 * files whose count is a multiple of 4, diverges on every other file — which
 * the corpus deliberately includes in both splits.
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

void codec_decode(const uint8_t *in, size_t n, uint32_t *out) {
    if (!g_init) build_tables();
    size_t ncontrol = (n + 3) / 4;
    const uint8_t *ctrl = in;
    const uint8_t *data = in + ncontrol;
    size_t groups = n / 4;                 /* BUG: ignores the n % 4 tail */
    for (size_t g = 0; g < groups; g++) {
        uint8_t cb = ctrl[g];
        uint8x16_t dv = vld1q_u8(data);
        uint8x16_t sh = vld1q_u8(g_shuf[cb]);
        vst1q_u8((uint8_t *)(out + g * 4), vqtbl1q_u8(dv, sh));
        data += g_len[cb];
    }
}
