#!/usr/bin/env bash
# Differential test for ../HerdrFailureModel.lean (target T2).
#
# Three halves over the same 8,328 cases (gen_corpus.py): the model (Lean), the REAL
# `herdrFailureCode`/`herdrMeansAgentGone` (bun), and the REAL `failure_code`/
# `means_agent_gone` (ailang). Compares:
#
#   1. model TS side   against the real TS functions     (fields: code, gone)
#   2. model AIL side  against the real AILANG functions (fields: code, gone)
#   3. the real TS against the real AILANG directly: P2.1 (gone) and P2.2 (code). These are
#      the properties, not the model check; they are counted and listed, not failed.
#
#   run_diff.sh [scratch dir]   needs lean 4.28.0, bun and ailang v0.54.14; run from anywhere.
#
# Exit 0 only when both model comparisons find 0 mismatches.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="${REPO:-$(cd "$here/../../tree" && pwd)}"
scratch="${1:-$(mktemp -d)}"
mkdir -p "$scratch"
export PATH="$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin:$PATH"

python3 -I "$here/gen_corpus.py" "$here" >&2

bun "$here/enumerate.ts" "$repo" "$here/gen/corpus.json" > "$scratch/ts.out"
echo "ts:   $(wc -l < "$scratch/ts.out") cases, sha256 $(sha256sum "$scratch/ts.out" | cut -c1-16)"

cat "$here/../HerdrFailureModel.lean" "$here/gen/Corpus.lean" "$here/enumerate.lean.tail" > "$scratch/Enumerate.lean"
lean "$scratch/Enumerate.lean" > "$scratch/lean.raw"
grep -E '^[0-9]+\|' "$scratch/lean.raw" > "$scratch/lean.out"
echo "lean: $(wc -l < "$scratch/lean.out") cases, sha256 $(sha256sum "$scratch/lean.out" | cut -c1-16)"

( cd "$here/gen" && ailang lock >/dev/null 2>&1; cd "$repo" && ailang run --relax-modules --caps IO --entry main "$here/gen/enumerate_herdr.ail" ) \
  > "$scratch/ail.raw" 2> "$scratch/ail.err"
grep -E '^[0-9]+\|' "$scratch/ail.raw" > "$scratch/ail.out" || true
echo "ail:  $(wc -l < "$scratch/ail.out") cases, sha256 $(sha256sum "$scratch/ail.out" | cut -c1-16)"

cut -d'|' -f1-4 "$scratch/lean.out" > "$scratch/lean.ts"
cut -d'|' -f1,2,5,6 "$scratch/lean.out" > "$scratch/lean.ail"
rc=0
if diff "$scratch/ts.out" "$scratch/lean.ts" > "$scratch/diff.ts"; then
  echo "model vs real TS:     0 mismatches"
else
  echo "model vs real TS:     MISMATCH, $(grep -c '^<' "$scratch/diff.ts") cases"; head -10 "$scratch/diff.ts"; rc=1
fi
if diff "$scratch/ail.out" "$scratch/lean.ail" > "$scratch/diff.ail"; then
  echo "model vs real AILANG: 0 mismatches"
else
  echo "model vs real AILANG: MISMATCH, $(grep -c '^<' "$scratch/diff.ail") cases"; head -10 "$scratch/diff.ail"; rc=1
fi

# The properties on the real code, no model: P2.1 (gone) and P2.2 (code).
paste -d'|' "$scratch/ts.out" "$scratch/ail.out" | awk -F'|' -v corpus="$here/gen/corpus.json" '
  $1 != $5 || $2 != $6 { print "ALIGNMENT ERROR at " NR; exit 2 }
  { n++ }
  $4 != $8 { p21++; k = "P2.1 exit=" $2 " ts=" $4 " ail=" $8; c21[k]++ }
  $3 != $7 { p22++; k = "P2.2 exit=" $2 " ts=" $3 " ail=" $7; c22[k]++ }
  END {
    printf "real TS vs real AILANG over %d cases: P2.1 differs on %d, P2.2 differs on %d\n", n, p21, p22
    for (k in c21) printf "  %5d  %s\n", c21[k], k
    for (k in c22) printf "  %5d  %s\n", c22[k], k
  }' | sort -k1,1 > "$scratch/props.txt"
grep '^real' "$scratch/props.txt"; grep -c 'P2.1' "$scratch/props.txt" | xargs echo "  distinct P2.1 (exit, ts, ail) classes:"
echo "scratch: $scratch"
exit $rc
