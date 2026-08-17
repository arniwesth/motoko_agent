# Plan: throwaway spike — does the resource-growth relation hold on the real driver?

Status: Proposed. Date: 2026-08-17.

**This is not the implementation plan.** `ADR-002-resource-growth-as-a-metamorphic-relation.md`
decides a mechanism; a later `PLAN-resource-growth-relation.md` will sequence its construction.
This spike exists because **every number in ADR-002 is synthetic.** The 1.3×-versus-6.5×
separation that justifies the whole design was measured on a hand-written probe in
`/tmp`, not on Motoko. Nothing has been run against `driver_only`.

It is a **down payment on that plan's evidence**. Three of the things ADR-002 leaves
explicitly undecided — the tolerance factor, the profile pair, and the gate cadence — are
unanswerable until the real separation is known, and a plan that picked them from synthetic
numbers would be picking them from nothing.

## Why now, and specifically why before the #160 fix lands

**Q1 stops being answerable once the fault is fixed.** The relation is being validated
against a known-bad system, and `.agent/issues/per-step-trace-fold-exceeds-recursion-depth.md`
is the only known-bad system available. Fix `session.ail:2470` first and the spike has
nothing to detect — it would then be validating an oracle against a system where the answer
is "no growth", which confirms nothing about whether it can *see* growth.

This is a scheduling constraint, not a preference. It is the one ordering dependency between
the two threads of work, and it runs the other way from the obvious instinct, which is to fix
the bug first.

It also inverts cheaply: if Q1–Q3 come back green, Q4 turns the spike into a **regression
test for #160** — measure, apply the fix, measure again, and watch the growth factor collapse.
That is a strictly better artifact than either piece of work produces alone, and it is
available only in this order.

## What is already measured, so the spike does not redo it

All 2026-08-17, AILANG v0.33.0 `ae36986`. These are settled; the spike inherits them.

- **No TCO.** A tail call costs one frame; boundary is exact (9 999 passes, 10 000 aborts).
- **Bisection is valid.** Linear scan over depths 190–230 on a faulty-driver program: exactly
  one transition, no oscillation.
- **Abort is classifiable.** Exit 1 plus a stable `RT_REC_003` stderr marker. Exit 1 alone is
  not sufficient — an ordinary invariant failure exits 1 too.
- **Stdlib and builtins are frame-free.** `++`, `std/json.encode`, `List.map`, `Str.join` all
  cost zero frames (300-deep descent then the operation over 300 elements, completing at a
  ceiling of 350). **Depth in this codebase comes only from Motoko's own hand-written
  recursive helpers**, never from the stdlib — which is why `ledger_append` is not a second
  instance of the fault, and why Q5 is scoped to `.ail` code we wrote.
- **`export_trace.ail` imports no `dst_invariants`**, so the driver phase is checker-free by
  construction rather than by discipline.

## Questions, with falsification criteria

Falsification stated before the work starts, because a spike without a stated negative result
becomes advocacy — and the author of ADR-002 is the same author writing this, which is exactly
when that risk is highest.

**Q1 — Does `driver_only` exhibit the fault at all?**
The load-bearing question. A relation validated on a profile that does not contain the bug has
demonstrated nothing.
- *Confirms* if bisected peak depth rises materially as `max_chunks_per_interaction` rises,
  with trajectory length held fixed.
- *Falsifies* if depth is flat. That most likely means `runtime_status_json`'s fold is not on
  the `driver_only` path — plausible if the profile's scripted steps rarely reach `RunTools`,
  since `session.ail:2470` sits only in that arm. **A falsification here is a finding about
  profile coverage, not about the relation**, and it promotes "the driver_only profile does not
  exercise the tool-dispatch arm" to a defect in its own right.

**Q2 — Does `max_chunks_per_interaction` actually move the record count?**
The knob has to work before the relation can use it. `export_trace.ail` takes profile and seed;
bounds arrive through `driver_only_manifest`, so varying them may need a knob that does not
exist yet.
- *Confirms* if raising the bound produces proportionally more `StreamDelta` records in the
  exported trace.
- *Falsifies* if the bound is pinned in the manifest with no override seam, or if
  `driver_only`'s generator does not draw chunks at all. Either turns "vary the bound" into
  design work the PLAN must budget rather than assume.

