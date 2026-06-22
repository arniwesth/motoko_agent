#!/usr/bin/env bash
set -euo pipefail
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BENCH_DIR/lib.sh"

verify_immutable

cand="$SIMDSCAN_CANDIDATE"
test -s "$cand" || fail "candidate scan.c must not be empty"

# Behavioral-verifier smell test (weak by design; held-out transfer is the real
# signal). The candidate must be pure computation over (buf,len,out) — no file
# I/O, no reading the corpus/reference/held-out, no canary, no path escapes.
# Match real I/O / sandbox-escape calls, not keywords in comments (grep is a weak
# smell test by design; reading the held-out corpus requires file I/O, which is
# caught here, and held-out transfer is the real anti-overfit signal).
if grep -nE 'fopen|freopen|fdopen|fread|fscanf|fwrite|[^_[:alnum:]]open[[:space:]]*\(|openat|popen|system[[:space:]]*\(|exec[lv]|mmap|getenv|socket|AR-SIMDSCAN|\.\./|#include[[:space:]]*"' \
  "$cand" >/dev/null; then
  fail "candidate appears to do I/O or escape its sandbox"
fi

# Build + a tiny correctness canary that exercises all four special bytes and the
# sub-16-byte tail (catches vectorized candidates that drop the tail).
scratch="${AR_BENCH_SCRATCH:-$REPO_ROOT/.motoko/ar_bench_scratch/simdscan_checks}"
rm -rf "$scratch"; mkdir -p "$scratch/canary"
bin="$scratch/scan_bin"
build_candidate "$bin"

printf '' > "$scratch/canary/empty.bin"
printf '<' > "$scratch/canary/one.bin"                       # 1 byte, special at tail
printf 'abc&' > "$scratch/canary/short_amp.bin"              # len 4, special at end
printf 'plain text with no specials here ok' > "$scratch/canary/none.bin"
printf 'sixteen_bytes!!!\r\0<&' > "$scratch/canary/tail.bin" # specials after the first 16B block
out="$scratch/canary.out"
"$bin" "$scratch/canary" 50 3 > "$out" 2>/dev/null || fail "candidate failed correctness on canary inputs"
grep -q '^CORRECTNESS_OK' "$out" || fail "candidate did not pass canary correctness"

# Benchmark contract.
grep -qE '^METRIC throughput_mbps=[0-9]+(\.[0-9]+)?$' "$out" || fail "no METRIC throughput_mbps"
grep -qE '^METRIC wall_ms=[0-9]+$' "$out" || fail "no METRIC wall_ms"

echo "checks: OK"
