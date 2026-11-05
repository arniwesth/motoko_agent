#!/usr/bin/env bash
# B1-T5-2. The cycle defect through the public API, on the UNMODIFIED journal.ail:
# fold_journal accepts a well-formed journal, and refuses with `header` the same journal
# with only the header's parent_id pointed back into the path (a cycle through the root),
# where D4 rule 1 stops at the repeated id and folds the same path, header first.
# Exit 1 when the defect is present, 0 when absent, 2 when the harness itself is broken.
source "$(dirname "$0")/_common.sh"
out=$(run_harness real fold_cycle.ail); echo "$out"
echo "$out" | grep -q '^control|accept|' || { echo "HARNESS BROKEN: control journal not accepted"; exit 2; }
echo "$out" | grep -q '^cycle_to_leaf|.*|header.parent_id=0*[1-9]' || { echo "HARNESS BROKEN: header parent not changed"; exit 2; }
if echo "$out" | grep -q '^cycle_to_leaf|header|' || echo "$out" | grep -q '^cycle_to_self|header|'; then
  echo "DEFECT PRESENT: a cycle through the header is refused with Refusal::Header"; exit 1
fi
echo "absent"; exit 0
