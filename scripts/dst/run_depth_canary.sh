#!/usr/bin/env bash
#
# The gate for motoko_agent#160: recursion depth must not scale with accumulated
# trace records.
#
# =============================================================================
# Why a gate at all, and why this shape
# =============================================================================
#
# AILANG v0.33.0 does not eliminate tail calls, so hand-written recursion over a
# list costs one interpreter frame per element. Anything on the driver's per-step
# path that traverses accumulated state therefore makes the maximum length of a
# session a function of the recursion ceiling — it does not run slowly, it aborts
# a live run mid-session with RT_REC_003. That happened at ~9,865 records.
#
# There is no depth counter to read. THE CEILING IS THE INSTRUMENT: run at a
# deliberately low --max-recursion-depth and let the process abort. Both tiers
# below work that way.
#
#   TIER 0 (unit)  scripts/dst/recursion_depth_probe.ail over 8,192 records at a
#                  ceiling of 200. Precise, milliseconds, cannot drift — but it
#                  guards ONE function.
#
#   TIER 1 (e2e)   the real driver, out of process, at pinned per-seed ceilings.
#                  General — it catches ANY new O(|trace|) traversal on the
#                  driver path, not just a regression of the known one — but the
#                  pins move when per-step frame cost legitimately changes.
#
# Neither is sufficient alone. Tier 0 is narrow; tier 1 is a pin. Together they
# cover each other's weakness, which is why this script runs both.
#
# =============================================================================
# The pins, and what would move them
# =============================================================================
#
# Measured 2026-08-17, AILANG v0.33.0 ae36986, tolerance-1 bisection of the
# driver phase, with and without the #160 fix:
#
#   seed  records   depth FIXED   depth WITH FAULT   ceiling here
#   7     79        58            86                 70
#   11    126       87            153                104
#   23    96        75            114                90
#
# Ceilings are floor + ~20%. Every one of them is comfortably below the
# fault-present depth, so reintroducing the traversal fails all three — this is
# not a guard that has never been shown to fire. The house caveat applies and is
# met: the fault-present column is a real measurement of a real regression, not
# a hypothetical.
#
# IT FAILS CLOSED. A new traversal can only RAISE depth, so the failure mode of
# the thing being guarded is the direction the gate is sensitive in.
#
# WHEN A PIN GOES RED WITHOUT A NEW TRAVERSAL, which will happen: the flat floor
# is approximately 2.4 frames per decision plus a ~23-frame constant, so any
# change to c2_loop's per-step frame cost moves it. That is worth a tripwire
# rather than a nuisance — per-step frame cost is a real property of the driver.
# BUMPING A PIN IS A DELIBERATE ACT WITH A RECORDED REASON, the same discipline
# D8 puts on the generator canary. A pin bumped reflexively makes this gate
# vacuous, which is worse than not having it.
#
# THE RECORD COUNTS ARE PINNED TOO, and that is not belt-and-braces. export_trace
# prints its refusals (bad profile, unparseable seed) and exits ZERO, so a
# misconfigured invocation would otherwise sail through as a pass. Asserting the
# expected record count means the gate fails closed on a broken harness as well
# as on a broken driver.
#
# Design record: .agent/projects/011_improve_test_axises/
#   ADR-002-resource-growth-as-a-metamorphic-relation.md (the relation this
#   approximates), NOTE-spike-findings-resource-growth.md (the measurements).
# The ADR's full relation — slope of depth against records with trajectory
# length held fixed — is NOT what this runs: it needs a records-per-step lever
# the generator does not have (max_chunks_per_interaction clamps a draw
# hardcoded to 0,3). This is the buildable approximation; tier 2 waits on that.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CAPS="IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace"
PROBE_CEILING=200
FAILED=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILED=1; }

echo "depth canary — tier 0: the per-step derivation is frame-free"

probe_out="$(ailang run --max-recursion-depth "$PROBE_CEILING" --caps IO \
  --entry main scripts/dst/recursion_depth_probe.ail < /dev/null 2>&1 || true)"
if printf '%s' "$probe_out" | grep -q 'RT_REC_003'; then
  fail "recursion_depth_probe hit the ceiling at $PROBE_CEILING — a per-step traversal over the trace has come back"
  printf '      %s\n' "$(printf '%s' "$probe_out" | grep 'RT_REC_003' | head -1)"
elif printf '%s' "$probe_out" | grep -q 'recursion_depth_probe: PASS'; then
  pass "runtime_status_counts: 8192 records, frame-free at ceiling $PROBE_CEILING"
else
  fail "recursion_depth_probe produced neither PASS nor RT_REC_003 — the probe itself is broken"
  printf '      %s\n' "$(printf '%s' "$probe_out" | tail -3)"
fi

echo "depth canary — tier 1: the real driver, out of process"

# seed:ceiling:expected_records  — see the pin table in the header
for row in "7:70:79" "11:104:126" "23:90:96"; do
  seed="${row%%:*}"; rest="${row#*:}"; ceiling="${rest%%:*}"; want_records="${rest##*:}"

  set +e
  out="$(CG_EXPORT_PHASE=driver \
         CG_EXPORT_SEED="$seed" \
         CG_EXPORT_PROFILE=driver_only \
         CG_OUT_DIR="$(mktemp -d)" \
         CG_AILANG_VERSION="$(ailang --version 2>/dev/null | head -1 || echo unknown)" \
         CG_MOTOKO_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo unknown)" \
         ailang run --max-recursion-depth "$ceiling" --caps "$CAPS" --ai-stub \
           --entry main scripts/dst/export_trace.ail < /dev/null 2>&1)"
  rc=$?
  set -e

  if printf '%s' "$out" | grep -q 'RT_REC_003'; then
    fail "seed $seed exceeded depth $ceiling (was $want_records records at a measured floor well under it) — something on the driver path now traverses accumulated state"
    continue
  fi
  if [ "$rc" -ne 0 ]; then
    fail "seed $seed exited $rc without RT_REC_003 — unrelated failure, not a depth result"
    printf '      %s\n' "$(printf '%s' "$out" | tail -2)"
    continue
  fi
  # Fail closed: a refusal from export_trace exits 0 and would otherwise pass.
  if ! printf '%s' "$out" | grep -q "phase=driver — ${want_records} records"; then
    fail "seed $seed did not report ${want_records} records — the harness did not measure what this pin describes"
    printf '      %s\n' "$(printf '%s' "$out" | tail -2)"
    continue
  fi
  pass "seed $seed: driver phase within depth $ceiling over $want_records records"
done

if [ "$FAILED" -ne 0 ]; then
  echo
  echo "depth canary FAILED. Before bumping a pin, read the header: a red pin means either a new"
  echo "O(|trace|) traversal on the driver path (fix it) or a change in c2_loop's per-step frame"
  echo "cost (re-measure, then bump with the reason recorded). Bumping reflexively makes this gate"
  echo "vacuous."
  exit 1
fi

echo "depth canary PASS"
