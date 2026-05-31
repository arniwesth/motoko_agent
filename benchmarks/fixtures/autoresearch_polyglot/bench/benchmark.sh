#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# TRAIN-only benchmark for ar_run. TEST is intentionally absent from this path.
source "$BENCH_DIR/lib.sh"
run_subset "$FIXTURE_DIR/splits/train.txt" "train"
