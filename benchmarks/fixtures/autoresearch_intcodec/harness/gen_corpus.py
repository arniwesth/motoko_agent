#!/usr/bin/env python3
"""Deterministic uint32-array corpus generator for the integer-codec fixture.

Emits raw little-endian uint32 files. Each value's significant-byte length is
drawn from a fixed mixed distribution over {1,2,3,4} bytes, then the value is
sampled uniformly within that byte range. The mix is deliberately spread:

    1 byte (< 2^8)            30%      -> value in [0, 2^8)
    2 bytes (< 2^16)          30%      -> value in [2^8, 2^16)
    3 bytes (< 2^24)          25%      -> value in [2^16, 2^24)
    4 bytes (>= 2^24)         15%      -> value in [2^24, 2^32)

Two consequences make this a clean fixture:
  * Per-value length is unpredictable, so a variable-length decoder that
    branches on each value's length mispredicts constantly.
  * ~15% of values need all 4 bytes, so no single fixed width works: fixed-3
    cannot represent them (round-trip fails) and fixed-4 does not compress
    (fails the < 4*n compression gate). Variable-length encoding is forced.

Value COUNTS per file vary, including counts that are not multiples of 4 and a
few tiny files (< 4 values), so a codec that mishandles the group tail or
overfits to a particular count structure diverges on the held-out corpus.

Off-limits to the optimizer: this generator and the corpora it produces are
part of the benchmark, not the candidate.
"""
import os
import random
import struct
import sys

# (cumulative threshold, low, high) for the byte-length classes above.
CLASSES = [
    (0.30, 0, 1 << 8),
    (0.60, 1 << 8, 1 << 16),
    (0.85, 1 << 16, 1 << 24),
    (1.00, 1 << 24, 1 << 32),
]


def gen_array(rng: random.Random, count: int) -> bytes:
    out = bytearray()
    for _ in range(count):
        r = rng.random()
        for thr, lo, hi in CLASSES:
            if r < thr:
                out += struct.pack("<I", rng.randrange(lo, hi))
                break
    return bytes(out)


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: gen_corpus.py <out_dir> <seed> <spec>", file=sys.stderr)
        print("  spec = comma-separated value COUNTS, one per file", file=sys.stderr)
        return 2
    out_dir, seed_s, spec = sys.argv[1], sys.argv[2], sys.argv[3]
    rng = random.Random(int(seed_s))
    os.makedirs(out_dir, exist_ok=True)
    counts = [int(x) for x in spec.split(",")]
    total = 0
    for i, c in enumerate(counts):
        data = gen_array(rng, c)
        with open(os.path.join(out_dir, f"arr_{i:03d}.u32"), "wb") as f:
            f.write(data)
        total += c
    print(f"wrote {len(counts)} files to {out_dir} ({total} values)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
