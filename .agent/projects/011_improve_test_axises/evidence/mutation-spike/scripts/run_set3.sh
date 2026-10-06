#!/usr/bin/env bash
# SPIKE ONLY — part 3 check set on the tree as it stands. Never merges.
# usage: run_set3.sh <label>
set -u
lbl="$1"; root="$(git rev-parse --show-toplevel)"; cd "$root" || exit 9
out="tmp/spike/out3/$lbl"; rm -rf "$out"; mkdir -p "$out"
rec() { echo "$*" >> "$out/summary.tsv"; }
rec "label	$lbl"; rec "head	$(git rev-parse --short HEAD)"; rec "ailang	$(ailang --version 2>&1 | head -1)"
rec "src_diff_lines	$(git diff --numstat -- src | awk '{a+=$1; d+=$2} END{print a+0 "+/" d+0 "-"}')"
git diff -U0 -- src > "$out/mutant.diff" 2>&1
rec "load_start	$(cut -d' ' -f1-3 /proc/loadavg)"
t0=$(date +%s); timeout 600 ailang check src/core/session.ail > "$out/check.log" 2>&1; crc=$?
rec "step	check	rc=$crc	secs=$(( $(date +%s) - t0 ))"
if [ "$crc" -ne 0 ]; then rec "gates	SKIPPED (type check failed)"; rec "done	$(date -Is)"; exit 0; fi
rm -f tmp/spike/corpus_pr.out
g0=$(date +%s); timeout 900 make --no-print-directory corpus_pr > "$out/corpus_pr.log" 2>&1; rc=$?   # alone: it gates on wall time
rec "step	corpus_pr	rc=$rc	secs=$(( $(date +%s) - g0 ))"
[ -f tmp/spike/corpus_pr.out ] && cp tmp/spike/corpus_pr.out "$out/corpus_pr.wire"
PAR="strict_replay discovery stream_parity ledger_parity world_state"
for g in $PAR; do
  ( g0=$(date +%s); timeout 900 make --no-print-directory "$g" > "$out/$g.log" 2>&1; rc=$?
    echo "step	$g	rc=$rc	secs=$(( $(date +%s) - g0 ))" > "$out/$g.rc" ) &
done
wait
for g in $PAR; do cat "$out/$g.rc" >> "$out/summary.tsv"; rm -f "$out/$g.rc"; done
g0=$(date +%s)
timeout 600 ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub \
  --entry families_probe scripts/dst/spike_families_on_bank.ail < /dev/null > "$out/probe.out" 2>&1; prc=$?
rec "step	bank_probe	rc=$prc	secs=$(( $(date +%s) - g0 ))"
echo "rc=$prc secs=0 rows=$(grep -a -c '^FAMROW ' "$out/probe.out") end=$(grep -a -c '^FAMPROBE end' "$out/probe.out")" > "$out/rc"
rec "load_end	$(cut -d' ' -f1-3 /proc/loadavg)"; rec "done	$(date -Is)"
