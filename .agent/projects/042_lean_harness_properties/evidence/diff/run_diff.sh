#!/usr/bin/env bash
# Differential test for ../PairingModel.lean (RESEARCH-lean-harness-properties.md §6).
#
# Runs the model's `hostPending` and the REAL `SessionJournal.updatePending` over every
# history of length 0..4 in the eleven-message alphabet of enumerate.*, and compares them.
# Then a bounded check on the model alone: for every history the model's pairing check
# accepts and that satisfies (H1) and (H2), host pending equals fold open ids. Histories
# that violate (H1) or (H2) and still disagree are listed, not failed: they are the cases
# the theorem's hypotheses exist to exclude.
#
#   run_diff.sh [scratch dir]          needs `lean` (4.28.0, core only) and `bun` on PATH
#   run_diff.sh --ts-only [scratch]    the bun half alone, when no Lean toolchain is present
#
# Exit 0 only when the full comparison ran and found no mismatch. --ts-only exits 2: it
# is not a pass, it is the half that could run.
set -euo pipefail

ts_only=0
if [[ "${1:-}" == "--ts-only" ]]; then ts_only=1; shift; fi

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../../../.." && pwd)"
scratch="${1:-$(mktemp -d)}"
mkdir -p "$scratch"

bun "$here/enumerate.ts" "$repo" "$scratch" > "$scratch/ts.out"
echo "ts: $(wc -l < "$scratch/ts.out") histories, sha256 $(sha256sum "$scratch/ts.out" | cut -c1-16)"

if [[ "$ts_only" -eq 1 ]]; then
  echo "differential: NOT RUN (--ts-only); the Lean half needs a toolchain"
  exit 2
fi

command -v lean >/dev/null || { echo "differential: NOT RUN -- no lean on PATH"; exit 2; }

cat "$here/../PairingModel.lean" "$here/enumerate.lean.tail" > "$scratch/Enumerate.lean"
lean "$scratch/Enumerate.lean" > "$scratch/lean.raw"
# The #eval lines start with the history's indices and a `|`; everything else on stdout is
# the axiom report, kept for the audit.
grep -E '^[0-9,]*\|' "$scratch/lean.raw" > "$scratch/lean.out"
grep -vE '^[0-9,]*\|' "$scratch/lean.raw" > "$scratch/axioms.txt" || true
cut -d'|' -f1,2 "$scratch/lean.out" > "$scratch/lean.cmp"

if ! diff -u "$scratch/ts.out" "$scratch/lean.cmp" > "$scratch/diff.txt"; then
  echo "differential: MISMATCH ($(grep -c '^[-+][0-9,]*|' "$scratch/diff.txt") lines differ)"
  head -20 "$scratch/diff.txt"
  exit 1
fi
echo "differential: $(wc -l < "$scratch/ts.out") histories, 0 mismatches"

# Bounded check. Message 8 violates (H2), message 10 violates (H1).
awk -F'|' '
  { hyp_ok = ($1 !~ /(^|,)(8|10)(,|$)/) }
  $3 == "accept" && hyp_ok && $2 != $4 { bad++; if (bad <= 10) print "  VIOLATION " $0 }
  $3 == "accept" && !hyp_ok && $2 != $4 { excl++; if (excl <= 10) print "  outside H1/H2: " $0 }
  $3 == "accept" && hyp_ok { n++ }
  END {
    printf "bounded: %d accepted histories within H1/H2, %d disagree; %d outside H1/H2 disagree\n", n, bad + 0, excl + 0
    exit (bad > 0)
  }' "$scratch/lean.out"
echo "axiom report: $scratch/axioms.txt"
