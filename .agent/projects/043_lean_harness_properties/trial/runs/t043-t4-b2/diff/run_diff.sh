#!/usr/bin/env bash
# Differential test for ../lean/ChainModel.lean (target T4, src/core/journal.ail:242-300).
#
# Two halves over the same 1,820 lines: every message list of length 0..3 in a six-message
# alphabet, against six bases (1,554 `C` cases, plus the empty base, six single steps and
# 259 `chain_digest_base` values):
#
#   * the REAL code: enumerate_chain.ail, run by ail_run.sh against the tree's unmodified
#     src/core/journal.ail (needs `ailang` v0.54.14 on PATH);
#   * the MODEL: ChainModel.lean + FrameModel.lean + Sha256.lean + Enumerate.lean.tail
#     (needs `lean` 4.28.0).
#
# Then the NEGATIVE CONTROL: four mutants of the model, one at a time; each must produce
# mismatches, or the test could not have told a wrong model from a right one.
#
#   run_diff.sh <tree root> [scratch dir, default ../runs/diff]
#
# Exit 0: both halves ran, 0 mismatches, every mutant caught. Exit 1: a mismatch, or a mutant
# not caught. Exit 2: a toolchain is missing (not a pass).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
lean_dir="$(cd "$here/../lean" && pwd)"
tree="$(cd "${1:?usage: run_diff.sh <tree root> [scratch]}" && pwd)"
scratch="${2:-$here/../runs/diff}"
mkdir -p "$scratch"

command -v lean >/dev/null || { echo "differential: NOT RUN -- no lean on PATH"; exit 2; }
command -v ailang >/dev/null || { echo "differential: NOT RUN -- no ailang on PATH"; exit 2; }

"$here/ail_run.sh" "$tree" "$here/enumerate_chain.ail" > "$scratch/ail.raw" 2> "$scratch/ail.err"
grep -E '^[EFBC]\|' "$scratch/ail.raw" > "$scratch/ail.out"
echo "ail:  $(wc -l < "$scratch/ail.out") lines, sha256 $(sha256sum "$scratch/ail.out" | cut -c1-16)"

model() {  # model <out-file> [sed expression applied to the concatenated model]
  cat "$lean_dir/ChainModel.lean" "$lean_dir/FrameModel.lean" "$lean_dir/Sha256.lean" "$lean_dir/Enumerate.lean.tail" > "$scratch/Enumerate.lean"
  if [[ -n "${2:-}" ]]; then
    cp "$scratch/Enumerate.lean" "$scratch/Enumerate.orig"
    sed -i "$2" "$scratch/Enumerate.lean"
    if cmp -s "$scratch/Enumerate.lean" "$scratch/Enumerate.orig"; then
      echo "mutant did not apply: $2"; exit 1
    fi
  fi
  # A mutant may break a proof; its #eval output is still what we compare.
  lean "$scratch/Enumerate.lean" > "$scratch/lean.raw" 2>&1 || true
  grep -E '^[EFBC]\|' "$scratch/lean.raw" > "$1" || true
}

model "$scratch/lean.out"
grep -E "depends on axioms|does not depend on any axioms" "$scratch/lean.raw" > "$scratch/axioms.txt" || true
echo "lean: $(wc -l < "$scratch/lean.out") lines, sha256 $(sha256sum "$scratch/lean.out" | cut -c1-16)"

if ! diff -u "$scratch/ail.out" "$scratch/lean.out" > "$scratch/diff.txt"; then
  echo "differential: MISMATCH ($(grep -c '^-[EFBC]|' "$scratch/diff.txt") lines differ)"
  head -20 "$scratch/diff.txt"
  exit 1
fi
echo "differential: $(wc -l < "$scratch/ail.out") lines, 0 mismatches"

# Negative control: each mutant must disagree with the real code somewhere.
status=0
while IFS='|' read -r name expr; do
  model "$scratch/mutant.out" "$expr"
  n=$(diff "$scratch/ail.out" "$scratch/mutant.out" | grep -c '^<' || true)
  echo "mutant $name: $n of $(wc -l < "$scratch/ail.out") lines mismatch"
  [[ "$n" -gt 0 ]] || status=1
done <<'MUTANTS'
fixed-base (chain_digests_over starts from base)|s/(ms.foldl (chainPrefixStep e) { last := chainEmptyBase e, out := \[\] }).out/(ms.foldl (chainPrefixStep e) { last := _base, out := [] }).out/
frame-first (frame ++ previous)|s/"sha256:" ++ e.h (previous ++ e.frame m)/"sha256:" ++ e.h (e.frame m ++ previous)/
prepend (d :: out)|s/{ last := d, out := acc.out ++ \[d\] }/{ last := d, out := d :: acc.out }/
bytes-not-runes (frame length in UTF-8 bytes)|s/label ++ ":" ++ toString value.length/label ++ ":" ++ toString value.utf8ByteSize/
MUTANTS
echo "axiom report: $scratch/axioms.txt ($(wc -l < "$scratch/axioms.txt") theorems)"
exit $status
