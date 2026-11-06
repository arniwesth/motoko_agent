#!/usr/bin/env bash
# run_ail.sh FILE.ail — run one repro against the REAL src/core/journal.ail, unmodified.
# ailang resolves `src/...`/`pkg/...` from the ailang.toml above the entry file, so the entry
# is copied into a mirror of the tree's package root made of symlinks (out/repro/.mirror);
# nothing in the tree is written. Prints the program's stdout; exits with ailang's status.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="${TREE:-$(cd "$here/../../tree" && pwd)}"
mirror="$here/.mirror${TREE:+_alt}"
mkdir -p "$mirror"
for f in ailang.toml ailang.lock src packages; do ln -sfn "$tree/$f" "$mirror/$f"; done
cp "$1" "$mirror/$(basename "$1")"
cd "$mirror" && ailang run --relax-modules --caps IO --entry main "$(basename "$1")" 2> "$mirror/stderr.txt"
