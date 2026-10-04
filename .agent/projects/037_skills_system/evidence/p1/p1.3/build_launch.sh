#!/usr/bin/env bash
# 037 P1.3: (re)build the disposable LAUNCH directory: a copy of this worktree's
# files without .git. Sessions are started from it, so an in-process BashExec
# (whose cwd is the launch directory) cannot write into the worktree or reach
# its git metadata. The workdir is a sibling under the same /tmp parent, so this
# is layout 1 (workdir outside the launch directory, absolute --workdir).
# Run from the worktree root.
#   .motoko/herdr-delegates/p1.3/build_launch.sh [dir]   (default /tmp/motoko-037-p1.3/launch)
set -euo pipefail
L="${1:-/tmp/motoko-037-p1.3/launch}"
mkdir -p "$L"
rsync -a --delete \
  --exclude '/.git' --exclude '/.motoko/herdr-delegates' --exclude 'node_modules' \
  ./ "$L/"
echo "launch dir at $L ($(du -sh "$L" | cut -f1))"
