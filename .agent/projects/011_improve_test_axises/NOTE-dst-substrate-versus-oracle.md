# Finding: DST's substrate was reusable; its oracle set was the gap

Date: 2026-08-17. Status: recorded. Scope: an observation about what the 2026-08-17
resource-growth work says about the DST system, separable from the decision it produced.

_Written because the obvious summary of that work — "DST caught it" — is wrong in one direction
and "DST missed it" is wrong in the other, and the accurate version is more useful than either._

## What "substrate" means here, objectively

The word is doing real work in this note, so it is defined by **dependency direction** rather
than by taste: the oracle imports the substrate and never the reverse. `dst_invariants.ail` —
the twelve families, ~53 `Violation` constructors, `evaluate()` — is the whole oracle.
Everything it imports is substrate:

| layer | module | contributes |
|---|---|---|
| world boundary | `ports.ail` | `WorldState`, the port surface — "swap the ports, keep the code" |
| seeded choice | `dst_generator.ail` | `GeneratorState`, `GeneratorBounds`, `bounded_draw`, `choose_provider` |
| the recorded program | `dst_interaction.ail`, `dst_program.ail` | `Interaction`, causal identity, ordinals, serialization |
| reproduction | `dst_replay.ail` | strict and regression replay |
| modelled faults | `dst_fault_catalogue.ail` | the fault classes, at the typed boundary |
| observation channel | `phase_vocab.ail` | `LedgerTrace` / `LedgerEvent` / `LedgerRecord` |
| event taxonomy | `dst_event_vocabulary.ail` | variant names, logical vs display-only |
| typed outcome | `dst_result.ail` | `DstResult = RunCompleted(SystemRun) \| RunFailed(HarnessFailure)` |

Plus `dst_profile.ail` (profiles and manifests) on the configuration side, and
`dst_execution.ail` as the **bridge** — `execution_of` is what turns a run into an
`ExecutionUnderTest` the oracle can read.

**The decisive test.** Delete `dst_invariants.ail`; what still works? You can generate a program
from a seed, run the real driver against a deterministic world, get a typed result, record a
complete trace, serialize the program, replay it strictly, and diff two runs. You lose every
*verdict*. That residue is the substrate, and it is exactly what the spike operated in.

**Substrate answers "what happened, reproducibly?"; the oracle answers "was that correct?"**

**Where the line genuinely blurs**, recorded because a clean taxonomy is usually lying
somewhere. `dst_event_vocabulary`'s logical/display-only classification and
`dst_fault_catalogue`'s class list are *normative* — judgments about what should be observable
and which faults are legitimate — which is oracle-flavoured work living in substrate modules.
`dst_program`'s validation rejects malformed programs, a correctness verdict about the artifact
rather than about the run. It is a gradient, not a partition. The import direction holds
throughout, which is what makes it usable rather than a vibe.

## The two halves

A production abort (`.agent/issues/per-step-trace-fold-exceeds-recursion-depth.md`) was missed by
every one of the twelve invariant families, and then detected on the real driver within hours by
an instrument built on the same DST world. Both facts are about the same system.

**The oracle set could not see it, and still cannot.** All twelve families
(`dst_invariants.ail:219-233`) are correctness relations over a trace — pairing, parity,
monotonicity, agreement, replay equality. The fault is a *resource* property whose quantity is how
many times the driver **walked** the trace, and a trace records appends, not reads. The trace that
killed the run is perfectly well-formed and merely large. Three further reasons are in the issue
record; nothing in this work changed any of them. **No thirteenth family was added.**

**The substrate carried the detection entirely.** The spike
(`NOTE-spike-findings-resource-growth.md`) reused, unmodified: the seeded generator and its bounds,
the `driver_only` profile, deterministic replay, the world/ports boundary, and the trace exporter as
a host. Its own three edits were a bounds parameter, a phase ablation, and a one-line measurement
instrument — all disposable. That a feasibility test of a genuinely new detector cost hours rather
than weeks is a property of the substrate, and it is the thing that got vindicated.

## The sharper form: the detector uses DST's world and none of its oracle

The instrument is an out-of-process bisection over `--max-recursion-depth`, comparing peak
recursion depth across a pair of runs. It never calls `evaluate()`, never constructs an
`ExecutionUnderTest`, and could not — that type describes **one** run and the property is a
relation between two. It consumes the generator and the profile and nothing else.

So the accurate sentence is not "DST detected it" but: **DST's world was reusable enough to build a
different kind of detector on top of.** The families are one oracle over that world, not the only
one it admits.

