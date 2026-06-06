/* levers/fast_decode.c — hand-written reference of the WINNING technique.
 * OFF-LIMITS to the optimizer; used by the model-free discipline test as the
 * "keep + transfers" candidate. The technique name and citation are recorded in
 * the operator handoff under .agent/plans/, deliberately not here.
 *
 * Approach: split the encoding into two streams — a per-group length-code stream
 * and a packed data stream — so that all lengths for a group of 4 values are
 * known up front and decode can run branchlessly via a per-code shuffle table
 * (NEON vqtbl1q_u8) rather than a per-value length branch.
 *
 * Layout written by encode: [control bytes ceil(n/4)] [packed data bytes].
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
            for (int b = 0; b < 4; b++) {
                /* lane j*4+b of the output uint32 comes from data byte `pos`
                 * for b < len, else 0xFF -> vqtbl1q_u8 yields 0 (zero-fill the
                 * high bytes of a short value). */
                g_shuf[cb][j * 4 + b] = (b < len) ? (uint8_t)pos++ : 0xFF;
            }
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
    uint8_t *ctrl = out;
    uint8_t *data = out + ncontrol;
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
    size_t groups = n / 4;

    for (size_t g = 0; g < groups; g++) {
        uint8_t cb = ctrl[g];
        uint8x16_t dv = vld1q_u8(data);              /* may over-read; padded */
        uint8x16_t sh = vld1q_u8(g_shuf[cb]);
        uint8x16_t res = vqtbl1q_u8(dv, sh);
        vst1q_u8((uint8_t *)(out + g * 4), res);
        data += g_len[cb];
    }

    /* scalar tail for the final n % 4 values */
    size_t rem = n - groups * 4;
    if (rem) {
        uint8_t cb = ctrl[groups];
        for (size_t j = 0; j < rem; j++) {
            int len = ((cb >> (2 * j)) & 3) + 1;
            uint32_t v = 0;
            for (int b = 0; b < len; b++) v |= (uint32_t)data[b] << (8 * b);
            data += len;
            out[groups * 4 + j] = v;
        }
    }
}
