#!/usr/bin/env python3
"""041 W5, A18: the generated programs differ only in the version, the digest and one line.

    a18_diff.py <base corpus dir> <head corpus dir>

Both directories are `.ailang/dst-corpus` after `make corpus_pr`, at the base commit and at this
item's, so the two sides are the real v5 encoder's bytes and the real v6 encoder's bytes for the
same seeds. Every artifact must exist on both sides, and must be line-for-line equal except
line 1 (the version), line 2 (the digest) and one inserted `process_limits<TAB>legacy` line.
Interactions hold the draws, so equal lines mean equal draws, salts and interactions.
"""
import pathlib, sys

base, head = map(pathlib.Path, sys.argv[1:3])
rel = lambda root: {p.relative_to(root) for p in root.rglob("*") if p.is_file()}
a, b = rel(base), rel(head)
bad = 0
if a != b:
    print("different artifact sets:", sorted(a ^ b)); bad += 1
for r in sorted(a & b):
    x = (base / r).read_text().split("\n")
    y = (head / r).read_text().split("\n")
    inserted = [l for l in y if l.startswith("process_limits\t")]
    rest = [l for l in y if not l.startswith("process_limits\t")]
    ok = (x[0] == "execution-program/5" and y[0] == "execution-program/6"
          and x[1].startswith("digest\t") and y[1].startswith("digest\t") and x[1] != y[1]
          and inserted == ["process_limits\tlegacy"] and x[2:] == rest[2:])
    print(f"{'same' if ok else 'DIFF'} {r}: {len(x)} lines at v5, {len(y)} at v6")
    bad += 0 if ok else 1
print(f"{len(a & b)} artifact(s) compared, {bad} differ beyond the version, digest and mode line")
sys.exit(1 if bad or not (a & b) else 0)
