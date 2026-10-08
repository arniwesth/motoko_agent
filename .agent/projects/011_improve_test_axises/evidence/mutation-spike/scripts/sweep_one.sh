#!/usr/bin/env bash
# SPIKE ONLY — one full `make dst` sweep on the tree as it stands. Never merges.
# usage: sweep_one.sh <label>
set -u
lbl="$1"; root="$(git rev-parse --show-toplevel)"; cd "$root" || exit 9
out="tmp/spike/out/sweep-$lbl"; rm -rf "$out"; mkdir -p "$out"
export PORT=28819   # recorded_stream's loopback port; 8819 is the host-wide default
git diff -U0 -- src > "$out/mutant.diff" 2>&1
echo "label	$lbl" > "$out/summary.tsv"
echo "src_diff	$(git diff --numstat -- src | tr '\t' ' ' | tr '\n' ';')" >> "$out/summary.tsv"
echo "load_start	$(cut -d' ' -f1-3 /proc/loadavg)" >> "$out/summary.tsv"
t0=$(date +%s)
timeout 3600 make --no-print-directory dst > "$out/dst.log" 2>&1; rc=$?
echo "sweep	rc=$rc	secs=$(( $(date +%s) - t0 ))" >> "$out/summary.tsv"
cp .ailang/dst-last.log "$out/dst-last.log" 2>/dev/null
echo "load_end	$(cut -d' ' -f1-3 /proc/loadavg)" >> "$out/summary.tsv"
echo "done	$(date -Is)" >> "$out/summary.tsv"
