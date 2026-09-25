#!/usr/bin/env bash
#
# WI-C3: D6.4's parity, with the two sides produced by DIFFERENT THINGS.
#
# =============================================================================
# Why this gate is in the shell and not in the invariant suite
# =============================================================================
#
# `stream_parity_dst.ail` compares the run's emission witness against the
# StreamDelta records in the returned trace, and both of those derive from
# `ProviderExchange.emissions` — the log the provider returned. That is not a
# shortcut; it is the ONLY in-process observation of the stream. The callback's
# own projections go to `ledger_emit`, which returns `()`, and the callback's row
# is closed `{IO}` so it cannot accumulate what it saw. D1 rejected the scoped
# recorder that would let it, and selecting it needs an amendment rather than a
# workaround.
#
# So the in-process check tests THREADING: that every branch after the provider
# call carries the trace and the witness forward together. What it cannot test is
# the thing D6.4 actually says — that the projected sequence and the returned
# emission log match.
#
# The projected sequence IS observable. It is the wire: `ledger_emit` writes one
# `thinking_delta` JSON line per projected chunk to stdout. That is written by
# the callback, DURING the call, from the chunk the provider handed it. The
# `STREAM_TRACE` line is written after the call, from the log the provider
# RETURNED, by way of `stream_chunk_events` and `ledger_append`. Two producers,
# two channels, one claim — which is what makes this comparison worth making and
# the in-process one insufficient on its own.
#
# =============================================================================
# The vacuity guard, and it earned its place at WI-C2
# =============================================================================
#
# Every assertion below is green over two empty sequences. A probe that produced
# no evidence must FAIL rather than print a screen of silent passes, so the wire
# count and the trace count are both asserted positive before anything is
# compared, and the expected count is read out of the run rather than written
# here.

set -euo pipefail

cd "$(dirname "$0")/../.."

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

echo "=== stream_parity wire-vs-trace (D6.4) ==="

set +e
ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
  --entry main scripts/dst/stream_parity_dst.ail < /dev/null > "$out" 2>&1
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "FAIL: scripts/dst/stream_parity_dst.ail exited ${rc}"
  grep -v '^{' "$out" | tail -40
  exit 1
fi

fail=0

check() {
  if [ "$2" = "1" ]; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1"
    [ -n "${3:-}" ] && echo "      $3"
    fail=1
  fi
}

# The wire side: what the CALLBACK projected, in arrival order.
wire="$(grep -o '"type":"thinking_delta".*"text_delta":"[^"]*"' "$out" \
        | sed 's/.*"text_delta":"\([^"]*\)"/\1|/' | tr -d '\n')"

# The trace side: what the DRIVER appended, from the returned log. Two runs, so
# two STREAM_TRACE lines, concatenated in the order they were produced.
trace="$(grep '^STREAM_TRACE ' "$out" | sed 's/^STREAM_TRACE [a-z]* //' | tr -d '\n')"

wire_n="$(grep -c '"type":"thinking_delta"' "$out" || true)"
trace_n="$(printf '%s' "$trace" | tr -cd '|' | wc -c | tr -d ' ')"
subjects="$(grep -c '^STREAM_TRACE ' "$out" || true)"

echo "  wire_deltas=${wire_n} trace_deltas=${trace_n} subjects=${subjects}"

# --- vacuity, before any comparison -----------------------------------------
check "the run projected at least one delta to the wire" \
      "$([ "$wire_n" -gt 0 ] && echo 1 || echo 0)" \
      "no thinking_delta on the wire: every row below would be vacuous"
check "the run appended at least one delta to the returned trace" \
      "$([ "$trace_n" -gt 0 ] && echo 1 || echo 0)" \
      "no StreamDelta in the returned trace: every row below would be vacuous"
check "both subjects reported a trace side" \
      "$([ "$subjects" -eq 2 ] && echo 1 || echo 0)" \
      "expected 2 STREAM_TRACE lines (scripted, recording), got ${subjects}"

if [ "$fail" -ne 0 ]; then
  echo "stream_parity wire gate FAIL (vacuous)"
  exit 1
fi

# --- the comparison ----------------------------------------------------------
# Count and order are SEPARATE rows for the same reason `stream_parity_findings`
# keeps them separate: a reordering leaves the count identical, so a count row
# alone would be green on the defect the order row exists for.
check "COUNT: the wire projected exactly as many deltas as the trace holds" \
      "$([ "$wire_n" -eq "$trace_n" ] && echo 1 || echo 0)" \
      "wire=${wire_n} trace=${trace_n}"
check "ORDER AND CONTENT: the projected sequence equals the returned sequence" \
      "$([ "$wire" = "$trace" ] && echo 1 || echo 0)" \
      "wire=${wire}
      trace=${trace}"

# The fixture's own adequacy, asserted here too rather than trusted from the
# .ail side: a sequence with no adjacent repeat cannot distinguish an
# implementation that de-duplicates, and one shorter than three chunks barely
# exercises order at all.
check "the compared sequence carries an adjacent repeat, so de-duplication is visible" \
      "$(printf '%s' "$wire" | grep -q 'rep|rep|' && echo 1 || echo 0)" \
      "no adjacent repeat in the projected sequence"

if [ "$fail" -ne 0 ]; then
  echo "stream_parity wire gate FAIL"
  exit 1
fi

echo "stream_parity wire gate PASS"
