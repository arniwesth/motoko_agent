#!/usr/bin/env bash
# B2-T2-7 — run from the tree root: bash ../out/repro/B2-T2-7.sh
exec bun "$(dirname "$0")/check.ts" gone 1 \"\\u00a0\{\\\"error\\\":\{\\\"code\\\":\\\"agent_not_found\\\"\,\\\"message\\\":\\\"x\\\"\}\}\"
