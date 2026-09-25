#!/usr/bin/env bash
# P1.2b stop artifact: can a batch-B pure/ProcessCtx callback obtain an env-derived
# setting WITHOUT the value crossing `config`? Compiled on the pin against the ABI at
# committed HEAD (git show), in a throwaway workspace (no primary lock). Run from repo root.
set -uo pipefail
R=$(pwd); D=$R/.agent/projects/031_system_one_decisions/evidence/P1.2b/env_probe
T=$(mktemp -d "${TMPDIR:-/tmp}/p12benv.XXXXXX"); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/abi" "$T/pkg"
git show HEAD:packages/motoko-ext-abi/types.ail > "$T/abi/types.ail"
git show HEAD:packages/motoko-ext-abi/ailang.toml > "$T/abi/ailang.toml"
echo "ABI at $(git rev-parse --short HEAD); $(ailang --version 2>&1 | head -1)"
for v in a_policy_reads_env a2_policy_declares_env b_judge_reads_env c_policy_reads_config; do
  rm -f "$T/pkg"/*.ail
  sed "s/@V@/$v/g" "$D/$v.ail" > "$T/pkg/$v.ail"
  cat > "$T/pkg/ailang.toml" <<TOML
[package]
name = "local/$v"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"
[dependencies]
"sunholo/motoko_ext_abi" = { path = "../abi", version = "8.0" }
[effects]
max = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "Rand", "Trace"]
TOML
  ( cd "$T/pkg" && ailang lock >/dev/null 2>&1 && AILANG_RELAX_MODULES=1 ailang check . ) > "$T/out.txt" 2>&1; rc=$?
  echo "$v: ailang check exit $rc"
  sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$T/out.txt" | grep -v -E "^(Warning|Run )" | cut -c1-300 | grep -v -E "MOD010|Auto-relaxed|^→|^$" | head -6
done
