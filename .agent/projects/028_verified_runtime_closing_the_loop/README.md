# 028 — Verified runtime, closing the loop

Making Motoko's verification loop close on itself: fail-closed at every
enforcement boundary (ADR-001), and rationale that is generated and gated
rather than hand-woven (ADR-002). Evidence from three independent live sessions
(2026-08-29, 2026-08-30, 2026-09-01), the first two ~130 steps each; the third
(53 steps) was run with no task at all, deliberately, to reach surfaces a
targeted task never touches.

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
10. **NOTE-005-third-session-compaction-blind-spot-and-ungated-examples.md** —
    third session (2026-09-01), run with **no task** in order to reach
    surfaces a targeted task would not. Eight findings: compaction silently
    and permanently disabled on the default profile (a missing
    model-catalogue row resolves the context limit to 0, and every consumer
    reads 0 as "healthy"); both shipped `examples/` files broken since the
    ABI-6.0 migration `8df66011` and enumerated by no gate; a session that
    cannot delegate (ExaSearch bridge absent, CodexExec 401, herdr pane
    unusable) and so cannot run its own long gates inside the 35s tool
    ceiling; exit codes masked by pipes; two accumulators that reset
    differently under one `usage` heading; a `make dst` smoke script
    hardcoded outside the FS sandbox (red today, with `DST_KNOWN_RED`
    empty); and — the one that moves a score — a recursive function with a
    **true** contract rejected as "verifier found a counterexample", where
    `verify_core` would call the same condition merely `blocked`.
11. **NOTE-006-harness-compaction-resilience-and-boundary-analysis.md** —
    compaction tiers, the `tool_call_id` invariant, and four boundary limits
    (non-tool flooding, silent synthesis degradation, char/token divergence,
    step-budget wire coupling).
12. **NOTE-007-the-loop-that-would-not-stop.md** — the 197-step herdr runaway
    (2026-09-01) and the `repetition_guard` that now breaks it (rule B:
    restated prose ≥200 chars, deny at step 31 of 197 on replay).
13. **NOTE-008-fourth-session-long-demo-uncatalogued-model.md** — fourth
    session (2026-09-03): long read-only demo under uncatalogued model
    `openrouter/meta/muse-spark-1.3`. Confirms NOTE-005 finding 1 is steady
    state (limit 0, compaction blind, `usage_pct: 0` at ~230k real tokens);
    measures tour cost (~8.2M input / 70 steps, ~96% cache reads);
    `progress_contract_guard` firing on assessment-shaped prose;
    interactive `make run` exceeding the tool ceiling.

## The one-paragraph state

The concept is proven (cells refuse unverified code; telemetry is honest; three
sessions agree on the numbers). The gaps are structural, not hypothetical:
fail-open boundaries (PLAN-001), a verification tier whose highest automatic
rung excludes the core's own idiom — folds — for a reason that turns out to be
gate ordering, not fragment limits (NOTE-002), a comprehension layer that
only gates have ever kept truthful (ADR-002), and — from the taskless third
session — whole subsystems that were never switched on and whose absence
renders as health: context measurement, the `examples/` set, and delegation
itself (NOTE-005). NOTE-005 finding 6 adds the failure in the *opposite*
direction — a verification surface that accuses correct code of being wrong,
which is the one that sends an agent rewriting what already worked. Fail-closed
is the right rule, but it has to be able to say "I could not decide" as loudly
as "this is broken". Every fix named here reuses a pattern the repo already
runs in production.
