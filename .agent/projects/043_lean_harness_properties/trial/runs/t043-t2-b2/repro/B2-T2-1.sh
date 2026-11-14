#!/usr/bin/env bash
# B2-T2-1 — run from the tree root: bash ../out/repro/B2-T2-1.sh
exec bun "$(dirname "$0")/check.ts" gone 1 \"\{\\\"error\\\":\{\\\"code\\\":\\\"pane_not_found\\\"\,\\\"message\\\":\\\"x\\\"\}\}\"
