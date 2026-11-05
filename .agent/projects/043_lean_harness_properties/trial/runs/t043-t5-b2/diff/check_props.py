#!/usr/bin/env python3
"""check_props.py <ail.out> — P5.2 and P5.3 checked directly on the REAL path_up's output
(the lines run_diff.sh collects), for the call-site variant 0 (seen=[], acc=[]).
No model involved: a bounded check of the registered properties on the code itself.
Prints counts; exit 0 always (it reports, run_diff.sh decides)."""
import sys
from collections import Counter
c = Counter()
first = {}
for line in open(sys.argv[1]):
    enc, start, v, res, n = line.rstrip("\n").split("|")
    if v != "0":
        continue
    es = [tuple(x.split(">")) for x in enc.split(";")] if enc else []
    r = [int(s) for s in res.split(",")] if res else []
    c["cases"] += 1
    ids = [es[i][0] for i in r]
    if len(set(ids)) != len(ids):
        c["P5.2 violated"] += 1
    if any(es[r[k]][1] != es[r[k - 1]][0] for k in range(1, len(r))):
        c["P5.3 chain violated"] += 1
    names = any(i == start for i, _ in es)
    if names:
        c["start names an entry"] += 1
        if not r or es[r[-1]][0] != start:
            kind = "start is \"\"" if start == "" else "parent cycle"
            key = f"P5.3 violated ({kind})"
            c[key] += 1
            first.setdefault(key, line.strip())
for k in sorted(c):
    print(f"  {k}: {c[k]}")
for k, v in first.items():
    print(f"  first {k}: {v}")
