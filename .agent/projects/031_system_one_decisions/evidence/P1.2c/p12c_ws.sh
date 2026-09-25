#!/usr/bin/env bash
# 031 PLAN-001 P1.2c: check / test batch C's five packages against the COMMITTED ABI 8.0
# package (git show HEAD:), in a throwaway workspace, and read the registration-shape gate.
# Adapted from evidence/P1.2a/p12a_ws.sh. Run from a repo root (primary, clone, or mutgate
# throwaway):
#
#   p12c_ws.sh check <pkg-dir>...     `ailang lock` in the package (its own ABI pin) and
#                                     ailang check every .ail of it; exit 1 on any failure
#   p12c_ws.sh test <module.ail>...   ailang test each (paths under packages/); the count
#                                     line is required, "0 failed" required
#   p12c_ws.sh smoke <pkg-dir>        the package's own _smoke.ail (entry main), in an empty
#                                     profile/workdir: exit 0 and an "OK:" line
#   p12c_ws.sh channel                p12c_channel.ail (beside this script): every
#                                     DescribeTools under its registration's config vs `{}`,
#                                     and each capture read back through ext_config
#   p12c_ws.sh gate <ext>...          `derive.py --hook-scope --no-provision` over the cwd;
#                                     each named extension's shape must read `pass`
#   p12c_ws.sh tree <pass> <bindings> the same run; the summary must read exactly
#                                     "pass <pass> of 18" and "binding rejections <bindings>"
#
# WHY A WORKSPACE (the ailang.lock trap): tracked locks pin path dependencies to the
# primary checkout's absolute path, so a check inside a clone resolves the primary's
# packages. This copies the ABI (from HEAD) and the five packages (the cwd's .ail files and
# ailang.toml, never a lock) into a fresh directory whose root ailang.toml names path
# dependencies inside it. The gate reads text and needs no workspace.
#
# No `cmd | grep -q` under pipefail anywhere: output goes to a file first.
set -uo pipefail
mode="${1:-}"; shift || true
E=.agent/projects/031_system_one_decisions/evidence/P1.2c
PKGS="motoko-ext-a2a motoko-ext-agentcli motoko-ext-ailang-docs motoko-ext-mcp motoko-ext-compaction-ai"
strip() { sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -v -E '^(Warning: dependency|Run .ailang lock.)'; }

gate_run() { # -> $G/out.txt
  G=$(mktemp -d "${TMPDIR:-/tmp}/p12cgate.XXXXXX")
  python3 tools/ext_ambient_inventory/derive.py --hook-scope --no-provision > "$G/out.txt" 2>&1
  echo "p12c: derive.py --hook-scope --no-provision exit $? (nonzero is expected while other batches are 7.4)"
}

case "$mode" in
  gate)
    [ $# -ge 1 ] || { echo "usage: $0 gate <ext>..." >&2; exit 2; }
    gate_run; fail=0
    for x in "$@"; do
      if grep -qE "^  ${x} +config-caps +pass *$" "$G/out.txt"; then echo "p12c: gate $x pass"
      else echo "p12c: gate $x NOT pass: $(grep -E "^  ${x} " "$G/out.txt")"; fail=1; fi
    done
    rm -rf "$G"; exit $fail ;;
  tree)
    [ $# -eq 2 ] || { echo "usage: $0 tree <pass> <bindings>" >&2; exit 2; }
    gate_run
    grep -E "^REGISTRATION SHAPE: pass|^  binding rejections" "$G/out.txt"
    rc=0
    grep -qE "^REGISTRATION SHAPE: pass $1 of 18;" "$G/out.txt" || rc=1
    grep -qE "^  binding rejections +$2 " "$G/out.txt" || rc=1
    rm -rf "$G"; exit $rc ;;
  check|test|smoke|channel) ;;
  *) echo "usage: $0 check|test|smoke|channel|gate|tree ..." >&2; exit 2 ;;
esac

