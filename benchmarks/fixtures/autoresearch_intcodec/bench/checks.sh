#!/usr/bin/env bash
set -euo pipefail
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BENCH_DIR/lib.sh"

verify_immutable

cand="$INTCODEC_CANDIDATE"
test -s "$cand" || fail "candidate codec.c must not be empty"

# Behavioral-verifier smell test (weak by design; held-out transfer is the real
# signal). The candidate must be pure computation over the codec buffers — no
# file I/O, no reading the corpus, no canary, no path escapes. NEON intrinsics
# (#include <arm_neon.h>) are allowed; only double-quoted local includes are
# blocked. grep is a weak smell test by design — reading any corpus requires
# file I/O, which is caught here, and held-out transfer is the real anti-overfit
# signal.
if grep -nE 'fopen|freopen|fdopen|fread|fscanf|fwrite|[^_[:alnum:]]open[[:space:]]*\(|openat|popen|system[[:space:]]*\(|exec[lv]|mmap|getenv|socket|AR-INTCODEC|\.\./|#include[[:space:]]*"' \
  "$cand" >/dev/null; then
  fail "candidate appears to do I/O or escape its sandbox"
fi

# Build + a correctness canary spanning the tricky cases: empty/tiny files,
# counts that are not multiples of 4 (group tail), and the full 1..4 byte value
# range (so a dropped-tail or fixed-width codec is caught here).
scratch="${AR_BENCH_SCRATCH:-$REPO_ROOT/.motoko/ar_bench_scratch/intcodec_checks}"
rm -rf "$scratch"; mkdir -p "$scratch"
python3 "$FIXTURE_DIR/harness/gen_corpus.py" "$scratch/canary" 4242 "1,2,3,5,7,15,16,17,64,257" >/dev/null
bin="$scratch/codec_bin"
build_candidate "$bin"

out="$scratch/canary.out"
"$bin" "$scratch/canary" 50 3 > "$out" 2>/dev/null || fail "candidate failed gates on canary inputs"
grep -q '^CORRECTNESS_OK' "$out" || fail "candidate did not pass canary correctness"

# Benchmark contract.
grep -qE '^METRIC throughput_mbps=[0-9]+(\.[0-9]+)?$' "$out" || fail "no METRIC throughput_mbps"
grep -qE '^METRIC wall_ms=[0-9]+$' "$out" || fail "no METRIC wall_ms"

echo "checks: OK"
