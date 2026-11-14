#!/usr/bin/env bash
# run_ail.sh <tree> <harness.ail> [caps] [args...] — copies the harness into <tree>/zz_planter/ (a new
# file; nothing in the tree is changed) and runs it from the tree root, stdout only.
set -euo pipefail
tree="$1"; h="$2"; caps="${3:-IO}"; shift 3 || true
mkdir -p "$tree/zz_planter"; rm -f "$tree/zz_planter/$(basename "$h")"; cp "$h" "$tree/zz_planter/"
cd "$tree" && ailang run --relax-modules --caps "$caps" --entry main "zz_planter/$(basename "$h")" "$@" 2>/dev/null
