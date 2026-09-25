#!/usr/bin/env bash
# WI-C2: ADR-001 D1's substrate gate, asserted clause by clause.
#
# D1: "the upstream recorded-stream API must be pinned and a direct positive
# version of the spike must prove immediate projection, exact returned-log
# parity, success, partial-stream-then-error, and no duplicate delivery."
#
# FIVE CLAUSES, FIVE ROWS, per subject, per mode. Deliberately NOT a conjunction:
# a single green line tells you nothing about which clause held, and cluster 12's
# rule is that a row asserts its own fact.
#
# TWO SUBJECTS:
#   substrate  std/ai.stepWithStreamRecorded, driven directly — proves the API,
#              on the PINNED RELEASE rather than the prototype the spike used.
#   adoption   stub_step.live_ports' own model_step closure — proves WI-C1.
#              The substrate rows stay green through a live_ports that discards
#              every chunk, because they never call it.
#
# The server is a real native SSE endpoint. `--ai-stub` cannot serve this probe:
# measured, it fires the callback exactly twice (ContentDelta + Usage) and always
# returns Ok, so it exercises ordering barely, duplication not at all, and
# partial-stream-then-error not at all.

set -uo pipefail

PORT="${PORT:-8819}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# Repo-relative deliberately: `ailang run` matches the module declaration against
# the file path, so an absolute path fails MOD010. The runner cd's to $ROOT.
PROBE="scripts/dst/recorded_stream_dst.ail"
SERVER="$HERE/recorded_stream_server.py"

# What the server supplies, in order. Kept in lockstep with recorded_stream_server.py
# BY ASSERTION rather than by comment: the runner reads DELTAS out of the server
# so the expectation cannot silently drift away from the fixture.
SUPPLIED_ORDER="$(python3 - "$SERVER" <<'PY'
import ast, sys, re
src = open(sys.argv[1]).read()
m = re.search(r'^DELTAS = (\[.*?\])$', src, re.M)
if not m:
    sys.stderr.write("cannot read DELTAS from the server\n"); sys.exit(1)
print("".join(d + "|" for d in ast.literal_eval(m.group(1))))
PY
)"
[ -n "$SUPPLIED_ORDER" ] || { echo "FAIL: could not derive the supplied sequence"; exit 1; }
SUPPLIED_COUNT="$(awk -F'|' '{print NF-1}' <<<"$SUPPLIED_ORDER")"

# The duplication control has to actually be present, or the no-duplicate row is
# testing nothing. S7: assert the fixture's coverage, do not describe it.
if [ "$SUPPLIED_COUNT" -lt 3 ]; then
  echo "FAIL: the supplied sequence has $SUPPLIED_COUNT chunks — too few to distinguish"
  echo "      ordering or duplication. That is the --ai-stub weakness this probe exists to avoid."
  exit 1
fi
if ! grep -q 'rep|rep|' <<<"$SUPPLIED_ORDER"; then
  echo "FAIL: the supplied sequence carries no adjacent repeat, so no_duplicate_delivery"
  echo "      cannot distinguish an exact log from a de-duplicated one. Got: $SUPPLIED_ORDER"
  exit 1
fi

failures=0
srv_pid=""
cleanup() { [ -n "$srv_pid" ] && kill "$srv_pid" 2>/dev/null; }
trap cleanup EXIT

check() { # check <clause> <label> <actual> <expected>
  if [ "$3" = "$4" ]; then
    printf '  PASS  %-28s %s\n' "$1" "$2"
  else
    printf '  FAIL  %-28s %s: got %s want %s\n' "$1" "$2" "'$3'" "'$4'"
    failures=$((failures + 1))
  fi
}

