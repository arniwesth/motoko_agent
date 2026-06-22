#!/usr/bin/env python3
"""Deterministic synthetic-HTML corpus generator for the SIMD-scan fixture.

Emits pseudo-HTML byte files containing the four "special" bytes the scan must
find: '<' (0x3C), '&' (0x26), '\\r' (0x0D), '\\0' (0x00). File sizes deliberately
vary, including sizes that are NOT multiples of 16 and a few tiny files (< 16
bytes), so a vectorized candidate that mishandles the sub-block tail will diverge
from the reference on the held-out corpus.

Off-limits to the optimizer: this generator and the corpora it produces are part
of the benchmark, not the candidate.
"""
import os
import random
import sys

WORDS = ["lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing",
         "elit", "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore"]
ENTITIES = ["&amp;", "&lt;", "&gt;", "&quot;", "&#39;", "&nbsp;"]
TAGS = ["div", "span", "p", "a", "ul", "li", "h1", "table", "tr", "td", "section"]


def gen_doc(rng: random.Random, target: int) -> bytes:
    # Realistic-ish HTML: long plain-text runs (where a SIMD scan skips 16 bytes
    # at a time) punctuated by sparse special bytes. Average run between specials
    # is ~60-140 bytes, so a correct vectorized scan wins big over the scalar loop.
    out = bytearray()
    while len(out) < target:
        r = rng.random()
        if r < 0.70:                      # a sentence of plain text (no specials)
            n = rng.randint(8, 20)
            out += (" ".join(rng.choice(WORDS) for _ in range(n))).encode()
            out += b". "
        elif r < 0.85:                    # an open/close tag (contains '<')
            tag = rng.choice(TAGS)
            out += (f"<{tag}>" if rng.random() < 0.5 else f"</{tag}>").encode()
        elif r < 0.93:                    # an HTML entity (contains '&')
            out += rng.choice(ENTITIES).encode()
        elif r < 0.98:                    # CRLF line break (contains '\r')
            out += b"\r\n"
        else:                             # stray NUL
            out += b"\x00"
    # Truncate to an exact target length so sizes are controlled (often not %16).
    return bytes(out[:target])


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: gen_corpus.py <out_dir> <seed> <spec>", file=sys.stderr)
        print("  spec = comma-separated target byte sizes, one per file", file=sys.stderr)
        return 2
    out_dir, seed_s, spec = sys.argv[1], sys.argv[2], sys.argv[3]
    rng = random.Random(int(seed_s))
    os.makedirs(out_dir, exist_ok=True)
    sizes = [int(x) for x in spec.split(",")]
    for i, sz in enumerate(sizes):
        data = gen_doc(rng, sz)
        with open(os.path.join(out_dir, f"doc_{i:03d}.html"), "wb") as f:
            f.write(data)
    print(f"wrote {len(sizes)} files to {out_dir} ({sum(sizes)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
