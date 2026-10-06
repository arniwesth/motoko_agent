#!/usr/bin/env python3
"""SPIKE ONLY — part 4 scorer. Reuses part 2's tested parser and comparison; the row's second
slot carries X, the probe-side prototype rules. Never merges."""
import importlib.util, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("score2", os.path.join(HERE, "score2.py"))
s2 = importlib.util.module_from_spec(spec); spec.loader.exec_module(s2)
s2.OUT = os.path.join(HERE, "out5")
IDS = ["K0", "K1", "K2", "M1", "M2", "M3", "M3m", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M12", "T1", "T2", "T3", "R1", "R2", "R3", "R4", "R5", "R6"]
preds = {}
for line in open(os.path.join(HERE, "predictions5.tsv"), encoding="utf-8"):
    if line.startswith("#") or not line.strip(): continue
    f = line.rstrip("\n").split("\t"); preds[f[0]] = (f[1], f[2])
ok, why, base = s2.parse(os.path.join(s2.OUT, "baseline"))
if not ok: sys.exit("baseline unusable: " + why)
if any(v[2] or v[3] for v in base.values()): sys.exit("baseline is not clean under the prototype")
print("id\tA\tX\tpredicted\tmatch\tA: new rules on members\tX: new rules on members")
right = 0; n = 0
for mid in IDS:
    if not os.path.isdir(os.path.join(s2.OUT, mid)): continue
    r = s2.score(mid, base); n += 1
    p = preds.get(mid, ("?", "?")); m = (r["verdict_a"], r["verdict_b"]) == p; right += m
    def show(pairs):
        rules = sorted({x for _, x in pairs}); mem = sorted({x for x, _ in pairs})
        return (", ".join(rules) + " on " + str(len(mem)) + " member(s)") if rules else (r["why"] or "-")
    print("\t".join([mid, r["verdict_a"], r["verdict_b"], p[0] + "/" + p[1], "yes" if m else "NO", show(r["a"]), show(r["b"])]))
print(f"\nrows={n} predictions right (both columns): {right}/{n}")
