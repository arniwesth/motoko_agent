#!/usr/bin/env bash
# mkcopy.sh <tree root> <dest> — the minimal copy of the tree the harnesses need, for
# negative controls: src/tui/src (the TS gate and buildChildEnv with their imports) and
# packages/motoko-ext-{abi,herdr}. The harnesses run against <dest> exactly as against the
# tree, by being run with <dest> as the working directory.
set -euo pipefail
src="$(cd "$1" && pwd)"; dst="$2"
mkdir -p "$dst/src/tui" "$dst/packages"
cp -r "$src/src/tui/src" "$dst/src/tui/"
cp "$src/src/tui/package.json" "$src/src/tui/tsconfig.json" "$dst/src/tui/" 2>/dev/null || true
cp -r "$src/packages/motoko-ext-abi" "$src/packages/motoko-ext-herdr" "$dst/packages/"
