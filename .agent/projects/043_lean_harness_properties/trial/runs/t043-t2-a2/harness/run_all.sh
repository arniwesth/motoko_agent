#!/usr/bin/env bash
# run_all.sh — every check in SUMMARY.md, from the tree root:
#
#   bash ../out/harness/run_all.sh
#
# Writes ../out/runs/<name>.txt per run. Case and output files are written to
# ../out/runs/<name>/ and deleted afterwards unless KEEP=1 (chunks 5 alone is ~150 MB).
# Exit 0 always: the per-run exit codes are recorded in ../out/runs/index.txt.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
runs="$out/runs"; mkdir -p "$runs"
fix_ts="$out/fixcheck/wake-waiter.fixed.ts"; fix_ail="$out/fixcheck/ail/ail_eval.ail"
: > "$runs/index.txt"
log() { echo "$1 rc=$2" | tee -a "$runs/index.txt"; }

diffrun() { # name, gen args...
  local name="$1"; shift
  SCRATCH="$runs/$name" COMPARE_FLAGS="--explain --quiet" bash "$here/run_diff.sh" "$@" > "$runs/$name.txt" 2>&1
  log "$name ($*)" $?
  [[ "${KEEP:-0}" == 1 ]] || rm -rf "$runs/$name"
}

diffrun structured structured
diffrun tokens4 tokens 4
diffrun chunks5 chunks 5
for s in 1 2 3; do diffrun "random_s$s" random 200000 "$s"; done
# The same structured set against the patched copies (fixcheck/): which causes remain.
T2_TS_MODULE="$fix_ts" T2_AIL_ENTRY="$fix_ail" diffrun fixcheck_structured structured

bun "$here/runner_signal.ts" x1 > "$runs/runner_signal.txt" 2>&1; log "runner_signal x1" $?
bun "$here/runner_signal.ts" emit > "$runs/runner_signal.cases.tsv"
( cd "$out/../tree" && ailang run --relax-modules --caps IO --entry main "$here/ail_eval.ail" < "$runs/runner_signal.cases.tsv" 2>/dev/null ) >> "$runs/runner_signal.txt"
( cd "$out/../tree" && bash "$here/deep_nesting.sh" 10000 100000 1000000 ) > "$runs/deep_nesting.txt" 2>&1; log "deep_nesting" $?
bun "$here/waiter_outcome.ts" > "$runs/waiter_outcome.txt" 2>&1; log "waiter_outcome" $?
T2_TS_MODULE="$fix_ts" bun "$here/waiter_outcome.ts" > "$runs/waiter_outcome.fixed.txt" 2>&1; log "waiter_outcome (fixcheck TS)" $?

# Every report's repro, on the tree and (where a patched copy exists) on the copies.
: > "$runs/repros.txt"
while IFS=$'\t' read -r id prop route claim repro witness notes; do
  [[ "$id" == report_id ]] && continue
  ( cd "$out/../tree" && timeout 120 bash -c "$repro" ) >> "$runs/repros.txt" 2>&1; rc=$?
  log "repro $id (tree)" $rc
  ( cd "$out/../tree" && T2_TS_MODULE="$fix_ts" T2_AIL_ENTRY="$fix_ail" timeout 120 bash -c "$repro" ) > /dev/null 2>&1; rc=$?
  log "repro $id (fixcheck copies)" $rc
done < "$out/reports.tsv"
