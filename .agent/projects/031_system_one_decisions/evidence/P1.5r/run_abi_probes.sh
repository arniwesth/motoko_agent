#!/usr/bin/env bash
# PLAN-001 (031) P1.5r. Runs ONLY the two ABI text probes of
# scripts/dst/run_declared_vs_performed.sh — BudgetShaper's payload row (was
# `:124`) and Compactor's slot row (was `:707`) — sliced out of the committed
# script by their `>>> P1.5r probe:` / `<<< P1.5r probe:` marker comments, so
# this runs the committed code and not a copy of it.
#
# WHY THIS EXISTS. `make declared_vs_performed` aborts under `set -e` in
# producer 1/2 on the four `compose_*` rows (the 7.4 compose extension against
# the 8.0 ABI, P1.2d's) before it is scoreable as a whole. Pure grep over
# packages/motoko-ext-abi/types.ail: nothing here compiles AILANG, so the
# `ailang.lock` path-dependency trap does not apply.
#
# Usage (from anywhere): bash <this file>    exit 0 iff both probes are `ok`
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
SRC=scripts/dst/run_declared_vs_performed.sh
ABI=packages/motoko-ext-abi/types.ail
pass=0
fail=0
ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
for probe in "BudgetShaper payload row" "Compactor slot row"; do
  start=$(grep -n "^# >>> P1.5r probe: $probe\$" "$SRC" | cut -d: -f1)
  end=$(grep -n "^# <<< P1.5r probe: $probe\$" "$SRC" | cut -d: -f1)
  [ -n "$start" ] && [ -n "$end" ] || { echo "markers for '$probe' not found in $SRC" >&2; exit 2; }
  echo "-- $probe ($SRC:$start-$end) --"
  eval "$(sed -n "${start},${end}p" "$SRC")"
done
echo ""
echo "P1.5r ABI text probes: $pass passed, $fail failed"
[ "$pass" -eq 2 ] && [ "$fail" -eq 0 ]
