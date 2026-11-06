#!/usr/bin/env bash
# negative_control.sh — do the harnesses tell the defect from its absence? Each mutant is applied
# to the GENERATED copy out/gen/journal_t5.ail only (never to the tree), the harness re-run, and
# the copy regenerated from the tree at the end.
#
#   M1 "pinned"  `else if contains_string(seen, id) then []` -> `then acc`: the body the twin's
#                SOURCE pin (reader.ail:1225, sha256 db222e4c...) hashes to, i.e. D4 rule 1's
#                "stopping at the first repeated id".
#   M2           M1 plus `if id == "" then acc` -> `if false then acc` (look the start id up even
#                when it is ""), the smallest change that makes repro/empty_id.ail's input pass.
#
# Expected: unmutated, all three repros exit 1 and path_props exits 1; under M1,
# repro/cycle.ail, fold_cycle.ail (its fold_journal from the M1 copy) and path_props (ids
# {a,b,c}, length <= 3) exit 0 and repro/empty_id.ail still exits 1; under M2,
# repro/empty_id.ail exits 0.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; cd "$here"
trap './gen_exports.sh; rm -f gen/fold_cycle_m1.ail' EXIT
run() { NO_GEN=1 bash repro/run.sh "$1" > /dev/null 2>&1; echo $?; }
props() { timeout 600 ailang run --relax-modules --caps IO --entry run --args-json '{"maxlen":3,"empty":false}' path_props.ail > "runs/negctl_$1.txt" 2>&1; echo $?; }

./gen_exports.sh
echo "unmodified: cycle=$(run repro/cycle.ail) empty_id=$(run repro/empty_id.ail) fold_cycle=$(run fold_cycle.ail) path_props=$(props base)"

sed -i 's#^  else if contains_string(seen, id) then \[\]$#  else if contains_string(seen, id) then acc#' gen/journal_t5.ail
grep -q '^  else if contains_string(seen, id) then acc$' gen/journal_t5.ail || { echo "M1 not applied"; exit 2; }
# The mutated body hashes to the twin's pin: the pinned original IS this body.
h=$(awk '/^export pure func path_up\(/{p=1} p{print} p&&/^}$/{exit}' gen/journal_t5.ail | sed 's/^export pure func/pure func/' | sha256sum | cut -c1-16)
echo "M1 body sha256 ${h}... (twin pin db222e4cc4cb2422...)"
# fold_cycle.ail with its fold_journal taken from the M1 copy instead of the tree (the
# eval_fold_journal twin and everything else unchanged).
sed -e 's#^import src/core/journal (#import gen/journal_t5 (#' -e 's#^module fold_cycle$#module fold_cycle_m1#' \
  fold_cycle.ail > gen/fold_cycle_m1.ail
echo "M1 pinned:  cycle=$(run repro/cycle.ail) empty_id=$(run repro/empty_id.ail) fold_cycle=$(run gen/fold_cycle_m1.ail) path_props=$(props m1)"

sed -i 's#^  if id == "" then acc$#  if false then acc#' gen/journal_t5.ail
grep -q '^  if false then acc$' gen/journal_t5.ail || { echo "M2 not applied"; exit 2; }
echo "M2:         cycle=$(run repro/cycle.ail) empty_id=$(run repro/empty_id.ail)"
