#!/usr/bin/env bash
# run_all.sh — every check in this directory, from the tree root, logged to runs/run_all.log:
#   bash /home/motoko/trial-043/s/t043-t4-b2/out/run_all.sh
# Needs `lean` 4.28.0 and `ailang` v0.54.14 on PATH.
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(pwd)"
mkdir -p "$here/runs"
{
  echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) tree: $tree"
  echo "=== lean/check.sh";                   bash "$here/lean/check.sh" | tail -1; echo "exit ${PIPESTATUS[0]}"
  echo "=== diff/run_diff.sh";                 bash "$here/diff/run_diff.sh" "$tree"; echo "exit $?"
  echo "=== diff/count_p42.awk";               awk -f "$here/diff/count_p42.awk" "$here/runs/diff/ail.out"
  echo "=== diff/run_scale.sh";                bash "$here/diff/run_scale.sh" "$tree"; echo "exit $?"
  for p in p4_1 p4_2 x1 x2; do
    echo "=== repro/$p.sh";                    bash "$here/repro/$p.sh" "$tree"; echo "exit $?"
  done
  echo "=== repro/check_on_fixed_copy.sh";     bash "$here/repro/check_on_fixed_copy.sh" "$tree"; echo "exit $?"
} > "$here/runs/run_all.log" 2>&1
cat "$here/runs/run_all.log"
