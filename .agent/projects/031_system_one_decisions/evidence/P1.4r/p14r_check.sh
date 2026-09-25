#!/usr/bin/env bash
# 031 PLAN-001 P1.4r (P1.3r's evidence/P1.3r/p13r_check.sh, re-pointed at its own e2e runner): P1.1's workspace (evidence/P1.1/p11_core_check.sh, reused
# line for line below its header -- read that header for WHY a workspace and why
# it is immune to the ailang.lock trap) plus two things P1.3r needs:
#   * P0.6's example consumers (packages/motoko_ext_conformance/examples/),
#     copied beside the kit, with the WORKSPACE copy of the kit's ailang.toml
#     exporting them. The real package does not export them and P1.3r does not
#     edit packages/; only this throwaway toml changes.
#   * the end-to-end runner evidence/P1.4r/cursor_e2e.ail, copied to
#     src/p14r/cursor_e2e.ail (it imports the real runtime and the examples).
# Modes, run from a repo root:
#   p13r_check.sh check <module.ail>...   as P1.1's
#   p13r_check.sh test  <module.ail>...   as P1.1's
#   p13r_check.sh e2e                     ailang run the runner; exit 1 on a
#                                         nonzero run (a mismatch, or the
#                                         tripwire port faulting) or a missing
#                                         PASS line
set -uo pipefail
mode="${1:-}"; shift || true
{ { [ "$mode" = check ] || [ "$mode" = test ]; } && [ $# -ge 1 ]; } || [ "$mode" = e2e ] \
  || { echo "usage: $0 check|test <module.ail>... | e2e" >&2; exit 2; }
R=$(pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/p14rws.XXXXXX"); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/deps/motoko-ext-abi" "$T/deps/motoko_ext_conformance/fixtures" \
         "$T/deps/motoko-ext-p11stub" "$T/deps/motoko-ext-scratchpad"
cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/deps/motoko-ext-abi/"
cp packages/motoko_ext_conformance/ailang.toml packages/motoko_ext_conformance/invariants.ail \
   packages/motoko_ext_conformance/harness.ail "$T/deps/motoko_ext_conformance/"
cp packages/motoko_ext_conformance/fixtures/reject_fixtures.ail "$T/deps/motoko_ext_conformance/fixtures/"
# the example consumers, exported by the WORKSPACE toml only
mkdir -p "$T/deps/motoko_ext_conformance/examples" "$T/src/p14r"
cp packages/motoko_ext_conformance/examples/*.ail "$T/deps/motoko_ext_conformance/examples/"
python3 - "$T/deps/motoko_ext_conformance/ailang.toml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = '"sunholo/motoko_ext_conformance/fixtures/reject_fixtures",'
assert old in s, "kit toml: exports list moved"
s = s.replace(old, old + '\n  "sunholo/motoko_ext_conformance/examples/completion_guard",\n  "sunholo/motoko_ext_conformance/examples/repeat_failure_policy",')
open(p, 'w').write(s)
PY
cp .agent/projects/031_system_one_decisions/evidence/P1.4r/cursor_e2e.ail "$T/src/p14r/cursor_e2e.ail"
( cd src && find core eval -name '*.ail' -print0 2>/dev/null | while IFS= read -r -d '' f; do
    mkdir -p "$T/src/$(dirname "$f")"; cp "$f" "$T/src/$f"; done )  # src/eval: scripts/eval imports it
# scripts/ and tools/ .ail files, so the type-driven inventory can check them in
# the same workspace; nothing under src/core imports them
for top in scripts tools; do
  [ -d "$top" ] && find "$top" -name '*.ail' -print0 | while IFS= read -r -d '' f; do
    mkdir -p "$T/$(dirname "$f")"; cp "$f" "$T/$f"; done
done

cat > "$T/deps/motoko-ext-p11stub/ailang.toml" <<'TOML'
[package]
name = "sunholo/motoko_ext_p11stub"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "../motoko-ext-abi" }

[exports]
modules = ["sunholo/motoko_ext_p11stub/register"]
TOML
cat > "$T/deps/motoko-ext-p11stub/register.ail" <<'AIL'
-- P1.1 workspace stand-in: one synthetic 8.0 extension so the real registry
-- template has something to generate over. Registers nothing.
module sunholo/motoko_ext_p11stub/register

import std/json (jo)
import pkg/sunholo/motoko_ext_abi/types (ExtRegistration)

export func register_with_config(_cfg: a) -> ExtRegistration {
  { config: jo([]), caps: [] }
}
AIL

cat > "$T/deps/motoko-ext-scratchpad/ailang.toml" <<'TOML'
[package]
name = "sunholo/motoko_ext_scratchpad"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "../motoko-ext-abi" }

[exports]
modules = ["sunholo/motoko_ext_scratchpad/ws_loopback"]
TOML
cat > "$T/deps/motoko-ext-scratchpad/ws_loopback.ail" <<'AIL'
-- P1.1 workspace stand-in for packages/motoko_scratchpad/ws_loopback.ail (7.4
-- until P1.2): the one export tool_phase.ail imports, signature-identical,
-- executing nothing.
module sunholo/motoko_ext_scratchpad/ws_loopback

import std/json (Json, jo)
import pkg/sunholo/motoko_ext_abi/types (ExtCtx, ExtRuntime)
import src/core/tool_contract (ToolCallEnvelope)
import src/core/types (CellExecResult)

export func exec_scratchpad_cell_ws(_rt: ExtRuntime, _ctx: ExtCtx, _call: ToolCallEnvelope, _cells: Json, _timeout_secs: int) -> CellExecResult ! {AI, Clock, Env, FS, IO, Net, Process, SharedMem, Stream, Rand} {
  { stdout: "", stderr: "p11 stand-in: no scratchpad in this workspace", exit_code: -1, metadata: jo([]) }
}
AIL

cat > "$T/ailang.toml" <<'TOML'
[package]
name = "local/p11core"
version = "0.1.0"
edition = "1"
module_prefix = "src"
ailang = ">=0.33.0"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "deps/motoko-ext-abi" }
"sunholo/motoko_ext_conformance" = { path = "deps/motoko_ext_conformance" }
"sunholo/motoko_ext_p11stub" = { path = "deps/motoko-ext-p11stub" }
"sunholo/motoko_ext_scratchpad" = { path = "deps/motoko-ext-scratchpad" }

[extensions]
packages = ["sunholo/motoko_ext_p11stub@0.1.0"]
config_import = "src/core/config.RuntimeConfig"
hooks_import = "pkg/sunholo/motoko_ext_abi/types.ExtensionHooks"
capability_import = "pkg/sunholo/motoko_ext_abi/types.Capability"
entry_import = "pkg/sunholo/motoko_ext_abi/types.ExtEntry"
normalize_import = "src/core/ext/registry_normalize"
registry_import = "pkg/sunholo/motoko_ext_abi/types.ExtRegistry"
output = "src/core/ext/registry_generated.ail"
effects = ["AI", "Clock", "Env", "FS", "IO", "Net", "Process", "Rand", "SharedMem", "Stream", "Trace"]

[effects]
max = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "SharedIndex", "Rand", "Trace"]
TOML

cd "$T"
ailang lock > lock.log 2>&1 || { tail -5 lock.log; echo "p14r: ailang lock failed in the workspace"; exit 1; }
python3 "$R/tools/ext_registry_gen/generate.py" --config ailang.toml > gen.log 2>&1 \
  || { tail -5 gen.log; echo "p14r: registry generation failed"; exit 1; }

strip() { sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -v -E '^(Warning: dependency|Run .ailang lock.)'; }
[ -n "${P11_RELAX:-}" ] && export AILANG_RELAX_MODULES=1
if [ "$mode" = e2e ]; then
  # Logged to a file, then grepped: `cmd | grep -q` under pipefail can score a
  # green run red (exit 141), the known mutgate trap.
  ailang run --caps IO,Process,Clock --entry main src/p14r/cursor_e2e.ail < /dev/null > e2e.log 2>&1; rc=$?
  strip < e2e.log | grep -v -E '^(→|✓ Running)' | sed '/^$/d'
  if [ $rc -ne 0 ]; then echo "p14r: e2e run FAILED (exit $rc)"; exit 1; fi
  if ! grep -q '^END_TO_END finalize=PASS tool_policy=PASS' e2e.log; then echo "p14r: e2e FAILED -- no PASS line"; exit 1; fi
  echo "p14r: e2e ok"; exit 0
fi
fail=0
for m in "$@"; do
  [ -f "$m" ] || { echo "p14r: no such module in the workspace: $m"; fail=1; continue; }
  if [ "$mode" = check ]; then
    out=$(ailang check "$m" 2>&1); rc=$?
    if [ $rc -eq 0 ]; then echo "p14r: check $m ok"
    else
      first=$(echo "$out" | strip | grep -m1 -E 'Error|PAT_|PAR_|LDR0|MOD0|TC0|EFF' | cut -c1-400)
      echo "$out" | strip | tail -8; echo "p14r: check $m FAILED (exit $rc): ${first}"; fail=1
    fi
  else
    # P11_ALLOW_SKIPS=1 passes --allow-skips: a module whose contract
    # properties have no generator (exit_manifest.ail, pre-existing) otherwise
    # exits 1 with "0 failed"; the count line is still parsed and required.
    out=$(ailang test ${P11_ALLOW_SKIPS:+--allow-skips} "$m" 2>&1); rc=$?
    line=$(echo "$out" | strip | grep -E '^[0-9]+ tests:' | tail -1)
    # A here-string, not `echo | grep -q`: under pipefail an early-exiting grep
    # can SIGPIPE the writer and score a green run red (the P0.3 mutgate trap).
    if [ $rc -eq 0 ] && grep -qE '^[0-9]+ tests: [0-9]+ passed, 0 failed' <<<"$out"; then
      echo "p14r: test $m ok -- $line"
    else
      echo "$out" | strip | grep -E 'FAIL|Error|error|tests:' | tail -12; echo "p14r: test $m FAILED (exit $rc; $line)"; fail=1
    fi
  fi
done
exit $fail
