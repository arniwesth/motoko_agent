#!/usr/bin/env bash
# Re-runs every check behind SUMMARY.md, from anywhere. Needs lean 4.28.0, bun, ailang v0.54.14.
#   1. Lean checks the model and all theorems, and prints the axiom report.
#   2. The differential test (model vs real TS vs real AILANG) and its negative control.
#   3. The mutation check of the bug_ statements.
#   4. Every repro in reports.tsv, from the tree root: each must exit 1 (defect present).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "$here/../tree" && pwd)"
LEAN="${LEAN:-$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin/lean}"
fail=0
echo "== 1. lean"
"$LEAN" "$here/HerdrFailureModel.lean" > /tmp/t2_lean.$$ 2>&1 || fail=1
grep -cE "depends on axioms|does not depend" /tmp/t2_lean.$$ | sed 's/^/theorems: /'
grep -E "sorryAx|ofReduceBool|: error" /tmp/t2_lean.$$ && fail=1; rm -f /tmp/t2_lean.$$
echo "== 2. differential test"
"$here/diff/run_diff.sh" "$(mktemp -d)" 20000 | tail -4 || fail=1
"$here/diff/negative_control.sh" "$(mktemp -d)" | tail -1 || fail=1
echo "== 3. mutants"
( cd "$here/mutants" && python3 make_mutants.py > /dev/null && ./run_mutants.sh ) || fail=1
echo "== 4. repros"
while IFS=$'\t' read -r id _ _ _ repro _; do
  [[ "$id" == report_id ]] && continue
  ( cd "$tree" && eval "$repro" > /dev/null 2>&1 ); rc=$?
  echo "$id exit $rc"; [[ $rc -eq 1 ]] || fail=1
done < "$here/reports.tsv"
echo "check_all: $([[ $fail -eq 0 ]] && echo OK || echo FAILED)"; exit $fail
