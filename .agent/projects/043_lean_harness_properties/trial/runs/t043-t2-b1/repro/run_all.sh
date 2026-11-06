#!/usr/bin/env bash
# Runs every repro command of ../reports.tsv from the tree root, plus the controls, and prints
# id, exit status (1 = defect present, 0 = absent) and seconds.
#   bash run_all.sh            (from anywhere)
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../../tree" || exit 2
tail -n +2 "$here/../reports.tsv" | while IFS=$'\t' read -r id prop route claim repro rest; do
  start=$(date +%s%N); bash -c "$repro" > "$here/last_$id.log" 2>&1; rc=$?; end=$(date +%s%N)
  printf "%-10s %-5s exit %d  %d ms\n" "$id" "$prop" "$rc" $(( (end - start) / 1000000 ))
done
for c in CTRL-1 CTRL-2 CTRL-3; do
  bash ../out/repro/check.sh "$c" > "$here/last_$c.log" 2>&1; printf '%-10s control exit %d (expect 0)\n' "$c" "$?"
done
