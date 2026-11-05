#!/usr/bin/env bash
# A2-T5-2 (X-2): the REAL, unmodified fold_journal refuses with `header` a journal whose parent
# chain closes a cycle THROUGH the header (header.parent_id = the leaf / a middle entry / itself),
# where D4 rule 1's path is the whole, header-first chain; the eval twin eval_fold_journal folds
# those journals to the unmodified journal's state. Exit 1 while any variant is BAD.
source "$(dirname "$0")/_common.sh"
src="${FOLD_SRC:-harness/fold_cycle.ail}"
( cd "$out" && timeout 100 ailang run --relax-modules --caps IO --entry main "$src" ) > "$tmp/r2.out" 2> "$tmp/r2.err"
grep -q '^J (unmodified)|' "$tmp/r2.out" || { echo "harness failed:"; tail -5 "$tmp/r2.err"; exit 2; }
cat "$tmp/r2.out"
! grep -q '|BAD$' "$tmp/r2.out"
