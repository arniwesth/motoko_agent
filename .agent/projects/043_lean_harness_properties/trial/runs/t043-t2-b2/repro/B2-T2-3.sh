#!/usr/bin/env bash
# B2-T2-3 — run from the tree root: bash ../out/repro/B2-T2-3.sh
exec bun "$(dirname "$0")/check.ts" gone 1 \"\{\\\"id\\\":\\\"cli:agent:get\\\"\,\\\"error\\\":\{\\\"code\\\":\\\"agent_not_found\\\"\}\}\"
