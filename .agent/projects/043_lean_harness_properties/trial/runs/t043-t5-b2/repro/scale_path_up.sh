#!/usr/bin/env bash
# scale_path_up.sh [n ...] — wall time of the REAL path_up (verbatim body, ../diff/build_harness.sh)
# on a linear journal of n entries in file order (e0 root, e_i's parent e_{i-1}), climbing from
# the last entry. Run from the tree root. Prints `n=<n> len=<result length> secs=<wall>`.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; tree="$(pwd)"; work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
for n in "${@:-500 1000 2000}"; do
  python3 -c "
n=$n
print(';'.join(f\"e{i}>{'e'+str(i-1) if i else ''}\" for i in range(n)) + f'|e{n-1}|0')" > "$work/c$n.txt"
  "$here/../diff/build_harness.sh" "$tree" "$work/c$n.txt" "$work/h$n.ail" 2>/dev/null
  s=$(date +%s%N)
  r=$(ailang run --relax-modules --package-dir "$tree" --caps IO,FS --entry main ${DEPTH:+--max-recursion-depth $DEPTH} "$work/h$n.ail" 2>"$work/err$n" | grep -F '|' | awk -F'|' '{print $NF}')
  e=$(date +%s%N)
  echo "n=$n len=${r:-ERROR $(grep -m1 -i 'error\|recursion' "$work/err$n" | cut -c1-120)} secs=$(( (e - s) / 1000000 ))e-3"
done
