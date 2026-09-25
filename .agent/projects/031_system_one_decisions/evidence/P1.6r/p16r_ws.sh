#!/usr/bin/env bash
# 031 PLAN-001 P1.6r: check / test / run this part's files against THIS checkout's
# tracked tree in a throwaway workspace. Run from a repo root (the primary, a clone,
# or a mutgate throwaway):
#
#   p16r_ws.sh check <module.ail>...      ailang check each (AILANG_RELAX_MODULES=1:
#                                         scripts/ and examples/ declare module names
#                                         that do not match their paths)
#   p16r_ws.sh test <module.ail>...       ailang test each; "N passed, 0 failed" required
#   p16r_ws.sh run <caps> <entry> <module.ail> <marker> [--ai-stub]
#                                         ailang run; exit 0 AND the marker line required
#   p16r_ws.sh make <target>...           make <target> inside the workspace (full tracked
#                                         tree, so the Makefile's python and ailang steps
#                                         see the same files)
#
# WHY A WORKSPACE (the ailang.lock trap): the tracked root ailang.lock pins path
# dependencies to the PRIMARY checkout's absolute path, so a check inside a clone would
# resolve the primary's packages. This copies the cwd's TRACKED files (their working-
# tree bytes, so a mutation applied in the cwd is what gets checked) into a fresh
# directory, drops ailang.lock and runs `ailang lock` there: every path dependency then
# resolves inside the workspace. Nothing resolves to the primary.
# No `cmd | grep -q` under pipefail: output goes to a file first.
set -uo pipefail
mode="${1:-}"; shift || true
case "$mode" in check|test|run|make) ;; *) echo "usage: $0 check|test|run|make ..." >&2; exit 2;; esac
strip() { sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -v -E '^(Warning: dependency|Run .ailang lock.)|WARNING MOD010|Auto-relaxed|Running under'; }

# NOT under /tmp: the ambient/call-inventory harnesses refuse a repo there (AILANG
# auto-relaxes MOD010 under /tmp), so the workspace lives in the user cache.
mkdir -p "${P16R_WS_ROOT:-$HOME/.cache/p16r}"
T=$(mktemp -d "${P16R_WS_ROOT:-$HOME/.cache/p16r}/p16rws.XXXXXX"); trap 'rm -rf "$T"' EXIT
git ls-files -z | grep -z -v -E '^ailang\.lock$|^little-coder/' | tar --null -T - -cf - 2>/dev/null | tar -x -C "$T"
cd "$T"
ailang lock > lock.log 2>&1 || { strip < lock.log | tail -6; echo "p16r: ailang lock FAILED in the workspace"; exit 1; }
export AILANG_RELAX_MODULES=1
fail=0
case "$mode" in
  check)
    for m in "$@"; do
      ailang check "$m" > out.txt 2>&1; rc=$?
      if [ $rc -eq 0 ]; then echo "p16r: check $m ok"
      else strip < out.txt | grep -v '^→' | head -8; echo "p16r: check $m FAILED (exit $rc)"; fail=1; fi
    done ;;
  test)
    for m in "$@"; do
      ailang test "$m" > out.txt 2>&1; rc=$?
      strip < out.txt > clean.txt
      line=$(grep -E '^[0-9]+ tests:' clean.txt | tail -1)
      if [ $rc -eq 0 ] && grep -qE '^[0-9]+ tests: [0-9]+ passed, 0 failed' clean.txt; then echo "p16r: test $m ok -- $line"
      else grep -v '^→' clean.txt | tail -10; echo "p16r: test $m FAILED (exit $rc; $line)"; fail=1; fi
    done ;;
  run)
    caps="$1"; entry="$2"; m="$3"; marker="$4"; stub="${5:-}"
    timeout 1200 ailang run --caps "$caps" $stub --entry "$entry" "$m" < /dev/null > out.txt 2>&1; rc=$?
    if [ $rc -eq 0 ] && grep -qF -- "$marker" out.txt; then echo "p16r: run $m:$entry ok ($marker)"
    else strip < out.txt | grep -v '^→' | tail -12; echo "p16r: run $m:$entry FAILED (exit $rc; marker '$marker')"; fail=1; fi ;;
  make)
    for t in "$@"; do
      timeout 1800 make --no-print-directory "$t" < /dev/null > out.txt 2>&1; rc=$?
      if [ $rc -eq 0 ]; then echo "p16r: make $t ok"; strip < out.txt | grep -E '✓|✗|PASS|FAIL' | tail -4
      else strip < out.txt | grep -v '^→' | tail -14; echo "p16r: make $t FAILED (exit $rc)"; fail=1; fi
    done ;;
esac
exit $fail
