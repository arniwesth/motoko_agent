#!/usr/bin/env bash
# run_caller.sh <cases file> <work dir>   (from the tree root)
#
# Builds a driver package in <work dir>/caller that depends on the REAL compose, abi,
# ai_compat and conformance packages by path, and runs t6_caller.ail over <cases file>.
set -euo pipefail
cases="$1"; work="$2"
tree="$(pwd)"
here="$(cd "$(dirname "$0")" && pwd)"
[[ -f "$tree/packages/motoko-ext-compose/store.ail" ]] || { echo "run_caller.sh: run from the tree root" >&2; exit 3; }
mkdir -p "$work/caller"
cat > "$work/caller/ailang.toml" <<TOML
[package]
name = "local/t6_caller"
version = "0.1.0"
edition = "1"
ailang = ">=0.54.14"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "$tree/packages/motoko-ext-abi" }
"sunholo/motoko_ext_ai_compat" = { path = "$tree/packages/motoko-ext-ai-compat" }
"sunholo/motoko_ext_compose" = { path = "$tree/packages/motoko-ext-compose" }
"sunholo/motoko_ext_conformance" = { path = "$tree/packages/motoko_ext_conformance" }
TOML
cp "$here/t6_caller.ail" "$work/caller/t6_caller.ail"
( cd "$work/caller" && ailang lock >/dev/null 2>&1 )
ailang run --relax-modules --caps IO,FS --entry main --args-json "\"$cases\"" "$work/caller/t6_caller.ail" > "$work/caller.raw" 2> "$work/caller.err" || true
grep -E '^[0-9,]*\|-?[0-9]+\|(true|false)\|' "$work/caller.raw" > "$work/caller.raw.lines" || { echo "run_caller.sh: no output; stderr:" >&2; cat "$work/caller.err" >&2; exit 3; }
cat "$work/caller.raw.lines"
