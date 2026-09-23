#!/usr/bin/env bash
# `make dst DST_JOBS=1` in a fresh clone. $1 = tag, $2 = optional patched dst_corpus.ail
set -uo pipefail
ROOT=/tmp/claude-1001/-workspaces-motoko-agent/bd8176ff-ae08-43f2-b32d-d7d1bfa1141e/scratchpad/d11
PRIMARY=/workspaces/motoko_agent
TAG="$1"; CLONE=$ROOT/clone-dst-$TAG
rm -rf "$CLONE"
git clone -q --no-hardlinks "$PRIMARY" "$CLONE" || exit 1
git -C "$CLONE" checkout -q cdf0f65f || exit 1
if [ -n "${2:-}" ]; then cp "$2" "$CLONE/src/core/dst_corpus.ail" || exit 1; fi
( cd "$CLONE" && make CI=1 sync_packages ) > "$ROOT/dst-$TAG-sync.log" 2>&1 || { echo "SYNC_FAIL $TAG"; exit 1; }
grep -q "$CLONE" "$CLONE/ailang.lock" || { echo "LOCK_NOT_REPOINTED $TAG"; exit 1; }
s=$(date +%s)
( cd "$CLONE" && make dst DST_JOBS=1 ) > "$ROOT/dst-$TAG.out" 2>&1; rc=$?
e=$(date +%s)
echo "DST $TAG rc=$rc elapsed_s=$((e-s))"
grep -cE "^  ✗|^✗|FAIL:" "$ROOT/dst-$TAG.out" 2>/dev/null | sed "s/^/DST $TAG red_lines=/"
echo "DST $TAG COMPLETE"
