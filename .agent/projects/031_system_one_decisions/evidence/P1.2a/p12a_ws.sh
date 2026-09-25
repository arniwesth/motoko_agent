#!/usr/bin/env bash
# 031 PLAN-001 P1.2a: check / test batch A's six packages against THIS checkout's
# ABI 8.0 package in a throwaway workspace, and read the registration-shape gate.
# Run from a repo root (the primary, a clone, or a mutgate throwaway):
#
#   p12a_ws.sh check <pkg-dir>...     `ailang lock` in the package (its own ABI pin) and
#                                     ailang check every .ail of it
#                                     (packages/<pkg-dir>/*.ail); exit 1 on any failure
#   p12a_ws.sh test <module.ail>...   ailang test each (paths under packages/); the
#                                     count line is required and every failing test
#                                     must be named in P12A_KNOWN_RED (space-separated)
#   p12a_ws.sh smoke                  omnigraph's own boot smoke (_smoke.ail), in an
#                                     empty workdir: exit 0 and an "OK:" line
#   p12a_ws.sh channel                the omnigraph configuration-channel probe
#                                     (p12a_omnigraph_channel.ail, beside this script)
#   p12a_ws.sh gate <ext>...          `derive.py --hook-scope --no-provision` over the
#                                     cwd; each named extension's shape must read `pass`
#   p12a_ws.sh tree <pass> <bindings> the same run; the summary must read exactly
#                                     "pass <pass> of 18" and "binding rejections <bindings>"
#
# WHY A WORKSPACE (the ailang.lock trap). Tracked lock files pin path dependencies
# to the PRIMARY checkout's absolute path, so a check inside a clone resolves the
# primary's packages. This copies the cwd's ABI package and the six packages
# (.ail files and ailang.toml only, never a lock) into a fresh directory whose root
# ailang.toml names path dependencies INSIDE it, and runs `ailang lock` there --
# which also enforces each package's `version = "8.0"` pin on the ABI.
#
# WHY THE GATE RUNS WITHOUT PROVISIONING. `make ext_hook_scope` first compiles
# every installable extension and fails closed while any is red; batches B-D (12
# packages) are 7.4 until later parts, so it cannot reach the shape table on this
# tree. The registration-shape result is computed from source text (`locate` and
# the binding pass, never the walk), so `--no-provision` reads the same field.
#
# No `cmd | grep -q` under pipefail anywhere: output goes to a file first.
set -uo pipefail
mode="${1:-}"; shift || true
R=$(pwd)
E=.agent/projects/031_system_one_decisions/evidence/P1.2a
PKGS="motoko-ext-compaction-structural motoko-ext-decision-framework motoko-ext-empty-stop-guard motoko-ext-microrag motoko-ext-omnigraph motoko-ext-progress-contract-guard"
strip() { sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -v -E '^(Warning: dependency|Run .ailang lock.)'; }

gate_run() { # -> $G/out.txt
  G=$(mktemp -d "${TMPDIR:-/tmp}/p12agate.XXXXXX")
  python3 tools/ext_ambient_inventory/derive.py --hook-scope --no-provision > "$G/out.txt" 2>&1
  echo "p12a: derive.py --hook-scope --no-provision exit $? (nonzero is expected while batches B-D are red)"
}

