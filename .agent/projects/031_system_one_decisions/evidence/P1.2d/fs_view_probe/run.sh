#!/usr/bin/env bash
# P1.2d: the FsCtx environment-route probe. Checks three probes against the
# COMMITTED ABI (git show HEAD:packages/motoko-ext-abi/...) in a throwaway workspace
# (no root ailang.lock is consulted). Run from the repo root. Exit 0 iff probe 1 and 2
# are rejected and probe 3 checks clean.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/p12dfs.XXXXXX"); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/abi"
git show HEAD:packages/motoko-ext-abi/types.ail > "$T/abi/types.ail"
git show HEAD:packages/motoko-ext-abi/ailang.toml > "$T/abi/ailang.toml"
cp "$D"/p_*.ail "$T/"
cat > "$T/ailang.toml" <<TOML
[package]
name = "local/p12d"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "abi", version = "8.0" }

[effects]
max = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "Rand", "Trace"]
TOML
cd "$T"; ailang lock > lock.log 2>&1 || { cat lock.log; exit 2; }
export AILANG_RELAX_MODULES=1
rc_all=0
for p in p_env_in_render:reject p_env_row_widened:reject p_value_in_config:clean; do
  f=${p%%:*}; want=${p##*:}
  ailang check "$f.ail" > "$f.out" 2>&1; rc=$?
  got=$([ $rc -eq 0 ] && echo clean || echo reject)
  first=$(sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$f.out" | grep -v -E 'WARNING|→|Auto-relaxed|Running under|^ *$' | grep -m3 -E 'Error|Missing|unify|mismatch|effect' | tr '\n' ' ' | cut -c1-400)
  echo "p12d-fs: $f exit $rc -> $got (want $want) ${first}"
  [ "$got" = "$want" ] || rc_all=1
done
exit $rc_all
