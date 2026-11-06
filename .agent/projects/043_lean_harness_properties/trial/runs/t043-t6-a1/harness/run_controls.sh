#!/usr/bin/env bash
# run_controls.sh [results dir]   (from the tree root; after run_survey.sh has written chars_6.cases)
#
# Negative controls: the same checks must PASS on corrected code, so a violation they report
# is the code's and not the checker's.
#   1. T6_MUTANT=bytegate: the AILANG shim with `Str.length(s)` -> `length(b)`. P6.1 should hold.
#   2. T6_MUTANT=fixed: bytegate plus a cut that backs off to a character boundary. P6.1, P6.2
#      and P6.3 should all hold.
#   3. controls/make_fixed_twins.ts: the TS twins with the same back-off. X-4, X-2 should hold.
#   4. repro.sh A1-T6-1 and A1-T6-2 under T6_MUTANT=fixed, and the TS repros' checks against the
#      fixed twins, should exit 0.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
res="${1:-$here/../results}"
work="$(mktemp -d)"
tree="$(pwd)"
for m in bytegate fixed; do
  T6_MUTANT=$m bash "$here/direct/run_direct.sh" "$res/chars_6.cases" "$work/$m" > "$res/mutant_${m}_chars_6.direct"
  bun "$here/check.ts" "$tree" "$res/chars_6.cases" --direct "$res/mutant_${m}_chars_6.direct" | tee "$res/mutant_${m}_chars_6.report"
done
bun "$here/controls/make_fixed_twins.ts" "$tree" "$work/fixedtree"
bun "$here/check.ts" "$work/fixedtree" "$res/chars_6.cases" --twins --runclaimcheck | tee "$res/fixed_twins_chars_6.report"
for id in A1-T6-1 A1-T6-2; do
  set +e; T6_MUTANT=fixed bash "$here/../repro/repro.sh" "$id" > /dev/null 2>&1; rc=$?; set -e
  echo "control: repro.sh $id under T6_MUTANT=fixed exits $rc (expected 0)"
done
echo "195,169|1" > "$work/w.cases"
set +e
bun "$here/check.ts" "$work/fixedtree" "$work/w.cases" --twins --runclaimcheck \
  --fail-on tsclaim:X-4,tsrun:X-4,tsenv:X-4,tsclaim:X-2,tsrun:X-2 > /dev/null; rc=$?
set -e
echo "control: the A1-T6-3/4/5 witness against the fixed TS twins exits $rc (expected 0)"
