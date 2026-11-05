#!/usr/bin/env bash
# Builds, in a scratch dir, a copy of the compose package whose ONLY change is the word
# `export` before `func truncate_utf8_by_bytes` (store.ail:20), so that the function can be
# called directly on inputs its caller never forwards (byte length <= max). Refuses to go on
# unless `diff` shows exactly that one-line change. The tree itself is never written.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "$here/../../../tree" && pwd)"
scratch="${1:?scratch dir}"
pk="$scratch/pkgs"
rm -rf "$pk"; mkdir -p "$pk"
cp -r "$tree/packages/motoko-ext-compose" "$pk/motoko-ext-compose"
for d in motoko-ext-abi motoko-ext-ai-compat motoko_ext_conformance; do ln -s "$tree/packages/$d" "$pk/$d"; done
sed -i 's/^func truncate_utf8_by_bytes(s: string, max_bytes: int) -> string {$/export func truncate_utf8_by_bytes(s: string, max_bytes: int) -> string {/' \
  "$pk/motoko-ext-compose/store.ail"
d="$(diff "$tree/packages/motoko-ext-compose/store.ail" "$pk/motoko-ext-compose/store.ail" || true)"
expected='20c20
< func truncate_utf8_by_bytes(s: string, max_bytes: int) -> string {
---
> export func truncate_utf8_by_bytes(s: string, max_bytes: int) -> string {'
[[ "$d" == "$expected" ]] || { echo "exposed copy differs unexpectedly:"; echo "$d"; exit 3; }
# The harness package, pointing at the copy.
h="$scratch/direct"; rm -rf "$h"; mkdir -p "$h"
cp "$here/harness.ail" "$h/harness.ail"
cat > "$h/ailang.toml" <<TOML
[package]
name = "t6/diffdirect"
version = "0.1.0"
edition = "1"
ailang = ">=0.21.0"

[dependencies]
"sunholo/motoko_ext_compose" = { path = "$pk/motoko-ext-compose" }

[effects]
max = ["IO"]

[exports]
modules = ["t6/diffdirect/harness"]
TOML
( cd "$h" && ailang lock > /dev/null )
echo "$h"
