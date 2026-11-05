#!/usr/bin/env bash
# X-2: the climb costs time quadratic in the path length. Each step calls `find_entry`, which
# rescans the entry list from the FILE's start (the parent of a late entry is late), and
# `contains_string`, which rescans `seen`. Exit 1 when doubling the path length multiplies the
# climb's cost by more than 8 (linear: ~4 per two doublings is 4; quadratic: 16), 0 otherwise.
#
# The REAL path_up (verbatim body, ../diff/build_harness.sh) on a linear journal of n entries in
# file order (e0 root, e_i's parent e_{i-1}), climbing from the last entry, against a BASELINE on
# the same list whose start id names no entry (one scan, no climb: parsing, one find_entry,
# printing). climb cost(n) = time(climb) - time(baseline). Run from the tree root.
# Measured as the ailang process's user+sys CPU time, after one discarded warm-up run (the
# first run of a fresh harness pays the import compile, ~15 s).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
declare -A cost
cpu_ms() {  # cpu_ms <cmd...> : run, print stdout to $WORK/run.out, echo user+sys CPU ms
  local t; TIMEFORMAT='%3U %3S'
  t=$( { time "$@" > "$WORK/run.out" 2>>"$WORK/ail.err"; } 2>&1 )
  python3 -c "u,s='$t'.split(); print(int(round((float(u)+float(s))*1000)))"
}
for n in 0 500 2000; do
  for mode in climb base; do
    start="e$((n - 1))"; [[ $mode == base || $n == 0 ]] && start="zz"
    python3 -c "
n=$n
print(';'.join(f\"e{i}>{'e'+str(i-1) if i else ''}\" for i in range(n)) + '|$start|0')" > "$WORK/c.txt"
    "$OUT/diff/build_harness.sh" "$TREE" "$WORK/c.txt" "$WORK/h.ail" 2>/dev/null
    ms=$(cpu_ms ailang run --relax-modules --package-dir "$TREE" --caps IO,FS --entry main "$WORK/h.ail")
    len=$(grep -F '|' "$WORK/run.out" | awk -F'|' '{print $NF}')
    [[ $n == 0 ]] && { echo "warm-up ($mode): ${ms} ms CPU, discarded"; continue; }
    echo "n=$n $mode: path length $len, ${ms} ms CPU"
    cost[$n.$mode]=$ms
  done
done
c1=$(( cost[500.climb] - cost[500.base] )); c2=$(( cost[2000.climb] - cost[2000.base] ))
(( c1 < 1 )) && c1=1
echo "climb cost: n=500 ${c1} ms, n=2000 ${c2} ms, ratio $(( c2 / c1 )) for 4x the path (linear 4, quadratic 16)"
(( c2 > 8 * c1 )) && { echo "  -> super-linear: quadratic climb"; exit 1; }
exit 0
