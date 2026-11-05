#!/usr/bin/env bash
# t3_run.sh <tree-name>  — gen + twin fold (AILANG), host write (bun), host fold (AILANG); writes runs/t3-<name>.{gen,jl,host}
set -euo pipefail
W=/home/motoko/trial-043/planter/work; H=$W/harness; n="$1"; [ "$n" = B0 ] && tree=$W/base || tree=$W/trees/$n
$H/run_ail.sh $tree $H/t3_gen.ail IO > $W/runs/t3-$n.gen
rm -rf $W/scratch/t3-$n; mkdir -p $W/scratch
bun $H/t3_host.ts $tree $W/runs/t3-$n.gen $W/scratch/t3-$n > $W/runs/t3-$n.jl
cp $W/runs/t3-$n.jl $tree/zz_planter/host.jl
$H/run_ail.sh $tree $H/t3_fold.ail IO,FS > $W/runs/t3-$n.host
rm -rf $W/scratch/t3-$n
echo "$n: $(grep -c '^W' $W/runs/t3-$n.gen) twin, $(wc -l < $W/runs/t3-$n.host) host"
