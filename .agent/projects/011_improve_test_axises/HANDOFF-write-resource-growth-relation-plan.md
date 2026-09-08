# Handoff: write the plan for ADR-002's full resource-growth relation

Date: 2026-08-17
From: the session that authored `ADR-002-resource-growth-as-a-metamorphic-relation.md`, adjudicated
the spike that tested it, fixed motoko_agent#160, and shipped the interim gate
For: a fresh session grounded against HEAD
Deliverable: `PLAN-resource-growth-relation.md` — a WI-numbered execution plan for replacing the
shipped pinned canary with ADR-002's slope relation

**Write the plan; do not build it.** This is the split
`../../meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md` names:
implementation plans are source-heavy and belong to a session fresh at HEAD, not to the one that
authored the decision. The ADR, the spike findings and this handoff are the inputs; a dense survey
of the generator, the profile machinery and the canary artifacts is the work.

Where this handoff and ADR-002 disagree, **the ADR wins** — with the exception of its *Corrections*
section, which supersedes its own body and is the first thing to read.

## Your task

Author `PLAN-resource-growth-relation.md`. Its subject is one sentence:

> Replace the shipped pinned-ceiling canary with a measured **slope** of recursion depth against
> accumulated records, with trajectory length held fixed.

**Do not re-derive the decision.** ADR-002 is Proposed and has survived a review pass and an
execution pass; three of its statements were wrong and are recorded as Corrections 6–8. Your plan
implements the corrected version. If you believe the decision itself is wrong, say so as a finding
against the ADR rather than by quietly planning something else.

## Read first, in order

1. **`ADR-002-resource-growth-as-a-metamorphic-relation.md`** — the spec. Load-bearing: the TL;DR's
   four easy-to-invert points, the *Decision*'s three load-bearing words, **Corrections 6–8**, and
   *Partially built* under Consequences, which lists what you no longer have to plan.
2. **`NOTE-spike-findings-resource-growth.md`** — every number that matters, and the only place the
   Q1–Q5 verdicts live. Its *Disposition* is your work list.
3. **`.agent/issues/per-step-trace-fold-exceeds-recursion-depth.md`** — the fault this exists to
   catch, and the *Gated* section describing what shipped.
4. `NOTE-dst-substrate-versus-oracle.md` — only if you need *why this is worth doing*. It argues
   the substrate is leveraged and the parameterization is the gap, which is the case for item 1
   below being worth its cost.

## What is already built, so you do not plan it

Re-ground each against HEAD before citing it; these are this session's claims, not yours.

| thing | where | state |
|---|---|---|
| driver-phase measurement seam | `scripts/dst/export_trace.ail`, `CG_EXPORT_PHASE=driver` | shipped, writes nothing, off by default |
| out-of-process bisection harness + gate | `scripts/dst/run_depth_canary.sh`, `make depth_canary` | shipped, in `DST_TARGETS`, shown to fire |
| unit-level frame-free probe | `scripts/dst/recursion_depth_probe.ail` | shipped; calls the real exported `session.runtime_status_counts` |
| the #160 fix | `src/core/session.ail` — `List.foldl` + a lazy, name-guarded call site | landed, verified 86/153/114 → 58/87/75 |

## The three work items, and what makes each hard

**WI-1 — make the records-per-step lever real.** `dst_generator.ail:598` draws chunks from a
hardcoded `0, 3` and `bounded_draw` (`:429`) clamps *downward*, so `max_chunks_per_interaction` is a
ceiling on a draw that never exceeds 3 — traces at c=4, 8, 16, 32 are byte-identical and the usable
record range is **1.25×**. Without this there is no slope to measure, so everything else depends on
it.

The cost is the reason this is a plan and not a patch: that draw is on the path `canary_bounds`
exists to certify, so changing the range re-pins every canary digest that walks it. **Price that
fallout before writing a schedule** — how many pinned artifacts, and whether D8's generator-version
bump is required. If the answer is "a version bump", the plan must say so on its first page.

**WI-2 — settle the seed question.** Seed 3 terminates after 2 decisions with **zero tool batches**,
never executes the faulty line, and is flat at 28 in both conditions: the relation is *vacuously
green* on it. Tool-arm coverage is a property of the seed, not the profile. Either the gate asserts
a minimum tool-batch count as a precondition, or it runs a seed set. The shipped canary sidesteps
this by picking three seeds that all reach the arm — a mitigation, not an answer, and the plan owns
the choice.

**WI-3 — replace the pins with the slope.** Tier 1's floor is ~2.4 frames per decision plus ~23, so
any legitimate change to `c2_loop`'s per-step cost reddens it. The slope statistic is immune to that
because it varies records with steps held fixed. Decide what replaces what: whether tier 1 retires,
becomes a cheap pre-filter, or stays as a second signal.

## Stop and report rather than deciding

- **If WI-1's canary fallout is larger than a handful of artifacts, or needs a generator-version
  bump.** That changes this from a test-infrastructure change into a D8 compatibility event, and it
  is an operator call, not a planning one.
- **If the widened lever does not actually widen the record range.** The `0, 3` reading is this
  session's, verified by byte-identical traces at c=4/8/16/32 but not by changing the literal.
  Measure before planning against it.
- **If a second profile turns out to be needed.** `export_trace.ail:42` refuses every profile but
  `driver_only`, and everything measured so far is that one profile. Widening it is a wiring
  decision the exporter's own comment says must be argued, not forked silently.

## Guardrails

- **The gate that exists must not regress while you plan.** `make depth_canary` is green at HEAD and
  is shown to fire against the pre-fix driver; any proposal that would retire it before the slope
  gate works must say what covers #160 in the interim.
- **Do not bump a canary pin to make something pass.** `run_depth_canary.sh`'s header carries D8's
  discipline: a pin moves as a deliberate act with a recorded reason. A plan whose first step is a
  pin bump has misdiagnosed something.
- **A green relation proves the instrument fires on the trajectories run, not that no
  `O(|state|)` traversal exists.** That is §3.3's oracle-strength question and stays out of scope;
  the plan should say so rather than implying coverage it has not measured.
- Expect to find defects in ADR-002. Its own author's prose survived one review pass and was still
  wrong in three ways that only execution found — budget a correction round rather than treating
  the ADR as settled.

## Calibration ask

The spike measured its own cost implicitly; nobody has measured WI-1's. **Report the canary-fallout
count before scheduling the rest** — how many pinned artifacts a changed draw range actually moves.
That number decides whether the full relation is a week or a quarter, and this session has only an
estimate to offer.
