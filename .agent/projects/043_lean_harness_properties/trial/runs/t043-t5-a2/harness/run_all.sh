#!/usr/bin/env bash
# run_all.sh — the whole campaign of SUMMARY.md, in order. Run from out/. Takes about 25 min
# (most of it e1_5, the long chains and the fold differential); results in runs/.
# Exit status is informational: the direct suites exit 1 because the defects are present.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; out="$(cd "$here/.." && pwd)"; cd "$out"
"$here/expose.sh" "$out/../tree" "$out" || exit 2
# direct: the real path_up / ev_path_up / find_entry, judged by check.ts
"$here/run_direct.sh" e1_4 exhaustive a/b/c _/a/b/c/z _/a/b/c/z 4
TMO=3000 "$here/run_direct.sh" e1_5 exhaustive a/b/c _/a/b/c/z _/a/b/c/z 5
"$here/run_direct.sh" e2_4 exhaustive _/a/b _/a/b/z _/a/b/z 4
"$here/run_direct.sh" r1 random 1 20000 40 12
"$here/run_direct.sh" r2 random 2 100000 60 25
"$here/run_direct.sh" s20 structured 20
for n in 250 500 1000 2000; do TMO=900 "$here/run_direct.sh" long_$n long $n; done
TMO=900 "$here/run_direct.sh" deep_100000 deep 100000
# P5.1 against the recursion ceiling
"$here/depth_check.sh"
# the unmodified fold: targeted variants and the exhaustive single-redirect differential
ailang run --relax-modules --caps IO --entry main harness/fold_cycle.ail > runs/fold_cycle.out 2> runs/fold_cycle.err
ailang run --relax-modules --caps IO --entry main harness/fold_diff.ail > runs/fold_diff.out 2> runs/fold_diff.err
tail -1 runs/fold_diff.out
# timing (X-3), path_up and its linear control
for m in "200 3 4" "200 3 4 linear"; do echo "$m" | ailang run --relax-modules --caps IO,Clock --entry main harness/path_timing.ail 2>/dev/null; done
# the repros against the tree and against fixed controls
( cd "$out/../tree" && "$here/negative_control.sh" )
