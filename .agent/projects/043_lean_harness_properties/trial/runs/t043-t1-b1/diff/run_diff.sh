#!/usr/bin/env bash
# diff/run_diff.sh — step (2): the Lean model against the real code, on generated inputs.
#
# Three halves over every triple (HERDR_ENV, HERDR_BIN_PATH, HERDR_PANE_ID) of the alphabet
# gen_alphabet.py writes (36 values, index 0 = unset, so 46,656 triples):
#
#   * Lean:   ../HerdrGateModel.lean + alphabet.lean + enumerate.lean.tail  (the model)
#   * bun:    enumerate.ts, the REAL readHerdrEnvironment (src/tui/src/herdr-agent-state.ts)
#   * ailang: enumerate_gate.ail, the REAL herdr_env_ready (packages/motoko-ext-herdr/types.ail),
#             imported by path through ./ailang.toml, unchanged
#
# Comparisons:
#   1. model readHerdrEnvironment  vs real readHerdrEnvironment   (must be 0 mismatches)
#   2. model herdrEnvReady         vs real herdr_env_ready         (must be 0 mismatches)
#   3. real vs real: P1.1 itself, TS non-null iff AILANG true. Reported, not failed on: it is
#      the property under test, and its counterexamples are the findings.
#
#   run_diff.sh [scratch dir]            needs lean 4.28.0, bun and ailang v0.54.14 on PATH
#   run_diff.sh --control [scratch dir]  negative control: the same run against two MUTATED
#                                        COPIES OF THE MODEL (never the real code); each must
#                                        produce mismatches, or the test is blind
#
# Env: REPO (default ../../tree) is the snapshot root. Exit 0 iff comparisons 1 and 2 found no
# mismatch (with --control: iff every mutant was caught).
set -euo pipefail

control=0
if [[ "${1:-}" == "--control" ]]; then control=1; shift; fi

here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
repo="$(cd "${REPO:-$out/../tree}" && pwd)"
scratch="${1:-$(mktemp -d)}"
mkdir -p "$scratch"

for t in lean bun ailang python3; do
  command -v "$t" >/dev/null || { echo "NOT RUN -- no $t on PATH"; exit 2; }
done

python3 "$here/gen_alphabet.py" "$here" >/dev/null
cat "$here/enumerate_gate.ail.head" "$here/alphabet.ail" > "$here/enumerate_gate.ail"

# --- real halves ---------------------------------------------------------------------------
bun "$here/enumerate.ts" "$repo" "$here/alphabet.json" > "$scratch/ts.out"
( cd "$here" && ailang run --relax-modules --caps IO --entry main enumerate_gate.ail ) \
  > "$scratch/ail.raw" 2> "$scratch/ail.err"
grep -E '^[0-9]+,[0-9]+,[0-9]+\|' "$scratch/ail.raw" > "$scratch/ail.out"
echo "ts:  $(wc -l < "$scratch/ts.out") triples, sha256 $(sha256sum "$scratch/ts.out" | cut -c1-16)"
echo "ail: $(wc -l < "$scratch/ail.out") triples, sha256 $(sha256sum "$scratch/ail.out" | cut -c1-16)"

# --- the model -----------------------------------------------------------------------------
run_model() {  # $1 = model file, $2 = tag; sets lean_rc (a mutant's broken proofs make it 1)
  cat "$1" "$here/alphabet.lean" "$here/enumerate.lean.tail" > "$scratch/Enumerate.$2.lean"
  lean_rc=0
  lean "$scratch/Enumerate.$2.lean" > "$scratch/lean.$2.raw" || lean_rc=$?
  grep -E '^[0-9]+,[0-9]+,[0-9]+\|' "$scratch/lean.$2.raw" > "$scratch/lean.$2.out" || true
  grep -vE '^[0-9]+,[0-9]+,[0-9]+\|' "$scratch/lean.$2.raw" > "$scratch/axioms.$2.txt" || true
  cut -d'|' -f1,2 "$scratch/lean.$2.out" > "$scratch/lean.$2.ts"
  cut -d'|' -f1,3 "$scratch/lean.$2.out" > "$scratch/lean.$2.ail"
}
compare() {  # $1 = tag; prints the two mismatch counts, returns their sum
  local a b
  a=$(diff "$scratch/ts.out"  "$scratch/lean.$1.ts"  | grep -c '^<' || true)
  b=$(diff "$scratch/ail.out" "$scratch/lean.$1.ail" | grep -c '^<' || true)
  echo "  [$1] model vs real readHerdrEnvironment: $a mismatches; model vs real herdr_env_ready: $b mismatches"
  return $(( a + b > 0 ? 1 : 0 ))
}

