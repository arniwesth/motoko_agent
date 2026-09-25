#!/usr/bin/env bash
# PLAN-001 (031) P0.2b. Runs ONLY the ADR-001 boundary section of
# scripts/dst/run_declared_vs_performed.sh (P0.2's rows plus P0.2b's
# RECONSTRUCTED rows), sliced out of the committed script by its own marker
# comments, so this runs the committed code and not a copy of it.
#
# WHY THIS EXISTS. `make declared_vs_performed` has been red since P0.4 put the
# ABI at 8.0, measured at ab1616b2, 857f778a and 0d085722: five producer-1/2
# failures on compose's slots and BudgetShaper's payload row. The script runs
# under `set -euo pipefail` and aborts inside producer 2, BEFORE the P0.2
# section is reached. The whole-suite count cannot score P0.2b until that is
# repaired, and the repair is outside P0.2b's scope. See evidence/P0.2b/README.md.
#
# Usage (from anywhere): bash <this file>    exit 0 iff every row in the section passes
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
SRC=scripts/dst/run_declared_vs_performed.sh
start=$(grep -n '^# PLAN-001 (031) §2 P0.2, ADR-001 (031) freeze evidence' "$SRC" | cut -d: -f1)
end=$(grep -n '^# THE FOURTH LIMITATION PROBE' "$SRC" | cut -d: -f1)
[ -n "$start" ] && [ -n "$end" ] || { echo "section markers not found in $SRC" >&2; exit 2; }
pass=0
fail=0
ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
eval "$(sed -n "${start},$((end - 1))p" "$SRC")"
echo ""
echo "ADR-001 section of $SRC (lines $start-$((end - 1))): $pass passed, $fail failed"
[ "$fail" -eq 0 ]
