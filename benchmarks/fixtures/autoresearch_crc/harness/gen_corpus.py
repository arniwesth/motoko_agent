#!/usr/bin/env python3
"""Deterministic byte-buffer corpus generator for the checksum fixture.

Emits raw random-byte files. The checksum is data-independent in cost, so the
content is just deterministic pseudo-random bytes; what matters is the SIZE
distribution. Sizes are dominated by large buffers (where a block-parallel
implementation wins big over a byte-at-a-time one), plus a few small and
non-block-aligned sizes so a candidate that mishandles the head/tail or only
fast-paths block-aligned lengths is exposed on the held-out corpus.

Off-limits to the optimizer: this generator and the corpora it produces are part
of the benchmark, not the candidate.
"""
import os
import random
import sys


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: gen_corpus.py <out_dir> <seed> <spec>", file=sys.stderr)
        print("  spec = comma-separated byte sizes, one per file", file=sys.stderr)
        return 2
    out_dir, seed_s, spec = sys.argv[1], sys.argv[2], sys.argv[3]
    rng = random.Random(int(seed_s))
    os.makedirs(out_dir, exist_ok=True)
    sizes = [int(x) for x in spec.split(",")]
    total = 0
    for i, sz in enumerate(sizes):
        data = bytes(rng.randrange(256) for _ in range(sz))
        with open(os.path.join(out_dir, f"buf_{i:03d}.bin"), "wb") as f:
            f.write(data)
        total += sz
    print(f"wrote {len(sizes)} files to {out_dir} ({total} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
