#!/usr/bin/env bash
# P3.2 acceptance on the REAL code for one child-simulator step sequence: the REAL fold over
# the REAL journal_lines_of_records of the run's records.
#   bash ../out/repro/p32.sh 7,8,5       (from the tree root)
# Exit 1 when the fold refuses the twin's journal (defect present), 0 when it accepts.
source "$(dirname "$0")/_env.sh"
steps="${1:?usage: p32.sh <comma-separated steps>}"
ail --caps IO --entry one_of --args-json "[${steps}]" diff/gen.ail > "$work/gen.out"
twin="$(grep -aE '^T	' "$work/gen.out" | cut -f3)"
echo "steps $steps: twin journal folds to: $twin"
if [[ "$twin" == R\;* ]]; then echo "P3.2 VIOLATED: the round trip is refused"; exit 1; fi
echo "accepted"; exit 0