run_subject() { # run_subject <entry> <subject> <mode> <expected_outcome>
  local entry="$1" subject="$2" mode="$3" expect_outcome="$4" out caps

  case "$subject" in
    substrate) caps="AI,IO" ;;
    adoption)  caps="AI,IO,Clock,Env,Trace" ;;
  esac

  MODE="$mode" PORT="$PORT" python3 "$SERVER" >/dev/null 2>&1 &
  srv_pid=$!
  sleep 1.5

  out="$(cd "$ROOT" && \
    OPENAI_BASE_URL="http://127.0.0.1:$PORT" OPENAI_API_KEY=probe \
    ailang run --caps "$caps" --ai gpt5-mini --entry "$entry" "$PROBE" 2>&1)"

  kill "$srv_pid" 2>/dev/null; srv_pid=""

  echo "subject=$subject mode=$mode"

  local live returned order outcome nonempty
  live="$(grep -c '^LIVE ' <<<"$out")"
  returned="$(sed -n 's/^RETURNED count=\([0-9]*\).*/\1/p' <<<"$out")"
  order="$(sed -n 's/^RETURNED .*order=\(.*\)$/\1/p' <<<"$out")"
  outcome="$(sed -n 's/^OUTCOME \(.*\)$/\1/p' <<<"$out")"
  nonempty="$(sed -n 's/^EMISSIONS_NONEMPTY \(.*\)$/\1/p' <<<"$out")"

  # A run that produced no evidence at all must not read as four silent passes.
  # Absent reads identically to unchanged, and that is Milestone B's whole lesson.
  if [ -z "$returned" ] || [ -z "$outcome" ]; then
    echo "  FAIL  probe produced no evidence — every row below would be vacuous"
    echo "$out" | sed 's/^/      | /'
    failures=$((failures + 1))
    return
  fi

  # CLAUSE 3/4 — the outcome itself. success mode must be Ok; partial_error mode
  # must be Err AFTER the chunks were observed.
  case "$mode" in
    success)       check "3 success"                    "outcome"  "$outcome"  "$expect_outcome" ;;
    partial_error) check "4 partial_stream_then_error"  "outcome"  "$outcome"  "$expect_outcome" ;;
  esac

  # CLAUSE 2 — exact returned-log parity. Count AND order, separately: an
  # implementation can preserve the count while reordering.
  check "2 returned_parity_count" "returned=$returned" "$returned" "$SUPPLIED_COUNT"
  check "2 returned_parity_order" "order"              "$order"    "$SUPPLIED_ORDER"

  # CLAUSE 5 — no duplicate delivery. The callback fired once per supplied chunk:
  # projected == supplied. With the adjacent repeat in the fixture this also
  # rejects a de-duplicating implementation, which would project 4.
  check "5 no_duplicate_delivery" "projected=$live" "$live" "$SUPPLIED_COUNT"

  # CLAUSE 1 — immediate projection, and the forbidden fallback made visibly
  # not-selected. Under D1's rejected "delay all projection until completion",
  # every LIVE line lands after RETURNED and this row inverts.
  local begin_ln last_live_ln returned_ln
  begin_ln="$(grep -n '^CALL begin$' <<<"$out" | head -1 | cut -d: -f1)"
  last_live_ln="$(grep -n '^LIVE ' <<<"$out" | tail -1 | cut -d: -f1)"
  returned_ln="$(grep -n '^RETURNED ' <<<"$out" | head -1 | cut -d: -f1)"
  if [ -n "$begin_ln" ] && [ -n "$last_live_ln" ] && [ -n "$returned_ln" ] &&
     [ "$begin_ln" -lt "$last_live_ln" ] && [ "$last_live_ln" -lt "$returned_ln" ]; then
    printf '  PASS  %-28s %s\n' "1 immediate_projection" \
      "all $live LIVE lines fall strictly between CALL begin and RETURNED"
  else
    printf '  FAIL  %-28s begin=%s last_live=%s returned=%s\n' \
      "1 immediate_projection" "$begin_ln" "$last_live_ln" "$returned_ln"
    echo "$out" | sed 's/^/      | /'
    failures=$((failures + 1))
  fi

  # WI-C1's own guard, and it is the only row in this file that is about Motoko's
  # source rather than about AILANG's. Adoption subject only — the substrate
  # entry point has no ProviderExchange to inspect.
  if [ "$subject" = "adoption" ]; then
    check "C1 err_branch_keeps_chunks" "emissions_nonempty" "${nonempty:-none}" "true"
  fi
  echo
}

echo "=== WI-C2 · ADR-001 D1 substrate gate · five clauses, five rows ==="
echo "toolchain: $(ailang --version | head -1)"
echo "supplied:  count=$SUPPLIED_COUNT order=$SUPPLIED_ORDER"
echo

# The negative control runs FIRST, because a gate whose discriminating power is
# unverified should not be allowed to print four screens of PASS before anyone
# finds out. S7: a rejecting artifact needs a fixture whose behaviour is checked
# in both directions.
control_delayed_projection() {
  local out begin_ln first_live_ln returned_ln
  MODE=success PORT="$PORT" python3 "$SERVER" >/dev/null 2>&1 &
  srv_pid=$!
  sleep 1.5
  out="$(cd "$ROOT" && \
    OPENAI_BASE_URL="http://127.0.0.1:$PORT" OPENAI_API_KEY=probe \
    ailang run --caps AI,IO --ai gpt5-mini --entry main_delayed_projection_control "$PROBE" 2>&1)"
  kill "$srv_pid" 2>/dev/null; srv_pid=""

  echo "control=delayed_projection (D1's REJECTED design — this must FAIL the sandwich)"
  begin_ln="$(grep -n '^CALL begin$' <<<"$out" | head -1 | cut -d: -f1)"
  first_live_ln="$(grep -n '^LIVE ' <<<"$out" | head -1 | cut -d: -f1)"
  returned_ln="$(grep -n '^RETURNED ' <<<"$out" | head -1 | cut -d: -f1)"

  if [ -z "$first_live_ln" ] || [ -z "$returned_ln" ]; then
    printf '  FAIL  %-28s control produced no LIVE/RETURNED evidence — it proves nothing\n' \
      "control inert"
    echo "$out" | sed 's/^/      | /'
    failures=$((failures + 1))
  elif [ "$first_live_ln" -gt "$returned_ln" ]; then
    printf '  PASS  %-28s %s\n' "1 sandwich_discriminates" \
      "delayed projection puts every LIVE line AFTER RETURNED (first_live=$first_live_ln > returned=$returned_ln), so clause 1 is a real test"
  else
    printf '  FAIL  %-28s the sandwich ACCEPTED delayed projection (begin=%s first_live=%s returned=%s)\n' \
      "1 sandwich_discriminates" "$begin_ln" "$first_live_ln" "$returned_ln"
    echo "      D1-LEVEL FINDING: clause 1 cannot distinguish the design D1 rejects"
    echo "$out" | sed 's/^/      | /'
    failures=$((failures + 1))
  fi
  echo
}

control_delayed_projection

run_subject main_substrate substrate success       "ok stop"
run_subject main_substrate substrate partial_error "err ConnectionFailed"
run_subject main_adoption  adoption  success       "ok stop"
run_subject main_adoption  adoption  partial_error "err ConnectionFailed"

if [ "$failures" -eq 0 ]; then
  echo "recorded_stream: PASS — D1's five clauses hold on both outcomes, for the API"
  echo "                 AND for live_ports' adoption of it."
  exit 0
fi
echo "recorded_stream: FAIL — $failures row(s) failed"
exit 1
