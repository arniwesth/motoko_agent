#!/usr/bin/env bash
# Differential test for ../HerdrFailureModel.lean (target T2).
#
# Three halves over the same deterministic cases (gen.ts):
#   * the Lean model (HerdrFailureModel.lean + run_model.lean.tail, `lean --run`);
#   * the REAL herdrFailureCode / herdrMeansAgentGone (bun, run_ts.ts);
#   * the REAL failure_code / means_agent_gone (ailang v0.54.14, run_ail.ail).
# compare.py fails on any model-vs-real mismatch, and counts the real cross-language
# disagreements (P2.1, P2.2) as information.
#
#   run_diff.sh [scratch dir] [random count]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../tree" && pwd)"
scratch="${1:-$(mktemp -d)}"; mkdir -p "$scratch"
nrand="${2:-20000}"
LEAN="${LEAN:-$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin/lean}"

bun "$here/gen.ts" "$scratch" "$nrand"
bun "$here/run_ts.ts" "$repo" "$scratch/cases.json" > "$scratch/ts.out"
( cd "$here" && ailang run --package-dir "$repo" --relax-modules --caps IO --max-recursion-depth 1000000 \
    --entry main --args-file "$scratch/cases.json" run_ail.ail ) > "$scratch/ail.out" 2> "$scratch/ail.err"
# The model without its theorems (they are checked by `lean HerdrFailureModel.lean` itself).
awk '/^\/-! ## Theorems/ {exit} {print}' "$here/../HerdrFailureModel.lean" > "$scratch/RunModel.lean"
cat "$here/run_model.lean.tail" >> "$scratch/RunModel.lean"
"$LEAN" --run "$scratch/RunModel.lean" "$scratch/cases.hex" > "$scratch/model.out"
python3 "$here/compare.py" "$scratch/ts.out" "$scratch/ail.out" "$scratch/model.out" "$scratch/cases.json"
