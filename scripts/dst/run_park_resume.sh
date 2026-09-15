#!/usr/bin/env bash
#
# PLAN-003 P4 (ADR-003 v6.1 D7): the park-resume rows, with the claims the
# in-process rows cannot make read off stdout.
#
#   Part 2: a wake served from the `wakes` cursor emits NO `wake_request` and
#   reads no stdin, because the host has already answered it (Part 5). The
#   live binding prints its request with `println`, which the returned
#   `WakeInput` cannot show, so this script counts `"type":"wake_request"`
#   lines inside the row's PARK_RESUME_BEGIN/END frame: zero.
#
#   Part 3: (a) R2 — a DROPPED reply appends nothing and emits one `warning`;
#   the trace cannot show a warning, so the `resume_dropped` frame prints
#   `PARK_DROPS resume_dropped <n>` and this script counts the `park dropped a
#   wake reply` warnings inside that frame: equal, non-zero. (b) D7's
#   exactly-once ORDER on the wire: inside the `resume_after_wake` frame the
#   `wake_received` for `<R'>.p0` (`w4.r1.0.p0`) precedes the `session_start`
#   that names `R'` (`w4.r1.0`), and there is exactly one of each.
#
# stdin is /dev/null, so a binding that DOES ask the host gets "" from
# `readLine` and returns `Aborted`/"eof" (`live_wake_await`): the row goes red
# and cannot hang.
#
# Failing closed: the row count and every frame marker are asserted before any
# comparison, because the counts below are zero over an empty wire.

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

grep -v '^{' "$out" | grep -v '^PARK_RESUME_' | grep -E '^(  [✓✗]|      |PARK_|park_resume_dst|[a-zA-Z].*:$|Error|error|.*rror:)' || true

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

first_line_in() {  # first_line_in LABEL REGEX -> 1-based line index inside the frame, or empty
  frame "$1" | grep -nE -- "$2" | head -1 | cut -d: -f1
}

check "the in-process rows passed (exit ${rc})" "$([ "$rc" -eq 0 ] && echo 1 || echo 0)"
rows="$(sed -n 's/^PARK_RESUME_ROWS \([0-9]*\)$/\1/p' "$out" | tail -1)"
check "all 7 rows reported" "$([ "${rows:-0}" -eq 7 ] && echo 1 || echo 0)" "PARK_RESUME_ROWS=${rows:-none}"

for label in live_cursor first_run resume_after_wake resume_after_park resume_park_exit resume_aborted resume_dropped; do
  b="$(grep -cx "PARK_RESUME_BEGIN ${label}" "$out" || true)"; e="$(grep -cx "PARK_RESUME_END ${label}" "$out" || true)"
  check "frame ${label} is printed once, closed" "$([ "$b" -eq 1 ] && [ "$e" -eq 1 ] && echo 1 || echo 0)" "begin=${b} end=${e}"
done

requests="$(count_in live_cursor '"type":"wake_request"')"
check "live_cursor: no wake_request reaches stdout (the host already answered)" \
  "$([ "$requests" -eq 0 ] && echo 1 || echo 0)" "wake_request lines in frame: ${requests}"

drop_warning="park dropped a wake reply"
drops="$(sed -n "s/^PARK_DROPS resume_dropped \([0-9]*\)$/\1/p" "$out" | tail -1)"
warnings="$(count_in resume_dropped "$drop_warning")"
check "resume_dropped: one warning per dropped reply (drops=${drops:-none}, warnings=${warnings})" \
  "$([ -n "${drops}" ] && [ "${drops}" -gt 0 ] && [ "$warnings" -eq "$drops" ] && echo 1 || echo 0)"
check "resume_dropped: no wake_received reaches the wire" "$([ "$(count_in resume_dropped '"type":"wake_received"')" -eq 0 ] && echo 1 || echo 0)"
for label in resume_after_wake resume_after_park resume_park_exit resume_aborted; do
  check "${label}: no reply is dropped" "$([ "$(count_in "$label" "$drop_warning")" -eq 0 ] && echo 1 || echo 0)"
done

wake_p0="$(first_line_in resume_after_wake '"type":"wake_received".*"request_id":"w4\.r1\.0\.p0"')"
started="$(first_line_in resume_after_wake '"type":"session_start".*"run_id":"w4\.r1\.0"')"
check "resume_after_wake: exactly one wake_received for w4.r1.0.p0 and one session_start for w4.r1.0 on the wire" \
  "$([ "$(count_in resume_after_wake '"request_id":"w4.r1.0.p0","wait_id":"h1","outcome":"settled"')" -eq 1 ] && [ "$(count_in resume_after_wake '"type":"session_start"')" -eq 1 ] && echo 1 || echo 0)" \
  "wake_received(p0)=$(count_in resume_after_wake '"request_id":"w4.r1.0.p0","wait_id":"h1","outcome":"settled"') session_start=$(count_in resume_after_wake '"type":"session_start"')"
check "resume_after_wake: exactly once, on the wire — wake_received(w4.r1.0.p0) precedes session_start(w4.r1.0)" \
  "$([ -n "$wake_p0" ] && [ -n "$started" ] && [ "$wake_p0" -lt "$started" ] && echo 1 || echo 0)" "wake_received@${wake_p0:-none} session_start@${started:-none}"
check "resume_aborted: no session_start on the wire (no run opens)" "$([ "$(count_in resume_aborted '"type":"session_start"')" -eq 0 ] && echo 1 || echo 0)"
check "abort/dropped: no error event in either frame" \
  "$([ "$(count_in resume_aborted '"type":"error"')" -eq 0 ] && [ "$(count_in resume_dropped '"type":"error"')" -eq 0 ] && echo 1 || echo 0)"

if [ "$fail" -ne 0 ]; then echo "park_resume gate FAIL"; exit 1; fi
echo "park_resume gate PASS"
