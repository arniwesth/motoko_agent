# Handoff: write the Phase C implementation plan

Date: 2026-07-03 (post-Phase-B; written by the Phase-B plan-authoring/review session)
Audience: a fresh agent session. You are deliberately fresh — same reasoning as
`NOTE-plan-authoring-session-choice.md`, applied for the third time and stronger than ever:
Phase B rewired every emission site and the whole compaction seam in the files Phase C
inverts, so any prior session's line-number knowledge is stale by construction. Your
freshness is again a test: **if you cannot produce this plan from the committed documents
plus the Phase B commits, the ADR has a gap — report it in an "ADR gaps found" section,
don't guess around it.**

## Mission

Write `PLAN-phase-c-full-inversion.md` in this directory: the implementation plan for
**Phase C only** of `ADR-001-phase-oriented-core.md` — pure `decide`, driver executes
decisions, scripted ports supersede `run_v2_with_stub`, the scripted TUI approval scenario,
and the L1 scenario family. Do NOT plan ABI v3 / conformance kit / `compaction_ai` v0.3.0
(parallel track). Do NOT start implementing.

## Reading order

1. `ADR-001-phase-oriented-core.md` — normative. The Phase C deliverables + gate are your
   acceptance criteria; Decision detail 5 (module split + approval protocol contract) and
   Decision detail 4's D7 checkpoint mechanics are the design you are sequencing. Read
   **both** dispositions logs (G1–G8, G-B1–G-B7) — settled, not yours to re-litigate.
2. **The Phase B as-built commits** — `fd933b6..a9616ad` (WI-0 … WI-8, 13 commits) — and
   `NOTE-phase-b-implementation-findings.md`. The diffs are the ground truth for Phase B's
   real shape; the findings note **supersedes parts of the plan and one ADR disposition**
   (see residuals). Record any plan-vs-as-built deviations you find in your grounding
   section, as `PLAN-phase-b-phase-results.md` did for Phase A.
3. `PLAN-phase-b-phase-results.md` — house style to follow; its D-B1–D-B10 decisions
   (especially **D-B1**, which enumerates exactly what was deferred to you and why); its
   per-WI parity protocol (D-B7) is the discipline your plan inherits. Its line anchors
   are **pre-implementation — do not reuse a single one.**
4. `RESEARCH-phase-core-dst-design.md` — §2 (P1 decisions-as-data, P2 ledger-as-trace,
   P3 ports), §5 (residual-logic homes), §7.3/§7.4 (scenario coverage + checkpoint seam),
   §11 facts (esp. 13, 17 — sealing/co-location rules the module split depends on).
5. `sketch/sketch_vocabulary.ail` + `sketch/probe_consumer_decide.ail` — the proven
   `decide` re-derivation (`CallModel → RunTools → Finalize` from applied state) and the
   separate-module-consuming-wrappers proof. Re-run before relying.
6. `NOTE-ailang-run-exit-code-false-alarm.md` — the measurement discipline (pipefail,
   minimal repro before defect claims, never `$?` through a pipeline).

## Non-negotiable discipline

- Re-verify **every** citation against post-Phase-B HEAD (`a9616ad` or later);
  `git log --oneline -20` first. Re-run before relying on: `make smoke_parity` (against
  the blessed baseline — find where WI-8 left it), the Phase B projection gate script,
  `ailang test src/core/phase_vocab.ail`, and the sketch probes if you lean on sealing or
  re-derivation claims.
- Toolchain pin is v0.26.0 / `3b52a24`; if `ailang --version` disagrees, STOP and flag.
- Every source claim in YOUR plan carries a `file:line` you verified yourself at HEAD.
- A substrate-defect claim requires a minimal repro before it enters the plan.

## Phase C deliverables (from the ADR — re-read it; summary, not substitute)

1. **Pure `decide`** in a separate `step_machine.ail` (consumes exported wrappers; sealing
   holds transitively — fact 17) with **all** loop policy: budget/cost caps, stream-retry,
   persist-nudge, DP7 gating, compaction-exhaustion → `Fail`, checkpoint policy (which in
   v1 **never** emits `TakeCheckpoint` — enforced by scenario).
2. **Driver executes decisions** — the D5 module split (`model_phase`, `tool_phase`,
   `hook_phase` returning `PhaseResult`; `tool_stream_phase` island; `session.ail` driver
   owning the real effect row and sole emission; `recovery`/`cost_phase` pure), with the
   residual-logic homes of §5 (hybrid-bash → response interpreter; scratchpad dispatch →
   executor registry; mid-dispatch `readLine` → `AwaitApproval`).
3. **Scripted ports supersede `run_v2_with_stub`** — the `StepProvider` pattern
   generalized per P3; config/env reads once at init into `StepPolicy`; clock into
   `StepState`.
4. **The approval protocol inversion** — `AwaitApproval(ApprovalRequest)` with the
   Decision detail 5 contract (event-before-read, `PolicyDefault` on EOF/unparseable,
   suspended `remaining` tail re-issued as `RunTools`), gated by the **scripted TUI
   approval scenario**.
