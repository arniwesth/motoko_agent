#!/usr/bin/env bash
# Differential test for ../T6Model.lean against the REAL `truncate_utf8_by_bytes`
# (packages/motoko-ext-compose/store.ail).
#
#   run_diff.sh [--mutant SED_EXPR] [scratch dir]     run from anywhere; needs lean 4.28.0
#                                                     (elan toolchain) and ailang v0.54.14
#   env T6_TREE (tree root), T6_MODEL (model file), T6_LEAN_FN (model function) override the
#   defaults; fix_diff.sh uses them to compare the fixed model with a fixed scratch copy.
#
# The real function is private to store.ail (no `export`), so it cannot be imported. The
# AILANG half is therefore assembled at run time: store.ail's own `import std/...` lines, then
# the function's text cut verbatim from store.ail (from `func truncate_utf8_by_bytes(` to the
# first `}` in column 0), then driver_body.ail.part. Nothing in the tree is written.
#
# --mutant applies a sed expression to the CUT COPY only (negative control: the test must
# see a one-token change in the real function). The tree is never modified.
#
# Exit 0: both halves ran, 0 mismatches. Exit 1: mismatch. Exit 2: a toolchain is missing.
set -euo pipefail

mutant=""
if [[ "${1:-}" == "--mutant" ]]; then mutant="$2"; shift 2; fi

here="$(cd "$(dirname "$0")" && pwd)"
tree="${T6_TREE:-/home/motoko/trial-043/s/t043-t6-b1/tree}"
src="$tree/packages/motoko-ext-compose/store.ail"
scratch="${1:-$(mktemp -d)}"
mkdir -p "$scratch"

export PATH="$HOME/.elan/bin:$PATH"
command -v lean >/dev/null || { echo "differential: NOT RUN -- no lean"; exit 2; }
command -v ailang >/dev/null || { echo "differential: NOT RUN -- no ailang"; exit 2; }
LEAN=(lean +leanprover/lean4:v4.28.0)

python3 "$here/gen_cases.py" > "$scratch/cases.txt"
echo "cases: $(wc -l < "$scratch/cases.txt"), sha256 $(sha256sum "$scratch/cases.txt" | cut -c1-16)"

# --- AILANG half: the real function, cut from the source.
# (A helper `rune_cut` placed just above it, as in the K2 fix tried on a scratch copy, is cut
# with it; the snapshot has none, so for the snapshot this is exactly the one function.)
awk '/^func (rune_cut|truncate_utf8_by_bytes)\(/{p=1} p{print} /^func truncate_utf8_by_bytes\(/{t=1} p&&t&&/^}/{exit}' "$src" > "$scratch/fn.ail"
[[ -s "$scratch/fn.ail" ]] || { echo "could not cut the function from $src"; exit 2; }
echo "real function: $(wc -l < "$scratch/fn.ail") lines, sha256 $(sha256sum "$scratch/fn.ail" | cut -c1-16)"
if [[ -n "$mutant" ]]; then
  sed -i -e "$mutant" "$scratch/fn.ail"
  echo "MUTANT applied to the cut copy: $mutant"
fi
{
  echo "module t6_driver"
  grep -E '^import std/' "$src"
  cat "$here/driver_imports.ail.part"
  echo
  cat "$scratch/fn.ail"
  echo
  cat "$here/driver_body.ail.part"
} > "$scratch/t6_driver.ail"
( cd "$scratch" && T6_CASES="$scratch/cases.txt" ailang run --relax-modules --caps IO,FS,Env \
    --entry main t6_driver.ail ) > "$scratch/ail.raw" 2> "$scratch/ail.err"
grep -E '^[0-9]+\|' "$scratch/ail.raw" > "$scratch/ail.out" || true
echo "ail:  $(wc -l < "$scratch/ail.out") lines, sha256 $(sha256sum "$scratch/ail.out" | cut -c1-16)"

# --- Lean half: the model.
# T6_MODEL / T6_LEAN_FN: run another model file / another model function (fix variants, controls).
cat "${T6_MODEL:-$here/../T6Model.lean}" > "$scratch/Diff.lean"
sed "s/(T6.truncate s m)/(${T6_LEAN_FN:-T6.truncate} s m)/" "$here/enumerate.lean.tail" >> "$scratch/Diff.lean"
"${LEAN[@]}" "$scratch/Diff.lean" > "$scratch/axioms.txt" 2>&1 || { echo "lean: model does not check"; cat "$scratch/axioms.txt"; exit 2; }
"${LEAN[@]}" --run "$scratch/Diff.lean" "$scratch/cases.txt" > "$scratch/lean.raw"
grep -E '^[0-9]+\|' "$scratch/lean.raw" > "$scratch/lean.out" || true
echo "lean: $(wc -l < "$scratch/lean.out") lines, sha256 $(sha256sum "$scratch/lean.out" | cut -c1-16)"

if ! diff "$scratch/ail.out" "$scratch/lean.out" > "$scratch/diff.txt"; then
  echo "differential: MISMATCH ($(grep -c '^<' "$scratch/diff.txt") cases differ)"
  head -20 "$scratch/diff.txt"
  exit 1
fi
[[ -s "$scratch/ail.out" ]] || { echo "differential: no output"; exit 2; }
echo "differential: $(wc -l < "$scratch/ail.out") cases, 0 mismatches"

# Per-field summary of what the cases exercised (on the real outputs).
awk -F'|' '
  { nin = ($2 == "") ? 0 : split($2, a, ","); nout = ($4 == "") ? 0 : split($4, b, ",");
    if ($3 + 0 < nin) multi++ }
  END { printf "coverage: %d cases with rune count < byte count\n", multi }' "$scratch/ail.out"
echo "scratch: $scratch"
