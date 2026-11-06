#!/usr/bin/env bash
# Differential test for ../HerdrGateModel.lean (target T1, the herdr environment gate).
#
# Three halves over every triple (HERDR_ENV, HERDR_BIN_PATH, HERDR_PANE_ID), each component
# unset or one of the alphabet's values (gen_inputs.py, seeded):
#
#   model  `readHerdrEnvironment` and `ailOpen` in HerdrGateModel.lean     (lean, 4.28.0, core)
#   TS     the REAL `readHerdrEnvironment`, src/tui/src/herdr-agent-state.ts:157   (bun)
#   AILANG the REAL `herdr_env_ready`, packages/motoko-ext-herdr/types.ail:1425   (ailang)
#
#   1. model TS half against the real TS gate, returned fields included: must match
#   2. model AILANG half against the real AILANG gate: must match
#   3. P1.1 on the REAL code (real TS non-null vs real AILANG true): counted and sampled,
#      not failed, because the disagreements are the finding, not a harness error
#   4. --mutants: the negative control. One behaviour is changed on the real-code side of each
#      half, in a COPY under the scratch dir (the tree is not modified), and the comparison is
#      required to see mismatches. A harness that cannot see a planted change proves nothing.
#
#   run_diff.sh [--mutants] [seed] [scratch dir]
#
# Exit 0: every half ran and steps 1-2 found 0 mismatches (and, with --mutants, every mutant
# was caught). Exit 1: a mismatch, or an uncaught mutant. Exit 2: a toolchain is missing.
set -euo pipefail

mutants=0
if [[ "${1:-}" == "--mutants" ]]; then mutants=1; shift; fi
seed="${1:-43}"
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
tree="$(cd "$out/../tree" && pwd)"
scratch="${2:-$(mktemp -d)}"
mkdir -p "$scratch"

LEAN="${LEAN:-$(command -v lean || echo "$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin/lean")}"
for t in bun ailang python3; do command -v "$t" >/dev/null || { echo "NOT RUN -- no $t"; exit 2; }; done
[[ -x "$LEAN" ]] || { echo "NOT RUN -- no lean"; exit 2; }
"$LEAN" --version | grep -q "version 4.28.0" || { echo "NOT RUN -- lean is not 4.28.0"; exit 2; }

python3 "$here/gen_inputs.py" "$here" "$seed"

# --- real TypeScript --------------------------------------------------------------------
bun "$here/enumerate.ts" "$tree" "$here/alphabet.json" > "$scratch/ts.out"
echo "ts:     $(wc -l < "$scratch/ts.out") triples, sha256 $(sha256sum "$scratch/ts.out" | cut -c1-16)"

# --- real AILANG ------------------------------------------------------------------------
# From this directory: its ailang.toml resolves pkg/sunholo/motoko_ext_herdr to the tree.
( cd "$here" && ailang run --relax-modules --caps IO --entry main enumerate_gate.ail ) \
  > "$scratch/ail.raw" 2> "$scratch/ail.err"
grep -E '^[u0-9]+,[u0-9]+,[u0-9]+\|' "$scratch/ail.raw" > "$scratch/ail.out"
echo "ailang: $(wc -l < "$scratch/ail.out") triples, sha256 $(sha256sum "$scratch/ail.out" | cut -c1-16)"

# --- model ------------------------------------------------------------------------------
cat "$out/HerdrGateModel.lean" "$here/enumerate.lean.tail" > "$scratch/Enumerate.lean"
t0=$(date +%s)
"$LEAN" "$scratch/Enumerate.lean" > "$scratch/lean.raw"
echo "model:  lean took $(( $(date +%s) - t0 )) s"
grep -E '^[u0-9]+,[u0-9]+,[u0-9]+\|' "$scratch/lean.raw" > "$scratch/lean.out"
grep -vE '^[u0-9]+,[u0-9]+,[u0-9]+\|' "$scratch/lean.raw" > "$scratch/axioms.txt" || true
echo "model:  $(wc -l < "$scratch/lean.out") triples"

cut -d'|' -f1,2 "$scratch/lean.out" > "$scratch/lean.ts"
cut -d'|' -f1,3 "$scratch/lean.out" > "$scratch/lean.ail"