T=$(mktemp -d "${TMPDIR:-/tmp}/p12cws.XXXXXX"); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/packages/motoko-ext-abi"
git show HEAD:packages/motoko-ext-abi/types.ail > "$T/packages/motoko-ext-abi/types.ail"
git show HEAD:packages/motoko-ext-abi/ailang.toml > "$T/packages/motoko-ext-abi/ailang.toml"
deps='"sunholo/motoko_ext_abi" = { path = "packages/motoko-ext-abi" }'
for p in $PKGS; do
  mkdir -p "$T/packages/$p"; cp packages/$p/*.ail packages/$p/ailang.toml "$T/packages/$p/"
  name=$(sed -nE 's/^name = "(.*)"/\1/p' "packages/$p/ailang.toml" | head -1)
  deps="$deps
\"$name\" = { path = \"packages/$p\" }"
done
cp "$E/p12c_channel.ail" "$T/"
cat > "$T/ailang.toml" <<TOML
[package]
name = "local/p12c"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"

[dependencies]
$deps

[effects]
max = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "Rand", "Trace"]
TOML
cd "$T"
ailang lock > lock.log 2>&1 || { strip < lock.log | tail -6; echo "p12c: ailang lock FAILED in the workspace"; exit 1; }
export AILANG_RELAX_MODULES=1
fail=0
case "$mode" in
  check)
    [ $# -ge 1 ] || { echo "usage: $0 check <pkg-dir>..." >&2; exit 2; }
    for p in "$@"; do
      ( cd "packages/$p" && ailang lock ) > pin.log 2>&1 \
        && echo "p12c: lock packages/$p ok (ABI pin $(sed -nE 's/.*motoko_ext_abi" = .*version = "([^"]*)".*/\1/p' packages/$p/ailang.toml))" \
        || { strip < pin.log | tail -4; echo "p12c: lock packages/$p FAILED (its ABI pin)"; fail=1; }
      for m in packages/$p/*.ail; do
        ailang check "$m" > out.txt 2>&1; rc=$?
        if [ $rc -eq 0 ]; then echo "p12c: check $m ok"
        else strip < out.txt | tail -8; echo "p12c: check $m FAILED (exit $rc)"; fail=1; fi
      done
    done ;;
  test)
    [ $# -ge 1 ] || { echo "usage: $0 test <module.ail>..." >&2; exit 2; }
    for m in "$@"; do
      ailang test "$m" > out.txt 2>&1; rc=$?
      strip < out.txt > clean.txt
      line=$(grep -E '^[0-9]+ tests:' clean.txt | tail -1)
      if [ -n "$line" ] && [ $rc -eq 0 ] && grep -qE '^[0-9]+ tests: [0-9]+ passed, 0 failed' clean.txt; then
        echo "p12c: test $m ok -- $line"
      else grep -E '✗|expected|Error|error' clean.txt | head -12; echo "p12c: test $m FAILED (exit $rc; $line)"; fail=1; fi
    done ;;
  smoke)
    [ $# -eq 1 ] || { echo "usage: $0 smoke <pkg-dir>" >&2; exit 2; }
    mkdir -p empty_wd empty_profile
    MOTOKO_WORKDIR="$T/empty_wd" MOTOKO_PROFILE_DIR="$T/empty_profile" \
      ailang run --caps AI,Env,FS,IO,Trace --ai-stub --entry main packages/$1/_smoke.ail > out.txt 2>&1; rc=$?
    strip < out.txt | grep -E '^(OK|FAIL)'
    if [ $rc -eq 0 ] && grep -q '^OK:' out.txt; then echo "p12c: smoke $1 ok"
    else strip < out.txt | tail -5; echo "p12c: smoke $1 FAILED (exit $rc)"; fail=1; fi ;;
  channel)
    # Synthetic fixtures only (PLAN-001 §0 item 9): one A2A agent, one mcp-http server, a
    # compaction threshold no context reaches, a workdir marked as an AILANG project.
    mkdir -p prof wd
    printf '{"agents":[{"name":"p12c_agent","url":"http://127.0.0.1:9","description":"P12C synthetic","skill_id":"main.p12c"}]}\n' > prof/a2a.json
    printf '{"servers":[{"name":"p12c_srv","command":"","transport":"mcp-http","tool_mappings":[{"canonical":"P12cTool","mcp_name":"p12c_tool","aliases":[]}]}]}\n' > prof/mcp.json
    printf '{"threshold_pct":100000}\n' > prof/compaction_ai.json
    printf '[package]\nname = "local/p12c_wd"\n' > wd/ailang.toml
    MOTOKO_PROFILE_DIR="$T/prof" MOTOKO_WORKDIR="$T/wd" \
    CODEX_MODEL=p12c-synthetic-model AILANG_DOCS_TIMEOUT_MS=4321 \
      ailang run --caps AI,Env,FS,IO,Trace,Net,Rand,Process,Clock,SharedMem,Stream --ai-stub --entry main p12c_channel.ail > out.txt 2>&1; rc=$?
    strip < out.txt | grep -E '^(OK|FAIL|describe_tools)'
    if [ $rc -eq 0 ] && grep -q '^OK: channel' out.txt; then echo "p12c: channel ok"
    else strip < out.txt | tail -5; echo "p12c: channel FAILED (exit $rc)"; fail=1; fi ;;
esac
exit $fail
