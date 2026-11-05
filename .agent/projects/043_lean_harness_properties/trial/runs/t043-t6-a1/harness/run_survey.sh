#!/usr/bin/env bash
# run_survey.sh [results dir]   (from the tree root)
#
# The full survey: every generator in gen.ts at the sizes in SUMMARY.md, each through the real
# AILANG function (run_direct.sh), its real caller (run_caller.sh), and the real TS twins, all
# checked by check.ts. Writes cases, outputs and one report per generator to the results dir.
# A survey, not a repro: exits 0 unless a harness step fails.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
res="${1:-$here/../results}"
mkdir -p "$res"
work="$(mktemp -d)"
for g in "chars 6" "bytes 3" "random 20000" "random 500 7 2000" "cjk 1400"; do
  name="${g// /_}"
  bun "$here/gen.ts" $g > "$res/$name.cases"
  bash "$here/direct/run_direct.sh" "$res/$name.cases" "$work/$name" > "$res/$name.direct"
  bash "$here/caller/run_caller.sh" "$res/$name.cases" "$work/$name" > "$res/$name.caller"
  bun "$here/check.ts" "$(pwd)" "$res/$name.cases" --direct "$res/$name.direct" --caller "$res/$name.caller" --twins --runclaimcheck \
    | tee "$res/$name.report"
  echo
done
