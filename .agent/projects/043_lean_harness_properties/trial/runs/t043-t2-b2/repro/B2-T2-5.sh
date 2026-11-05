#!/usr/bin/env bash
# B2-T2-5 — run from the tree root: bash ../out/repro/B2-T2-5.sh
exec bun "$(dirname "$0")/check.ts" gone 1 \"\{\\\"error\\\":\{\\\"code\\\":\\\"timeout\\\"\,\\\"code\\\":\\\"agent_not_found\\\"\}\}\"
