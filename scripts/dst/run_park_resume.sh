#!/usr/bin/env bash
#
# PLAN-003 P4 (ADR-003 v6.1 D7): the park-resume rows, with the claim the
# in-process row cannot make read off stdout.
#
#   Part 2: a wake served from the `wakes` cursor emits NO `wake_request` and
#   reads no stdin, because the host has already answered it (Part 5). The
#   live binding prints its request with `println`, which the returned
#   `WakeInput` cannot show, so this script counts `"type":"wake_request"`
#   lines inside the row's PARK_RESUME_BEGIN/END frame: zero.
#
# stdin is /dev/null, so a binding that DOES ask the host gets "" from
# `readLine` and returns `Aborted`/"eof" (`live_wake_await`): the row goes red
# and cannot hang.
#
# Failing closed: the row count and every frame marker are asserted before any
# comparison, because the count below is zero over an empty wire.

set -euo pipefail

cd "$(dirname "$0")/../.."

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

echo "=== park_resume (PLAN-003 P4, ADR-003 D7) ==="

set +e
ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
  --entry main scripts/dst/park_resume_dst.ail < /dev/null > "$out" 2>&1
rc=$?
set -e

grep -v '^{' "$out" | grep -v '^PARK_RESUME_' | grep -E '^(  [✓✗]|      |PARK_|park_resume_dst|[a-zA-Z].*:$)' || true

fail=0
check() {
  if [ "$2" = "1" ]; then echo "  ✓ $1"; else echo "  ✗ $1"; [ -n "${3:-}" ] && echo "      $3"; fail=1; fi
}

frame() {  # frame LABEL -> the lines strictly inside the frame
  awk -v l="$1" '$0 == "PARK_RESUME_BEGIN " l { on = 1; next } $0 == "PARK_RESUME_END " l { on = 0 } on' "$out"
}

count_in() {  # count_in LABEL FIXED-STRING
  frame "$1" | grep -cF -- "$2" || true
}

check "the in-process rows passed (exit ${rc})" "$([ "$rc" -eq 0 ] && echo 1 || echo 0)"
rows="$(sed -n 's/^PARK_RESUME_ROWS \([0-9]*\)$/\1/p' "$out" | tail -1)"
check "all 1 rows reported" "$([ "${rows:-0}" -eq 1 ] && echo 1 || echo 0)" "PARK_RESUME_ROWS=${rows:-none}"

for label in live_cursor; do
  b="$(grep -cx "PARK_RESUME_BEGIN ${label}" "$out" || true)"; e="$(grep -cx "PARK_RESUME_END ${label}" "$out" || true)"
  check "frame ${label} is printed once, closed" "$([ "$b" -eq 1 ] && [ "$e" -eq 1 ] && echo 1 || echo 0)" "begin=${b} end=${e}"
done

requests="$(count_in live_cursor '"type":"wake_request"')"
check "live_cursor: no wake_request reaches stdout (the host already answered)" \
  "$([ "$requests" -eq 0 ] && echo 1 || echo 0)" "wake_request lines in frame: ${requests}"

if [ "$fail" -ne 0 ]; then echo "park_resume gate FAIL"; exit 1; fi
echo "park_resume gate PASS"
