#!/usr/bin/env bash
# The trial tree (PLAN-001 §7, A1 item 3): BASE's tracked files, plus project 043 from
# PROJECT_REF (default HEAD) without PLAN-001-*.md and trial/, without .git, .agent/github/,
# AGENTS.md, tools/code-graph/AGENTS.md, .claude/ and .mcp.json (A1 item 3, A2 item 1);
# then the seeds, if a patch is given.
#   build_tree.sh <dest> [seeds.patch]      prints the tree's sha256
set -euo pipefail
source "$(dirname "$0")/common.sh"
dest="$1"; seeds="${2:-}"
[ -e "$dest" ] && { echo "build_tree: $dest exists" >&2; exit 1; }
mkdir -p "$dest"
git -C "$REPO" archive "$BASE" | tar -x -C "$dest"
git -C "$REPO" archive "${PROJECT_REF:-HEAD}" .agent/projects/043_lean_harness_properties | tar -x -C "$dest"
p="$dest/.agent/projects/043_lean_harness_properties"
rm -rf "$p"/PLAN-001-*.md "$p/trial" "$dest/.agent/github" "$dest/AGENTS.md" "$dest/tools/code-graph/AGENTS.md" "$dest/.claude" "$dest/.mcp.json"
if [ -n "$seeds" ]; then (cd "$dest" && patch -s -p1 < "$seeds"); fi
hash_dir "$dest"
