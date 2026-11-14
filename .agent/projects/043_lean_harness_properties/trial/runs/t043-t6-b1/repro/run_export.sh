#!/usr/bin/env bash
# run_export.sh CAP INPUT_CSV_FILE OUT_FILE — run elide_driver.ail against the tree's real packages.
# Builds a throwaway package directory (outside the tree) whose ailang.toml points at the
# tree's compose, abi and conformance packages by path; the tree is not written to.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="${T6_TREE:-/home/motoko/trial-043/s/t043-t6-b1/tree}"
cap="$1"; input="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; out="$3"
pkg="$(mktemp -d)"
trap 'rm -rf "$pkg"' EXIT
cat > "$pkg/ailang.toml" <<TOML
[package]
name = "local/t6_repro"
version = "0.1.0"
edition = "1"
ailang = ">=0.54.14"

[dependencies]
"sunholo/motoko_ext_compose" = { path = "$tree/packages/motoko-ext-compose" }
"sunholo/motoko_ext_abi" = { path = "$tree/packages/motoko-ext-abi" }
"sunholo/motoko_ext_conformance" = { path = "$tree/packages/motoko_ext_conformance" }
"sunholo/motoko_ext_ai_compat" = { path = "$tree/packages/motoko-ext-ai-compat" }

[effects]
max = ["IO", "FS", "Env", "AI", "Net", "Stream", "Process", "Clock", "SharedMem", "Rand", "Trace"]
TOML
cp "$here/elide_driver.ail" "$pkg/elide_driver.ail"
( cd "$pkg" && ailang lock ) > "$pkg/lock.log" 2>&1 || { echo "ailang lock failed:"; cat "$pkg/lock.log"; exit 2; }
( cd "$pkg" && T6_CAP="$cap" T6_INPUT="$input" timeout 110 \
    ailang run --relax-modules --caps IO,FS,Env --entry main elide_driver.ail ) > "$out" 2> "$out.err" \
  || { echo "ailang failed:"; tail -20 "$out.err"; exit 2; }
