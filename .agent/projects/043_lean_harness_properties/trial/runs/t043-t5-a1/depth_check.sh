#!/usr/bin/env bash
# depth_check.sh — P5.1 on long paths: does the REAL path_up (with find_entry and
# contains_string under it) use stack per step? Runs perf_path.ail's `walk` over a 300-entry
# chain with the interpreter's recursion ceiling at 20. A walk that recursed per step would die
# with RT_REC_003; the control (`fold`, whose test fixture `appends` is NOT tail-recursive) must
# die at the same ceiling, which shows the ceiling is enforced. Exit 0 when both behave so.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; cd "$here"; ./gen_exports.sh
walk="$(timeout 120 ailang run --relax-modules --max-recursion-depth 20 --caps IO,Clock --entry walk --args-json 300 perf_path.ail 2>&1)"
ctl="$(timeout 120 ailang run --relax-modules --max-recursion-depth 20 --caps IO,Clock --entry fold --args-json 300 perf_path.ail 2>&1)"
echo "walk(300) at depth 20:  $(grep -o 'path_up .*\|RT_REC_003[^.]*' <<< "$walk" | head -1)"
echo "control   at depth 20:  $(grep -o 'fold_journal .*\|RT_REC_003[^.]*' <<< "$ctl" | head -1)"
grep -q "path length 300" <<< "$walk" && grep -q RT_REC_003 <<< "$ctl"