Two consequences worth carrying:

- **"Add a family" is not the only way to extend coverage**, and for whole classes of property it
  is the wrong way. Resource behaviour, timing, and anything relational across executions do not fit
  a per-run invariant, and forcing them into one was the first draft of ADR-002 — which review and
  execution then had to undo (its *Corrections* 1 and 7).
- **The substrate's value is partly independent of the oracle's completeness.** Project 009 built a
  deterministic world to serve twelve families; it turns out to serve instruments those families
  cannot express. That is an argument for the world's generality that the acceptance table does not
  make and could not.

## What follows for investment — and the reading that inverts it

The tempting conclusion is "invest in the deterministic world". Correct, but **the naive form
inverts the evidence**: the substrate is the thing that *worked*. Its **fidelity** was never the
gap. Read as "simulate more, more faithfully", nothing here supports it.

What the spike actually strained against was **parameterization and observability**. Three gaps,
each of which measurably narrowed the result:

| gap | evidence | cost |
|---|---|---|
| chunk draw hardcoded `0, 3`; `max_chunks_per_interaction` only clamps it (`dst_generator.ail:598`, `:429`) | traces at c=4, 8, 16, 32 byte-identical | lever was **1.25×**, not 8× — and that range is "the whole evidence base for Q3" |
| trajectory shape is whatever the seed draws; not requirable | seed 3: 2 decisions, **zero** tool batches | relation *vacuously green* there — a single-seed gate can be silently blind |
| phases are not ablatable; the exporter's serializer is welded in | `export_trace.ail:237` masked the signal entirely | needed a `SPIKE_PHASE` patch to isolate the driver at all |

Consistent with the paper's own §8 admission — three profiles exist (`driver_only`,
`driver_plus_no_ops`, `driver_plus_compose`), ten of fifteen extensions are installed in none of
them, fourteen of fifteen have no dynamic evidence. **The world is faithful but
under-parameterized and, in places, hard to observe.**

So the backable investments are: make generator ranges declarable rather than literal; make
trajectory shape something a profile can *require* rather than hope for; make phases separately
measurable. Each is cheap next to building world, and each directly unblocks something this
spike had to work around.

**The asymmetry is the real argument, and it is independent of this fault.** Substrate is
**leveraged** — one improvement makes every future instrument cheaper and every future result
wider; the `0, 3` literal caps the evidence base of anything measuring record volume, forever.
Oracle is **additive** — each family catches what it catches, and a missing one is a silent
blind spot rather than a narrowed result.

Keep it distinct from the complementary axis. §3.3's mutation study — the paper's own top
self-diagnosed gap, *"no systematic mutation study showing which of the twelve invariant families
would catch which classes of incorrect recovery; reachability is not oracle strength"* — asks
whether the oracles already built are any good. This work did not touch it, and substrate
parameterization will not answer it.

## What this does not claim

- **Not that the oracle set is deficient by design.** D7 is prefaced "At minimum" and was always a
  floor. The families were built against the failure classes 009 could enumerate; a resource
  property was not among them, and this note is not a finding against the choice made then.
- **Not that the new instrument is calibrated.** It fires on one fault, on one profile, over the
  trajectories four seeds walked, and nothing is built. See the spike note's *What this note does
  not establish*.
- **Not that DST would have caught #160 in production.** It would not have. The gate did not exist,
  and — per the spike — a single-seed gate could have been silently vacuous even if it had.

## Where this belongs eventually

`papers/motoko-dst-report/DRAFT.md` §8 (Discussion and limitations) or §9 (Future work). §8 already
carries the "coverage is thin, and the system says exactly how thin" paragraph, and this is the same
genre of admission with a positive half attached: the first production fault measured against the
built system, what the oracle could not express, and what the world supported anyway.

**Deliberately not edited into the paper here.** It is a full draft under a freeze discipline with a
binding compliance note and an open `[VERIFY]` register; adding a claim to it is an act for whoever
owns the freeze, against HEAD at freeze time, not a drive-by from the session that produced the
claim.

## Related

- `ADR-002-resource-growth-as-a-metamorphic-relation.md` — the decision; its *Corrections* carry the
  three specification errors execution found.
- `NOTE-spike-findings-resource-growth.md` — the measurements.
- `RESEARCH-test-axes-beyond-dst.md` §3.9 — the axis, and §3.6, whose metamorphic family is where a
  relation over a pair of executions belongs.
- `.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
  — the *process* lesson from the same work, recorded separately because it is about how to work
  rather than about what DST is.
