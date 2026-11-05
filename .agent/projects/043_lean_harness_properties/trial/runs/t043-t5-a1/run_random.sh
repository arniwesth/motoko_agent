#!/usr/bin/env bash
# run_random.sh [seed] [count] — the random test of path_up: bun generates cases (gen_cases.ts),
# the REAL path_up / ev_path_up / strict_path run on them in AILANG (run_cases.ail), bun checks
# the properties on the outputs (check_cases.ts). Exit status is check_cases.ts's: 0 clean,
# 1 a property violated, 2 the AILANG half did not return a result for every case.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
seed="${1:-1}"; count="${2:-700}"
"$here/gen_exports.sh"
mkdir -p "$here/runs"
cases="runs/cases_s${seed}_n${count}.jsonl"; res="runs/results_s${seed}_n${count}.jsonl"
cd "$here"
bun gen_cases.ts "$seed" "$count" > "$cases"
timeout 1500 ailang run --relax-modules --caps IO,FS --entry main --args-json "{\"path\":\"$cases\"}" run_cases.ail > "$res" 2> "$res.err" || true
bun check_cases.ts "$cases" "$res"
