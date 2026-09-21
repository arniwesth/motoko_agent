#!/usr/bin/env bash
# 031 PLAN-001 P0.5: check and run the conformance kit against THIS checkout's
# ABI 8.0 package, in a throwaway workspace. Run from a repo root.
#
# Why a workspace: the repo's ailang.lock pins path dependencies to the PRIMARY
# checkout's absolute path, so inside a clone `harness.ail`'s
# `import pkg/sunholo/motoko_ext_conformance/invariants` would resolve the
# primary's file, not the clone's (P0.4's trap; its p04_consumer_check.sh is the
# precedent). Here the only packages are the cwd's ABI and conformance kit.
set -euo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P0.5
T=$(mktemp -d "${TMPDIR:-/tmp}/p05ws.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/deps/motoko-ext-abi" "$T/deps/motoko_ext_conformance/fixtures"
cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/deps/motoko-ext-abi/"
cp packages/motoko_ext_conformance/ailang.toml packages/motoko_ext_conformance/invariants.ail \
   packages/motoko_ext_conformance/harness.ail "$T/deps/motoko_ext_conformance/"
cp packages/motoko_ext_conformance/fixtures/reject_fixtures.ail "$T/deps/motoko_ext_conformance/fixtures/"
cp "$E/conformance_kit_run.ail" "$T/run.ail"
cat > "$T/ailang.toml" <<'TOML'
[package]
name = "local/p05kit"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "deps/motoko-ext-abi" }
"sunholo/motoko_ext_conformance" = { path = "deps/motoko_ext_conformance" }
TOML
cd "$T"
ailang lock >/dev/null 2>&1
export AILANG_RELAX_MODULES=1
for m in invariants harness fixtures/reject_fixtures; do
  ailang check "deps/motoko_ext_conformance/$m.ail" >/dev/null 2>&1 \
    || { ailang check "deps/motoko_ext_conformance/$m.ail" 2>&1 | tail -5; echo "p05: check $m FAILED"; exit 1; }
  echo "p05: ailang check $m ok"
done
out=$(ailang test deps/motoko_ext_conformance/invariants.ail 2>&1) || { echo "$out" | tail -8; echo "p05: ailang test invariants FAILED"; exit 1; }
echo "$out" | grep -E '^[0-9]+ tests:'
# A count, not only the exit status (the Makefile's WI-A17 rule): zero failed.
# A here-string, not `echo | grep -q`: under pipefail an early-exiting grep can
# SIGPIPE the writer and score a green run red (the P0.3 mutgate trap).
grep -qE '^[0-9]+ tests: [0-9]+ passed, 0 failed' <<<"$out" || { echo "p05: invariants tests not all passed"; exit 1; }
ailang check run.ail >/dev/null 2>&1 || { ailang check run.ail 2>&1 | tail -5; echo "p05: check run.ail FAILED"; exit 1; }
ailang run --caps IO,Env,FS --entry main run.ail < /dev/null
