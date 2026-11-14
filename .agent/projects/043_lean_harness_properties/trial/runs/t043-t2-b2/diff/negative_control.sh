#!/usr/bin/env bash
# Negative control for run_diff.sh: the comparison must notice a planted change.
#   1. A mutant COPY of the real wake-waiter.ts (the tree is not touched), with the twin's
#      verdict narrowed to `=== "agent_not_found"`: the TS half must now mismatch the model.
#   2. A mutant COPY of the model, with AILANG's `get` keeping the LAST duplicate key: the
#      AILANG half must now mismatch the model.
# Exit 0 when both mutants are caught.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../tree" && pwd)"
scratch="${1:-$(mktemp -d)}"; mkdir -p "$scratch"
LEAN="${LEAN:-$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin/lean}"
bun "$here/gen.ts" "$scratch" 2000
( cd "$here" && ailang run --package-dir "$repo" --relax-modules --caps IO --max-recursion-depth 1000000 \
    --entry main --args-file "$scratch/cases.json" run_ail.ail ) > "$scratch/ail.out" 2> "$scratch/ail.err"
awk '/^\/-! ## Theorems/ {exit} {print}' "$here/../HerdrFailureModel.lean" > "$scratch/RunModel.lean"
cat "$here/run_model.lean.tail" >> "$scratch/RunModel.lean"
"$LEAN" --run "$scratch/RunModel.lean" "$scratch/cases.hex" > "$scratch/model.out"

sed 's/return herdrFailureCode(r).endsWith("_not_found");/return herdrFailureCode(r) === "agent_not_found";/' \
  "$repo/src/tui/src/wake-waiter.ts" > "$scratch/wake-waiter.mutant.ts"
cmp -s "$repo/src/tui/src/wake-waiter.ts" "$scratch/wake-waiter.mutant.ts" && { echo "mutant 1 not planted"; exit 2; }
WW_TS="$scratch/wake-waiter.mutant.ts" bun "$here/run_ts.ts" "$repo" "$scratch/cases.json" > "$scratch/ts.mut.out"
echo "== mutant 1 (TS verdict narrowed), real AILANG, true model:"
python3 "$here/compare.py" "$scratch/ts.mut.out" "$scratch/ail.out" "$scratch/model.out" "$scratch/cases.json" | grep -E "mismatches|cases"
m1=$?
python3 "$here/compare.py" "$scratch/ts.mut.out" "$scratch/ail.out" "$scratch/model.out" "$scratch/cases.json" > /dev/null; r1=$?

sed 's/  | .obj kvs, k => lookupFirst k kvs$/  | .obj kvs, k => lookupFirst k kvs.reverse/' "$scratch/RunModel.lean" > "$scratch/RunModel.mut.lean"
cmp -s "$scratch/RunModel.lean" "$scratch/RunModel.mut.lean" && { echo "mutant 2 not planted"; exit 2; }
"$LEAN" --run "$scratch/RunModel.mut.lean" "$scratch/cases.hex" > "$scratch/model.mut.out"
bun "$here/run_ts.ts" "$repo" "$scratch/cases.json" > "$scratch/ts.out"
echo "== mutant 2 (model's AILANG get keeps the last duplicate), real code:"
python3 "$here/compare.py" "$scratch/ts.out" "$scratch/ail.out" "$scratch/model.mut.out" "$scratch/cases.json" | grep -E "mismatches|cases"
python3 "$here/compare.py" "$scratch/ts.out" "$scratch/ail.out" "$scratch/model.mut.out" "$scratch/cases.json" > /dev/null; r2=$?
if [[ $r1 -eq 1 && $r2 -eq 1 ]]; then echo "negative control: both mutants caught"; exit 0; fi
echo "negative control: FAILED (r1=$r1 r2=$r2)"; exit 1
