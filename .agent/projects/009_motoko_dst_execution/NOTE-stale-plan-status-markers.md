# Finding: both of this project's plans still read `Status: Proposed`, and one of them is finished

Date: 2026-08-17. Status: recorded, not fixed — deliberately.

_Found by walking into it. A session was asked to execute `PLAN-spike-real-driver-vertical.md`, read
its `Status: Proposed` at face value, and began orienting to build. The plan had been executed in
full seventeen days earlier. Nothing was written to the tree before the marker was caught, so the
cost here was minutes; the finding is recorded because the next session's cost is not bounded by
that._

## The defect

Two plans in this project carry a status line that contradicts the project's own evidence.

| Plan | Line 3 says | What the project records |
|---|---|---|
| `PLAN-spike-real-driver-vertical.md` | `Status: Proposed. Date: 2026-07-29.` | `NOTE-spike-findings-real-driver-vertical.md:3` — "Status: complete, dispositioned into this note", executed **2026-07-31**, all five questions resolved |
| `PLAN-implementation-deterministic-test-world.md` | `Status: Proposed. Date: 2026-08-02.` | `NOTE-d28-the-final-acceptance-rerun.md:1` — "**THE CLOSING NOTE**", verdict YES at HEAD `b3953a9`, **2026-08-09** |

The first is established. The second is **very likely stale but not proven so here**: the closing
note is unambiguous about the goal line, but this session did not complete the work-item inventory
across the plan's 4,825 lines and cannot assert that every item is discharged. Anyone stamping it
should finish that inventory first, and should decide what the marker says about D1, whose gate the
spike findings explicitly left open (`NOTE-spike-findings-real-driver-vertical.md:30-34`).

## Why the marker is load-bearing rather than cosmetic

The project holds **59 `NOTE-*.md` and 68 `HANDOFF-*.md` files**. The evidence that the work
happened is overwhelming and it is all one directory listing away — but none of it is at the top of
the plan, and the plan is what a session opens first when handed a plan. A reader who trusts line 3
concludes "unexecuted" from the one line written before the work started and never revised.

The failure direction is what makes this worth a note. A stale `Proposed` fails toward **redoing
completed work**, and specifically toward redoing it *destructively*: this plan's guardrails mandate
a branch that never merges and a tree that "may break things freely" (`PLAN-spike-real-driver-vertical.md:87-90`).
An agent executing it in earnest starts by repinning the toolchain and migrating `Message` across 28
files. That is a large, tree-wide, deliberately-unmergeable change undertaken for no reason, and the
plan tells its executor not to expect the result to be reviewable.

## The convention exists; these two just missed it

This is not an unwritten rule. Three plans elsewhere in `.agent/projects` carry a completed marker,
and they agree on the shape — verb, date, and the commit or artifact that discharges it:

- `004_phase_core_refactor/PLAN-phase-c2-live-inversion.md:4` — `Status: Completed 2026-07-05 (WI-C14 gate passed; ...)`
- `004_phase_core_refactor/PLAN-abi-v3-rollout.md:4` — `Status: **Implemented 2026-07-07** (commit `e650b56`). ...`
- `007_dst_consolidation/PLAN-smoke-parity-precondition.md:4` — `Status: Completed 2026-07-12 (implementation commit `22f494e`; review amendment recorded)`

So the gap is not a missing convention but an unclosed loop: the disposal step of an executed plan
writes the findings note and never returns to the plan that ordered it. Both of this project's plans
have that shape, which suggests the loop, not the author.

**Not every `Proposed` is stale, and a sweep must not assume so.**
`011_improve_test_axises/PLAN-spike-resource-growth-feasibility.md:3` reads `Status: Proposed. Date:
2026-08-17` and is correct — authored today, unexecuted by discipline. A blanket rewrite would
falsify it in the opposite direction, which is the worse error: it would mark unbuilt work as done.

## Action

Not taken here, by instruction. When it is taken:

1. Stamp `PLAN-spike-real-driver-vertical.md` as executed 2026-07-31, pointing at
   `NOTE-spike-findings-real-driver-vertical.md` and at branch `spike/009-real-driver-vertical`
   (which exists locally and on `origin`, and by guardrail never merges). Say in the marker that the
   code is disposed of, so the next reader does not go looking for `src/core/world.ail`, which the
   spike created and the disposal step deleted.
2. Settle `PLAN-implementation-deterministic-test-world.md` only after the work-item inventory, and
   have the marker distinguish the goal line (met, per WI-D28) from the D1 substrate gate (open at
   the time of the spike findings — re-check before writing anything about it).

The check is mechanical and worth preferring over a habit, per
`../../meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`:
**a plan reading `Status: Proposed` in a project directory that also contains a NOTE reporting that
plan's execution is a contradiction a grep can find.** It is one greppable pair, it has exactly the
two hits above today, and it fails closed — a new plan with no execution note never trips it.

## What this does not claim

Only the markers are wrong. Nothing here reopens a finding, a decision, or an acceptance row, and
the four spike findings spot-checked while chasing this were all landed in production code — F1/F2
(`dispatch_step` and `ext_ports_for_provider` gone, `ported_provider` returns `PortedProvider`), F4
(`ExtPorts.clock_now` has real users at `packages/motoko-ext-compose/compose.ail:756,796`), F5
(`phase_vocab`'s `"wire"` collapse down from 31 variants to 2), and F6 (`scripted_ports()` consumes
`state.script` off `C2LoopState.world_state`; the probe survives as
`scripts/dst/scripted_cursor_probe.ail`, renamed from its `spike_`-prefixed original). That is a
spot-check by grep, not a closure audit — it establishes that the code moved, not that each finding
was fully discharged.
