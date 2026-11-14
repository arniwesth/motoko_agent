#!/usr/bin/env bash
# mkpkg.sh <tree root> <dir> — make <dir> an AILANG package whose two dependencies are the
# tree's own packages/motoko-ext-abi and packages/motoko-ext-herdr (absolute paths), and lock
# it. The harnesses' AILANG programs are copied into such a directory and run from there, so
# they import the code of WHATEVER tree is given (the real one, or a mutated copy for a
# negative control) and nothing is written into the tree.
set -euo pipefail
root="$(cd "$1" && pwd)"
dir="$2"
mkdir -p "$dir"
cat > "$dir/ailang.toml" <<TOML
[package]
name = "local/t043_t1_harness"
version = "0.1.0"
edition = "1"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "$root/packages/motoko-ext-abi" }
"sunholo/motoko_ext_herdr" = { path = "$root/packages/motoko-ext-herdr" }
TOML
( cd "$dir" && ailang lock > lock.log 2>&1 ) || { cat "$dir/lock.log" >&2; exit 2; }
