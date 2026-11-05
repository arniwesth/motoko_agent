#!/usr/bin/env bash
# From the tree root: bash ../out/repro/repro_P4_2.sh   — exit 1 iff P4.2 is violated.
exec "$(cd "$(dirname "$0")" && pwd)/verdict.sh" "$(cd "$(dirname "$0")" && pwd)/repro_P4_2.ail"
