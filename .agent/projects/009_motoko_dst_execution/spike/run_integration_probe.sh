#!/usr/bin/env bash
# Direct positive integration probe for the ADR-001 D1 streaming-capture gate.
#
# Drives probe_recorded_stream_integration.ail against a real native SSE
# provider in two modes, and asserts the five properties D1 requires before the
# ADR can be accepted.
#
# PREREQUISITE: a toolchain containing stepWithStreamRecorded. As of
# 2026-07-25 that is a local prototype only — the upstream API has not landed.
# Point AILANG_BIN and AILANG_SRC at it:
#
#   AILANG_SRC=~/src/ailang AILANG_BIN=~/src/ailang/bin/ailang ./run_integration_probe.sh
#
# AILANG_SRC must be the toolchain source root: the compiler resolves its
# stdlib from the working directory, and the probe needs the std/ai that
# exports stepWithStreamRecorded.
#
# Exits non-zero on the first failed assertion. Prints one PASS line per
# property per mode, then a summary.

set -uo pipefail

AILANG_SRC="${AILANG_SRC:-$HOME/src/ailang}"
AILANG_BIN="${AILANG_BIN:-$AILANG_SRC/bin/ailang}"
PORT="${PORT:-8817}"
PROBE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="$PROBE_DIR/probe_recorded_stream_integration.ail"
SERVER="$PROBE_DIR/fault_sse_server.py"

# The server supplies exactly these deltas in this order, in both modes.
SUPPLIED_COUNT=2
SUPPLIED_ORDER="partial-1|partial-2|"

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
  echo "      This probe needs a build containing stepWithStreamRecorded."
  exit 1
fi
run_mode() { # run_mode <mode> <expected_outcome>
  local mode="$1" expect_outcome="$2" out
  echo "mode=$mode"

  MODE="$mode" PORT="$PORT" python3 "$SERVER" >/dev/null 2>&1 &
  srv_pid=$!
  sleep 1.5

  # AILANG_RELAX_MODULES: the probe lives in this repo but must be compiled
  # from the toolchain source root (that is where its stdlib resolves from), so
  # its module name cannot match its absolute path.
  out="$(cd "$AILANG_SRC" && \
    OPENAI_BASE_URL="http://127.0.0.1:$PORT" OPENAI_API_KEY=probe \
    AILANG_RELAX_MODULES=1 \
    "$AILANG_BIN" run --caps AI,IO --ai gpt5-mini --entry main "$PROBE" 2>&1)"

  kill "$srv_pid" 2>/dev/null; srv_pid=""

  local live returned order outcome
  live="$(grep -c '^LIVE ' <<<"$out")"
  returned="$(sed -n 's/^RETURNED count=\([0-9]*\).*/\1/p' <<<"$out")"
  order="$(sed -n 's/^RETURNED .*order=\(.*\)$/\1/p' <<<"$out")"
  outcome="$(sed -n 's/^OUTCOME \(.*\)$/\1/p' <<<"$out")"

  # 5. no duplicate delivery — the callback fired once per supplied chunk
  check "no_duplicate_delivery (projected=$live)" "$live" "$SUPPLIED_COUNT"
  # 2. exact returned-log parity — returned list matches what was projected
  check "returned_parity_count (returned=$returned)" "${returned:-none}" "$SUPPLIED_COUNT"
  check "returned_parity_order" "${order:-none}" "$SUPPLIED_ORDER"
  # 3/4. the outcome itself
  check "outcome" "${outcome:-none}" "$expect_outcome"

  # 1. immediate projection — every LIVE line lies between CALL begin and
  # RETURNED, so chunks reached the sink during the call, not after it.
  local begin_ln last_live_ln returned_ln
  begin_ln="$(grep -n '^CALL begin$' <<<"$out" | head -1 | cut -d: -f1)"
  last_live_ln="$(grep -n '^LIVE ' <<<"$out" | tail -1 | cut -d: -f1)"
  returned_ln="$(grep -n '^RETURNED ' <<<"$out" | head -1 | cut -d: -f1)"
  if [ -n "$begin_ln" ] && [ -n "$last_live_ln" ] && [ -n "$returned_ln" ] &&
     [ "$begin_ln" -lt "$last_live_ln" ] && [ "$last_live_ln" -lt "$returned_ln" ]; then
    echo "  PASS immediate_projection (all LIVE within the call)"
  else
    echo "  FAIL immediate_projection: begin=$begin_ln last_live=$last_live_ln returned=$returned_ln"
    echo "$out" | sed 's/^/      | /'
    failures=$((failures + 1))
  fi
}

echo "=== D1 direct positive integration probe ==="
echo "toolchain: $("$AILANG_BIN" --version | head -1) ($AILANG_BIN)"
echo

run_mode success    "ok stop"
echo
run_mode partial_error "err ConnectionFailed"

echo
if [ "$failures" -eq 0 ]; then
  echo "integration_probe: PASS — all five D1 properties hold on both outcomes"
  exit 0
fi
echo "integration_probe: FAIL — $failures assertion(s) failed"
exit 1
