#!/usr/bin/env bash
# run_p11.sh — P1.1 differential test, real readHerdrEnvironment vs real herdr_env_ready.
#
# From the tree root:
#   bash <out>/p11/run_p11.sh [--class ENV_GT_1|BIN_EMPTY|all] [--random N] [--seed S]
#
# 1. gen_cases.ts writes the cases (G1 exhaustive 29^3, G2 all HERDR_ENV strings of length
#    0..3 over 7 characters x 16, G3 N seeded random triples; default N=20000, seed 118).
# 2. gate_ail.ail runs the real herdr_env_ready on them (unset -> "").
# 3. gate_ts.ts runs the real readHerdrEnvironment on them (unset -> key absent).
# 4. compare_gate.ts states P1.1 and compares.
# Exit 1 when the selected class of disagreement occurs, 0 when it does not, 2 when a half
# could not run or the two halves did not see the same strings.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(pwd)"
cls=all; random=20000; seed=118
while [[ $# -gt 0 ]]; do
  case "$1" in
    --class) cls="$2"; shift 2 ;;
    --random) random="$2"; shift 2 ;;
    --seed) seed="$2"; shift 2 ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
[[ -f "$root/src/tui/src/herdr-agent-state.ts" ]] || { echo "run from the tree root" >&2; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bash "$here/../mkpkg.sh" "$root" "$tmp"
bun "$here/gen_cases.ts" "$tmp" "$random" "$seed"
cp "$here/gate_ail.ail" "$tmp/"
: > "$tmp/ail.out"
for ((k = 0; k < $(cat "$tmp/batches"); k++)); do
  cp "$tmp/gate_cases.$k.ail" "$tmp/gate_cases.ail"
  ( cd "$tmp" && ailang run --relax-modules --caps IO --entry main gate_ail.ail >> ail.out 2> ail.err ) \
    || { echo "AILANG half failed on batch $k:" >&2; tail -5 "$tmp/ail.err" >&2; exit 2; }
done
bun "$here/gate_ts.ts" "$root" "$tmp/cases.json" > "$tmp/ts.out" || { echo "TS half failed" >&2; exit 2; }
bun "$here/compare_gate.ts" "$tmp/cases.json" "$tmp/ts.out" "$tmp/ail.out" --class "$cls"
