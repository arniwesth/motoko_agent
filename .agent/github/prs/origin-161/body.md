---
repo: arniwesth/motoko_agent
pr: 161
branch: arniwesth/mot-99-fix-max-recursion-depth-10000-exceeded
ticket: MOT-99
title: "MOT-99: fix max recursion depth 10000 exceeded"
---

## Summary

Closes #160.

A live session aborted mid-run with `RT_REC_003: max recursion depth 10000 exceeded`, in code
containing no unbounded recursion. The driver derived `MotokoRuntimeStatus`'s counters by folding
its whole accumulated `LedgerTrace` once per tool batch; the fold was hand-written recursion,
AILANG v0.33.0 eliminates no tail calls, and the trace had reached ~9,865 records. The fix is two
hunks — fold with `List.foldl` (stdlib traversals are frame-free) and compute the payload lazily
under a name guard — plus a gate so it cannot come back silently.

Stacked on #162 (`mot-98`), so the diff is exactly this work. The `.agent/` documents are the
larger half of it by line count and are the record of how the fix was reached: an ADR that was
wrong three times, the spike that found it, and the closeout of the generator work that followed.

## Changes


- Record #160: a per-step fold over the whole trace, and the axis that missed it
- ADR-002: resource growth as a metamorphic relation, not a budget
- ADR-002 review: the property was wrong, and the instrument could not decide it
- ADR-002: add a TL;DR
- Spike plan: validate ADR-002's relation against the real driver
- Spike plan: add a Method appendix, and fix the two traps it walked into
- Spike executed: ADR-002 keeps its mechanism, loses every number
- 009: record that both of this project's plans still read `Status: Proposed`
- Record what the resource-growth work says about DST, and about how it was built
- Define the substrate objectively, and say what follows for investment
- Fix #160: fold the status counters with foldl, and compute them lazily
- Verify #160 in the DST world: restore the driver-phase measurement seam
- Gate #160: `make depth_canary`, two tiers, both shown to fire
- Anchor the unwritten plan: fix two ADR phrasings, commission it by handoff
- Declare the chunk draw range: plumbing only, no drawn value moves
- Read the chunk draw range from the bounds, and show it moved nothing
- Give export_trace a records-per-step lever, opt-in and off by default
- Commit the plan and its handoff, and unstale the three ADR-002 pointers
- Added research note
- Close out cluster A: the implementation record and a corrected work ratio
- WI-5: write Corrections 9-12 back into ADR-002, and retire three stale claims
- Re-anchor the five session.ail clock sites after #160, and re-issue three profiles
- Record PR #161, driver-created

43 files changed.

## Governing docs


- `.agent/projects/009_motoko_dst_execution/NOTE-stale-plan-status-markers.md`
- `.agent/projects/011_improve_test_axises/ADR-002-resource-growth-as-a-metamorphic-relation.md`
- `.agent/projects/011_improve_test_axises/HANDOFF-declare-the-chunk-draw-range.md`
- `.agent/projects/011_improve_test_axises/HANDOFF-write-resource-growth-relation-plan.md`
- `.agent/projects/011_improve_test_axises/NOTE-chunk-draw-lever-calibration.md`
- `.agent/projects/011_improve_test_axises/NOTE-declare-the-chunk-draw-range-closeout.md`
- `.agent/projects/011_improve_test_axises/NOTE-dst-substrate-versus-oracle.md`
- `.agent/projects/011_improve_test_axises/NOTE-spike-findings-resource-growth.md`
- `.agent/projects/011_improve_test_axises/PLAN-resource-growth-relation.md`
- `.agent/projects/011_improve_test_axises/PLAN-spike-resource-growth-feasibility.md`
- `.agent/projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md`
- `.agent/projects/017_extension_handling/RESEARCH-extension-abi-evolution.md`

## Predicted outcome


- **Long sessions stop aborting at ~10,000 trace records.** Checked by `make depth_canary`, which
  measures the real driver's peak recursion depth out of process at pinned per-seed ceilings, and
  by the live-session procedure in `tmp/issue-160-test/` for production scale.
- **A regression cannot land silently.** `depth_canary` is in `DST_TARGETS` and was shown to fire:
  against the pre-fix driver all four rows go red, against HEAD all four are green.
- **The generator gains a records-per-step lever** (`GeneratorBounds.chunk_draw_hi`), off by
  default and moving no pinned digest — verified by a full sweep with the canary green at both
  pinned versions. It is the precondition for the slope relation that replaces the pins.
- **Not delivered, and scoped rather than left dangling:** ADR-002's full slope relation. It needs
  a declared threshold (the healthy slope is not zero at a wide lever) and a seed-set decision
  (37.5% of seeds never reach the tool arm). `PLAN-resource-growth-relation.md` WI-2/WI-3 own both.

## Test evidence


```
ailang check src/core/session.ail        ✓ No errors found
ailang test  src/core/session.ail        23 tests: 23 passed, 0 failed
make check_core                          57 passed, 0 failed
make depth_canary                        PASS — tier 0 + seeds 7/11/23
make anchors                             PASS — all 10 anchors
make attribution_table                   PASS
make driver_only / profile_definition    PASS
driver_only_dst, invariants_dst,
discovery_dst, execution_program_dst     PASS
```

**The fix, measured on the real driver** — driver phase, out of process, tolerance-1 bisection of
the minimum viable `--max-recursion-depth`, same seeds and byte-identical traces in both
conditions:

| seed | records | before | after | spike's independently-derived floor |
|---|---|---|---|---|
| 7  | 79  | 86  | **58** | 58 |
| 11 | 126 | 153 | **87** | 87 |
| 23 | 96  | 114 | **75** | 75 |

Exact agreement on all three, against a spike that removed the traversal a different way.

**The gate was shown to fire, not just to pass.** With the fold regressed, all four `depth_canary`
rows go red. With the fold regressed but the fix's *name guard* left in place, tier 0 fires and
tier 1 stays green — recorded as ADR-002 Correction 10, because it means the end-to-end tier does
not subsume the unit probe and tier 0 cannot be retired.

**Known red, pre-existing and untouched:** `driver_plus_no_ops` and `driver_plus_compose` fail the
`agentcli` inheritance check — `agentcli` is in `ailang.toml` and appears in neither profile's
install nor omission list. Confirmed identical at the stashed baseline before and after this
branch's changes; both profiles' own re-issues validate inside those runs (v10 and v2 load clean,
attribution refs current). It is `017_extension_handling`'s subject.
