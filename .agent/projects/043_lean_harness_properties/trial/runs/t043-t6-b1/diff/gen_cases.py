#!/usr/bin/env python3
"""Generate differential-test cases for T6 (truncate_utf8_by_bytes).

One case per line: `<max_bytes>;<b1>,<b2>,...` (decimal bytes; nothing after `;` for "").
Deterministic (fixed seed). Aimed at the boundaries the function has: multi-byte text, caps
either side of the rune count and of the byte count, negative caps, and every row of Go's
UTF-8 first-byte table and accept ranges (overlong, surrogate, > U+10FFFF, truncated).

    gen_cases.py [seed] > cases.txt
"""
import random, sys, itertools

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 43006
rng = random.Random(seed)

VALID = [
    [0x61], [0x7F], [0x00], [0x0A],
    [0xC2, 0x80], [0xC3, 0xA9], [0xDF, 0xBF],
    [0xE0, 0xA0, 0x80], [0xE2, 0x82, 0xAC], [0xED, 0x9F, 0xBF], [0xEE, 0x80, 0x80], [0xEF, 0xBF, 0xBF],
    [0xE6, 0x97, 0xA5],
    [0xF0, 0x90, 0x80, 0x80], [0xF0, 0x9F, 0x98, 0x80], [0xF3, 0xBF, 0xBF, 0xBF], [0xF4, 0x8F, 0xBF, 0xBF],
]
INVALID = [
    [0x80], [0xBF], [0xC0], [0xC1], [0xF5], [0xFF], [0xFE],
    [0xC0, 0x80], [0xC1, 0xBF],               # overlong 2-byte leads
    [0xC3], [0xE2, 0x82], [0xF0, 0x9F, 0x98], # truncated
    [0xE0, 0x80, 0x80], [0xE0, 0x9F, 0xBF],   # overlong 3-byte
    [0xED, 0xA0, 0x80], [0xED, 0xBF, 0xBF],   # surrogates
    [0xF0, 0x80, 0x80, 0x80], [0xF0, 0x8F, 0xBF, 0xBF],  # overlong 4-byte
    [0xF4, 0x90, 0x80, 0x80],                 # > U+10FFFF
    [0xE2, 0x41, 0x82], [0xF0, 0x9F, 0x41, 0x80], [0xC3, 0xC3],  # bad continuation
]
TOKENS = VALID * 3 + INVALID

def caps_for(b):
    n = len(b)
    cand = {-2, -1, 0, 1, n - 1, n, n + 1, n + 2}
    cand |= {rng.randint(0, n + 1) for _ in range(3)}
    return sorted(cand)

cases = []

# 1. Token strings: 0..10 tokens.
for _ in range(1800):
    k = rng.randint(0, 10)
    b = [x for _ in range(k) for x in rng.choice(TOKENS)]
    for m in caps_for(b):
        cases.append((m, b))

# 2. Uniform random bytes, length 0..8.
for _ in range(1500):
    b = [rng.randint(0, 255) for _ in range(rng.randint(0, 8))]
    for m in rng.sample(caps_for(b), 3):
        cases.append((m, b))

# 3. Every single byte, caps 0 and 1 (the whole first-byte table).
for c in range(256):
    for m in (0, 1):
        cases.append((m, [c]))

# 4. Structured 2-, 3- and 4-byte sequences over every lead byte's accept-range edges, cap 1.
leads = list(range(0xC0, 0x100))
edges = [0x00, 0x41, 0x7F, 0x80, 0x8F, 0x90, 0x9F, 0xA0, 0xBF, 0xC0, 0xFF]
for c, b1 in itertools.product(leads, edges):
    cases.append((1, [c, b1]))
for c in (0xE0, 0xE1, 0xEC, 0xED, 0xEE, 0xEF, 0xF0, 0xF1, 0xF3, 0xF4, 0xF5):
    for b1, b2 in itertools.product(edges, (0x7F, 0x80, 0xBF, 0xC0)):
        cases.append((1, [c, b1, b2]))
        cases.append((2, [c, b1, b2, 0x61]))
for c in (0xF0, 0xF1, 0xF3, 0xF4):
    for b1, b2, b3 in itertools.product((0x80, 0x8F, 0x90, 0xBF), (0x7F, 0x80, 0xBF), (0x7F, 0x80, 0xBF, 0xC0)):
        cases.append((2, [c, b1, b2, b3]))

for m, b in cases:
    print(f"{m};{','.join(map(str, b))}")
