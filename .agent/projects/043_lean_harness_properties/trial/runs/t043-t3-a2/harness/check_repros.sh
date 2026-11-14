#!/usr/bin/env bash
# Runs every `repro` command of ../out/reports.tsv from the tree root, as written, and records
# its exit code and wall time. Run from the tree root:  bash ../out/harness/check_repros.sh
here="$(cd "$(dirname "$0")" && pwd)"
tail -n +2 "$here/../reports.tsv" | while IFS=$'\t' read -r id prop route claim repro witness notes; do
  start=$(date +%s)
  bash -c "$repro" > /dev/null 2>&1
  code=$?
  printf '%s\t%s\texit=%s\t%ss\n' "$id" "$prop" "$code" "$(( $(date +%s) - start ))"
done
