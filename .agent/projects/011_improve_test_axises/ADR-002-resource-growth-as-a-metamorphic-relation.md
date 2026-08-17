# ADR-002: How should DST detect unbounded per-step work over accumulated state?

**Status:** Proposed
**Date:** 2026-08-17

Relates to:
- `RESEARCH-test-axes-beyond-dst.md` §3.9 — the axis this ADR decides. **This ADR
  supersedes both of §3.9's proposals**; see *Options considered* 1 and 2 for why each
  fails on measurement rather than on taste.
- `.agent/issues/per-step-trace-fold-exceeds-recursion-depth.md` — the production fault
  that motivated the axis, and the only fault in this survey that reached production
  before it reached a test.
- `.agent/issues/ailang-no-tail-call-optimization.md` — why interpreter frames are a
  measurable global resource here at all.
- `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`
  — D2 (declared bounds), D6.4 (stream parity), D6.6/D6.7 (`HarnessFailureKind` must be
  observable by the runner while it is still running), D7 (whole-execution invariants).
- `RESEARCH-test-axes-beyond-dst.md` §3.6 — metamorphic testing; this decision lands in
  that family's shape rather than in a new one.
- `ADR-001-adopt-program-shrinking.md` — this project's other decision, and the ADR style
  followed here.

---

## Context

A live session aborted with `RT_REC_003` because the driver re-folds its whole accumulated
`LedgerTrace` once per tool step. None of the twelve invariant families could have caught
it, for four independent reasons recorded in the issue. The question this ADR settles is
narrower than "add a family": **by what mechanism can a deterministic simulation observe
that per-step work grows with accumulated state, given that the work itself leaves no
trace record?**

Three constraints bound the answer, and each one kills an obvious design:

**D6.4 forbids bounding trace size.** `StreamParityCount` (`dst_invariants.ail:432`)
requires every projected stream emission to reach the returned trace. The trace is
*supposed* to scale with token volume. Any rule of the form "a run may not accumulate more
than N records" contradicts an existing family.

**The quantity is not in the trace.** A trace records appends; the fault is unbounded
*reads*. No amount of reading the trace reveals how many times the driver walked it.

**D6.6/D6.7 say every `HarnessFailureKind` is "observable by the runner while it is still
running."** A frame-budget abort is precisely not: the DST harness runs in the same
`ailang run` process at the same ceiling, so a trajectory that trips it kills the observer
too. Today that yields a process exit with no violation, no trajectory and no seed — a
sixth `HarnessFailureKind` bolted onto the existing type would be a lie about the type's
own documented property.

## Options considered

1. **A declared record budget, sibling to `decision_budget`/`retry_budget` (§3.9(b)).**
   Shape is right — `ExecutionUnderTest` already carries two declared budgets and
   `bounded_progress_findings` (`dst_invariants.ail:1258-1268`) checks them with a
   `>= 0`-means-declared idiom. **Rejected on the measurement:** it caps trace size, which
   D6.4 forbids, and it fires on a long-but-healthy run while staying silent on a short
   run with a quadratic driver. It measures the wrong quantity in both directions.

2. **A long-run / soak profile with raised bounds (§3.9(a)).** Raise
   `max_chunks_per_interaction` into the hundreds and run nightly. **Rejected on cost and
   on signal:** reaching ~10 000 records means generating them, and the failure it produces
   is the process exit of constraint 3 — an abort with no attribution. It detects by brute
   force and reports nothing usable.

3. **Z3 contract over the fold sites (RESEARCH open question 6).** Assert statically that
   nothing reachable from the per-step path traverses `st.trace`. **Rejected as
   out-of-reach, not as wrong:** this is the honest home for the property, but it needs a
   reachability predicate over an effectful call graph that §3.1's contract work does not
   have and does not plan. Worth revisiting if §3.1 ever reaches that expressiveness.

4. **Scale the resource down instead of the workload up, and compare two runs (chosen).**
   `--max-recursion-depth` is settable *downward*. Bisecting the minimum viable ceiling
   for a program is a direct, cheap measurement of its peak recursion depth. Hold the
   trajectory length fixed, vary the per-step record volume, and require peak depth to stay
   within a small constant factor.

## Decision

Adopt **resource growth as a metamorphic relation over a pair of executions, measured by
bisecting the minimum viable `--max-recursion-depth` of an out-of-process run.**

The relation:

> For two runs of the same generator differing **only** in `max_chunks_per_interaction`
> (records produced per step), with `max_interactions` (trajectory length) held fixed,
> peak recursion depth must not grow proportionally to the record volume.

### Why this is the right measurement, in numbers

Two drivers over identical synthetic workloads — one carrying its counters forward, one
re-deriving them by folding accumulated state each step. Trajectory length fixed at 50
steps; per-step record volume scaled 8×. The figure is the minimum `--max-recursion-depth`
at which the run completes, found by bisection:

| driver | per=5 | per=10 | per=20 | per=40 | growth over 8× input |
|---|---|---|---|---|---|
| counters carried forward | 73 | 73 | 73 | 98 | **1.3×** |
| per-step fold over accumulated state | 317 | 561 | 1074 | 2074 | **6.5×** |

The faulty driver's depth tracks the input almost exactly. The healthy one is flat. The
separation is roughly 20× at the largest scale and widens with it, so the threshold does
not need to be tuned finely.

**Vary records-per-step, not steps.** Scaling the trajectory length instead is *not* a
discriminator: both drivers are linear in steps, because `c2_loop` is itself
non-tail-optimized. Holding steps fixed is what isolates accumulated state from loop
length, and getting this backwards produces a check that is red on everything.

### What this buys, beyond detecting the fault

- **Out-of-process by construction.** The ceiling is a CLI flag on a subprocess, so the
  observer never shares the observed run's frame budget. Constraint 3 dissolves rather
  than being worked around, and `HarnessFailureKind`'s documented property survives
  untouched — the abort is classified by the parent from exit status and a stable
  `RT_REC_003` marker on stderr (measured: exit 1 on abort, exit 0 otherwise), not by a
  runner that has to outlive its own death.
- **Cheap.** Bisection over ~12 subprocess runs, each of which is a normal DST run
  (`driver_only_dst` completes in 0.46 s). Seconds, not a soak.
- **D2 is respected exactly as written**, and this is the part worth stating plainly:
  no declared bound is raised and no run is unbounded. The workload stays inside the
  existing bounds; the *resource* is what moves. §3.9(a) proposed the opposite and would
  have needed a new declared bound to stay legal.
- **Nothing is capped.** The relation never asserts a limit on trace size, so D6.4 is
  untouched.
- **It generalizes past this bug.** Any per-step traversal of accumulated state — trace,
  emissions, message history — has the same signature, whoever writes it next.

### Family placement

This is a relation between two executions, so it belongs with §3.6's metamorphic family
rather than as a thirteenth whole-execution family. `ExecutionUnderTest` describes one run
and cannot express it; the existing pair-of-executions discovery-contract check is the
precedent for where paired properties live.

**D7 does not need amending.** Its list is prefaced "At minimum, the name-adoption gate
requires", so it is a floor, not a closed set. But `family_obligation`'s header — "D7's
twelve bullets, transcribed... so the acceptance script can assert that every family it
runs is a family D7 names" — assumes the two sets are equal. If a later decision does add a
whole-execution family, that comment and its guard must first learn to distinguish D7's
floor from families beyond it. Recorded here because it is a trap for the next family,
not a problem for this one.

### House caveats respected

- **Mutation proves a guard CAN fire, not that it fires too much.** The table above is
  exactly such a demonstration — a known-bad driver and a known-good one, both measured —
  and it is evidence of firing, not of calibration. A green relation says peak depth did
  not grow *on the trajectories run*; it does not say no O(|state|) per-step work exists.
  That is §3.3's question and is not answered here.
- **Faults are outcomes at the typed boundary, never Buggify-style in-code fault points.**
  Nothing is injected. The ceiling is a runtime configuration of the process under test,
  and the record volume is a declared generator bound already in `GeneratorBounds`.

## Consequences

**Costs:**
- A new out-of-process runner in the shell, alongside `run_stream_parity_wire.sh` and
  `run_ledger_parity_wire.sh`. That is a third shell gate; the project has been
  deliberate about keeping these few.
- The relation needs a tolerance, and a tolerance is a tuned number. The measured
  separation is ~20×, so a factor of 2–3 sits far from both populations — but the
  `good` column's 73 → 98 shows the floor is not exactly flat: a step's own records are
  legitimately walked once, which is a per-step constant, not accumulation. The tolerance
  must be stated as "constant factor plus per-step allowance", never as "flat".
- Bisection assumes monotonicity in the ceiling — that a run passing at depth *d* passes at
  every *d′ > d*. True for a deterministic run, and worth asserting rather than assuming,
  since a flaky world would make the bisection meaningless rather than merely noisy.

**Enables:**
- A resource axis that is cheap enough for CI rather than nightly-only.
- Attribution: the failing side reports the program, the seed, and the two bounds it was
  run under, instead of a bare process exit.
- The out-of-process runner is reusable — anything needing to observe a run that may kill
  its own observer now has a place to live.

**Explicitly NOT decided here:** whether the existing suites should *also* run under a
reduced ceiling as a blunt regression guard (they bottom out at depths 300–800 today, so
there is headroom to exploit); whether §3.9(a)'s soak profile still has independent value
for non-recursion resources; and the Z3 route (option 3), which remains the right long-term
home if §3.1 ever reaches the needed expressiveness. None of these are blocked by this
decision.