compare() {  # compare <name> <real> <model>; prints mismatch count, returns it via $mm
  if [[ "$(wc -l < "$2")" -ne "$(wc -l < "$3")" ]]; then
    echo "$1: LINE COUNT DIFFERS ($(wc -l < "$2") real, $(wc -l < "$3") model)"; mm=999999; return
  fi
  mm=$(paste -d'#' "$2" "$3" | awk -F'#' '$1 != $2' | wc -l)
  echo "$1: $(wc -l < "$2") triples, $mm mismatches"
  paste -d'#' "$2" "$3" | awk -F'#' '$1 != $2 && ++k <= 5 { print "    real " $1 "   model " $2 }'
}

fail=0
compare "diff TS     (model vs real readHerdrEnvironment)" "$scratch/ts.out" "$scratch/lean.ts"
[[ "$mm" -eq 0 ]] || fail=1
compare "diff AILANG (model vs real herdr_env_ready)    " "$scratch/ail.out" "$scratch/lean.ail"
[[ "$mm" -eq 0 ]] || fail=1

# --- P1.1 on the real code --------------------------------------------------------------
paste -d'|' "$scratch/ts.out" "$scratch/ail.out" | awk -F'|' -v alpha="$here/alphabet.json" '
  { ts_open = ($2 != "null"); ail_open = ($4 == "true") }
  ts_open != ail_open {
    n++; split($1, k, ",")
    if (ts_open) { tsw++; if (tsw <= 3) print "    TS open, AILANG shut:  " $0 }
    else         { aw++;  if (aw  <= 3) print "    AILANG open, TS shut:  " $0 }
  }
  END { printf "P1.1 on the real code: %d of %d triples disagree (%d TS-only, %d AILANG-only)\n", n, NR, tsw, aw }'
echo "axiom report: $scratch/axioms.txt"
grep -q "sorryAx" "$scratch/axioms.txt" && { echo "AXIOMS: sorryAx present"; fail=1; }

# --- negative control -------------------------------------------------------------------
if [[ "$mutants" -eq 1 ]]; then
  # TS mutant: `bin === undefined` -> `!bin` (the fix of witness B), in a copy of the module.
  mkdir -p "$scratch/mut_ts/src/tui/src"
  sed 's/if (!paneId || bin === undefined) return null;/if (!paneId || !bin) return null;/' \
    "$tree/src/tui/src/herdr-agent-state.ts" > "$scratch/mut_ts/src/tui/src/herdr-agent-state.ts"
  cmp -s "$tree/src/tui/src/herdr-agent-state.ts" "$scratch/mut_ts/src/tui/src/herdr-agent-state.ts" \
    && { echo "mutant TS: sed did not apply"; exit 1; }
  bun "$here/enumerate.ts" "$scratch/mut_ts" "$here/alphabet.json" > "$scratch/ts.mut"
  compare "mutant TS     (bin === undefined -> !bin)" "$scratch/ts.mut" "$scratch/lean.ts"
  [[ "$mm" -gt 0 ]] || { echo "  mutant NOT caught"; fail=1; }

  # AILANG mutant: `herdr_env >= "1"` -> `herdr_env == "1"`, in a copy of the package.
  mp="$scratch/mut_ail/packages/motoko-ext-herdr"; mkdir -p "$mp" "$scratch/mut_ail/drv"
  cp -r "$tree/packages/motoko-ext-herdr/." "$mp/"
  cp -r "$tree/packages/motoko-ext-abi" "$scratch/mut_ail/packages/"
  sed -i 's/{ herdr_env >= "1" \&\& bin_path != "" \&\& pane_id != "" }/{ herdr_env == "1" \&\& bin_path != "" \&\& pane_id != "" }/' "$mp/types.ail"
  cmp -s "$tree/packages/motoko-ext-herdr/types.ail" "$mp/types.ail" && { echo "mutant AILANG: sed did not apply"; exit 1; }
  sed 's#path = "../../tree/packages/#path = "../packages/#' "$here/ailang.toml" > "$scratch/mut_ail/drv/ailang.toml"
  cp "$here/enumerate_gate.ail" "$scratch/mut_ail/drv/"
  ( cd "$scratch/mut_ail/drv" && ailang lock >/dev/null && \
    ailang run --relax-modules --caps IO --entry main enumerate_gate.ail ) 2>/dev/null \
    | grep -E '^[u0-9]+,[u0-9]+,[u0-9]+\|' > "$scratch/ail.mut"
  compare "mutant AILANG (>= \"1\" -> == \"1\")      " "$scratch/ail.mut" "$scratch/lean.ail"
  [[ "$mm" -gt 0 ]] || { echo "  mutant NOT caught"; fail=1; }
fi

exit "$fail"
