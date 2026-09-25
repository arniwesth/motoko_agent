#!/usr/bin/env bash
# 031 PLAN-001 P0.6: build a throwaway AILANG workspace holding THIS checkout's
# ABI 8.0 package and conformance kit (examples included), and print its path.
# Source it or call it; the caller removes the directory.
#
# Why a workspace: the repo's ailang.lock pins path dependencies to the PRIMARY
# checkout's absolute path, so inside a mutgate clone an in-place check would
# resolve the primary's packages (P0.4's trap; p05_conformance_check.sh is the
# precedent). Here the only packages are the cwd's ABI and kit.
#
# The workspace copy of the kit's ailang.toml gains the example modules in its
# [exports] (the repo's manifest is P0.5's file and is not edited by P0.6).
set -euo pipefail
T=$(mktemp -d "${TMPDIR:-/tmp}/p06ws.XXXXXX")
mkdir -p "$T/deps/motoko-ext-abi" "$T/deps/motoko_ext_conformance/fixtures" "$T/deps/motoko_ext_conformance/examples"
cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/deps/motoko-ext-abi/"
cp packages/motoko_ext_conformance/ailang.toml packages/motoko_ext_conformance/invariants.ail \
   packages/motoko_ext_conformance/harness.ail "$T/deps/motoko_ext_conformance/"
cp packages/motoko_ext_conformance/fixtures/reject_fixtures.ail "$T/deps/motoko_ext_conformance/fixtures/"
cp packages/motoko_ext_conformance/examples/*.ail "$T/deps/motoko_ext_conformance/examples/"
python3 - "$T/deps/motoko_ext_conformance/ailang.toml" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text()
mods = sorted(f.stem for f in (p.parent / "examples").glob("*.ail"))
add = "".join(f'  "sunholo/motoko_ext_conformance/examples/{m}",\n' for m in mods)
anchor = '  "sunholo/motoko_ext_conformance/fixtures/reject_fixtures",\n'
assert anchor in t, "kit manifest changed shape"
p.write_text(t.replace(anchor, anchor + add))
PY
cat > "$T/ailang.toml" <<'TOML'
[package]
name = "local/p06examples"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "deps/motoko-ext-abi" }
"sunholo/motoko_ext_conformance" = { path = "deps/motoko_ext_conformance" }
TOML
( cd "$T" && ailang lock >/dev/null 2>&1 )
echo "$T"
