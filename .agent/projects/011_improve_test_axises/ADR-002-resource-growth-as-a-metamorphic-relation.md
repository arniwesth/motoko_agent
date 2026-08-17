# ADR-002: How should DST detect recursion depth that scales with accumulated state?

**Status:** Proposed
**Date:** 2026-08-17
**Revised:** 2026-08-17 twice — once after review, once after execution. See *Corrections*.
The mechanism has survived both; every number and two of its three key statements have not.
Review found the property stated too narrowly and the scope requirement missing;
the spike (`NOTE-spike-findings-resource-growth.md`) found the scope requirement still too
wide to work, the statistic wrong for the range available, and every figure here synthetic by
a factor of six. **All measurements in this document are now from the real driver.**

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

## TL;DR

**Problem.** A production session aborted at `RT_REC_003` because the driver folds its whole
accumulated ledger once per step, and AILANG has no TCO. Twelve invariant families could not
have caught it: they check correctness relations over a trace, and this is a resource
property whose quantity — how many times the driver *walked* the trace — is not in the trace.

**Decision.** Don't grow the workload until it breaks; **shrink the resource until it
does.** `--max-recursion-depth` is settable *downward*, so bisecting the minimum viable
ceiling measures a program's peak recursion depth directly. Then compare two runs:

> Same generator, `max_interactions` (trajectory length) **fixed**, records-per-step
> **varied** — the peak recursion depth of a **phase strictly narrower than the export
> process** must have a **slope** of zero frames per accumulated record.

**Why it works,** measured on the real driver (`driver_only`, spike findings, three seeds):

| statistic | fault present | fault removed |
|---|---|---|
| growth **ratio** over the available 1.25× range | 1.06–1.18× | 1.00× |
| **slope**, frames per accumulated record | 0.75–0.90 | **exactly 0.00** |

The separation is not a wide margin — it is *qualitative*, linear versus identically flat.
That is why the relation is stated on the slope: over the range the generator actually
offers, a ratio tolerance of "2–3×" is green on every faulty seed measured.

**Four things that are easy to get backwards, and all four were, at first:**

1. **Vary records-per-step, not steps.** Both drivers are linear in *steps* — `c2_loop` is
   itself non-tail-optimized — so scaling the trajectory is red on everything. Holding steps
   fixed is what isolates accumulated state from loop length.
2. **The property is "no depth that scales with accumulated state", not "no per-step
   fold".** Peak depth cannot tell a per-step fold from one end-of-run fold. That is fine,
   because both are equally fatal — but it means the narrower property is undecidable here
   and the broader one is what gets checked.
3. **Measure a phase narrower than the export, not just "the driver without the checker".**
   Excluding `dst_invariants.evaluate()` is necessary and *not sufficient*:
   `export_trace.ail:237`'s `record_lines` recurses once per record from inside the exporter,
   and through the whole export process a faulty and a fixed driver both report **86**. The
   two rows this relation exists to separate are the two rows that instrument cannot tell
   apart.
4. **Use the slope, not the ratio** — and do not add a "per-step allowance". On the real
   driver with steps held fixed the healthy floor is *identically* flat; the drift that
   earlier drafts budgeted for was an artefact of the synthetic probe.

**Cost.** ~17 subprocess runs per scale point at 0.46 s each (tolerance 1) — CI-cheap, not a
nightly soak. `run_export_trace.sh` is the nearest existing runner but **cannot be used as-is**:
its quiet path pipes through `grep`, and its serializer is the masking traversal in (3).

**Constraints respected, all three by construction:** no declared bound is raised (D2), no
trace size is capped (D6.4), and the observer never shares the observed run's frame budget,
so `HarnessFailureKind` keeps its "observable while still running" property (D6.6/D6.7).

**Lands in §3.6's metamorphic family**, not as a thirteenth whole-execution family —
`ExecutionUnderTest` describes one run and cannot express a relation between two.

