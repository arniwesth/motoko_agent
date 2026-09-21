#!/usr/bin/env bash
# P1.2b: run exa-search's own tests at a git revision (default 181051d0, ABI 7.4) in a lock-free
# workspace -- ABI, motoko-ext-mcp and exa-search all read with `git show <rev>:` -- to show which
# failures predate this part. Run from a repo root.
set -uo pipefail
REV=${1:-181051d0}
T=$(mktemp -d "${TMPDIR:-/tmp}/p12bexa74.XXXXXX"); trap 'rm -rf "$T"' EXIT
for p in motoko-ext-abi motoko-ext-mcp motoko-ext-exa-search; do
  mkdir -p "$T/packages/$p"
  for f in $(git ls-tree --name-only $REV packages/$p/); do
    b=$(basename "$f"); case $b in *.ail|ailang.toml|*.mjs) git show $REV:"$f" > "$T/packages/$p/$b";; esac; done
done
cat > "$T/ailang.toml" <<TOML
[package]
name = "local/p12bexa74"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"
[dependencies]
"sunholo/motoko_ext_abi" = { path = "packages/motoko-ext-abi" }
"sunholo/motoko_ext_mcp" = { path = "packages/motoko-ext-mcp" }
"sunholo/motoko_ext_exa_search" = { path = "packages/motoko-ext-exa-search" }
[effects]
max = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "Rand", "Trace"]
TOML
cd "$T" && ailang lock > lock.log 2>&1 || { tail -5 lock.log; exit 1; }
echo "exa-search tests at $REV (ABI $(sed -nE 's/^version = "(.*)"/\1/p' packages/motoko-ext-abi/ailang.toml)):"
AILANG_RELAX_MODULES=1 ailang test packages/motoko-ext-exa-search/exa_search.ail 2>&1 | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -E '✓|✗|tests:|expected'
