#!/usr/bin/env bash
# T1 witness checks for s01 and s02 on B0, only-s, T and T-s. P1.1 holds on a case iff both sides agree.
set -uo pipefail
P=/home/motoko/trial-043/planter; W=$P/work; H=$W/harness
for s in s01 s02; do
  out=$P/validation/$s; mkdir -p $out
  { echo "# $s: P1.1 witness check. Each line: tree | case | TS gate | AILANG gate | P1.1"
    for t in base trees/only-$s trees/T trees/minus-$s; do
      tree=$W/$t; [ "$t" = base ] && name=B0 || name=$(basename $t)
      paste -d'|' <(bun $H/t1_gate.ts $tree) <($H/run_ail.sh $tree $H/t1_gate.ail IO) | awk -F'|' -v n=$name '{
        split($1,a," -> "); split($2,b," -> "); ok=(a[2]==b[2])?"holds":"VIOLATED"; printf "%-14s | %-40s | TS %-6s | AIL %-6s | %s\n", n, a[1], a[2], b[2], ok }'
    done; } > $out/witness.log
done
cat $P/validation/s01/witness.log | grep -E "s01-witness|^#"; grep -E "s02-witness|^#" $P/validation/s02/witness.log
