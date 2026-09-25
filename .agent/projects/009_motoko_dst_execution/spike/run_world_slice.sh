#!/usr/bin/env bash
# Vertical slice of the ADR-001 D1 world protocol, run against the real provider.
#
# Answers the question the other probes do not: can a driver actually satisfy D1
# with the proposed recorded-stream API? Runs a full discovery -> replay cycle
# and asserts live/deterministic parity, on both outcomes.
#
# PREREQUISITE: a toolchain containing stepWithStreamRecorded (a local
# prototype as of 2026-07-25 — the upstream API has not landed).
#
#   AILANG_SRC=~/src/ailang AILANG_BIN=~/src/ailang/bin/ailang ./run_world_slice.sh

set -uo pipefail

AILANG_SRC="${AILANG_SRC:-$HOME/src/ailang}"
AILANG_BIN="${AILANG_BIN:-$AILANG_SRC/bin/ailang}"
PORT="${PORT:-8820}"
PROBE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="$PROBE_DIR/probe_world_protocol_slice.ail"
SERVER="$PROBE_DIR/fault_sse_server.py"

failures=0
srv_pid=""

cleanup() { [ -n "$srv_pid" ] && kill "$srv_pid" 2>/dev/null; }
trap cleanup EXIT

check() { # check <label> <actual> <expected>
  if [ "$2" = "$3" ]; then
    echo "  PASS $1"
  else
    echo "  FAIL $1: got '$2' want '$3'"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$AILANG_BIN" ]; then
  echo "FAIL: no toolchain at $AILANG_BIN"
  echo "      This slice needs a build containing stepWithStreamRecorded."
  exit 1
fi

run_mode() { # run_mode <mode> <expected_outcome_record>
  local mode="$1" expect_outcome="$2" out
  echo "mode=$mode"

  MODE="$mode" PORT="$PORT" python3 "$SERVER" >/dev/null 2>&1 &
  srv_pid=$!
  sleep 1.5

  out="$(cd "$AILANG_SRC" && \
    OPENAI_BASE_URL="http://127.0.0.1:$PORT" OPENAI_API_KEY=probe \
    AILANG_RELAX_MODULES=1 \
    "$AILANG_BIN" run --caps AI,IO --ai gpt5-mini --entry main "$PROBE" 2>&1)"

  kill "$srv_pid" 2>/dev/null; srv_pid=""

  local live_proj replay_proj emissions live_trace replay_trace probe_fails
  live_proj="$(grep -c '^PROJECT live ' <<<"$out")"
  replay_proj="$(grep -c '^PROJECT replay ' <<<"$out")"
  emissions="$(sed -n 's/^SLICE emissions=\([0-9]*\)$/\1/p' <<<"$out")"
  live_trace="$(sed -n 's/^SLICE live_trace=\(.*\)$/\1/p' <<<"$out")"
  replay_trace="$(sed -n 's/^SLICE replay_trace=\(.*\)$/\1/p' <<<"$out")"

  # Every in-probe assertion must have passed.
  probe_fails="$(grep -c '^FAIL ' <<<"$out")"
  check "probe_assertions (in-probe FAILs)" "$probe_fails" "0"

  # The recorded program was non-empty — guards against a vacuous parity pass,
  # which is exactly what the current callback-only API would produce.
  if [ "${emissions:-0}" -gt 0 ] 2>/dev/null; then
    echo "  PASS program_non_empty (emissions=$emissions)"
  else
    echo "  FAIL program_non_empty: emissions='${emissions:-none}'"
    failures=$((failures + 1))
  fi

  # No double projection: each path projected exactly once per emission.
  check "live_projection_count" "$live_proj" "${emissions:-none}"
  check "replay_projection_count" "$replay_proj" "${emissions:-none}"

  # D1: the two paths produce the same event ordering and content.
  check "trace_parity (live == replay)" "${live_trace:-none}" "${replay_trace:-none}"

  # The trace ends with the final response record, after every emission.
  check "trace_terminal_record" \
    "$(sed 's:.*/\([^/]*\)/$:\1:' <<<"${live_trace:-}")" "$expect_outcome"

  if [ "$failures" -ne 0 ]; then
    echo "$out" | sed 's/^/      | /'
  fi
}

echo "=== D1 world-protocol vertical slice ==="
echo "toolchain: $("$AILANG_BIN" --version | head -1) ($AILANG_BIN)"
echo

run_mode success       "outcome:ok:finish:stop"
echo
run_mode partial_error "outcome:err:code:ConnectionFailed"

echo
if [ "$failures" -eq 0 ]; then
  echo "world_slice: PASS — live and deterministic paths agree on both outcomes"
  exit 0
fi
echo "world_slice: FAIL — $failures assertion(s) failed"
exit 1
