#!/usr/bin/env bash
# fold1.sh <name> <expected-defect-line>: runs the REAL fold_journal on harness/<name>.ail;
# exit 1 if its output line equals the defect line, 0 otherwise.
O=/home/motoko/trial-043/s/t043-dry-b/out
got=$(cd "$O/pkg" && timeout 110 ailang run --relax-modules --caps IO --entry main "harness/$1.ail" 2>/dev/null | tail -1)
echo "real fold: $got"
[[ "$got" == "$2" ]] && { echo "DEFECT PRESENT"; exit 1; } || { echo "absent"; exit 0; }
