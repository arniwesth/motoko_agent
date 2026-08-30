# 028 — Verified runtime, closing the loop

Making Motoko's verification loop close on itself: fail-closed at every
enforcement boundary (ADR-001), and rationale that is generated and gated
rather than hand-woven (ADR-002). Evidence from two independent live sessions
(2026-08-29, 2026-08-30), each ~130 steps.

## Reading order

1. **NOTE-motoko-session-assessment.md** (a.k.a. NOTE-001) — first session's
   evidence: gate results, DP7 fail-open defect, batch-skip defect,
   9/10-7/10-6/10 verdict.
2. **VISION-001-path-to-10-of-10.md** — the four layers that close the loop.
3. **ADR-001-fail-closed-verification-everywhere.md** — flip every
   enforcement boundary to fail-closed.
4. **PLAN-001-closing-the-loop.md** — enforcement work items (DP7, batch
   semantics, FORK.md, preflight, claim provenance).
5. **NOTE-002-second-session-fold-wall-and-parser-hang.md** — second session:
   cross-confirmations, the fold-verification wall (stale annotations; the
   fix is re-wiring existing machinery, W1-W4), parser-hang + example-rot
   defects.
6. **NOTE-003-complexity.md** — complexity measured (48 sprint ids / 861
   mentions; hub fan-in 13; 12-parameter entry points) and the five levers.
7. **ADR-002-generated-and-gated-rationale.md** — conventions that carry
   weight (taxonomy, examples, deprecations, failure modes) become generated
   artifacts with gates.
8. **PLAN-002-lower-the-complexity.md** — comprehension-cost work items
   (glossary gate, surface check + options record, hub splits, runnable tour,
   failure-mode triage).
9. **NOTE-004-relation-to-026-operational-ontology.md** — 028 ↔ 026: the
   operational ontology (named actions, refusal codes, authority maps) is the
   general theory ADR-002 instantiated for the rationale layer; glossary gains
   a schema; VISION-001 Layer 3 independently confirmed. Its refinements are
   folded in as "Amended (NOTE-004)" markers in ADR-002 (§4 refusal shape,
   consequences) and PLAN-002 (item 1 schema, new item 6 symbol-anchored
   references, sequencing with the ABI major).

## The one-paragraph state

The concept is proven (cells refuse unverified code; telemetry is honest; two
sessions agree on the numbers). The gaps are structural, not hypothetical:
fail-open boundaries (PLAN-001), a verification tier whose highest automatic
rung excludes the core's own idiom — folds — for a reason that turns out to be
gate ordering, not fragment limits (NOTE-002), and a comprehension layer that
only gates have ever kept truthful (ADR-002). Every fix named here reuses a
pattern the repo already runs in production.
