#!/usr/bin/env bash
# trees/T = base + seeds.patch (the trial tree's source files); trees/minus-<s> = T with s reversed
# (the adjudicator's T-s); trees/only-<s> = base + s. Hardlinked copies; patch writes new files.
set -euo pipefail
P=/home/motoko/trial-043/planter; W=$P/work; cd $W
rm -rf trees; mkdir trees
ids=$(ls $P/seeds | sed 's/\.patch$//')
cp -al base trees/T; (cd trees/T && patch -s -p1 < $P/seeds.patch)
for s in $ids; do
  cp -al base "trees/only-$s"; (cd "trees/only-$s" && patch -s -p1 < "$P/seeds/$s.patch")
  cp -al trees/T "trees/minus-$s"; (cd "trees/minus-$s" && patch -s -R -p1 < "$P/seeds/$s.patch")
done
find trees -name '*.orig' -o -name '*.rej' | head
echo "trees: $(ls trees | wc -l)"
