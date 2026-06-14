#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Operator-invoked held-out grader. Never wire this into ar_init benchmark_script.
source "$BENCH_DIR/lib.sh"
run_subset "$FIXTURE_DIR/splits/test.txt" "test"
