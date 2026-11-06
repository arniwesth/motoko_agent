#!/usr/bin/env bash
# P6.3 on the REAL code (known, K2): valid UTF-8 in gives valid UTF-8 out.
# Through the real exported store_stdout_and_elide, unmodified. Run from the tree root:
#   bash /home/motoko/trial-043/s/t043-t6-b1/out/repro/repro_p63.sh
# Exit 1 if P6.3 is violated on either witness, 0 if it holds on both, 2 on a harness failure.
#   W1 (Lean: bug_P6_3)           "éé" = C3 A9 C3 A9, cap 1 -> C3
#   W2 (shipped default cap 4000) "a" x 3999 + "日本" (4005 bytes, 4001 runes), cap 4000
#                                 -> 3999 x "a" then E6, a lead byte cut from its rune
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
w="$(mktemp -d)"; trap 'rm -rf "$w"' EXIT
echo "195,169,195,169" > "$w/w1.csv"
python3 -c 'print(",".join(str(x) for x in ("a" * 3999 + "日本").encode()))' > "$w/w2.csv"
rc=0
for spec in "1 w1" "4000 w2"; do
  set -- $spec
  "$here/run_export.sh" "$1" "$w/$2.csv" "$w/$2.out" || exit 2
  echo -n "$2: "; python3 "$here/check.py" P6.3 "$1" "$w/$2.out"; r=$?
  [[ $r -eq 2 ]] && exit 2
  [[ $r -eq 1 ]] && rc=1
done
exit $rc