**Q3 — How wide is the real separation?**
Measurement, not pass/fail. Report the growth factor at three or more scale points, against the
synthetic baseline of 1.3× (correct) versus 6.5× (faulty).
- The number the eventual PLAN needs is the **gap between populations**, not either factor
  alone. A real result of 1.2× versus 1.4× makes the tolerance question unanswerable and sends
  ADR-002 back for rework — which is a legitimate outcome of this spike and must not be
  argued around.

**Q4 — Does the #160 fix collapse the growth factor?**
The payoff question, and only answerable in this window.
- *Confirms* if applying incremental counts (`session.ail:507`, using the existing
  `prior_counts` / `runtime_status_counts_add` machinery) drops the factor to the flat
  population.
- *Falsifies* if it does not — which would mean a second O(|accumulated state|) traversal
  survives on the driver path, and the issue record's fix list is incomplete. That is a finding
  about #160 worth more than the spike.

**Q5 — Is anything else on the measured path frame-deep?**
The review of ADR-002 already caught one masking traversal (`dst_invariants.evaluate`). The
same class of error can hide in the export path.
- *Confirms* if bisected depth for a run with the fault removed is flat in record volume —
  i.e. nothing else on the `export_trace` path traverses the trace.
- *Falsifies* if a floor rises with the bound anyway. Candidates are Motoko's own recursive
  helpers reachable from export — `canonical_messages_raw`, `system_prefix_chars`,
  `stream_chunk_events`, `c2_trace_wire_events` — since the stdlib is already cleared. A
  falsification means the measurement needs a narrower phase than "the whole export".

## Sequence

1. Branch that never merges, cut **before** any #160 fix.
2. Establish the knob (Q2) — the smallest thing that varies `max_chunks_per_interaction` per
   invocation. If it needs a manifest seam, **stop and report** rather than building one; that
   is PLAN work, not spike work.
3. Bisect peak depth at three or more bound values, trajectory fixed (Q1, Q3).
4. Apply the #160 fix on the spike branch and re-measure the same points (Q4, Q5).
5. Write the findings note. One table, five verdicts.

## Out of scope

Named explicitly, because this spike's characteristic failure mode is becoming the
implementation — the measurement harness looks like the gate.

- The tolerance factor, the profile pair, the gate cadence. This spike produces the numbers
  those decisions need; it does not make them.
- Any `make` target, CI wiring, or gate.
- The §3.6 metamorphic family placement, and any change to `dst_invariants`.
- A second bearing profile, even if Q1 falsifies and one is clearly needed.
- Landing the #160 fix. It is applied here only as a measurement instrument; it lands on its
  own branch, on its own merits, reviewed normally.

## Guardrails

- **It never merges.** The branch is deleted or left dangling; no PR is opened.
- **The #160 fix applied here is not the #160 fix.** It exists to move a number. Whatever
  lands in production is written and reviewed separately, and a green Q4 is not a review.
- **It does not block the #160 fix.** If the spike stalls, the fix proceeds; Q1 and Q4 are
  then simply lost, and the eventual PLAN carries synthetic numbers with that fact stated.
- **A red Q3 is a result, not a setback.** ADR-002 is Proposed, not Accepted, and a separation
  too narrow to set a tolerance is exactly the finding that should stop it.
- Expect it to surface further ADR-002 defects. The review already found two majors in a
  document its own author believed finished; budget for a third correction pass rather than
  treating a green spike as a finish line.

## Disposal

What dies with the branch: all of the code, including the #160 fix applied to it.

What survives, and where it goes:
- Q1–Q5 verdicts and the Q3 table → `NOTE-spike-findings-resource-growth.md`, following
  `009/NOTE-spike-findings-real-driver-vertical.md`.
- The Q3 numbers, which `PLAN-resource-growth-relation.md` cites instead of the synthetic
  ones, and which ADR-002's *Why this is the right measurement* table is then rewritten
  against — replacing a probe result with a real one.
- Any Q1 falsification, filed as a profile-coverage finding against `driver_only`.
- Any Q4 falsification, filed against
  `.agent/issues/per-step-trace-fold-exceeds-recursion-depth.md` as an incomplete fix list.
- Any ADR-002 defect, appended to its *Corrections* section the same way the review's two were.
