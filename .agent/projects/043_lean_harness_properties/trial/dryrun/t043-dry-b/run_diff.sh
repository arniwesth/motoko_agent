#!/usr/bin/env bash
# Differential test for ../T0Model.lean, adapted from the project's evidence/diff/run_diff.sh.
# Same three halves, same 16,105 histories (length 0..4, eleven-message alphabet):
#   model (lean) vs real updatePending (bun); bounded check on the model; model fold vs real
#   fold_journal (ailang) and real host vs real fold (compare_fold.awk).
#   run_diff.sh <scratch dir>     exit 0: no mismatch; 1: mismatch; 2: a half could not run
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo=/home/motoko/trial-043/s/t043-dry-b/tree
export PATH="$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin:$PATH"
scratch="${1:-$(mktemp -d)}"; mkdir -p "$scratch"
bun "$here/enumerate.ts" "$repo" "$scratch" > "$scratch/ts.out"
echo "ts: $(wc -l < "$scratch/ts.out") histories, sha256 $(sha256sum "$scratch/ts.out" | cut -c1-16)"
cat "$here/../T0Model.lean" "$here/enumerate.lean.tail" > "$scratch/Enumerate.lean"
lean "$scratch/Enumerate.lean" > "$scratch/lean.raw"
grep -E '^[0-9,]*\|' "$scratch/lean.raw" > "$scratch/lean.out"
cut -d'|' -f1,2 "$scratch/lean.out" > "$scratch/lean.cmp"
if ! diff -u "$scratch/ts.out" "$scratch/lean.cmp" > "$scratch/diff.txt"; then
  echo "differential: MISMATCH ($(grep -c '^[-+][0-9,]*|' "$scratch/diff.txt") lines differ)"; head -20 "$scratch/diff.txt"; exit 1
fi
echo "differential: $(wc -l < "$scratch/ts.out") histories, 0 mismatches (model host vs real updatePending)"
awk -F'|' '
  { hyp_ok = ($1 !~ /(^|,)(8|10)(,|$)/) }
  $3 == "accept" && hyp_ok && $2 != $4 { bad++ }
  $3 == "accept" && !hyp_ok && $2 != $4 { excl++ }
  $3 == "accept" && hyp_ok { n++ }
  END { printf "bounded: %d accepted within H1/H2, %d disagree; %d outside disagree\n", n, bad+0, excl+0; exit (bad > 0) }' "$scratch/lean.out"
( cd "$here/../pkg" && ailang run --relax-modules --caps IO --entry main harness/enumerate_fold.ail ) > "$scratch/ail.raw" 2> "$scratch/ail.err"
grep -E '^[0-9,]*\|' "$scratch/ail.raw" > "$scratch/ail.out" || true
echo "ail: $(wc -l < "$scratch/ail.out") histories, sha256 $(sha256sum "$scratch/ail.out" | cut -c1-16)"
[[ $(wc -l < "$scratch/ail.out") -eq 16105 ]] || { echo "fold: NOT RUN (see ail.err)"; tail -5 "$scratch/ail.err"; exit 2; }
paste -d'|' "$scratch/lean.out" "$scratch/ail.out" > "$scratch/fold.joined"
awk -f "$here/compare_fold.awk" "$scratch/fold.joined"
