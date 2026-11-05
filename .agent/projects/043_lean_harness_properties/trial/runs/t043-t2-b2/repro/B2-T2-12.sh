#!/usr/bin/env bash
# B2-T2-12 — run from the tree root: bash ../out/repro/B2-T2-12.sh
exec bun "$(dirname "$0")/check.ts" code 1 \"\{\\\"error\\\":\"
