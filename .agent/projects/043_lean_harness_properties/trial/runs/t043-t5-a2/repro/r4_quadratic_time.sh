#!/usr/bin/env bash
# A2-T5-4 (X-3, efficiency): path_up's time on a host-shaped linear journal grows quadratically
# with the path length. path_timing.ail times the real path_up in-process on chains of N = 200
# and 4N = 800 entries (best of 3, interleaved). Quadratic growth gives a ratio near 16, linear
# near 4; on this shared machine the linear control (`linear` mode, the real find_entry doing N
# full scans) measured 3.9-6.0 and path_up 15.3-18.6, so the line is drawn at 10.
# Exit 1 while t(800)/t(200) >= 10. Timing-based: see SUMMARY.md for the caveats.
source "$(dirname "$0")/_common.sh"
"$out/harness/expose.sh" "$tree" "$out" || exit 2
res=$( (cd "$out" && echo "200 3 4" | timeout 110 ailang run --relax-modules --caps IO,Clock --entry main harness/path_timing.ail) 2>/dev/null | grep '^N=')
echo "$res"
r=$(sed -n 's/.*ratio_x100=\(-\{0,1\}[0-9]*\).*/\1/p' <<<"$res")
[[ -n "$r" && "$r" -gt 0 ]] || { echo "harness failed"; exit 2; }
[[ "$r" -lt 1000 ]]
