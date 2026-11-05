#!/usr/bin/env bash
# B2-T2-14 — run from the tree root: bash ../out/repro/B2-T2-14.sh
exec bun "$(dirname "$0")/check.ts" gone 1 \"\{\\\"error\\\":\{\\\"code\\\":\\\"agent_not_found\\\"\,\\\"message\\\":\\\"x\\\"\}\,\\\"n\\\":1e999\}\"
