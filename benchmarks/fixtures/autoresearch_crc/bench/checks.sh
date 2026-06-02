#!/usr/bin/env bash
set -euo pipefail
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BENCH_DIR/lib.sh"

verify_immutable

cand="$CRC_CANDIDATE"
test -s "$cand" || fail "candidate crc.c must not be empty"

# Behavioral-verifier smell test (weak by design; held-out transfer is the real
# signal). The candidate must be pure computation over (data,len) — no file I/O,
# no reading the corpus/reference, no path escapes. NEON/crypto intrinsics
# (#include <arm_neon.h>) are allowed; only double-quoted local includes blocked.
if grep -nE 'fopen|freopen|fdopen|fread|fscanf|fwrite|[^_[:alnum:]]open[[:space:]]*\(|openat|popen|system[[:space:]]*\(|exec[lv]|mmap|getenv|socket|AR-CRC|\.\./|#include[[:space:]]*"' \
  "$cand" >/dev/null; then
  fail "candidate appears to do I/O or escape its sandbox"
fi

# Build + a correctness canary spanning the tricky cases: empty/tiny buffers,
# lengths that are not multiples of common block widths (head/tail), and lengths
# straddling 16/64-byte boundaries (catches block-parallel candidates that drop
# the tail). The canary uses a deterministic small corpus.
scratch="${AR_BENCH_SCRATCH:-$REPO_ROOT/.motoko/ar_bench_scratch/crc_checks}"
rm -rf "$scratch"; mkdir -p "$scratch"
python3 "$FIXTURE_DIR/harness/gen_corpus.py" "$scratch/canary" 4242 \
  "0,1,2,3,7,8,15,16,17,31,63,64,65,127,128,129,255,1000" >/dev/null
bin="$scratch/crc_bin"
build_candidate "$bin"

out="$scratch/canary.out"
"$bin" "$scratch/canary" 20 3 > "$out" 2>/dev/null || fail "candidate failed correctness on canary inputs"
grep -q '^CORRECTNESS_OK' "$out" || fail "candidate did not pass canary correctness"

grep -qE '^METRIC throughput_mbps=[0-9]+(\.[0-9]+)?$' "$out" || fail "no METRIC throughput_mbps"
grep -qE '^METRIC wall_ms=[0-9]+$' "$out" || fail "no METRIC wall_ms"

echo "checks: OK"