**Not implemented.** Read *Corrections* before changing the design.

## Context

A live session aborted with `RT_REC_003` because the driver re-folds its whole accumulated
`LedgerTrace` once per tool step. None of the twelve invariant families could have caught
it, for four independent reasons recorded in the issue. The question this ADR settles is
narrower than "add a family": **by what mechanism can a deterministic simulation observe
that a run's recursion depth scales with accumulated state, given that the traversal leaves
no trace record?**

The question was first written as "per-step work grows with accumulated state". Review
showed that is the wrong property — narrower than what matters and, worse, not decidable by
any instrument this ADR could find. See *The property is "no depth that scales with
accumulated state"* under the Decision.

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

> For two or more runs of the same generator differing **only** in records-produced-per-step,
> with `max_interactions` (trajectory length) held fixed, the peak recursion depth of **a
> measured phase strictly narrower than the export process** must have a **slope of zero
> frames per accumulated record**.

Three words in that sentence are load-bearing and each was wrong in an earlier draft:
**slope** (not growth ratio — Correction 7), **strictly narrower than the export** (not "the
driver phase", which still contains the exporter's serializer — Correction 6), and
**records-produced-per-step** rather than `max_chunks_per_interaction`, which is a clamp on a
draw hardcoded to `0, 3` and cannot scale the volume on its own (Correction 8).

### The property is "no depth that scales with accumulated state", not "no per-step fold"

This distinction is the whole correctness of the design and the first draft got it wrong.

**Peak depth cannot distinguish "folds accumulated state every step" from "folds it once at
the end".** Both reach the same maximum. Measured — a *correct* driver whose finished trace
is then walked once, versus the faulty driver, trajectory fixed at 50 steps:

| configuration | per=5 | per=10 | per=20 | per=40 | growth |
|---|---|---|---|---|---|
| correct driver, nothing else | 73 | 73 | 73 | 98 | 1.3× |
| **correct driver + one end-of-run fold** | **268** | **512** | **1025** | **2025** | **7.6×** |
| faulty driver (per-step fold) | 317 | 561 | 1074 | 2074 | 6.5× |

Rows 2 and 3 are indistinguishable. So a relation phrased as "per-step work must be O(1) in
accumulated state" is not decidable by this instrument, and an implementation of the first
draft would have gone red on a correct driver.

**The resolution is that row 2 is not a false positive.** Any recursion whose depth scales
with accumulated state is a hard cap on session length — whether it runs once or every step,
it aborts the run at the same size. A single end-of-run fold over a 10 000-record trace is
exactly as fatal as a per-step one. So the property worth checking is the broader and simpler
one, and this instrument decides it exactly.

**What that costs is a scope requirement, and it is mandatory rather than an optimization.**
Row 2's fold is real: `dst_invariants.evaluate()` walks the trace through `count_variant` and
`count_decisions` (`dst_invariants.ail:1198-1215`), both non-tail-recursive over records. That
is test-only code, and its depth is not a production property.

**Excluding the checker is necessary and not sufficient**, which the spike established the
hard way — see Correction 6. `export_trace.ail:237`'s `record_lines` recurses once per record
from inside the exporter, so the export process masks the signal completely: at the top of the
range a faulty and a fixed driver both report **86**. **The measured phase must therefore be
strictly narrower than the export** — run the driver, touch the trace only through frame-free
operations, and serialize elsewhere or not at all.

`scripts/dst/export_trace.ail` remains the right host for that phase, but it needs an ablation
seam rather than a flag, and `run_export_trace.sh` cannot be the harness: its quiet path pipes
through `grep`, so `$?` is grep's.

### Why this is the right measurement, in numbers

Measured on the real driver, `driver_only`, by the spike
(`NOTE-spike-findings-resource-growth.md`). Trajectory length held fixed — verified, not
assumed: decision, provider-call and tool-batch counts are constant across each sweep and only
`StreamDelta` volume moves. Seed 7, records 63 → 79, driver phase only:

| condition | 63 | 69 | 74 | 79 | slope | ratio |
|---|---|---|---|---|---|---|
| fault present | 73 | 78 | 82 | 86 | **0.81 frames/record** | 1.18× |
| fault removed | 58 | 58 | 58 | 58 | **0.00** | 1.00× |

Across seeds 7/11/23 the faulty slope is 0.75–0.90 and the fixed slope is **exactly 0.00** at
every point. The flat floor is attributed: 28/58/75/87 frames at 2/15/21/26 decisions ≈ 2.4
frames per step plus a ~23-frame constant, which is `c2_loop`'s known linearity in steps.

**The separation is qualitative, not wide.** As a ratio it is 1.06–1.18× against 1.00× — no
"2–3× tolerance far from both populations" exists, and a ratio-based gate would be green on
every faulty seed measured. As a slope it is linear against identically flat, and any threshold
in (0, 0.75) decides it.

**Vary records-per-step, not steps.** Scaling the trajectory length instead is *not* a
discriminator: both drivers are linear in steps, because `c2_loop` is itself
non-tail-optimized. Holding steps fixed is what isolates accumulated state from loop
length, and getting this backwards produces a check that is red on everything.

**The available range is 1.25×, and widening it is core work.** `max_chunks_per_interaction`
clamps a draw hardcoded to `0, 3` (`dst_generator.ail:598`, `bounded_draw` at `:429`), so
raising it above 3 is a no-op — traces at c=4, 8, 16, 32 are byte-identical. Records move only
63 → 79. A wider lever means changing that draw range in core, which moves every pinned canary
digest walking the chunk path. **A plan for the full relation — not yet written; see
`HANDOFF-write-resource-growth-relation-plan.md`** — must budget that change rather than assume
the knob scales.

### What this buys, beyond detecting the fault

- **Out-of-process by construction, and the scope requirement comes free with it.** The
  ceiling is a CLI flag on a subprocess, so the observer never shares the observed run's
  frame budget: constraint 3 dissolves rather than being worked around, and
  `HarnessFailureKind`'s documented property survives untouched. The abort is classified by
  the parent from exit status plus the `RT_REC_003` stderr marker, not by a runner that has
  to outlive its own death. The same subprocess boundary is what keeps invariant evaluation
  out of the measurement — one mechanism, two obligations.
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
- The scope requirement is load-bearing, not hygiene, and it is **narrower than "exclude the
  checker"**: the exporter's own serializer masks the signal from inside the process this ADR
  originally named. Whoever implements this must be able to state which *phase* is measured
  and demonstrate — not assert — that nothing in it traverses accumulated state.
- **A seed with no tool batches makes the relation vacuously green.** Seed 3 terminates after
  2 decisions with zero tool batches, never executes `session.ail:2470`, and is flat at 28 in
  both conditions. Tool-arm coverage is a property of the seed, not the profile. The gate must
  either assert a minimum tool-batch count as a precondition or run a seed set. **Undecided**;
  the plan named in `HANDOFF-write-resource-growth-relation-plan.md` owns the choice. The tier-1
  canary shipped in `scripts/dst/run_depth_canary.sh` sidesteps it by running three seeds that
  all reach the arm, which is a mitigation rather than an answer.
- **The lever is narrow and widening it is core work.** 1.25× of record range today; more means
  changing `dst_generator.ail:598`'s hardcoded `0, 3` draw and re-pinning every canary digest
  that walks it.
- Shell-gate count is unchanged, but `run_export_trace.sh` **cannot be the harness** — its
  quiet path pipes through `grep`, so `$?` is grep's, and its serializer is the masking
  traversal. The bisection calls `ailang` directly and reproduces the wrapper's environment.

**No tolerance is needed, which is not what earlier drafts expected.** They argued a tolerance
"must be stated as 'constant factor plus per-step allowance', never as 'flat'", from a synthetic
healthy driver that drifted 73 → 98. On the real driver with steps held fixed there is no drift:
the healthy slope is *identically* 0.00 at every point on every seed, because a step's own
records are walked inside the step and never re-walked. The allowance was an artefact of the
probe. A slope threshold anywhere in (0, 0.75) decides it.

**Verified rather than assumed** (all measured 2026-08-17 against AILANG v0.33.0 `ae36986`):
- **Bisection is valid.** Monotonicity in the ceiling — a run passing at depth *d* passes at
  every *d′ > d* — was scanned linearly over depths 190–230 on a faulty-driver program:
  exactly one transition, no oscillation. A flaky world would still make the bisection
  meaningless rather than merely noisy, so determinism remains a precondition.
- **`++` is frame-free.** Descending 300 frames and then appending to a 300-element list
  completes at a ceiling of 350, so list concatenation costs no interpreter frames. This
  matters twice: `ledger_append` (`phase_vocab.ail:604`) is *not* a second instance of the
  fault, and the incremental-counts fix for #160 is therefore viable rather than merely
  moving the cost.
- **Abort is classifiable.** Exit 1 on abort, exit 0 otherwise, with a stable `RT_REC_003`
  marker on stderr. Note exit 1 alone is *not* sufficient — an ordinary invariant failure
  exits 1 too — so the marker is required, not a convenience.

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

### Partially built, 2026-08-17 — what this ADR no longer has to carry

Three things it named as future work exist, which shrinks the plan it points at:

- **The measurement seam.** `CG_EXPORT_PHASE=driver` in `scripts/dst/export_trace.ail` — the
  driver phase, without the serializer that Correction 6 found masking the signal.
- **The out-of-process harness and a gate.** `make depth_canary`
  (`scripts/dst/run_depth_canary.sh`), in `DST_TARGETS`. Two tiers: a unit probe over 8 192
  constructed records, and the real driver at pinned per-seed ceilings. Shown to fire against the
  pre-fix driver on all four rows.
- **A fix to verify against.** #160 landed and the driver phase measured 86/153/114 → 58/87/75 on
  seeds 7/11/23, matching the spike's independently-derived floor exactly.

**What remains is the relation itself**, and only one thing blocks it: the record volume cannot be
scaled while trajectory length is held fixed, because `dst_generator.ail:598`'s draw range is a
literal. The shipped gate is a **pinned approximation** — general, but its floor moves with
`c2_loop`'s per-step cost — and replacing pins with a slope is what a plan for the full relation is
for. See `HANDOFF-write-resource-growth-relation-plan.md`.

## Corrections

Read this before changing the design. Each entry is something the first draft asserted
without measuring, and that measurement then contradicted. They are kept because in every
case the wrong version is the one a reader will re-derive.

**1. "Per-step work" was the wrong property, and no instrument here decides it.** The first
draft's relation was "per-step work must be O(1) in accumulated state". Peak recursion depth
cannot see the difference between folding accumulated state every step and folding it once
at the end — both reach the same maximum, measured at 6.5× versus 7.6× growth on the same
input scaling. An implementation of that draft would have been red on a correct driver whose
trace is evaluated by the invariant suite. The property is the broader one: *no recursion
depth that scales with accumulated state, anywhere in the production path*. That is worth
having on its own terms — a single end-of-run fold over a 10 000-record trace aborts the run
just as surely as a per-step one.

**2. The measurement must exclude invariant evaluation, and this is not an optimization.**
`dst_invariants.evaluate()` walks the trace non-tail-recursively (`count_variant`,
`count_decisions`, `dst_invariants.ail:1198-1215`). Bisecting a combined driver-plus-checker
process measures the checker. The first draft did not scope the measurement at all.

**3. The out-of-process runner already exists.** The first draft costed it as "a new
out-of-process runner… a third shell gate". `scripts/dst/export_trace.ail` +
`run_export_trace.sh` is the D9 ledger-trace exporter — one profile, one seed, trace written
out — which is precisely the driver-phase-only process the design needs. This is a flag on an
existing runner.

**4. Two assumptions held, and were assumptions until they were checked.** Bisection
monotonicity: scanned linearly over depths 190–230, exactly one transition, no oscillation.
`++` frame cost: zero, so `ledger_append` is not a second instance of the fault and #160's
incremental-counts fix is viable rather than merely relocating the cost. Neither was
measured in the first draft; had `++` cost frames, the fix for #160 would have been wrong
too.

### From the spike (`NOTE-spike-findings-resource-growth.md`, 2026-08-17)

Corrections 1–5 came from reading. These came from running, and all three verified
independently before being accepted here.

**6. The measured phase must be strictly narrower than the export process, not merely
checker-free.** Correction 2 excluded `dst_invariants.evaluate()` and then named
`export_trace` as the process to bisect — but `export_trace.ail:232-237`'s `record_lines`
recurses once per record from inside it. Through the whole export, a faulty and a fixed driver
both report **86** at the top of the range: the two rows this relation exists to separate are
the two the specified instrument cannot tell apart.

**This is the third instance of the same confounder**, and the pattern is worth more than the
fix. Twice I found a maximum-wins masking traversal, corrected the specific source, and did not
go looking for the class. Worse, I *verified the recipe end-to-end* against this very process,
got a number, and never asked whether the number was the driver or the serializer. A verified
instrument is not a validated one.

Corollary the spike measured and it is a trap: **rewriting `record_lines` with an accumulator
does not fix it.** With no TCO a tail call costs a frame identically — accumulator recursion over
400 elements costs 401 frames, and the rewrite left the curve rising with the same slope. Only
stdlib builtins are frame-free. "Make it tail-recursive" is not a remedy for anything here.

**7. The relation is on the slope, not the growth ratio, and needs no per-step allowance.**
Over the range the generator actually offers, the faulty population is 1.06–1.18× against a
healthy 1.00×; the "2–3× tolerance far from both populations" this ADR contemplated does not
exist, and a ratio gate is green on every faulty seed. As a slope it is 0.75–0.90 frames/record
against **exactly 0.00**. The *Consequences* claim that a "per-step allowance" is mandatory was
derived from the synthetic probe's own list-building helper and is false on the real driver.

**8. `max_chunks_per_interaction` is a clamp, not a scale.** Every synthetic number here was
measured over an 8× input scaling; the real lever gives **1.25×**. `bounded_draw`
(`dst_generator.ail:429`) draws from a hardcoded `0, 3` at the call site (`:598`) and clamps
*downward*, so the bound is a ceiling on a draw that never exceeds 3 — traces at c=4, 8, 16, 32
are byte-identical. I quoted that call site early in the analysis and read the bound as the scale
knob without reading what it bounds.

**What the spike confirmed, recorded because a correction list reads as failure otherwise:** the
fault is real and visible on `driver_only` (Q1), the mechanism fires on it and is silent on the
fixed driver (Q3), and removing `runtime_status_counts` alone takes the slope to exactly zero
(Q4) — so #160's fix list is complete for the paths `driver_only` walks, and Q4's falsification
branch did not fire.

### Elsewhere

**5. Not an ADR correction, but found in the same review and recorded here because it
travels with the analysis:** the response posted to motoko_agent#160 claimed `st.emissions`
is "folded in `c2_finalize` at termination", and concluded a large session "may not be able
to terminate cleanly either". Both are wrong. `c2_finalize` passes emissions through
unchanged (`session.ail:1480`), and nothing in the production path folds them — the only
fold is `stream_parity_findings`, which is DST-side. The claim never reached the issue
record; it exists only in the posted comment, which now carries a correction. Recorded here
because a wrong claim that was published is worth more scrutiny than one that was not.
