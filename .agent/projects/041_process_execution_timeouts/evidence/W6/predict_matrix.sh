#!/usr/bin/env bash
# 041 W6: predict which rows of `make eval_matrix` move, BEFORE that target runs, by the pattern of
# 034's evidence/W1.1/predict_matrix.sh.
#
#   predict_matrix.sh <base> <head> <out-dir>
#
# Clones the repository at each commit, runs scripts/eval/test_candidate.py in both with
# EVAL_CANDIDATE_LIVE=0 and EVAL_MATRIX_OBS set, and prints every test whose observed (verdict,
# first finding, position) differs, with the MATRIX.expected.tsv rows it feeds. Unlike 034's it
# needs no simulated widening, because this item's source already exists. Live rows are skipped by
# EVAL_CANDIDATE_LIVE=0, so the protected-span diff below is what speaks for them.
set -euo pipefail
base=$1; head=$2; out=$3
here=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$here" rev-parse --show-toplevel)
mkdir -p "$out"; out=$(cd "$out" && pwd)
rm -rf "$out/base" "$out/w6"
git clone -q --no-hardlinks "$repo" "$out/base"; git -C "$out/base" checkout -q "$base"
git clone -q "$out/base" "$out/w6"; git -C "$out/w6" fetch -q "$repo" "$head"; git -C "$out/w6" checkout -q "$head"
for t in base w6; do
  (cd "$out/$t" && python3 tools/eval_protected/protected.py check --manifest tools/eval_protected/manifest-A.json --tree . --json > "$out/protected_$t.json") || true
done
python3 - "$out" <<'PY'
import json, sys
out = sys.argv[1]
def spans(t):
    d = json.load(open(f"{out}/protected_{t}.json"))
    return {(f["file"], f["symbol"]) : f["finding"] for f in d["findings"]}
b, w = spans("base"), spans("w6")
print(f"protected findings: base {len(b)}, w6 {len(w)}")
print("  new at w6:", sorted(set(w) - set(b)))
print("  gone at w6:", sorted(set(b) - set(w)))
PY
for t in base w6; do
  rm -f "$out/obs_$t.tsv"
  (cd "$out/$t" && EVAL_CANDIDATE_LIVE=0 EVAL_MATRIX_OBS="$out/obs_$t.tsv" \
     python3 -m pytest -q -p no:cacheprovider scripts/eval/test_candidate.py > "$out/pytest_$t.log" 2>&1) || true
  tail -1 "$out/pytest_$t.log"
done
python3 - "$out" "$out/base/src/eval/journal/testdata/MATRIX.expected.tsv" <<'PY'
import sys
out, expected = sys.argv[1], sys.argv[2]
def load(p):
    d = {}
    for line in open(p):
        a = line.rstrip("\n").split("\t"); d[a[0]] = tuple(a[1:3])
    return d
b, w = load(f"{out}/obs_base.tsv"), load(f"{out}/obs_w6.tsv")
rows = {}
for i, line in enumerate(open(expected), 1):
    a = line.rstrip("\n").split("\t")
    if len(a) > 3: rows.setdefault(a[1], []).append(f"{i}:{a[0]} expects {a[2]} {a[3]}")
n = 0
for k in sorted(set(b) | set(w)):
    if b.get(k) != w.get(k):
        n += 1
        print(f"{k}\n    base {b.get(k)}\n    w6   {w.get(k)}\n    rows {rows.get(k)}")
print(f"{n} test(s) differ")
PY
