#!/usr/bin/env bash
# run_gates.sh <tree> <logdir> [ailang modules...]  — runs the §6 rule-2 gates, one log each.
tree="$1"; logs="$2"; shift 2
mkdir -p "$logs"
cd "$tree"
run() { local name="$1"; shift; local t0=$(date +%s); "$@" > "$logs/$name.log" 2>&1; local rc=$?; echo "$name rc=$rc secs=$(( $(date +%s) - t0 ))" | tee -a "$logs/SUMMARY"; }
: > "$logs/SUMMARY"
run check_core make check_core
run test make test
run verify_core make verify_core
run bun_test bash -c 'cd src/tui && bun run test'
for m in "$@"; do run "ailang_test_$(echo "$m" | tr '/' '_')" ailang test "$m"; done
