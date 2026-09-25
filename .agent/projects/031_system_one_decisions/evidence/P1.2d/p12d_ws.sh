#!/usr/bin/env bash
# 031 PLAN-001 P1.2d: check / test batch D's two packages (compose, herdr) against THIS
# checkout's ABI 8.0 package in a throwaway workspace, and read the registration-shape
# gate. Adapted from evidence/P1.2a/p12a_ws.sh. Run from a repo root (the primary, a
# clone, or a mutgate throwaway):
#
#   p12d_ws.sh check <pkg-dir>...     `ailang lock` in the package (its own ABI pin) and
#                                     ailang check every .ail of it (recursively)
#   p12d_ws.sh test <module.ail>...   ailang test each (paths under packages/); the count
#                                     line is required and every failing test must be
#                                     named in P12D_KNOWN_RED (space-separated)
#   p12d_ws.sh gate <ext>...          `derive.py --hook-scope --no-provision` over the cwd;
#                                     each named extension's shape must read `pass`
#   p12d_ws.sh tree                   the same run; prints the summary lines
#   p12d_ws.sh channel                the configuration-channel probe (p12d_channel.ail, entry
#                                     main): every payload reached through caps + ext_config
#   p12d_ws.sh provider               compose's ToolProvider once (--ai-stub): its compose_start
#                                     event must carry the model and attempts from ext_config
#   p12d_ws.sh registration           both register.ail under a synthetic environment/profile:
#                                     the disclosed config must carry what registration read
#
# WHY A WORKSPACE (the ailang.lock trap): tracked lock files pin path dependencies to
# the PRIMARY checkout's absolute path. This copies the cwd's ABI, ai-compat (compose's
# second path dependency) and the two packages (.ail + ailang.toml, never a lock) into
# a fresh directory whose root ailang.toml names path dependencies inside it.
# No `cmd | grep -q` under pipefail: output goes to a file first.
set -uo pipefail
mode="${1:-}"; shift || true
PKGS="motoko-ext-compose motoko-ext-herdr"
strip() { sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -v -E '^(Warning: dependency|Run .ailang lock.)'; }

gate_run() {
  G=$(mktemp -d "${TMPDIR:-/tmp}/p12dgate.XXXXXX")
  python3 tools/ext_ambient_inventory/derive.py --hook-scope --no-provision > "$G/out.txt" 2>&1
  echo "p12d: derive.py --hook-scope --no-provision exit $? (nonzero expected while other batches are red)"
}

case "$mode" in
  gate)
    [ $# -ge 1 ] || { echo "usage: $0 gate <ext>..." >&2; exit 2; }
    gate_run; fail=0
    for x in "$@"; do
      if grep -qE "^  ${x} +config-caps +pass *$" "$G/out.txt"; then echo "p12d: gate $x pass"
      else echo "p12d: gate $x NOT pass: $(grep -E "^  ${x} " "$G/out.txt")"; fail=1; fi
    done
    rm -rf "$G"; exit $fail ;;
  tree)
    gate_run
    grep -E "^REGISTRATION SHAPE: pass|^  binding rejections|^  (motoko_ext_)?(compose|herdr) " "$G/out.txt"
    rm -rf "$G"; exit 0 ;;
  check|test|channel|provider|registration) ;;
  *) echo "usage: $0 check|test|gate|tree|channel|provider|registration ..." >&2; exit 2 ;;
esac

