#!/usr/bin/env bash
# 031 PLAN-001 P1.2b: check / test / probe batch B's five packages against THIS checkout's
# ABI 8.0 package in a throwaway workspace, and read the registration-shape gate.
# Run from a repo root (the primary, a clone, or a mutgate throwaway):
#
#   p12b_ws.sh check <pkg-dir>...     `ailang lock` in the package (its own ABI pin) and
#                                     ailang check every .ail of it; exit 1 on any failure
#   p12b_ws.sh test <module.ail>...   ailang test each (paths under packages/); the count
#                                     line is required and every failing test must be named
#                                     in P12B_KNOWN_RED (space-separated; each shown
#                                     pre-existing at 181051d0 by p12b_exa_test_at_74.sh)
#   p12b_ws.sh probe <rg|td|sp|exa|cm>  the package's configuration-channel probe
#                                     (p12b_<name>_channel.ail beside this script), run with
#                                     synthetic environment values: every value registration
#                                     discloses must reach its callback through ext_config,
#                                     an EMPTY config must give the defaults, and no workdir
#                                     or credential value may appear in the config
#   p12b_ws.sh gate <ext>...          `derive.py --hook-scope --no-provision` over the cwd;
#                                     each named extension's shape must read `pass`
#   p12b_ws.sh tree <pass> <bindings> the same run; the summary must read exactly
#                                     "pass <pass> of 18" and "binding rejections <bindings>"
#
# THE ailang.lock TRAP: tracked locks pin path dependencies to the PRIMARY checkout, so this
# copies the cwd's ABI package and the five packages (.ail + ailang.toml, never a lock) into a
# fresh directory whose root manifest names path dependencies INSIDE it. Two inputs are read
# from COMMITTED HEAD, never from another part's working tree (PLAN-001 §0 item 13):
# `packages/motoko-ext-mcp` (exa-search's dependency; batch C's package) and `src/core`
# (scratchpad imports src/core/env_client; the probes build ProviderCtx with core's
# ctx_defaults.noop_ext_ports -- a test harness, not extension code).
#
# No `cmd | grep -q` under pipefail anywhere: output goes to a file first.
set -uo pipefail
mode="${1:-}"; shift || true
R=$(pwd)
E=.agent/projects/031_system_one_decisions/evidence/P1.2b
PKGS="motoko-ext-repetition-guard motoko-ext-test-dummy motoko_scratchpad motoko-ext-exa-search motoko-ext-context-mode"
strip() { sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -v -E '^(Warning: dependency|Run .ailang lock.)|MOD010|Auto-relaxed'; }

gate_run() { # -> $G/out.txt
  G=$(mktemp -d "${TMPDIR:-/tmp}/p12bgate.XXXXXX")
  python3 tools/ext_ambient_inventory/derive.py --hook-scope --no-provision > "$G/out.txt" 2>&1
  echo "p12b: derive.py --hook-scope --no-provision exit $? (nonzero is expected while other batches are red)"
}

case "$mode" in
  gate)
    [ $# -ge 1 ] || { echo "usage: $0 gate <ext>..." >&2; exit 2; }
    gate_run; fail=0
    for x in "$@"; do
      if grep -qE "^  ${x} +config-caps +pass *$" "$G/out.txt"; then echo "p12b: gate $x pass"
      else echo "p12b: gate $x NOT pass: $(grep -E "^  ${x} " "$G/out.txt" | head -1)"; fail=1; fi
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
  check|test|probe) ;;
  *) echo "usage: $0 check|test|probe|gate|tree ..." >&2; exit 2 ;;
esac

T=$(mktemp -d "${TMPDIR:-/tmp}/p12bws.XXXXXX"); trap 'rm -rf "$T"; [ -n "${SRV:-}" ] && kill $SRV 2>/dev/null' EXIT
mkdir -p "$T/packages/motoko-ext-abi" "$T/packages/motoko-ext-mcp"
cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/packages/motoko-ext-abi/"
for f in $(git ls-tree --name-only HEAD packages/motoko-ext-mcp/); do
  b=$(basename "$f"); case $b in *.ail|ailang.toml|*.mjs) git show HEAD:"$f" > "$T/packages/motoko-ext-mcp/$b";; esac
