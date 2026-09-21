#!/usr/bin/env bash
#
# PLAN-002 W4 Parts 6-7 (ADR-002 D2/D3): the park-and-wake fixtures, with the
# three claims the in-process run cannot make read off stdout.
#
#   1. R2: a DROPPED reply appends nothing and emits one `warning`. The trace
#      cannot show a warning, so each frame that drops replies prints
#      `PARK_DROPS <label> <n>` and this script counts the `park dropped a wake
#      reply` warnings between that frame's PARK_RUN_BEGIN/END: equal, and
#      non-zero for `wrong_handle`. A frame that drops nothing (`success`) has
#      zero.
#   2. §8.7: after a mid-park `restart` the conversation loop emits ONE
#      `session_suspend` naming the profile; after `abort` it emits none.
#   3. Determinism, on the wire: the two runs from one script print
#      byte-identical frames.
#
# Failing closed: the fixture count and every marker are asserted before any
# comparison, because every comparison below is green over an empty wire.

set -euo pipefail

cd "$(dirname "$0")/../.."

out="$(mktemp)"
trap 'rm -f "$out" "${out}.a" "${out}.b"' EXIT

echo "=== park_wake (PLAN-002 W4 Parts 6-7) ==="

set +e
ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
  --entry main scripts/dst/park_wake_dst.ail < /dev/null > "$out" 2>&1
rc=$?
set -e

grep -v '^{' "$out" | grep -v '^PARK_RUN_' | grep -E '^(  [✓✗]|      |METRIC|PARK_|park_wake_dst|[a-zA-Z].*:$)' || true

fail=0
check() {
  if [ "$2" = "1" ]; then echo "  ✓ $1"; else echo "  ✗ $1"; [ -n "${3:-}" ] && echo "      $3"; fail=1; fi
}

frame() {  # frame LABEL -> the lines strictly inside the frame
  awk -v l="$1" '$0 == "PARK_RUN_BEGIN " l { on = 1; next } $0 == "PARK_RUN_END " l { on = 0 } on' "$out"
}

count_in() {  # count_in LABEL FIXED-STRING
  frame "$1" | grep -cF -- "$2" || true
}

check "the in-process fixtures passed (exit ${rc})" "$([ "$rc" -eq 0 ] && echo 1 || echo 0)"
fixtures="$(sed -n 's/^PARK_WAKE_FIXTURES \([0-9]*\)$/\1/p' "$out" | tail -1)"
check "all 17 fixtures reported" "$([ "${fixtures:-0}" -eq 17 ] && echo 1 || echo 0)" "PARK_WAKE_FIXTURES=${fixtures:-none}"

for label in success wrong_handle duplicate_wake abort_exit restart_exit determinism_a determinism_b; do
  b="$(grep -cx "PARK_RUN_BEGIN ${label}" "$out" || true)"; e="$(grep -cx "PARK_RUN_END ${label}" "$out" || true)"
  check "frame ${label} is printed once, closed" "$([ "$b" -eq 1 ] && [ "$e" -eq 1 ] && echo 1 || echo 0)" "begin=${b} end=${e}"
done

drop_warning="park dropped a wake reply"
for label in wrong_handle duplicate_wake; do
  drops="$(sed -n "s/^PARK_DROPS ${label} \([0-9]*\)$/\1/p" "$out" | tail -1)"
  warnings="$(count_in "$label" "$drop_warning")"
  check "${label}: one warning per dropped reply (drops=${drops:-none}, warnings=${warnings})" \
    "$([ -n "${drops}" ] && [ "${drops}" -gt 0 ] && [ "$warnings" -eq "$drops" ] && echo 1 || echo 0)"
done
check "success: no reply is dropped" "$([ "$(count_in success "$drop_warning")" -eq 0 ] && echo 1 || echo 0)"
check "wrong_handle: no wake_received reaches the wire" "$([ "$(count_in wrong_handle '"type":"wake_received"')" -eq 0 ] && echo 1 || echo 0)"
check "wrong_handle: one park_entered on the wire" "$([ "$(count_in wrong_handle '"type":"park_entered"')" -eq 1 ] && echo 1 || echo 0)"

check "restart: the conversation loop's exit emits one session_suspend for dogfood" \
  "$([ "$(count_in restart_exit '"type":"session_suspend"')" -eq 1 ] && [ "$(count_in restart_exit '"target_profile":"dogfood"')" -eq 1 ] && echo 1 || echo 0)"
check "abort: the conversation loop's exit emits no session_suspend" \
  "$([ "$(count_in abort_exit '"type":"session_suspend"')" -eq 0 ] && echo 1 || echo 0)"
check "abort/restart: no error event in either run" \
  "$([ "$(count_in abort '"type":"error"')" -eq 0 ] && [ "$(count_in restart '"type":"error"')" -eq 0 ] && echo 1 || echo 0)"

frame determinism_a > "${out}.a"
frame determinism_b > "${out}.b"
check "determinism: the two runs' wire frames are byte-identical ($(wc -l < "${out}.a") lines)" \
  "$([ -s "${out}.a" ] && cmp -s "${out}.a" "${out}.b" && echo 1 || echo 0)" "$(diff "${out}.a" "${out}.b" | head -5)"

if [ "$fail" -ne 0 ]; then echo "park_wake gate FAIL"; exit 1; fi
echo "park_wake gate PASS"
