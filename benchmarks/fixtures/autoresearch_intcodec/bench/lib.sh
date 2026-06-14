#!/usr/bin/env bash
set -euo pipefail

fail() { echo "CHECK FAILED: $1" >&2; exit 1; }

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="$(cd "$BENCH_DIR/.." && pwd)"
REPO_ROOT="$(cd "$FIXTURE_DIR/../../.." && pwd)"

# The candidate file (the only thing the optimizer edits). Defaults to the
# in-tree copy; the autoresearch harness points this at the linked worktree so
# the measured file is the committed file.
INTCODEC_CANDIDATE="${INTCODEC_CANDIDATE:-$FIXTURE_DIR/candidate/codec.c}"

verify_immutable() {
  (cd "$FIXTURE_DIR" && sha256sum -c immutable.sha256 >/dev/null)
}

# Compile harness + candidate; abort (no METRIC) on build failure so a broken
# candidate cannot be kept. Plain -O2 (aarch64 NEON intrinsics are baseline, no
# -march needed) — matches the simdscan fixture.
build_candidate() {
  local bin="$1"
  test -f "$INTCODEC_CANDIDATE" || fail "candidate not found: $INTCODEC_CANDIDATE"
  gcc -O2 -o "$bin" "$FIXTURE_DIR/harness/main.c" "$INTCODEC_CANDIDATE" \
    2> "${bin}.cc.err" || fail "candidate failed to compile: $(tail -3 "${bin}.cc.err")"
}

run_split() {
  local corpus="$1" label="$2"
  verify_immutable
  test -d "$corpus" || fail "corpus dir missing: $corpus"

  local scratch="${AR_BENCH_SCRATCH:-$REPO_ROOT/.motoko/ar_bench_scratch/intcodec_${label}}"
  rm -rf "$scratch"; mkdir -p "$scratch"
  local bin="$scratch/codec_bin"
  build_candidate "$bin"

  local reps="${INTCODEC_REPS:-300}" rounds="${INTCODEC_ROUNDS:-7}"
  # The binary exits non-zero (and prints no METRIC) on a compression or
  # correctness gate failure, which fails the run and blocks keep.
  "$bin" "$corpus" "$reps" "$rounds"
}