done
git archive HEAD src/core | tar -x -C "$T"
deps='"sunholo/motoko_ext_abi" = { path = "packages/motoko-ext-abi" }
"sunholo/motoko_ext_mcp" = { path = "packages/motoko-ext-mcp" }'
for p in $PKGS; do
  mkdir -p "$T/packages/$p"; cp packages/$p/*.ail packages/$p/ailang.toml "$T/packages/$p/"
  name=$(sed -nE 's/^name = "(.*)"/\1/p' "packages/$p/ailang.toml" | head -1)
  deps="$deps
\"$name\" = { path = \"packages/$p\" }"
done
cp "$E"/p12b_*_channel.ail "$T/" 2>/dev/null
cat > "$T/ailang.toml" <<TOML
[package]
name = "local/p12b"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"

[dependencies]
$deps

[effects]
max = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "SharedIndex", "Rand", "Trace"]
TOML
cd "$T"
ailang lock > lock.log 2>&1 || { strip < lock.log | tail -6; echo "p12b: ailang lock FAILED in the workspace"; exit 1; }
export AILANG_RELAX_MODULES=1
fail=0
case "$mode" in
  check)
    [ $# -ge 1 ] || { echo "usage: $0 check <pkg-dir>..." >&2; exit 2; }
    for p in "$@"; do
      ( cd "packages/$p" && sed -i -E 's#("sunholo/motoko_ext_(abi|mcp)" = \{ path = )"\.\./#\1"../#' ailang.toml && ailang lock ) > pin.log 2>&1 \
        && echo "p12b: lock packages/$p ok (ABI pin $(sed -nE 's/.*motoko_ext_abi" = .*version = "([^"]*)".*/\1/p' packages/$p/ailang.toml))" \
        || { strip < pin.log | tail -4; echo "p12b: lock packages/$p FAILED (its ABI pin)"; fail=1; }
      for m in packages/$p/*.ail; do
        ailang check "$m" > out.txt 2>&1; rc=$?
        if [ $rc -eq 0 ]; then echo "p12b: check $m ok"
        else strip < out.txt | tail -8; echo "p12b: check $m FAILED (exit $rc)"; fail=1; fi
      done
    done ;;
  test)
    [ $# -ge 1 ] || { echo "usage: $0 test <module.ail>..." >&2; exit 2; }
    for m in "$@"; do
      ailang test "$m" > out.txt 2>&1; rc=$?
      strip < out.txt > clean.txt
      line=$(grep -E '^[0-9]+ tests:' clean.txt | tail -1)
      [ -n "$line" ] || { tail -8 clean.txt; echo "p12b: test $m FAILED (exit $rc, no count line)"; fail=1; continue; }
      bad=""
      for t in $(sed -nE 's/^ *✗ ([A-Za-z0-9_]+) \(.*/\1/p' clean.txt); do
        case " ${P12B_KNOWN_RED:-} " in *" $t "*) echo "p12b: known red (pre-existing at 181051d0) $t";; *) bad="$bad $t";; esac
      done
      if [ -z "$bad" ]; then echo "p12b: test $m ok -- $line"
      else grep -E '✗|expected' clean.txt | head -12; echo "p12b: test $m FAILED:$bad ($line)"; fail=1; fi
    done ;;
  probe)
    [ $# -eq 1 ] || { echo "usage: $0 probe <rg|td|sp|exa|cm>" >&2; exit 2; }
    n=$1; mod="p12b_${n}_channel.ail"; [ -f "$mod" ] || { echo "p12b: no probe $mod"; exit 2; }
    wd="$T/wd"; mkdir -p "$wd/scripts" "$wd/src/core/ext/exa_search" "$wd/src/core/ext/context_mode"
    caps="Env,FS,IO,Process,SharedMem,Net,Rand,Clock,Stream,AI,Trace"
    extra=()
    case "$n" in
      rg) extra=(MOTOKO_REPEAT_CALL_BUDGET=2 MOTOKO_REPEAT_ANSWER_BUDGET=1) ;;
      td) extra=(EXT_DUMMY_PROMPT=P12B-MARK EXT_DUMMY_TOOL_DECISION=deny EXT_DUMMY_FINALIZE=accept EXT_DUMMY_BUDGET_TOTAL=17) ;;
      sp)
        port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')
        python3 "$R/$E/p12b_echo_server.py" "$port" > srv.log 2>&1 & SRV=$!
        for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q listening srv.log 2>/dev/null && break; sleep 0.2; done
        extra=(MOTOKO_SCRATCHPAD_TIMEOUT_SECS=7 P12B_ENV_URL="http://127.0.0.1:$port"); NETFLAGS="--net-allow-http --net-allow-localhost" ;;
      exa)
        printf 'P12B-EXA-PROMPT\n' > "$wd/src/core/ext/exa_search/AGENT.md"
        # std/package.assetPath resolves ~/.ailang/cache/registry/<vendor>/<name>/<ver>/assets/;
        # a scratch HOME holds the stand-in there (~/.local linked through for the toolchain).
        mkdir -p "$T/home/.ailang/cache/registry/sunholo/motoko_ext_mcp/0.0.0-p12b/assets"
        cp "$R/$E/p12b_fake_bridge.mjs" "$T/home/.ailang/cache/registry/sunholo/motoko_ext_mcp/0.0.0-p12b/assets/mcp-call.mjs"
        ln -s "$HOME/.local" "$T/home/.local"
        extra=(HOME="$T/home" EXA_TIMEOUT_MS=7000 EXA_MAX_OUTPUT_CHARS=600 EXA_API_KEY=P12B-NOT-A-REAL-KEY) ;;
      cm)
        printf 'P12B-CM-PROMPT\n' > "$wd/src/core/ext/context_mode/AGENT.md"
        cp "$R/$E/p12b_fake_bridge.mjs" "$wd/scripts/context-mode-mcp-call.mjs"
        extra=(CONTEXT_MODE_BIN=P12B-BIN CONTEXT_MODE_TIMEOUT_MS=7000 CONTEXT_MODE_MAX_OUTPUT_CHARS=600 CONTEXT_MODE_SNAPSHOT_KEY_PREFIX=p12b:pfx:) ;;
    esac
    env MOTOKO_WORKDIR="$wd" P12B_WORKDIR="$wd" P12B_CALLS_LOG="$wd/calls.log" "${extra[@]}" \
      ailang run --caps "$caps" --ai-stub ${NETFLAGS:-} --entry main "$mod" > out.txt 2>&1; rc=$?
    strip < out.txt | grep -E '^(OK|FAIL)'
    if [ $rc -eq 0 ] && grep -q '^OK: channel' out.txt && ! grep -q '^FAIL' out.txt; then echo "p12b: probe $n ok"
    else strip < out.txt | tail -6; echo "p12b: probe $n FAILED (exit $rc)"; fail=1; fi ;;
esac
exit $fail
