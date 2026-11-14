#!/usr/bin/env python3
"""show.py <scratch>: the model-vs-AILANG mismatches, one per stderr index, with the stderr."""
import json, sys, collections
import os; here = os.path.dirname(os.path.abspath(sys.argv[0]))
cs = json.load(open(here + "/gen/corpus.json"))["stderr"]
ail = {tuple(l.split("|")[:2]): l.rstrip("\n").split("|") for l in open(sys.argv[1] + "/ail.out")}
lean = {tuple(l.split("|")[:2]): l.rstrip("\n").split("|") for l in open(sys.argv[1] + "/lean.out")}
by = collections.defaultdict(list)
for k, a in ail.items():
    m = lean[k]
    if (a[2], a[3]) != (m[4], m[5]):
        by[int(k[0])].append((k[1], a[2], a[3], m[4], m[5]))
for i in sorted(by):
    print(i, json.dumps(cs[i]), by[i][0], "x%d" % len(by[i]))