T=$(mktemp -d "${TMPDIR:-/tmp}/p12dws.XXXXXX"); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/packages/motoko-ext-abi" "$T/packages/motoko-ext-ai-compat"
cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/packages/motoko-ext-abi/"
cp packages/motoko-ext-ai-compat/*.ail packages/motoko-ext-ai-compat/ailang.toml "$T/packages/motoko-ext-ai-compat/"
deps='"sunholo/motoko_ext_abi" = { path = "packages/motoko-ext-abi" }
"sunholo/motoko_ext_ai_compat" = { path = "packages/motoko-ext-ai-compat" }'
for p in $PKGS; do
  ( cd packages/$p && find . -name '*.ail' -o -name ailang.toml ) | while read -r f; do
    mkdir -p "$T/packages/$p/$(dirname "$f")"; cp "packages/$p/$f" "$T/packages/$p/$f"; done
  name=$(sed -nE 's/^name = "(.*)"/\1/p' "packages/$p/ailang.toml" | head -1)
  deps="$deps
\"$name\" = { path = \"packages/$p\" }"
done
cp .agent/projects/031_system_one_decisions/evidence/P1.2d/p12d_channel.ail "$T/"
cat > "$T/ailang.toml" <<TOML
[package]
name = "local/p12d"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"

[dependencies]
$deps

[effects]
max = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "Rand", "Trace"]
TOML
cd "$T"
ailang lock > lock.log 2>&1 || { strip < lock.log | tail -6; echo "p12d: ailang lock FAILED in the workspace"; exit 1; }
export AILANG_RELAX_MODULES=1
fail=0
case "$mode" in
  check)
    [ $# -ge 1 ] || { echo "usage: $0 check <pkg-dir>..." >&2; exit 2; }
    for p in "$@"; do
      ( cd "packages/$p" && ailang lock ) > pin.log 2>&1 \
        && echo "p12d: lock packages/$p ok (ABI pin $(sed -nE 's/.*motoko_ext_abi" = .*version = "([^"]*)".*/\1/p' packages/$p/ailang.toml))" \
        || { strip < pin.log | tail -4; echo "p12d: lock packages/$p FAILED (its ABI pin)"; fail=1; }
      for m in $(find packages/$p -name '*.ail' | sort); do
        ailang check "$m" > out.txt 2>&1; rc=$?
        if [ $rc -eq 0 ]; then echo "p12d: check $m ok"
        else strip < out.txt | grep -v -E 'WARNING MOD010|Auto-relaxed|Running under|^→' | tail -8; echo "p12d: check $m FAILED (exit $rc)"; fail=1; fi
      done
    done ;;
  test)
    [ $# -ge 1 ] || { echo "usage: $0 test <module.ail>..." >&2; exit 2; }
    for m in "$@"; do
      ailang test "$m" > out.txt 2>&1; rc=$?
      strip < out.txt > clean.txt
      line=$(grep -E '^[0-9]+ tests:' clean.txt | tail -1)
      [ -n "$line" ] || { tail -8 clean.txt; echo "p12d: test $m FAILED (exit $rc, no count line)"; fail=1; continue; }
      bad=""
      for t in $(sed -nE 's/^ *✗ ([A-Za-z0-9_]+) \(.*/\1/p' clean.txt); do
        case " ${P12D_KNOWN_RED:-} " in *" $t "*) echo "p12d: known red (pre-existing) $t";; *) bad="$bad $t";; esac
      done
      if [ -z "$bad" ] && [ $rc -eq 0 -o -n "${P12D_KNOWN_RED:-}" ]; then echo "p12d: test $m ok -- $line"
      else grep -E '✗|expected' clean.txt | head -12; echo "p12d: test $m FAILED:$bad (exit $rc; $line)"; fail=1; fi
    done ;;
  channel)
    ailang run --caps IO,Process,FS,Clock,AI,Env,Net,SharedMem,Stream,Rand,Trace --ai-stub --entry main p12d_channel.ail > out.txt 2>&1; rc=$?
    strip < out.txt | grep -E '^(OK|FAIL)'
    if [ $rc -eq 0 ] && grep -q '^OK: channel' out.txt; then echo "p12d: channel ok"
    else strip < out.txt | grep -v -E 'WARNING MOD010|Auto-relaxed|Running under|^→' | tail -6; echo "p12d: channel FAILED (exit $rc)"; fail=1; fi ;;
  provider)
    timeout 300 ailang run --caps IO,Process,FS,Clock,AI,Env,Net,SharedMem,Stream,Rand,Trace --ai-stub --entry compose_provider p12d_channel.ail > out.txt 2>&1; rc=$?
    grep -m1 'compose_start' out.txt | cut -c1-300
    if [ $rc -eq 0 ] && grep -q '^PROVIDER handled' out.txt && grep -q '"model":"p12d-sub-model"' out.txt && grep -q '"max_attempts":1' out.txt
    then echo "p12d: provider ok (model and attempts from ext_config)"
    else strip < out.txt | tail -6; echo "p12d: provider FAILED (exit $rc)"; fail=1; fi ;;
  registration)
    mkdir -p prof wd
    printf '{"compose":{"mode":"inline","subagent_model":"p12d-reg-model"}}' > prof/compose.json
    printf '{"tools":{"snippet_caps":["IO","Net"]}}' > prof/config.json
    env -u HERDR_ORCHESTRATOR -u MOTOKO_DAGR_DIR -u HERDR_DELEGATE_DIR MOTOKO_PROFILE_DIR="$T/prof" MOTOKO_WORKDIR="$T/wd" \
      HERDR_ENV=1 HERDR_BIN_PATH=/opt/probe/herdr HERDR_PANE_ID=w5:p7 MOTOKO_SESSION_MS=1756000000001 HERDR_ALLOWED_KINDS=claude,codex \
      ailang run --caps IO,Process,FS,Clock,AI,Env,Rand --entry registration p12d_channel.ail > out.txt 2>&1; rc=$?
    miss=""
    for want in '"mode":"inline"' '"subagent_model":"p12d-reg-model"' '"snippet_caps":["IO","Net"]' \
                '"own_pane":"w5:p7"' '"session_ms":"1756000000001"' '"bin":"/opt/probe/herdr"' '"allowed_kinds":"claude,codex"' \
                '"tools":["Delegate","DelegateCheck"]'; do
      grep -qF -- "$want" out.txt || miss="$miss $want"
    done
    if [ $rc -eq 0 ] && [ -z "$miss" ]; then echo "p12d: registration ok (config carries what registration read)"
    else strip < out.txt | grep CONFIG | cut -c1-400; echo "p12d: registration FAILED (exit $rc; missing:$miss)"; fail=1; fi ;;
esac
exit $fail
