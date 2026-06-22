#!/usr/bin/env bash
set -euo pipefail
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# TRAIN-only benchmark for ar_run. The held-out TEST corpus is never referenced here.
source "$BENCH_DIR/lib.sh"
run_split "$FIXTURE_DIR/corpus/train" "train"
