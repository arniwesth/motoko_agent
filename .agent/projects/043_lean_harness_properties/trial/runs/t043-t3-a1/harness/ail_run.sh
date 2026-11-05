#!/usr/bin/env bash
# ail_run.sh <harness.ail> [ENV=VAL ...] — run an AILANG harness from the tree root.
# ailang resolves `src/core/...` and `pkg/...` imports only for a file inside the
# package, so the harness is copied into a transient directory under the tree root
# and removed on exit. Nothing in the tree is modified.
# T3_JOURNAL_PATCHED: see below (negative controls only).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# The tree: T3_TREE, else the current directory when it is the repository root, else ../../tree.
if [[ -n "${T3_TREE:-}" ]]; then tree="$T3_TREE"; elif [[ -f "$PWD/src/core/journal.ail" ]]; then tree="$PWD"; else tree="$(cd "$here/../../tree" && pwd)"; fi
export T3_TREE="$tree"
src="$1"; shift
envs="$(IFS=,; echo "$*")"
cd "$tree"
d="$(mktemp -d t3h_XXXXXX)"
trap 'rm -rf "$tree/$d"' EXIT
cp "$src" "$d/"
# Negative controls: T3_JOURNAL_PATCHED=<a patched copy of src/core/journal.ail> is copied
# beside the harness and the harness imports it instead of the real module.
if [[ -n "${T3_JOURNAL_PATCHED:-}" ]]; then
  cp "$T3_JOURNAL_PATCHED" "$d/journal_patched.ail"
  sed -i "s|^import src/core/journal (|import $d/journal_patched (|" "$d/$(basename "$src")"
fi
ailang run --relax-modules --caps IO,FS,Env ${envs:+--env "$envs"} --entry main "$d/$(basename "$src")"
