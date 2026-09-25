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
# Measured 2026-09-15, AILANG v0.33.0 ae36986, motoko 298bec5, tolerance-1
# bisection of the driver phase (the lowest ceiling that passes; the ceiling
# one below it aborts with RT_REC_003), with and without the #160 fault:
#
#   seed  records   depth FIXED   depth WITH FAULT   ceiling here
#   7     123       63            150                76
#   11    191       92            237                110
#   23    217       105           265                126
#
# Ceilings are floor + ~20%. Every one of them is comfortably below the
# fault-present depth, so reintroducing the traversal fails all three — this is
# not a guard that has never been shown to fire. The fault-present column was
# RE-MEASURED at this commit, not carried forward: the hand-written recursion
# that b1ad13ba replaced with `foldl` was put back into `runtime_status_counts`
# in a scratch worktree of this same tree (tier 0 goes red there too), and the
# record counts and trajectories are identical with and without it. The house
# caveat applies and is met.
#
# WHAT MOVED THE PINS SINCE 2026-08-17. The previous table was 79/126/96
# records, floors 58/87/75, fault-present 86/153/114, ceilings 70/104/90. Each
# step below is the same bisection in a clean worktree at the default lever,
# "records / floor" per seed:
#
#   commit    seed 7      seed 11     seed 23     what changed
#   650f0e0   79 / 60     126 / 88    96 / 76     last bisected-green tree; +2/+1/+1 on the
#                                                 August floors is drift that predates it
#   8980ba6   79 / 60     126 / 88    139 / 101   PLAN-001 fix 1: refuse undecodable tool args
#   d72fff1   79 / 61     126 / 89    139 / 102   merge of the PLAN-003 P1 (journal) branch
#   bd0eac7   96 / 62     154 / 91    169 / 104   ADR-003 P3 emits + PLAN-001 P2A: state_delta,
#                                                 history_seeded/appended, context_limit_resolved
#   6b33f36   122 / 62    190 / 90    216 / 103   PLAN-001 P2B: WorldRequest at every successor
#   a2113e8   123 / 63    191 / 92    217 / 105   ADR-002 W2: open_waits, ExtCtx 7.4, classify_candidate
#   298bec5   123 / 63    191 / 92    217 / 105   HEAD, unchanged since a2113e8
#
# Two different things are in that table and they must not be conflated:
#
#   1. SEED 23 IS A TRAJECTORY CHANGE, NOT A FRAME-COST CHANGE. Its generated
#      world contains a native `Read` call whose argument string does not
#      parse (raw_length 8). Before 8980ba6 that call was dispatched against
#      `{}`; after it, `execute_allowed_tool_call` refuses it and tells the
#      model, and the stub trajectory takes a longer path: 8 → 11 provider
#      calls, 6 → 8 tool batches, 96 → 139 records, floor 76 → 101 (+25). The
#      decode itself costs NOTHING in depth: seeds 7 and 11, whose worlds have
#      no such call, sit at 60/88 on both sides of 8980ba6; `decode` is the
#      `_json_decode` builtin (frame-free, like every stdlib traversal); and
#      `arguments_undecodable` is one transient frame on the tool-dispatch
#      path, which is not the deepest path. Moving the decode off the
#      per-step frame would move no pin — it would only undo the refusal. The
#      Makefile's earlier reading of this as "a per-step frame-cost change on
#      the tool-phase path" was the right commit and the wrong mechanism.
#      Seeds 7 and 11 keep their August trajectories (6 and 9 provider calls,
#      4 and 8 tool batches); seed 23's is constant from 8980ba6 onward.
#
#   2. THE REST IS THE SECOND CASE BELOW, a flat per-step frame-cost shift:
#      +3/+4/+4 frames across the journal records, the WorldRequest witness
#      and the ADR-002 loop restructuring, while records rose 79→123,
#      126→191 and 139→217. Records nearly doubled and the floor moved by
#      single frames — that is what a flat floor looks like. The fault-present
#      column, +87/+145/+160 over the same records, is what a traversal looks
#      like.
#
# THE LEVER WAS SWEPT AT THIS COMMIT AND THE FLOOR IS FLAT IN RECORDS.
# CG_EXPORT_CHUNK_DRAW_HI=0/4/8 gives 107/112/140 records on seed 7 and
# 199/221/245 on seed 23 at the unchanged floors, 63 and 105. Above 8 the
# floor DOES move (seed 7: 68 at 16, 78 at 32; seed 23: 117 at 16, 130 at 32)
# and that is NOT a traversal of accumulated state: step, provider-call and
# tool-batch counts are constant, seed 11 gains 55 records for one frame, and
# what the depth tracks is the chunk count of the single LARGEST RESPONSE
# (`session.stream_chunk_events` is non-tail recursion over one response's
# chunk log, and `max_chunks_per_interaction` follows the lever above 4). It
# is present identically at 650f0e0 — 66/91/85 at lever 16 against 60/88/76 —
# so it predates every commit above. It is a per-response cost, bounded by
# one stream, not by the session; but WI-3's slope measurement must hold the
# per-response chunk count fixed or subtract it, because a lever above 8 does
# not vary "only records".
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
# length held fixed — is NOT what this runs. It needed a records-per-step lever
# the generator did not have, and WI-1 built it: the chunk draw's range is now
# declared as GeneratorBounds.chunk_draw_hi, and export_trace's
# CG_EXPORT_CHUNK_DRAW_HI sweeps it — measured 1.65x/1.71x/1.82x records on seeds
# 7/11/23 with step, provider-call and tool-batch counts constant. This is still
# the buildable approximation and tier 2 now waits only on WI-3, which owns the
# slope, its threshold and the "shown to fire" demonstration. Until WI-3 is green
# THIS SCRIPT IS THE ONLY THING GUARDING #160, so it does not retire early. The
# pins below are measured at the DEFAULT lever and the knob is off by default —
# a widened run reports a record count and writes nothing.
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
for row in "7:76:123" "11:110:191" "23:126:217"; do
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
