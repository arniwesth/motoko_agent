#!/usr/bin/env bash
# ail_run.sh <tree root> <harness.ail> [entry] — run an AILANG harness that lives OUTSIDE the tree
# against the tree's REAL, unmodified code.
#
# ailang resolves `src/...` modules and `pkg/...` packages from the entry file's own
# directory, so a harness in ../out cannot be run in place. This builds a throwaway root
# whose ailang.toml, ailang.lock, src/ and packages/ are SYMLINKS to the tree's, copies the
# harness beside them, and runs it there. The root is made under ../runs and removed on exit.
# Nothing in the tree is written. stdout is the
# harness's; stderr carries ailang's notices.
set -euo pipefail
tree="$(cd "$1" && pwd)"
harness="$2"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$here/../runs"
root="$(mktemp -d "$here/../runs/.root.XXXXXX")"
trap 'rm -rf "$root"' EXIT
for f in ailang.toml ailang.lock src packages; do ln -s "$tree/$f" "$root/$f"; done
cp "$harness" "$root/"
cd "$root"
ailang run --relax-modules --caps IO --entry "${3:-main}" "$(basename "$harness")"
