#!/usr/bin/env bash
# 031 PLAN-001 P0.5: `make registry_gen_check` against the ABI 8.0 fixture tree,
# then the golden output type-checked and RUN against THIS checkout's ABI.
# Run from a repo root.
#
# Why a fixture tree: the real registry and its 18 extensions stay 7.4 until
# P1.1/P1.2, so the real `registry_gen_check` is red by design (the template now
# emits 8.0). Why a throwaway workspace for the type-check: a real ailang.lock
# pins path dependencies to the checkout it was written in (P0.4's trap).
set -euo pipefail
R=$(pwd)
F=tools/ext_registry_gen/fixtures/abi8
make -s -C "$F" -f "$R/Makefile" registry_gen_check
T=$(mktemp -d "${TMPDIR:-/tmp}/p05reg.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/deps/motoko-ext-abi"
cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/deps/motoko-ext-abi/"
cp -r "$F/registry" "$F/exts" "$T/"
sed 's#path = "\.\./\.\./\.\./\.\./packages/motoko-ext-abi"#path = "deps/motoko-ext-abi"#' "$F/ailang.toml" > "$T/ailang.toml"
for x in alpha beta; do
  sed -i 's#path = "\.\./\.\./\.\./\.\./\.\./\.\./packages/motoko-ext-abi"#path = "../../deps/motoko-ext-abi"#' \
    "$T/exts/motoko-ext-$x/ailang.toml"
done
cd "$T"
ailang lock >/dev/null 2>&1
export AILANG_RELAX_MODULES=1
ailang check registry/registry_generated.ail >/dev/null 2>&1 \
  || { ailang check registry/registry_generated.ail 2>&1 | tail -4; echo "p05: generated registry does not check on ABI 8.0"; exit 1; }
echo "p05: generated registry checks against ABI 8.0"
ailang run --caps IO --entry main registry/run.ail < /dev/null 2>&1 | grep -v '^→\|^✓ Running\|^Warning\|MOD010\|relax'
