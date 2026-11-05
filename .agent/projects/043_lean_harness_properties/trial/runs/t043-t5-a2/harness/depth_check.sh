#!/usr/bin/env bash
# depth_check.sh — P5.1 against AILANG's recursion ceiling. AILANG refuses NON-tail recursion
# deeper than --max-recursion-depth (default 10000, RT_REC_003); a tail call runs in constant
# depth. With the ceiling lowered to 50:
#   * the real path_up (path_scale.ail) on a 500-entry linear chain, and on the same chain with
#     a cycle through the root, must finish: its own recursion, find_entry's and
#     contains_string's are then tail calls, so no path length can hit the ceiling;
#   * depth_probe.ail, a deliberately NON-tail recursion of depth 500, must fail (the control:
#     the flag is in force).
# Exit 0 when both hold. Run from out/ (or anywhere: it cds there).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; out="$(cd "$here/.." && pwd)"; cd "$out"
"$here/expose.sh" "$out/../tree" "$out" || exit 2
fail=0
for c in 0 1; do
  r=$(echo "500 $c" | timeout 300 ailang run --relax-modules --caps IO --max-recursion-depth 50 --entry main harness/path_scale.ail 2>&1 | grep -E '^N=|RT_REC')
  echo "path_up, depth cap 50, N=500 cycle=$c: $r"
  grep -q '^N=500' <<<"$r" || fail=1
done
r=$(timeout 60 ailang run --relax-modules --caps IO --max-recursion-depth 50 --entry main harness/depth_probe.ail 2>&1 | grep -oE 'RT_REC_003[^.]*|^[0-9]+$')
echo "control, non-tail depth 500 under cap 50: $r"
grep -q RT_REC_003 <<<"$r" || fail=1
exit $fail
