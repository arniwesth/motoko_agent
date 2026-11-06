#!/usr/bin/env bash
# The Rocq port of the pairing model, run against the Lean model and the real fold
# (NOTE-001-rocq-compared-2026-11-03.md).
#
#   1. PairingModel.v is checked, and `Print Assumptions` must report all eight printed
#      theorems "Closed under the global context".
#   2. Enumerate.v is extracted to OCaml, compiled with main.ml and run: rocq.out.
#   3. rocq.out must be byte-identical to the Lean model's lean.out.
#   4. ../diff/compare_fold.awk compares rocq.out with the real fold's ail.out.
#
#   run_rocq.sh <run_diff.sh scratch dir> [rocq scratch dir]
#
# The first directory must hold lean.out and ail.out from a full run of ../diff/run_diff.sh.
# Needs `rocq` (9.3.0, with rocq-stdlib) and `ocamlopt` on PATH; README.md says how to get them
# without root. Exit 0 only when all four steps pass; a missing input or toolchain exits 2.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
diffdir="${1:?usage: run_rocq.sh <run_diff.sh scratch dir> [rocq scratch dir]}"
diffdir="$(cd "$diffdir" && pwd)"
scratch="${2:-$(mktemp -d)}"
mkdir -p "$scratch"

for f in lean.out ail.out; do
  [[ -s "$diffdir/$f" ]] || { echo "rocq: NOT RUN -- no $f in $diffdir; run ../diff/run_diff.sh first"; exit 2; }
done
for t in rocq ocamlopt; do
  command -v "$t" >/dev/null || { echo "rocq: NOT RUN -- no $t on PATH"; exit 2; }
done

cp "$here/PairingModel.v" "$here/Enumerate.v" "$here/main.ml" "$scratch/"
cd "$scratch"

rocq compile -Q . "" PairingModel.v > assumptions.txt
closed=$(grep -c 'Closed under the global context' assumptions.txt || true)
echo "kernel: PairingModel.v checks; Print Assumptions: $closed of 8 theorems closed"
[[ "$closed" -eq 8 ]] || { cat assumptions.txt; exit 1; }

# Extraction writes enum.ml and enum.mli here, and warns that it chose this directory.
rocq compile -Q . "" Enumerate.v 2> extraction.err
ocamlopt enum.mli enum.ml main.ml -o enum
./enum > rocq.out
echo "rocq: $(wc -l < rocq.out) histories, sha256 $(sha256sum rocq.out | cut -c1-16)"

if ! cmp -s rocq.out "$diffdir/lean.out"; then
  echo "rocq vs lean: MISMATCH"
  diff -u "$diffdir/lean.out" rocq.out | head -20
  exit 1
fi
echo "rocq vs lean: byte-identical to lean.out"

paste -d'|' rocq.out "$diffdir/ail.out" > fold.joined
awk -f "$here/../diff/compare_fold.awk" fold.joined
