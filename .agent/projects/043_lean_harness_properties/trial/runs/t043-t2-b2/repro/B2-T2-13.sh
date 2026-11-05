#!/usr/bin/env bash
# B2-T2-13 — run from the tree root: bash ../out/repro/B2-T2-13.sh
exec bun "$(dirname "$0")/check.ts" x1 -1 \"killed\ by\ SIGTERM\"
