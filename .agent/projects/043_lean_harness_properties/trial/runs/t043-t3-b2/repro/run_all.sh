#!/usr/bin/env bash
# run_all.sh — every repro in ../reports.tsv, on the unmodified code (expect exit 1) and, where
# a one-line fix exists, against a patched temporary copy (T3_FIX; expect exit 0). Logs to logs/.
#   (from anywhere)  out/repro/run_all.sh [name-regex]   only the cases whose name matches
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../tree" && pwd)"
mkdir -p "$here/logs"
SPEC_560='accept|s:you are motoko::;a:[CHECKPOINT] s::;a:plain::|#0'
SPEC_58='accept|s:you are motoko::;a:[CHECKPOINT] s::;u:next::|#0'
only="${1:-}"
run() { # name fix expected args...
  local name="$1" fix="$2" want="$3"; shift 3
  [[ -z "$only" || "$name" =~ $only ]] || return 0
  local t0=$SECONDS
  ( cd "$repo" && T3_FIX="$fix" "$here/case.sh" "$@" ) > "$here/logs/$name.log" 2>&1
  local rc=$?
  printf '%-28s fix=%-5s exit=%d want=%d  %3ds  %s\n' "$name" "${fix:--}" "$rc" "$want" $((SECONDS - t0)) \
    "$([[ $rc == "$want" ]] && echo ok || echo UNEXPECTED)" | tee -a "$here/logs/summary.txt"
}
[[ -n "$only" ]] || : > "$here/logs/summary.txt"
run B2-T3-1            ""   1 5,6,0 p31
run B2-T3-1.fixed      twin 0 5,6,0 p31
run B2-T3-2            ""   1 5,6,0 p32 "$SPEC_560"
run B2-T3-2.fixed      twin 0 5,6,0 p32 "$SPEC_560"
run B2-T3-3            ""   1 0,4,6 p31
run B2-T3-3.fixed      host 0 0,4,6 p31
run B2-T3-4            ""   1 0,4,6,0 p31-across
run B2-T3-4.fixed      host 0 0,4,6,0 p31-across
run B2-T3-5            ""   1 5,8 p32 "$SPEC_58"
run B2-T3-5.bothfixes  both 1 5,8 p32 "$SPEC_58"
run B2-T3-6            ""   1 x1 p31
