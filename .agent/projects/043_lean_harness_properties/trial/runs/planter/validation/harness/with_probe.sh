#!/usr/bin/env bash
# with_probe.sh <tree> <file-in-tree> <wrapper-file> <harness.ail>
# The target is module-private, so a copy of <tree> gets one exported wrapper appended to <file>
# (the function under test is not touched), and <harness.ail> runs against that copy.
set -euo pipefail
W=/home/motoko/trial-043/planter/work; tree="$1"; f="$2"; wrap="$3"; h="$4"
probe=$W/probe/$(basename "$tree")-$(basename "$h" .ail)
rm -rf "$probe"; mkdir -p $W/probe; cp -al "$tree" "$probe"
cp --remove-destination "$tree/$f" "$probe/$f"; cat "$wrap" >> "$probe/$f"
$W/harness/run_ail.sh "$probe" "$h" IO
