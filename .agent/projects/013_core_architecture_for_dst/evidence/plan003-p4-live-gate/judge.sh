#!/usr/bin/env bash
# PLAN-003 P4 Part 7 (ADR-003 D7): the live gate's judge. Reads one session's wire log
# (`.motoko/logfile/<sid>.jsonl`, the SessionLogger's copy of the child's stdout, both children
# appended in order) and its journal (`.motoko/sessions/<sid>/journal.jsonl`), and checks the
# five gate items, the provider-call count across both child processes, and Part 7's T0 (the
# session directory's contents). Usage: judge.sh <sid> <log.jsonl> <journal.jsonl> <session-dir-listing-while-live> [expected-outcome]
set -uo pipefail
sid="$1"; log="$2"; journal="$3"; live_ls="$4"; outcome="${5:-settled}"
fail=0
check() { if [ "$2" = "1" ]; then echo "  ✓ $1"; else echo "  ✗ $1"; [ -n "${3:-}" ] && echo "      $3"; fail=1; fi; }
cnt() { grep -c -E -- "$1" "$2" || true; }
first_line() { grep -n -E -- "$1" "$2" | head -1 | cut -d: -f1; }

echo "=== live gate judge: $sid (expected wake outcome: $outcome) ==="
resumed_at="$(first_line '"type":"session_resumed"' "$log")"
check "the wire holds one session_resumed (the --resume child's first event)" "$([ "$(cnt '"type":"session_resumed"' "$log")" -eq 1 ] && echo 1 || echo 0)" "session_resumed lines: $(cnt '"type":"session_resumed"' "$log")"
[ -z "$resumed_at" ] && resumed_at=0
# Segment the wire at session_resumed: first child before it, resumed child from it.
first="$(mktemp)"; second="$(mktemp)"; trap 'rm -f "$first" "$second"' EXIT
head -n "$((resumed_at - 1))" "$log" > "$first"; tail -n "+$resumed_at" "$log" > "$second"

# (1) Delegate, then the run parks.
delegate_at="$(first_line '"type":"native_tool_calls".*"tool":"Delegate"' "$first")"
park_at="$(first_line '"type":"park_entered"' "$first")"
park_rid="$(grep -o -E '"type":"park_entered","request_id":"[^"]+"' "$first" | head -1 | sed 's/.*"request_id":"//; s/"$//')"
check "(1) Delegate is called, then the run parks (park_entered ${park_rid:-none})" "$([ -n "$delegate_at" ] && [ -n "$park_at" ] && [ "$delegate_at" -lt "$park_at" ] && echo 1 || echo 0)" "Delegate@${delegate_at:-none} park_entered@${park_at:-none}"
check "(1) the first child issued the wake_request for that park exactly once (attempt 0)" "$([ "$(cnt "\"type\":\"wake_request\",\"request_id\":\"$park_rid\",\"step\":[0-9]+,\"attempt\":0" "$first")" -eq 1 ] && echo 1 || echo 0)" "wake_request lines in the first child: $(cnt '"type":"wake_request"' "$first")"

# (2) The child exits with no error; the journal's leaf at that moment is the park.
check "(2) no error event from the first child, and no wake_received from it (it was ended on the park)" "$([ "$(cnt '"type":"error"' "$first")" -eq 0 ] && [ "$(cnt '"type":"wake_received"' "$first")" -eq 0 ] && echo 1 || echo 0)" "error=$(cnt '"type":"error"' "$first") wake_received=$(cnt '"type":"wake_received"' "$first")"
kinds="$(grep -o '"type":"[a-z_]*"' "$journal" | sed 's/"type"://; s/"//g' | tr '\n' ' ')"
park_line="$(grep -n -E "\"type\":\"park\",\"request_id\":\"$park_rid\"" "$journal" | head -1)"
park_no="$(echo "$park_line" | cut -d: -f1)"
park_id="$(echo "$park_line" | grep -o '"id":"[0-9]*"' | head -1 | sed 's/"id":"//; s/"//')"
next_after_park="$(sed -n "$((park_no + 1))p" "$journal" | grep -o '"type":"[a-z_]*"' | head -1)"
check "(2) the journal's entry after the park is the wake — nothing (no exit) was appended between them" "$([ -n "$park_no" ] && [ "$next_after_park" = '"type":"wake"' ] && echo 1 || echo 0)" "park at line ${park_no:-none} (id ${park_id:-none}); next: ${next_after_park:-none}; kinds: $kinds"

