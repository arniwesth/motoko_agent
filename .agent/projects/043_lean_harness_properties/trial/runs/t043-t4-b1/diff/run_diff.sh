#!/usr/bin/env bash
# Differential test for ../ChainModel.lean against the REAL chain functions of
# src/core/journal.ail (step (2) of the method).
#
#   run_diff.sh [SEED] [N] [SCRATCH]      from anywhere; defaults: SEED=1 N=300, scratch out/diff/runs/seed<SEED>-n<N>
#
# gen_cases.py draws N cases from SEED and writes them twice: cases.ail (the real code, run
# with `ailang run` from the tree root) and Cases.lean.tail (the model, with a real SHA-256
# in Sha256.lean.tail standing in for std/crypto `sha256Hex`). The two outputs are diffed
# line for line. Exit 0 only when both halves ran and agree on every line; 1 on a mismatch;
# 2 when a half could not run; 3 when MUTANT=fixed mismatches outside the predicted set.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
tree="${TREE:-$(cd "$out/../tree" && pwd)}"
seed="${1:-1}"
n="${2:-300}"
scratch="${3:-$out/diff/runs/seed$seed-n$n${MUTANT:+-$MUTANT}}"
mkdir -p "$scratch"
LEAN="${LEAN:-$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin/lean}"
command -v "$LEAN" >/dev/null || { echo "differential: NOT RUN -- no lean"; exit 2; }
command -v ailang >/dev/null || { echo "differential: NOT RUN -- no ailang"; exit 2; }

python3 -I "$here/gen_cases.py" "$seed" "$n" "$scratch"

# MUTANT=fixed runs the negative control: the model's `chainDigestsOver` is swapped for the
# fixed `chainDigestsOverFixed` (which reads `base`). The test must then FAIL, in exactly the
# cases whose base is not chain_empty_base() and whose list is non-empty.
if [[ "${MUTANT:-}" == "fixed" ]]; then
  sed -i 's/chainDigestsOver sha256Hex/chainDigestsOverFixed sha256Hex/' "$scratch/Cases.lean.tail"
fi
cat "$out/ChainModel.lean" "$here/Sha256.lean.tail" "$scratch/Cases.lean.tail" > "$scratch/Enumerate.lean"
"$LEAN" "$scratch/Enumerate.lean" > "$scratch/lean.raw" 2> "$scratch/lean.err" || {
  echo "lean half FAILED"; head -20 "$scratch/lean.raw" "$scratch/lean.err"; exit 2; }
grep -q '^#sha256-selftest ok' "$scratch/lean.raw" || { echo "sha256 self-test failed"; exit 2; }
grep -E '^(E|[0-9]+)\|' "$scratch/lean.raw" > "$scratch/lean.out"
grep -E "depends on axioms|does not depend on any axioms" "$scratch/lean.raw" > "$scratch/axioms.txt" || true

# ailang resolves `src/...` and `pkg/...` from the ailang.toml above the ENTRY FILE, so the
# entry goes in a mirror of the tree's package root made of symlinks; the tree is not written.
mirror="$scratch/mirror"
mkdir -p "$mirror"
for f in ailang.toml ailang.lock src packages; do ln -sfn "$tree/$f" "$mirror/$f"; done
cp "$scratch/cases.ail" "$mirror/cases.ail"
( cd "$mirror" && ailang run --relax-modules --caps IO --entry main cases.ail ) \
  > "$scratch/ail.raw" 2> "$scratch/ail.err" || {
  echo "ailang half FAILED"; head -30 "$scratch/ail.err"; exit 2; }
grep -E '^(E|[0-9]+)\|' "$scratch/ail.raw" > "$scratch/ail.out"

echo "lean: $(wc -l < "$scratch/lean.out") lines; ail: $(wc -l < "$scratch/ail.out") lines (seed $seed, $n cases)"
if ! diff "$scratch/ail.out" "$scratch/lean.out" > "$scratch/diff.txt"; then
  echo "differential: MISMATCH ($(grep -c '^<' "$scratch/diff.txt") real-code lines differ); see $scratch/diff.txt"
  head -6 "$scratch/diff.txt" | cut -c1-160
  if [[ "${MUTANT:-}" == "fixed" ]]; then
    # Predicted: base kind B or L (a literal never equals chain_empty_base()) and len > 0.
    awk -F'\t' 'NR > 1 && $2 != "E" && $4 > 0 { print $1 }' "$scratch/cases.tsv" | sort -n > "$scratch/predicted.txt"
    grep -E '^[<>] [0-9]+\|' "$scratch/diff.txt" | sed -E 's/^[<>] ([0-9]+)\|.*/\1/' | sort -nu > "$scratch/mismatched.txt"
    if cmp -s "$scratch/predicted.txt" "$scratch/mismatched.txt"; then
      echo "negative control: $(wc -l < "$scratch/mismatched.txt") cases mismatch, exactly the predicted set (base != chain_empty_base(), ms != [])"
    else
      echo "negative control: mismatching cases differ from the predicted set"; exit 3
    fi
  fi
  exit 1
fi
echo "differential: $(wc -l < "$scratch/ail.out") lines, 0 mismatches; scratch $scratch"
