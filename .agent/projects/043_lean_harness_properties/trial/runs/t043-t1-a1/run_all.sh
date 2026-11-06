#!/usr/bin/env bash
# run_all.sh — every check in SUMMARY.md, in order, with its output kept under runs/.
#
#   run_all.sh            from anywhere; needs bun (1.4.4) and ailang (v0.54.14) on PATH
#
# Each step prints its own summary line; `exit=` after it is the step's exit code (1 = defect
# present, as reports.tsv's repros use it). The script itself exits 0 when every step ran (exit 0 or
# 1), and 2 if any step could not run.
set -uo pipefail
out="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "$out/../tree" && pwd)"
runs="$out/runs"
mkdir -p "$runs"
cd "$tree"
broken=0

step() { # name, command...
  local name="$1"; shift
  echo "== $name"
  "$@" > "$runs/$name.out" 2>&1; local rc=$?
  echo "exit=$rc" >> "$runs/$name.out"
  cat "$runs/$name.out"
  [[ $rc -le 1 ]] || broken=1
}

step p11-all        bun "$out/gate_diff.ts" --gen all --scratch "$runs/p11-all"
step p11-env-order  bun "$out/gate_diff.ts" --gen env-order --scratch "$runs/p11-env-order"
step p11-bin        bun "$out/gate_diff.ts" --gen bin --scratch "$runs/p11-bin"
step p11-pane       bun "$out/gate_diff.ts" --gen pane --scratch "$runs/p11-pane"
step p11-random-s1  bun "$out/gate_diff.ts" --gen random --n 200000 --seed 1 --scratch "$runs/p11-random-s1"
step p11-random-s2  bun "$out/gate_diff.ts" --gen random --n 200000 --seed 2 --scratch "$runs/p11-random-s2"
step register       bun "$out/register_diff.ts" --mode both --scratch "$runs/register"
step mutants        "$out/mutants.sh" "$runs/mut"
rm -rf "$runs/mut"   # the mutated copies; mutants.out keeps the table
exit $(( broken ? 2 : 0 ))
