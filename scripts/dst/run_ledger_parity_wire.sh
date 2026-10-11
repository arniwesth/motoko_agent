#!/usr/bin/env bash
#
# WI-D2: D6.4's GENERAL obligation, with the two sides produced by DIFFERENT
# THINGS.
#
# =============================================================================
# Why this gate is in the shell, and it is WI-C3's reason restated one variant
# at a time
# =============================================================================
#
# `ledger_parity_dst.ail` can assert that the returned trace HOLDS a variant. It
# cannot assert that the trace holds what the driver PROJECTED, because in
# process there is one accumulation: the driver builds the event value, hands it
# to `ledger_emit`, and appends the same value. Both sides of any in-process
# comparison derive from that one expression, so a branch that builds the event
# and forgets both halves is invisible, and so is one that appends a DIFFERENT
# count from what it emitted.
#
# The projected side IS observable out of process. `ledger_emit` writes one JSON
# line per event to stdout, from the site where the event happened. The returned
# side is the `LEDGER_TRACE` line, written after each run from the trace the
# driver returned. Two producers, two channels, one claim.
#
# WI-C3's `run_stream_parity_wire.sh` makes exactly this comparison for
# `StreamDelta`. This script makes it for every Logical variant the register
# does not excuse — and it does not restate which those are: the .ail side
# prints `LEDGER_REQUIRE <variant> <wire_name>` rows read out of
# `dst_event_vocabulary.event_vocabulary()` minus `dst_invariants
# .d64_gap_register()`. **Shrinking the register is therefore what makes this
# gate demand an append**, which is the coupling that keeps the register from
# being a comment.
#
# =============================================================================
# Failing closed, per WI-D1's M6
# =============================================================================
#
# An unreadable required-set is a RED, not an empty loop that passes. The
# `LEDGER_REQUIRE` count, the subject count and the witnessed-variant floor are
# all asserted before any comparison, because every comparison below is green
# over two empty channels.

set -euo pipefail

cd "$(dirname "$0")/../.."

out="$(mktemp)"
trap 'rm -f "$out" "${out}.trace"' EXIT

echo "=== ledger_parity wire-vs-trace (D6.4, general) ==="

set +e
ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
  --entry main scripts/dst/ledger_parity_dst.ail < /dev/null > "$out" 2>&1
rc=$?
set -e

fail=0

# The census's own failures are reported and CARRIED, not returned on. A run
# whose trace is missing a variant is exactly the run whose wire-vs-trace
# comparison is most worth printing, and returning here would hide which of the
# two channels the variant is missing from.
if [ "$rc" -ne 0 ]; then
  echo "  ✗ the in-process census failed (exit ${rc}); its rows:"
  grep -v '^{' "$out" | grep -E '^  ✗' | sed 's/^/    /' | head -40
  fail=1
fi

check() {
  if [ "$2" = "1" ]; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1"
    [ -n "${3:-}" ] && echo "      $3"
    fail=1
  fi
}

# A vacuity failure stops the run; a census failure does not, because the
# comparison below is what says WHICH channel the missing variant is missing
# from.
vacuous=0
vcheck() {
  check "$1" "$2" "${3:-}"
  [ "$2" = "1" ] || vacuous=1
}

# --- the required set, read out of the run ----------------------------------
require_n="$(grep -c '^LEDGER_REQUIRE ' "$out" || true)"
subjects="$(sed -n 's/^LEDGER_SUBJECTS \([0-9]*\)$/\1/p' "$out" | tail -1)"
subjects="${subjects:-0}"

vcheck "the run published a required set" \
      "$([ "$require_n" -gt 0 ] && echo 1 || echo 0)" \
      "no LEDGER_REQUIRE rows: the vocabulary-minus-register set could not be read, and every row below would iterate over nothing"

vcheck "every subject reported a trace side" \
      "$([ "$subjects" -eq 8 ] && echo 1 || echo 0)" \
      "expected LEDGER_SUBJECTS 8, got ${subjects}"

trace_lines="$(grep -c '^LEDGER_TRACE ' "$out" || true)"
vcheck "the subject count matches the number of trace lines" \
      "$([ "$trace_lines" -eq "$subjects" ] && echo 1 || echo 0)" \
      "LEDGER_SUBJECTS=${subjects} but ${trace_lines} LEDGER_TRACE line(s) were printed"

if [ "$vacuous" -ne 0 ]; then
  echo "ledger_parity wire gate FAIL (vacuous)"
  exit 1
fi

# The whole returned side, one variant per line, across every subject.
grep '^LEDGER_TRACE ' "$out" | sed 's/^LEDGER_TRACE [a-z0-9]* //' | tr '|' '\n' \
  | grep -v '^$' > "${out}.trace"

# --- the comparison, one required variant at a time --------------------------
# A variant with zero on BOTH channels is not a parity failure — it is a variant
# this fixture does not reach, which is a COVERAGE claim and is reported as one.
# Conflating the two is how a green parity family comes to mean nothing.
witnessed=0
unwitnessed=""

for variant in $(grep '^LEDGER_REQUIRE ' "$out" | awk '{print $2}' | sort -u); do
  wire_n=0
  for name in $(grep "^LEDGER_REQUIRE ${variant} " "$out" | awk '{print $3}'); do
    n="$(grep -c "\"type\":\"${name}\"" "$out" || true)"
    wire_n=$((wire_n + n))
  done
  trace_n="$(grep -c "^${variant}\$" "${out}.trace" || true)"

  if [ "$wire_n" -eq 0 ] && [ "$trace_n" -eq 0 ]; then
    unwitnessed="${unwitnessed} ${variant}"
    continue
  fi
  witnessed=$((witnessed + 1))
  check "${variant}: projected ${wire_n}, returned ${trace_n}" \
        "$([ "$wire_n" -eq "$trace_n" ] && echo 1 || echo 0)" \
        "the driver projected ${wire_n} and appended ${trace_n} — D6.4 requires every projected Logical event to reach the returned trace"
done

echo "  witnessed=${witnessed} unwitnessed:${unwitnessed:- none}"

# The witnessed floor is a MEASUREMENT (S15), not a design claim: WI-D2 measured
# 17 of the 26 required variants reached by this fixture's eight subjects, and
# ALL ELEVEN it closed are among them — none of the eleven is closed on a
# structural argument alone. The nine it does not reach need compaction, hybrid
# tools, checkpoints, a solver hook, a response intercept or a persist budget;
# none of those is configured here, and each is a COVERAGE gap rather than a
# parity one, which is why they are printed by name above instead of counted as
# passes. A drop below the floor means the fixture stopped exercising paths it
# used to and every row above it got quietly cheaper.
check "the fixture witnesses at least 17 required variants on both channels" \
      "$([ "$witnessed" -ge 17 ] && echo 1 || echo 0)" \
      "witnessed=${witnessed} — measured 17 at WI-D2; below that the comparison is thinner than the run it certifies"

if [ "$fail" -ne 0 ]; then
  echo "ledger_parity wire gate FAIL"
  exit 1
fi

echo "ledger_parity wire gate PASS"
