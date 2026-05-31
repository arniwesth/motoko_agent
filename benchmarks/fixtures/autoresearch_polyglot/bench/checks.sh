#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BENCH_DIR/lib.sh"

verify_immutable
ensure_polyglot_env

prompt="$REPO_ROOT/benchmarks/prompts/polyglot_system.md"
test -s "$prompt" || fail "polyglot system prompt must not be empty"

if grep -R -n -E 'AR-POLYGLOT-0_5A|splits/test.txt|grade_test.sh|dominoes|ledger|minesweeper|satellite' \
  "$REPO_ROOT/benchmarks/prompts/polyglot_system.md" >/dev/null; then
  fail "candidate prompt appears to reference held-out TEST or the canary"
fi

scratch="${AR_BENCH_SCRATCH:-$REPO_ROOT/.motoko/ar_bench_scratch/polyglot_checks}"
rm -rf "$scratch"
mkdir -p "$scratch"
printf 'hello-world\n' > "$scratch/check_split.txt"

out="$scratch/contract.out"
POLYGLOT_HEARTBEAT_SECS=0 \
POLYGLOT_CORE_EXT_ORDER="${POLYGLOT_CORE_EXT_ORDER:-context_mode,exa_search}" \
run_subset "$scratch/check_split.txt" "checks_contract" > "$out"

grep -qE '^METRIC pass_rate=([01](\.[0-9]+)?)$' "$out" \
  || fail "benchmark contract did not emit METRIC pass_rate"
grep -qE '^METRIC wall_ms=[0-9]+$' "$out" \
  || fail "benchmark contract did not emit METRIC wall_ms"

echo "checks: OK"