# (3) The delegate answers; exactly one wake entry is the park's child.
wake_children="$(grep -c -E "\"parent_id\":\"$park_id\".*\"type\":\"wake\"" "$journal" || true)"
wake_entry="$(grep -E "\"parent_id\":\"$park_id\".*\"type\":\"wake\"" "$journal" | head -1)"
wake_outcome="$(echo "$wake_entry" | grep -o '"outcome":"[a-z_]*"' | sed 's/"outcome":"//; s/"//')"
check "(3) exactly one wake entry is the park's child, outcome $outcome" "$([ "$wake_children" = "1" ] && [ "$wake_outcome" = "$outcome" ] && echo 1 || echo 0)" "children=$wake_children outcome=${wake_outcome:-none}"
check "(3) the journal holds exactly one wake for the first park's request_id" "$([ "$(cnt "\"type\":\"wake\",\"request_id\":\"$park_rid\"" "$journal")" -eq 1 ] && echo 1 || echo 0)"

# (4) The host respawns with --resume; the resumed frame serves <R'>.p0 from the cursor.
resumed_entry="$(grep -c '"type":"resumed"' "$journal" || true)"
check "(4) the journal holds one resumed entry (a --resume child folded it)" "$([ "$resumed_entry" = "1" ] && echo 1 || echo 0)" "resumed entries: $resumed_entry"
rp0="$(grep -o -E '"type":"wake_received","request_id":"[^"]+"' "$second" | head -1 | sed 's/.*"request_id":"//; s/"$//')"
first_wr="$(first_line '"type":"wake_request"' "$second")"
first_wrecv="$(first_line '"type":"wake_received"' "$second")"
check "(4) the resumed child's first wake event is wake_received for <R'>.p0 (${rp0:-none}); no wake_request precedes it" "$([ -n "$first_wrecv" ] && { [ -z "$first_wr" ] || [ "$first_wrecv" -lt "$first_wr" ]; } && echo "$rp0" | grep -q -E '\.r1\.0\.p0$' && echo 1 || echo 0)" "wake_received@${first_wrecv:-none} wake_request@${first_wr:-none}"
wake_detail="$(echo "$wake_entry" | grep -o '"detail":".*"' | head -1)"
rp0_detail="$(grep -E '"type":"wake_received"' "$second" | head -1 | grep -o '"detail":".*"' | head -1)"
check "(4) the served wake carries the journal's wake: same outcome and detail" "$([ -n "$rp0_detail" ] && [ "$rp0_detail" = "$wake_detail" ] && grep -q "\"type\":\"wake_received\",\"request_id\":\"$rp0\",\"wait_id\":\"[^\"]*\",\"outcome\":\"$outcome\"" "$second" && echo 1 || echo 0)" "journal: ${wake_detail:0:80} / wire: ${rp0_detail:0:80}"
start_at="$(first_line '"type":"session_start".*"run_id":"[^"]*\.r1\.0"' "$second")"
check "(4) exactly once on the wire: wake_received(<R'>.p0) precedes session_start(R')" "$([ -n "$start_at" ] && [ "$first_wrecv" -lt "$start_at" ] && echo 1 || echo 0)" "wake_received@${first_wrecv:-none} session_start(r1.0)@${start_at:-none}"
check "(4) the journal: run_started(R') comes after the wake for <R'>.p0" "$([ -n "$(first_line "\"type\":\"wake\",\"request_id\":\"$rp0\"" "$journal")" ] && [ "$(first_line "\"type\":\"wake\",\"request_id\":\"$rp0\"" "$journal")" -lt "$(first_line '"type":"run_started","run_id":"[^"]*\.r1\.0"' "$journal")" ] && echo 1 || echo 0)"

# (5) DelegateCheck, then the final answer.
check_at="$(first_line '"type":"native_tool_calls".*"tool":"DelegateCheck"' "$second")"
done_at="$(first_line '"type":"done"' "$second")"
check "(5) the resumed child calls DelegateCheck, then reports done; no error" "$([ -n "$check_at" ] && [ -n "$done_at" ] && [ "$check_at" -lt "$done_at" ] && [ "$(cnt '"type":"error"' "$second")" -eq 0 ] && echo 1 || echo 0)" "DelegateCheck@${check_at:-none} done@${done_at:-none} error=$(cnt '"type":"error"' "$second")"

# The provider-call count across both processes.
c1="$(cnt '"type":"provider_call_prepared"' "$first")"; c2="$(cnt '"type":"provider_call_prepared"' "$second")"
echo "  provider_call_prepared: first child $c1, resumed child $c2, total $((c1 + c2))"
check "provider calls across both processes: 4 (2 + 2)" "$([ "$((c1 + c2))" -eq 4 ] && echo 1 || echo 0)"

# T0, live: the session directory.
check "T0 live: while the session ran, the session directory held journal.jsonl and lease only" "$([ "$(tr '\n' ' ' < "$live_ls" | sed 's/ *$//')" = "journal.jsonl lease" ] && echo 1 || echo 0)" "$(tr '\n' ' ' < "$live_ls")"
echo "journal kinds: $kinds"
if [ "$fail" -ne 0 ]; then echo "live gate judge FAIL"; exit 1; fi
echo "live gate judge PASS"
