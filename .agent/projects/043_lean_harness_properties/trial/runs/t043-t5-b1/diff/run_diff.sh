#!/usr/bin/env bash
# Differential test for ../PathUpModel.lean (target T5: `find_entry` and `path_up`,
# src/core/journal.ail:1392-1410).
#
# Two halves over the same 50,704 inputs (enumerate_pathup.ail's header lists them): the
# model's `pathUp` (Lean) and the REAL `path_up` (ailang), reached through the export-only
# shim root that make_root.sh builds outside the tree. One line per input; `diff` compares.
#
#   run_diff.sh [scratch]                  model `pathUp` against the real `path_up`
#   run_diff.sh --mutant NAME [scratch]    negative control: plant mutant NAME (make_root.sh)
#                                          in the shim, and count the mismatches against the
#                                          model. For NAME=fix, also compare the mutant with
#                                          the model's `pathUpFixed`, which must agree.
#
# Needs `lean` 4.28.0 (elan toolchain leanprover/lean4:v4.28.0) and `ailang` v0.54.14. About
# 1 min for ailang and 40 s for Lean. Exit 0 only when both halves ran and found no mismatch
# (with --mutant: when the mutant was SEEN, i.e. mismatches > 0, and, for fix, the fixed model
# agreed). A missing toolchain exits 2.
set -euo pipefail
mutant=""
if [[ "${1:-}" == "--mutant" ]]; then mutant="$2"; shift 2; fi
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
tree="${TREE:-$(cd "$out/../tree" && pwd)}"
scratch="${1:-$(mktemp -d)}"; mkdir -p "$scratch"
LEAN="${LEAN:-$HOME/.elan/bin/lean +leanprover/lean4:v4.28.0}"
command -v ailang >/dev/null || { echo "NOT RUN -- no ailang on PATH"; exit 2; }
$LEAN --version >/dev/null 2>&1 || { echo "NOT RUN -- no lean 4.28.0"; exit 2; }

# The Lean half (cached per scratch dir; the model does not depend on the mutant).
if [[ ! -s "$scratch/lean.out" ]]; then
  cat "$out/PathUpModel.lean" "$here/enumerate.lean.tail" > "$scratch/Enumerate.lean"
  $LEAN "$scratch/Enumerate.lean" > "$scratch/lean.raw" 2>&1
  grep -E '^[BRX]\|' "$scratch/lean.raw" > "$scratch/lean.out"
  grep -E "depends on axioms|does not depend" "$scratch/lean.raw" > "$scratch/axioms.txt" || true
  if grep -q "error" "$scratch/lean.raw"; then echo "lean: ERROR"; grep error "$scratch/lean.raw" | head; exit 1; fi
fi
echo "lean: $(wc -l < "$scratch/lean.out") lines, sha256 $(sha256sum "$scratch/lean.out" | cut -c1-16)"

# The AILANG half.
tag="${mutant:-real}"
root="$scratch/root_$tag"
bash "$here/make_root.sh" "$tree" "$root" shim $mutant
cp "$here/enumerate_pathup.ail" "$root/"
( cd "$root" && ailang run --relax-modules --caps IO --entry main enumerate_pathup.ail ) \
  > "$scratch/ail_$tag.raw" 2> "$scratch/ail_$tag.err" || { echo "ailang: FAILED"; grep -v '^Warning\|^Run ' "$scratch/ail_$tag.err" | head; exit 1; }
grep -E '^[BRX]\|' "$scratch/ail_$tag.raw" > "$scratch/ail_$tag.out" || true
echo "ail ($tag): $(wc -l < "$scratch/ail_$tag.out") lines, sha256 $(sha256sum "$scratch/ail_$tag.out" | cut -c1-16)"

n=$(diff "$scratch/lean.out" "$scratch/ail_$tag.out" | grep -c '^<' || true)
m=$(diff "$scratch/lean.out" "$scratch/ail_$tag.out" | grep -c '^>' || true)
diff "$scratch/lean.out" "$scratch/ail_$tag.out" > "$scratch/diff_$tag.txt" || true
if [[ -z "$mutant" ]]; then
  if [[ "$n" -ne 0 || "$m" -ne 0 || ! -s "$scratch/lean.out" ]]; then
    echo "differential: MISMATCH ($n model lines, $m real lines differ)"; head -20 "$scratch/diff_$tag.txt"; exit 1
  fi
  echo "differential: $(wc -l < "$scratch/lean.out") inputs, 0 mismatches"
  echo "axiom report: $scratch/axioms.txt"
  exit 0
fi

echo "negative control ($mutant): $n of $(wc -l < "$scratch/lean.out") lines differ from the model"
status=0
[[ "$n" -gt 0 ]] || { echo "  NOT SEEN: the test cannot tell this mutant from the real code"; status=1; }
if [[ "$mutant" == fix ]]; then
  sed 's/let r := pathUp es /let r := pathUpFixed es /; s/let r := pathUp (ring/let r := pathUpFixed (ring/; s/let r := pathUp es start/let r := pathUpFixed es start/' \
    "$here/enumerate.lean.tail" > "$scratch/enumerate_fixed.tail"
  grep -q pathUpFixed "$scratch/enumerate_fixed.tail"
  cat "$out/PathUpModel.lean" "$scratch/enumerate_fixed.tail" > "$scratch/EnumerateFixed.lean"
  $LEAN "$scratch/EnumerateFixed.lean" 2>&1 | grep -E '^[BRX]\|' > "$scratch/lean_fixed.out"
  f=$(diff "$scratch/lean_fixed.out" "$scratch/ail_fix.out" | grep -c '^<' || true)
  echo "  fixed model pathUpFixed against the fix mutant: $f mismatches over $(wc -l < "$scratch/lean_fixed.out") lines"
  [[ "$f" -eq 0 ]] || status=1
fi
exit $status
