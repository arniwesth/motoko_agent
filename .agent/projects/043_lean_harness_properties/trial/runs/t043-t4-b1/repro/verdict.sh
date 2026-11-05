#!/usr/bin/env bash
# verdict.sh FILE.ail — exit 1 if the program prints "VIOLATED" (defect present), 0 if it
# prints "HOLDS" (defect absent), 2 if it printed neither (the repro itself failed).
here="$(cd "$(dirname "$0")" && pwd)"
out="$(timeout 110 "$here/run_ail.sh" "$1")" || { echo "$out"; echo "repro did not run"; cat "$here/.mirror${TREE:+_alt}/stderr.txt" 2>/dev/null | head -20; exit 2; }
echo "$out"
if grep -q "VIOLATED" <<< "$out"; then exit 1; fi
if grep -q "HOLDS" <<< "$out"; then exit 0; fi
exit 2
