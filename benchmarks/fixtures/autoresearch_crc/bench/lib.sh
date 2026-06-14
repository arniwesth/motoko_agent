#!/usr/bin/env bash
set -euo pipefail

fail() { echo "CHECK FAILED: $1" >&2; exit 1; }

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="$(cd "$BENCH_DIR/.." && pwd)"
REPO_ROOT="$(cd "$FIXTURE_DIR/../../.." && pwd)"

# The candidate file (the only thing the optimizer edits). Defaults to the
# in-tree copy; the autoresearch harness points this at the linked worktree so
# the measured file is the committed file.
CRC_CANDIDATE="${CRC_CANDIDATE:-$FIXTURE_DIR/candidate/crc.c}"

verify_immutable() {
  (cd "$FIXTURE_DIR" && sha256sum -c immutable.sha256 >/dev/null)
}

# Compile harness + candidate; abort (no METRIC) on build failure so a broken
# candidate cannot be kept. -march=armv8-a+crypto enables NEON AND the carry-less
# multiply intrinsics (vmull_p64); it does NOT enable the hardware crc32
# instruction's polynomials (which are useless for this custom polynomial anyway).
build_candidate() {
  local bin="$1"
  test -f "$CRC_CANDIDATE" || fail "candidate not found: $CRC_CANDIDATE"
  gcc -O2 -march=armv8-a+crypto -o "$bin" "$FIXTURE_DIR/harness/main.c" "$CRC_CANDIDATE" \
    2> "${bin}.cc.err" || fail "candidate failed to compile: $(tail -3 "${bin}.cc.err")"
}

run_split() {
  local corpus="$1" label="$2"
  verify_immutable
  test -d "$corpus" || fail "corpus dir missing: $corpus"

  local scratch="${AR_BENCH_SCRATCH:-$REPO_ROOT/.motoko/ar_bench_scratch/crc_${label}}"
  rm -rf "$scratch"; mkdir -p "$scratch"
  local bin="$scratch/crc_bin"
  build_candidate "$bin"

  local reps="${CRC_REPS:-100}" rounds="${CRC_ROUNDS:-7}"
  # The binary exits non-zero (and prints no METRIC) on a correctness mismatch,
  # which fails the run and blocks keep.
  "$bin" "$corpus" "$reps" "$rounds"
}
