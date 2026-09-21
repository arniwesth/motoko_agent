#!/usr/bin/env bash
# 031 PLAN-001 R-G pre-gate: run every target on R-G's checklist in the primary checkout,
# the way CI does, and record exit code + closing lines per target. Run from the repo root.
# REFUSES to run if src/, packages/, tools/ or scripts/ carry uncommitted changes: every
# result must be attributable to a commit (the HEAD recorded below).
set -uo pipefail
OUT=${1:-.agent/projects/031_system_one_decisions/evidence/R-G}
mkdir -p "$OUT/logs"
dirty=$(git status --porcelain -- src packages tools scripts | grep -v -E '^\?\? (scripts/dst/mem_(canonical_bench|growth_probe)\.ail|src/eval/journal/testdata/MATRIX\.tsv)$' || true)
if [ -n "$dirty" ]; then echo "pregate: REFUSED — uncommitted changes under src/ packages/ tools/ scripts/:"; echo "$dirty"; exit 2; fi
HEAD=$(git rev-parse --short HEAD)
TARGETS="check_core test test_integration conformance declared_vs_performed ext_hook_scope ext_hook_scope_selftest profile_definition driver_only profile_coverage driver_plus_no_ops registry_gen_check anchors driver_leaf_inventory event_vocabulary"
S="$OUT/SUMMARY.tsv"; printf 'target\texit\tseconds\tlast_line\n' > "$S"
echo "pregate at $HEAD, $(date -u +%FT%TZ)"
for t in $TARGETS; do
  st=$(date +%s); make "$t" > "$OUT/logs/$t.log" 2>&1; rc=$?; el=$(( $(date +%s) - st ))
  last=$(grep -v '^\s*$' "$OUT/logs/$t.log" | tail -1 | cut -c1-160 | tr '\t' ' ')
  printf '%s\t%s\t%s\t%s\n' "$t" "$rc" "$el" "$last" >> "$S"
  printf '  %-26s exit %-3s %5ss  %s\n' "$t" "$rc" "$el" "$last"
done
st=$(date +%s); ( cd src/tui && bun run test ) > "$OUT/logs/tui_bun_test.log" 2>&1; rc=$?; el=$(( $(date +%s) - st ))
last=$(grep -v '^\s*$' "$OUT/logs/tui_bun_test.log" | tail -1 | cut -c1-160 | tr '\t' ' ')
printf 'tui_bun_test\t%s\t%s\t%s\n' "$rc" "$el" "$last" >> "$S"; printf '  %-26s exit %-3s %5ss  %s\n' tui_bun_test "$rc" "$el" "$last"
red=$(awk -F'\t' 'NR>1 && $2!=0' "$S" | wc -l)
echo "pregate at $HEAD: $red red of $(( $(wc -l < "$S") - 1 ))"
[ "$red" -eq 0 ]
