#!/usr/bin/env bash
# run_diff.sh [scratch dir] — differential test of ../PathUpModel.lean against the REAL
# `path_up` / `find_entry` / `contains_string` of src/core/journal.ail.
#
#   1. gen_cases.py writes the shared case file (29,004 cases; deterministic).
#   2. Lean half: ../PathUpModel.lean + enumerate.lean.tail, `lean` 4.28.0 core only.
#      Everything the file prints that is not a case line is the axiom report (axioms.txt).
#   3. AILANG half: build_harness.sh copies the three real bodies verbatim out of
#      src/core/journal.ail (printing their sha256), ailang v0.54.14 runs them on the cases.
#   4. diff. Exit 0: both halves ran, 0 mismatches. Exit 1: a mismatch. Exit 2: a toolchain
#      is missing (not a pass).
#
# FIXED=1: step 8. The real side's path_up body gets the one-line fix (`then []` -> `then acc`,
# applied to the harness copy only, via build_harness.sh's MUTANT) and the Lean side runs
# `pathUpFix` instead of `pathUp`.
#
# Run from anywhere; the tree is found relative to this script (out/../tree), or $TREE.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="${TREE:-$(cd "$here/../../tree" && pwd)}"
scratch="${1:-$(mktemp -d)}"
mkdir -p "$scratch"; scratch="$(cd "$scratch" && pwd)"
LEAN="${LEAN:-$(command -v lean || echo "$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin/lean")}"
[[ -x "$LEAN" ]] || { echo "differential: NOT RUN -- no lean"; exit 2; }
command -v ailang >/dev/null || { echo "differential: NOT RUN -- no ailang"; exit 2; }

python3 "$here/gen_cases.py" > "$scratch/cases.txt"
echo "cases: $(wc -l < "$scratch/cases.txt"), sha256 $(sha256sum "$scratch/cases.txt" | cut -c1-16)"

fn=pathUp
if [[ "${FIXED:-}" == 1 ]]; then
  fn=pathUpFix
  export MUTANT='path_up:s/contains_string(seen, id) then \[\]/contains_string(seen, id) then acc/'
  echo "FIXED: real path_up with the fix, model pathUpFix"
fi
sed -e "s#CASES_PATH#$scratch/cases.txt#" -e "s#let r := pathUp es start#let r := $fn es start#" "$here/enumerate.lean.tail" | cat "$here/../PathUpModel.lean" - > "$scratch/Enumerate.lean"
"$LEAN" "$scratch/Enumerate.lean" > "$scratch/lean.raw" 2>&1 || { echo "lean: FAILED"; head -30 "$scratch/lean.raw"; exit 1; }
grep -F '|' "$scratch/lean.raw" > "$scratch/lean.out" || true
grep -vF '|' "$scratch/lean.raw" > "$scratch/axioms.txt" || true
echo "lean: $(wc -l < "$scratch/lean.out") lines, sha256 $(sha256sum "$scratch/lean.out" | cut -c1-16)"

"$here/build_harness.sh" "$tree" "$scratch/cases.txt" "$scratch/harness_path_up.ail" 2> "$scratch/bodies.txt"
cat "$scratch/bodies.txt"
( cd "$tree" && ailang run --relax-modules --package-dir . --caps IO,FS --entry main \
    "$scratch/harness_path_up.ail" ) > "$scratch/ail.raw" 2> "$scratch/ail.err"
grep -F '|' "$scratch/ail.raw" > "$scratch/ail.out" || true
echo "ail: $(wc -l < "$scratch/ail.out") lines, sha256 $(sha256sum "$scratch/ail.out" | cut -c1-16)"

if ! diff "$scratch/ail.out" "$scratch/lean.out" > "$scratch/diff.txt"; then
  echo "differential: MISMATCH, $(grep -c '^<' "$scratch/diff.txt") real lines differ from the model"
  head -20 "$scratch/diff.txt"
  exit 1
fi
echo "differential: $(wc -l < "$scratch/ail.out") cases, 0 mismatches"
echo "registered properties on the REAL output (variant 0, the call site):"
python3 "$here/check_props.py" "$scratch/ail.out"
echo "axiom report: $scratch/axioms.txt"