5. **The L1 scenario family** under `--caps IO` or less, no network:
   `provider_payload_vs_uncompacted_history_pressure`, `ext_compaction_invalid_rejected`,
   `summary_cache_replay_stable`, `history_rewrite_requires_checkpoint_event`,
   `checkpoint_never_emitted_in_v1`, `checkpoint_output_is_valid_transcript`, plus the D9
   chain scenarios (`compactor_chain_order_is_registry_order`,
   `invalid_stage_skipped_chain_continues`, `zero_compactors_exhaustion_behavior` — check
   what WI-6/WI-7's chain smoke already covers before duplicating).
6. **Checkpoint mechanics become real** — the scenarios above consume digests, so the D7
   content-hash digest, previous-digest chaining, atomic `apply_checkpoint`, and
   `history_from_seed` chain validation are due here (they were explicitly deferred as
   labeled placeholders; D-B6 says the content-hash replaces `payload_digest`'s label
   too). Expect a substrate probe: no vetted hash primitive has been identified in this
   repo's AILANG usage.

**Gate (from the ADR, re-read the exact wording):** L1 scenarios pass under minimal caps
with no network/Ollama/OpenRouter (core DST gate class); every DST failure prints scenario
id, first failed invariant, and normalized trace. Plus the inherited instrument: the parity
harness must remain green or carry expected-diff tables per the D-B7 protocol — Phase C
changes control flow, so **event ordering** is the parity risk, not event shape.

## Session residuals worth having (things the docs underemphasize)

- **D-B1's deferral is your core work item.** In Phase B, `loop_v2` *is* the driver: tool
  events are constructed-and-emitted in place inside the dispatch recursion **because**
  `tool_pending` must precede the `readLine()` block. The `AwaitApproval` inversion is
  what unblocks full `PhaseResult` batching for the tool phase — sequence it that way.
  `ApprovalRequest` (with `default_allow`, `stream_id`, `remaining`) already exists in
  `phase_vocab`.
- **There is no in-memory ledger yet.** `ledger_emit` projects typed events straight to
  JSONL. P2's L1 invariants consume typed events *in memory* — Phase C must introduce
  that layer, and G-B1's disposition says pass-through stage records (`StagePassed`)
  arrive with it.
- **The findings note supersedes ADR G-B7 in part.** The path-dep probe passed from
  outside the root package, but root registration hit a MOD011 module-namespace collision
  (mirrored `src/core/compaction` vs. the root's own), so
  `motoko_ext_compaction_structural` **vendors a self-contained measurement helper** —
  the D9 anti-duplication goal is only partially met in-repo. Known discrepancy, owned by
  the ABI track (published `motoko_core`); report it in your grounding, don't re-derive
  or try to fix it in Phase C.
- **`run_v2_with_stub` supersession has a large blast radius**: the entire parity smoke
  fleet and harness are built on it. Your plan must state how the harness migrates
  (strangler: the stub entry probably survives as a thin adapter over scripted ports
  until the fleet converts) — killing it in one step would orphan the gate instrument.
- **`validate_compactor_output`'s pair-preservation arm has history**: it shipped
  narrowed in WI-5 after a false rejection, and WI-6 fixed the real cause (validation
  against the shrinking recursion tail instead of the full output). Read the findings
  note + the WI-6 diff before touching the predicate; the conformance kit will import
  these functions later.
- **The re-derivation fields exist**: `StepState` already carries `pending_tool_calls`,
  `last_finish_reason`, `last_response_text` (the P3-R3 fix) and the sketch's `decide`
  drives `CallModel → RunTools → Finalize` from applied state. Seed `step_machine.ail`
  from the sketch the way Phase A seeded `phase_vocab`.
- **Ports parser constraints** (research §4, proven): zero-arg anonymous `func()` does
  not parse; anonymous `func` cannot sit directly in record literals — port
  implementations are named funcs or let-bound lambdas.
- **An implementation session summary exists** at
  `.agent/summaries/2026-07-03-phase-b-phase-results-implementation.md` — read it if
  committed; it is the implementer's own account and may carry residuals the findings
  note compresses.

## Plan output contract

House style per the three prior plans (`PLAN-phase-b-phase-results.md` is the closest
model). Must include: ordered WIs with file-level change lists, per-step verification
commands, per-step rollback, the gate checklist as the final step; a grounding section
recording Phase-B plan-vs-as-built deviations; an "ADR gaps found" section (empty is a
valid finding); an explicit out-of-scope list (ABI v3, conformance kit, `compaction_ai`
0.3.0, registry publication of the structural package); the toolchain you verified
against; and an anchor re-verification log. Strangler discipline: every WI leaves the
system shippable and `make smoke_parity` explicable (identical, or a committed
expected-diff table per D-B7).

## Constraints

- D1–D9, G1–G8, G-B1–G-B7, and the Phase B plan's D-B1–D-B10 are settled. Contradictions
  between documents and HEAD are findings, not license to redesign.
- One plan per phase; Phase C is the last core phase — resist absorbing ABI-track work.
- Do not modify the ADR, research doc, sketch, or prior plans. Your plan is a new file.
