# Plan: throwaway vertical spike through the real driver

Status: Proposed. Date: 2026-07-29.

**This is not the implementation plan.** `ADR-001-deterministic-test-world-architecture.md`'s
*Implementation handoff* mandates a separate, later document: a source-grounded plan for the
production migration, written after both ADRs are accepted and the upstream gate passes, which
"must preserve user changes and current behavior while migrating one effect class at a time."

This spike is the opposite of that on every axis. It is throwaway, it preserves nothing, and it cuts
vertically through several effect classes at once to answer questions rather than to ship. It exists
because the ADR contains architectural claims that no one has tried to build, and this session has
repeatedly shown that executing finds defects reading does not.

It is a **down payment on the implementation plan's evidence**, not a substitute for it. Four of the
ten items the ADR requires that plan to re-verify are things this spike measures directly; the plan
can then cite a measured result instead of re-deriving an estimate.

## Why now, rather than after the upstream API lands

The upstream API shape risk is **localized to one adapter**. World-state threading, clock routing,
the terminal-trace contract, and discovery→replay parity do not depend on how `stepWithStreamRecorded`
is eventually spelled. If upstream lands a different shape, the provider-emission adapter is rewritten
and everything else stands. "Throwaway" therefore overstates the exposure: the discardable fraction is
small and known in advance.

The strongest single reason is D4. It is the newest decision in the ADR, it was rewritten on
2026-07-26 after review found its original mechanism did not exist, and the rewrite made it
*stricter* — clock routing is now all-or-nothing within a profile's scope. Nobody has attempted it.
That is exactly the class of claim a build falsifies cheaply and a reader never will.

## Questions, with falsification criteria

A spike without a stated negative result becomes advocacy. Each question below names what would
count as failure, decided before the work starts.

**Q1 — Is D1's world-state threading feasible in fact, not just by inspection?**
Two reviewers ruled it threadable by reading. Nobody has done it.
- *Confirms* if `world_state` threads through `C2LoopState`, provider dispatch, and the traced entry
  point; every successor literal is updated; the driver compiles; and an existing scenario still passes.
- *Falsifies* if any seam requires production code to branch on test mode, or requires hidden mutable
  state that D1 forbids. Either result is a finding worth more than the code.

**Q2 — Is D4's all-or-nothing clock routing tractable?**
- *Confirms* if every profile-reachable `std/clock` read is routed through the world, and a run with
  the `Clock` capability withheld still executes.
- *Falsifies* if a reachable read cannot be routed without changing production behaviour, or if the
  reachable set is materially larger than the four reads the review counted.

**Q3 — What does the `Message` migration actually cost?**
Measurement, not pass/fail. Report sites touched, files, elapsed time, and — the part that matters —
how many needed judgement rather than a mechanical edit. The current figure is an estimate derived
from grep; replace it with a number.

**Q4 — Is D6's one-canonical-`RunSummary` contract reachable?**
- *Confirms* if at least one terminal path returns exactly one `RunSummary` in the returned trace.
- *Falsifies* if a terminal return cannot be routed through a single finalizer without restructuring
  the driver beyond what the ADR budgets.

**Q5 — Does discovery→replay parity hold against the real driver?**
The existing world-protocol slice fakes discovery in-process. This does it for real.
- *Confirms* if the same program yields the same interaction log and the same normalized trace.
- *Falsifies* on any divergence not explained by a recorded projection difference.

## Sequence

1. Branch that never merges. Repin to the local AILANG clone.
2. `Message` migration — **measure it and report before continuing** (Q3). If it is materially worse
   than mechanical, stop and re-scope rather than pressing on.
3. Thread `world_state` through `C2LoopState` and the traced entry point (Q1).
4. Route the clock completely (Q2).
5. One provider request and one clock request end-to-end through `run_v2_session_traced` (Q4).
6. Discovery → replay against the real driver (Q5).

## Out of scope

Named explicitly, because scope drift is this spike's characteristic failure mode — the work looks
like the migration, so it invites becoming the migration.

- Tool, approval, environment, and randomness request kinds beyond what Q4 needs.
- The extension ABI, the profile/manifest model, the event-vocabulary artifact, search corpora.
- Any behaviour-preservation guarantee. This branch may break things freely.
- Any attempt to make the result mergeable.

## Guardrails

- **It never merges.** The branch is deleted or left dangling; no PR is opened.
- **It is not the D1 gate cleared**, no matter how green it runs. D1 requires the upstream API to have
  landed and the toolchain to be repinned to a released version containing it. A local clone is
  neither.
- **It does not delay filing the upstream issue**, which remains the only item on either project with
  third-party latency.
- Expect it to surface further ADR defects. That is the point, and it means budgeting for another
  revision round rather than treating a green spike as a finish line.

## Disposal

What dies with the branch: all of the code.

What survives, and where it goes:
- Q1–Q5 results, including any falsification, appended to `spike/README.md` alongside the existing
  probes.
- The Q3 measurement, which the eventual implementation plan cites instead of estimating.
- Any ADR defect found, filed as a finding against the ADR the same way the two reviews were.
