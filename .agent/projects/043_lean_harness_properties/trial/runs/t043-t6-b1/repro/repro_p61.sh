#!/usr/bin/env bash
# P6.1 on the REAL code: for n >= 0 the result of truncate_utf8_by_bytes is at most n bytes.
# Through the real exported store_stdout_and_elide, unmodified. Run from the tree root:
#   bash /home/motoko/trial-043/s/t043-t6-b1/out/repro/repro_p61.sh
# Exit 1 if P6.1 is violated on either witness, 0 if it holds on both, 2 on a harness failure.
#   W1 (Lean: bug_P6_1_two_byte)  "é" = C3 A9, cap 1     -> comes back whole, 2 bytes
#   W2 (shipped default cap 4000) "日" x 2000 = 6000 bytes, 2000 runes, cap 4000 -> 6000 bytes
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
w="$(mktemp -d)"; trap 'rm -rf "$w"' EXIT
echo "195,169" > "$w/w1.csv"
python3 -c 'print(",".join(str(x) for x in ("日" * 2000).encode()))' > "$w/w2.csv"
rc=0
for spec in "1 w1" "4000 w2"; do
  set -- $spec
  "$here/run_export.sh" "$1" "$w/$2.csv" "$w/$2.out" || exit 2
  echo -n "$2: "; python3 "$here/check.py" P6.1 "$1" "$w/$2.out"; r=$?
  [[ $r -eq 2 ]] && exit 2
  [[ $r -eq 1 ]] && rc=1
done
exit $rc
