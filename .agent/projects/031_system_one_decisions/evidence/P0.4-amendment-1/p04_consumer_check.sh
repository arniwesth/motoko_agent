#!/usr/bin/env bash
# Check the committed 8.0 consumer against THIS checkout's ABI package.
# Run from a repo root. The repo's ailang.lock pins the ABI path dependency
# to an absolute path (the primary checkout), so a consumer checked in place
# inside a clone would resolve the primary's ABI, not the clone's. This builds
# a throwaway workspace whose only dependency is the cwd's package.
set -euo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P0.4-amendment-1
T=$(mktemp -d "${TMPDIR:-/tmp}/p04ws.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/pkg/motoko-ext-abi"
cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/pkg/motoko-ext-abi/"
cp "$E/ws_distinct/ailang.toml" "$E/ws_distinct/consumer80.ail" "$T/"
cd "$T"
ailang lock >/dev/null 2>&1
AILANG_RELAX_MODULES=1 ailang check consumer80.ail
