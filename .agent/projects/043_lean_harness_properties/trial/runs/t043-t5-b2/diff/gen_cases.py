#!/usr/bin/env python3
"""gen_cases.py -- the shared input set for the path_up differential test.

One case per line:   <entries>|<start id>|<variant>
  <entries>  ';'-separated `id>parent_id`, the entry at position i has seq i ("" = no entries)
  <variant>  0: seen=[], acc=[]            (the one call site, journal.ail:1684)
             1: seen=["a"], acc=[]
             2: seen=[], acc=[{id q, parent a, seq 99}]
Ids never contain ';', '>' or '|'. Deterministic: no clock, fixed seed.
"""
import random, sys

out = []
# 1. Exhaustive: every list of length 0..3 over 12 entry kinds, 4 starts, 3 variants.
ids = ["", "a", "b"]
pars = ["", "a", "b", "x"]
kinds = [(i, p) for i in ids for p in pars]
starts = ["", "a", "b", "x"]
lists = [[]]
frontier = [[]]
for n in range(3):
    frontier = [l + [k] for l in frontier for k in kinds]
    lists += frontier
for l in lists:
    enc = ";".join(f"{i}>{p}" for i, p in l)
    for s in starts:
        for v in (0, 1, 2):
            out.append(f"{enc}|{s}|{v}")
# 2. Random: longer lists, more ids, so longer chains and longer cycles.
rng = random.Random(43005)
ids2 = ["", "a", "b", "c", "d", "e", "f"]
pars2 = ids2 + ["x"]
for _ in range(6000):
    n = rng.randint(0, 12)
    l = [(rng.choice(ids2), rng.choice(pars2)) for _ in range(n)]
    enc = ";".join(f"{i}>{p}" for i, p in l)
    out.append(f"{enc}|{rng.choice(pars2)}|{rng.choice((0, 0, 0, 1, 2))}")
# 3. Shaped: a permuted chain of k distinct ids, optionally closed into a cycle.
for k in range(1, 25):
    names = [f"n{j}" for j in range(k)]
    for close in (False, True):
        for _ in range(4):
            es = [(names[j], names[j - 1] if j > 0 else (names[-1] if close else "")) for j in range(k)]
            rng.shuffle(es)
            enc = ";".join(f"{i}>{p}" for i, p in es)
            out.append(f"{enc}|{names[-1]}|0")
            out.append(f"{enc}|{names[k // 2]}|0")
sys.stdout.write("\n".join(out) + "\n")
