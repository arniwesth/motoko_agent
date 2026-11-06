#!/usr/bin/env bash
# Differential test for the EXPLORATORY part of ../HerdrGateModel.lean: the model of the path
# the variables take in the running system (`forward`, `getEnvOr`, `registerGate`), which
# X-1 and X-2 rest on. Same alphabet as run_diff.sh (gen_inputs.py, same seed).
#
#   1. host: the REAL readHerdrEnvironment(process.env) and buildChildEnv's forwarded HERDR_*
#      (enumerate_chain.ts), against the model's readHerdrEnvironment and forwardEnv jsBlank,
#      over every triple: must match;
#   2. runtime: the REAL register_with_config (chain_ail_sample.py, one `ailang run` per input)
#      against the model's registerGate, on a seeded sample of the distinct forwarded triples:
#      must match;
#   3. the chain on the real code: how many triples have the TS gate and the runtime's gate
#      disagreeing, among those whose forwarded triple was sampled.
#
#   run_chain.sh [seed] [sample size] [scratch dir]
#
# Exit 0: no mismatch in 1 or 2. Exit 1: a mismatch. Exit 2: a toolchain is missing.
set -euo pipefail
seed="${1:-43}"
nsample="${2:-240}"
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
tree="$(cd "$out/../tree" && pwd)"
scratch="${3:-$(mktemp -d)}"
mkdir -p "$scratch/wd"
LEAN="${LEAN:-$(command -v lean || echo "$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin/lean")}"
for t in bun ailang python3; do command -v "$t" >/dev/null || { echo "NOT RUN -- no $t"; exit 2; }; done
[[ -x "$LEAN" ]] || { echo "NOT RUN -- no lean"; exit 2; }

python3 "$here/gen_inputs.py" "$here" "$seed"
pat='^[u0-9]+,[u0-9]+,[u0-9]+\|'

bun "$here/enumerate_chain.ts" "$tree" "$here/alphabet.json" "$scratch/wd" > "$scratch/chain_ts.out"
echo "host:    $(wc -l < "$scratch/chain_ts.out") triples, sha256 $(sha256sum "$scratch/chain_ts.out" | cut -c1-16)"

cat "$out/HerdrGateModel.lean" "$here/enumerate_chain.lean.tail" > "$scratch/EnumerateChain.lean"
"$LEAN" "$scratch/EnumerateChain.lean" | grep -E "$pat" > "$scratch/chain_lean.out"
echo "model:   $(wc -l < "$scratch/chain_lean.out") triples"

fail=0
cut -d'|' -f1-3 "$scratch/chain_lean.out" > "$scratch/chain_lean.host"
mm=$(paste -d'#' "$scratch/chain_ts.out" "$scratch/chain_lean.host" | awk -F'#' '$1 != $2' | wc -l)
echo "diff host (gate + forwarded HERDR_*): $(wc -l < "$scratch/chain_ts.out") triples, $mm mismatches"
paste -d'#' "$scratch/chain_ts.out" "$scratch/chain_lean.host" | awk -F'#' '$1 != $2 && ++k <= 5 { print "    real " $1 "   model " $2 }'
[[ "$mm" -eq 0 ]] || fail=1

CHAIN_WORKDIR="$scratch/wd" python3 -I "$here/chain_ail_sample.py" "$here/alphabet.json" \
  "$scratch/chain_ts.out" "$nsample" "$seed" > "$scratch/chain_ail.out"
echo "runtime: $(wc -l < "$scratch/chain_ail.out") distinct forwarded triples sampled, $(grep -c ERROR "$scratch/chain_ail.out" || true) errors"
grep -q ERROR "$scratch/chain_ail.out" && fail=1

# model registerGate per forwarded triple (it is a function of the forwarded triple only)
awk -F'|' '{ print $3 "|" $4 }' "$scratch/chain_lean.out" | sort -u > "$scratch/chain_lean.reg"
awk -F'|' 'NR == FNR { m[$1] = $2; next }
  { n++; if (!($1 in m)) { miss++; next } if (m[$1] != $2) { bad++; if (bad <= 5) print "    real " $0 "   model " m[$1] } }
  END { printf "diff runtime (register_with_config): %d sampled, %d mismatches, %d not in model\n", n, bad + 0, miss + 0; exit (bad + miss > 0) }' \
  "$scratch/chain_lean.reg" "$scratch/chain_ail.out" || fail=1

# the chain on the real code, over every triple whose forwarded triple was sampled
awk -F'|' 'NR == FNR { r[$1] = $2; next }
  ($3 in r) { n++; ts = ($2 != "null"); rt = (r[$3] == "true")
    if (ts != rt) { d++; if (ts) tso++; else rto++
      if ((ts && tso <= 3) || (!ts && rto <= 3)) print "    " (ts ? "TS open, runtime shut:  " : "runtime open, TS shut:  ") $0 "|" r[$3] } }
  END { printf "chain on the real code: %d of %d covered triples disagree (%d TS-only, %d runtime-only)\n", d, n, tso, rto }' \
  "$scratch/chain_ail.out" "$scratch/chain_ts.out"
exit "$fail"