if [[ "$control" -eq 1 ]]; then
  caught=0; total=0
  # M1: AILANG side compares with `==` (the fix) instead of `>=`.
  sed 's/strGe herdrEnv \[.1.\] \&\& binPath/herdrEnv == ['"'"'1'"'"'] \&\& binPath/' \
    "$out/HerdrGateModel.lean" > "$scratch/M1.lean"
  # M2: TypeScript side tests `!bin` (the fix) instead of `bin === undefined`.
  sed 's/if falsy paneId || binPath == none then none else/if falsy paneId || falsy binPath then none else/' \
    "$out/HerdrGateModel.lean" > "$scratch/M2.lean"
  # M3: the code-point order is replaced by a length-first order (a plausible misreading of >=).
  sed 's/^def strGe (a b : Str) : Bool := !strLt a b/def strGe (a b : Str) : Bool := a.length > b.length || (a.length == b.length \&\& !strLt a b)/' \
    "$out/HerdrGateModel.lean" > "$scratch/M3.lean"
  for m in M1 M2 M3; do
    total=$((total + 1))
    if cmp -s "$scratch/$m.lean" "$out/HerdrGateModel.lean"; then echo "  [$m] sed did not apply"; continue; fi
    run_model "$scratch/$m.lean" "$m"
    if compare "$m"; then echo "  [$m] NOT CAUGHT"; else caught=$((caught + 1)); echo "  [$m] caught"; fi
  done
  echo "control: $caught of $total mutants of the model caught"
  [[ "$caught" -eq "$total" ]]
  exit $?
fi

run_model "$out/HerdrGateModel.lean" model
cp "$scratch/axioms.model.txt" "$scratch/axioms.txt"
status=0
if [[ "$lean_rc" -ne 0 ]]; then
  echo "lean: the model does NOT check (exit $lean_rc); see $scratch/axioms.txt"; status=1
else
  echo "lean: the model checks; $(grep -c 'axioms' "$scratch/axioms.txt" || true) axiom lines"
fi
compare model || status=1
if [[ "$status" -ne 0 ]]; then
  echo "differential: MISMATCH -- the model does not match the real code"
  diff "$scratch/ts.out"  "$scratch/lean.model.ts"  | head -10 || true
  diff "$scratch/ail.out" "$scratch/lean.model.ail" | head -10 || true
else
  echo "differential: $(wc -l < "$scratch/ts.out") triples, 0 mismatches on either side"
fi

# --- P1.1 on the real code, no model in between --------------------------------------------
paste -d'|' "$scratch/ts.out" "$scratch/ail.out" | awk -F'|' -v alpha="$here/alphabet.json" '
  { ts = ($2 != "null"); ail = ($4 == "true")
    if (ts != ail) {
      split($1, ix, ",")
      bad++
      key = (ts ? "TS non-null, AILANG false" : "TS null, AILANG true")
      cls[key]++
      if (!(key in first)) first[key] = $0
      if (ix[1] != 2) env[ix[1]]++; else bin[ix[2]]++
    } }
  END {
    printf "P1.1 on the real code: %d of %d triples disagree\n", bad + 0, NR
    for (k in cls) printf "  %-26s %6d   first: %s\n", k, cls[k], first[k]
    printf "  HERDR_ENV indices (not \"1\") that open only the AILANG gate:"; for (i in env) printf " %s", i; printf "\n"
    printf "  HERDR_BIN_PATH indices that open only the TS gate (HERDR_ENV=\"1\"):"; for (j in bin) printf " %s", j; printf "\n"
  }' | tee "$scratch/p11.txt"
echo "axiom report: $scratch/axioms.txt"
exit "$status"