case "$mode" in
  gate)
    [ $# -ge 1 ] || { echo "usage: $0 gate <ext>..." >&2; exit 2; }
    gate_run; fail=0
    for x in "$@"; do
      if grep -qE "^  ${x} +config-caps +pass *$" "$G/out.txt"; then echo "p12a: gate $x pass"
      else echo "p12a: gate $x NOT pass: $(grep -E "^  ${x} " "$G/out.txt")"; fail=1; fi
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

T=$(mktemp -d "${TMPDIR:-/tmp}/p12aws.XXXXXX"); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/packages/motoko-ext-abi"
cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/packages/motoko-ext-abi/"
deps='"sunholo/motoko_ext_abi" = { path = "packages/motoko-ext-abi" }'
for p in $PKGS; do
  mkdir -p "$T/packages/$p"; cp packages/$p/*.ail packages/$p/ailang.toml "$T/packages/$p/"
  name=$(sed -nE 's/^name = "(.*)"/\1/p' "packages/$p/ailang.toml" | head -1)
  deps="$deps
\"$name\" = { path = \"packages/$p\" }"
done
cp "$E/p12a_omnigraph_channel.ail" "$T/"
cat > "$T/ailang.toml" <<TOML
[package]
name = "local/p12a"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"

[dependencies]
$deps

[effects]
max = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "Rand", "Trace"]
TOML
cd "$T"
ailang lock > lock.log 2>&1 || { strip < lock.log | tail -6; echo "p12a: ailang lock FAILED in the workspace"; exit 1; }
export AILANG_RELAX_MODULES=1
fail=0
case "$mode" in
  check)
    [ $# -ge 1 ] || { echo "usage: $0 check <pkg-dir>..." >&2; exit 2; }
    for p in "$@"; do
      # The package's OWN manifest pins the ABI (`version = "8.0"`); a root lock
      # does not enforce a dependency's pin, so lock the package by itself too.
      ( cd "packages/$p" && ailang lock ) > pin.log 2>&1 \
        && echo "p12a: lock packages/$p ok (ABI pin $(sed -nE 's/.*motoko_ext_abi" = .*version = "([^"]*)".*/\1/p' packages/$p/ailang.toml))" \
        || { strip < pin.log | tail -4; echo "p12a: lock packages/$p FAILED (its ABI pin)"; fail=1; }
      for m in packages/$p/*.ail; do
        ailang check "$m" > out.txt 2>&1; rc=$?
        if [ $rc -eq 0 ]; then echo "p12a: check $m ok"
        else strip < out.txt | tail -8; echo "p12a: check $m FAILED (exit $rc)"; fail=1; fi
      done
    done ;;
  test)
    [ $# -ge 1 ] || { echo "usage: $0 test <module.ail>..." >&2; exit 2; }
    for m in "$@"; do
      ailang test "$m" > out.txt 2>&1; rc=$?
      strip < out.txt > clean.txt
      line=$(grep -E '^[0-9]+ tests:' clean.txt | tail -1)
      [ -n "$line" ] || { tail -8 clean.txt; echo "p12a: test $m FAILED (exit $rc, no count line)"; fail=1; continue; }
      bad=""
      for t in $(sed -nE 's/^ *✗ ([A-Za-z0-9_]+) \(.*/\1/p' clean.txt); do
        case " ${P12A_KNOWN_RED:-} " in *" $t "*) echo "p12a: known red (pre-existing) $t";; *) bad="$bad $t";; esac
      done
      if [ -z "$bad" ]; then echo "p12a: test $m ok -- $line"
      else grep -E '✗|expected' clean.txt | head -12; echo "p12a: test $m FAILED:$bad ($line)"; fail=1; fi
    done ;;
  smoke)
    mkdir -p empty_wd
    MOTOKO_WORKDIR="$T/empty_wd" ailang run --caps Env,FS,IO,Process,Rand --entry main \
      packages/motoko-ext-omnigraph/_smoke.ail > out.txt 2>&1; rc=$?
    strip < out.txt | tail -3
    if [ $rc -eq 0 ] && grep -q '^OK:' out.txt; then echo "p12a: smoke ok"; else echo "p12a: smoke FAILED (exit $rc)"; fail=1; fi ;;
  channel)
    mkdir -p wd/omnigraph
    printf 'P12A-SYNTHETIC-PROMPT line one\nline two\n' > wd/omnigraph/AGENT_PROMPT.md
    MOTOKO_WORKDIR="$T/wd" P12A_WORKDIR="$T/wd" ailang run --caps Env,FS,IO,Process,Rand --entry main \
      p12a_omnigraph_channel.ail > out.txt 2>&1; rc=$?
    strip < out.txt | grep -E '^(OK|FAIL)'
    if [ $rc -eq 0 ] && grep -q '^OK: channel' out.txt; then echo "p12a: channel ok"
    else strip < out.txt | tail -5; echo "p12a: channel FAILED (exit $rc)"; fail=1; fi ;;
esac
exit $fail
