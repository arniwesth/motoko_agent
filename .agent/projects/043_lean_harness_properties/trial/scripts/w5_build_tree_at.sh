#!/usr/bin/env bash
# W5: build_tree.sh's tree (PLAN-001 §7, A1 item 3, A2 item 1) from another base commit, for
# re-running the unknown real defects on origin/main (PLAN-001 §8, §12 W5). The steps are
# build_tree.sh's, unchanged, except that the base is an argument instead of BASE (43530c0a):
# the base's tracked files, plus project 043 from PLAN-001's own commit, 12672be8, without
# PLAN-001-*.md and trial/, without .git, .agent/github/, AGENTS.md, tools/code-graph/AGENTS.md,
# .claude/ and .mcp.json. No seeds.
#   w5_build_tree_at.sh <dest> <commit>      prints the tree's sha256
set -euo pipefail
source "$(dirname "$0")/common.sh"
dest="$1"; base="$2"
[ -e "$dest" ] && { echo "w5_build_tree_at: $dest exists" >&2; exit 1; }
mkdir -p "$dest"
git -C "$REPO" archive "$base" | tar -x -C "$dest"
git -C "$REPO" archive 12672be8 .agent/projects/043_lean_harness_properties | tar -x -C "$dest"
p="$dest/.agent/projects/043_lean_harness_properties"
rm -rf "$p"/PLAN-001-*.md "$p/trial" "$dest/.agent/github" "$dest/AGENTS.md" "$dest/tools/code-graph/AGENTS.md" "$dest/.claude" "$dest/.mcp.json"
hash_dir "$dest"
