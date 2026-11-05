#!/usr/bin/env bash
# P6.2 on the REAL code (PROVED in the model; this is a check, not a finding): the clipped
# output is a byte prefix of the input. Same witnesses as repro_p61.sh and repro_p63.sh, plus
# invalid UTF-8 input (FF 80 C3 61 E2 82, cap 3), where a repairing toString would break it.
# Exit 1 if P6.2 is violated on any witness, 0 if it holds on all.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
w="$(mktemp -d)"; trap 'rm -rf "$w"' EXIT
echo "195,169" > "$w/a.csv"; echo "195,169,195,169" > "$w/b.csv"; echo "255,128,195,97,226,130" > "$w/c.csv"
rc=0
for spec in "1 a" "1 b" "3 c"; do
  set -- $spec
  "$here/run_export.sh" "$1" "$w/$2.csv" "$w/$2.out" || exit 2
  echo -n "$2: "; python3 "$here/check.py" P6.2 "$1" "$w/$2.out"; r=$?
  [[ $r -eq 2 ]] && exit 2
  [[ $r -eq 1 ]] && rc=1
done
exit $rc
