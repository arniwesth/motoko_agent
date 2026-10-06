#!/usr/bin/env bash
# SPIKE ONLY — runs the fixed check set on the tree as it stands. Never merges.
# usage: run_set.sh <label>
# Type check first (serial). If it fails the gates are skipped: a mutant that does not
# compile is recorded as that, not as a kill. Gates then run in parallel, one rc each.
set -u
lbl="$1"; root="$(git rev-parse --show-toplevel)"; cd "$root" || exit 9
out="tmp/spike/out/$lbl"; rm -rf "$out"; mkdir -p "$out"
rec() { echo "$*" >> "$out/summary.tsv"; }
rec "label	$lbl"
rec "head	$(git rev-parse --short HEAD)"
rec "ailang	$(ailang --version 2>&1 | head -1)"
rec "src_diff_files	$(git diff --name-only -- src | tr '\n' ' ')"
rec "src_diff_lines	$(git diff --numstat -- src | awk '{a+=$1; d+=$2} END{print a+0 "+/" d+0 "-"}')"
git diff -U0 -- src > "$out/mutant.diff" 2>&1
rec "load_start	$(cut -d' ' -f1-3 /proc/loadavg)"
t0=$(date +%s)
timeout 600 ailang check src/core/session.ail > "$out/check.log" 2>&1; crc=$?
rec "step	check	rc=$crc	secs=$(( $(date +%s) - t0 ))"
if [ "$crc" -ne 0 ]; then rec "gates	SKIPPED (type check failed)"; rec "done	$(date -Is)"; exit 0; fi
# Not a DST gate: the Z3 contract on the retry predicate, recorded in its own column.
v0=$(date +%s); timeout 120 ailang verify src/core/recovery.ail > "$out/contract.log" 2>&1; vrc=$?
rec "step	contract	rc=$vrc	secs=$(( $(date +%s) - v0 ))"
rm -f tmp/spike/corpus_pr.out
# corpus_pr gates on its own wall clock (pr_target_ceiling_ms), so it runs ALONE first, exactly
# as `make dst` runs it (DST_TIMED_TARGETS, Makefile:632). The other gates then run in parallel.
g0=$(date +%s); timeout 900 make --no-print-directory corpus_pr > "$out/corpus_pr.log" 2>&1; rc=$?
rec "step	corpus_pr	rc=$rc	secs=$(( $(date +%s) - g0 ))"
[ -f tmp/spike/corpus_pr.out ] && cp tmp/spike/corpus_pr.out "$out/corpus_pr.wire"
PAR="strict_replay discovery stream_parity ledger_parity"
for g in $PAR; do
  ( g0=$(date +%s); timeout 900 make --no-print-directory "$g" > "$out/$g.log" 2>&1; rc=$?
    echo "step	$g	rc=$rc	secs=$(( $(date +%s) - g0 ))" > "$out/$g.rc" ) &
done
wait
for g in $PAR; do cat "$out/$g.rc" >> "$out/summary.tsv"; rm -f "$out/$g.rc"; done
rec "load_end	$(cut -d' ' -f1-3 /proc/loadavg)"
rec "done	$(date -Is)"
