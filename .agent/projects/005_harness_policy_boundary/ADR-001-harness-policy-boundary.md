# ADR-001: The harness policy boundary — finalize/pre-step policy belongs in extensions; core keeps mechanism + safety-floor invariants

Date: 2026-07-10
Status: Proposed
Pinned toolchain: AILANG **v0.26.0**; `ailang.lock` → `ailang_version: "v0.26.0"`
Grounded at: branch `arniwesth/mot-35-fix-context-size-estimation`, HEAD `66a4ecb`

Relates to:
- `../../issues/silent-empty-stop-finalize.md` — the motivating failure (a session that
  finalized silently on an empty model response) and the guard-as-extension proposal. This ADR
  is the decision record for that proposal's boundary question.
- `../../issues/ephemeral-compaction-and-ai-noop-thrash.md` — the compactor-strategy problems
  that gutted the context which drove the empty stop. **Out of scope here** (compaction is
  already correctly extension-resident; its *strategy* fixes are a separate decision).
- `../001_DST/ADR-003-harness-boundary-dst-regrounded-on-system-prompt-materialization.md` —
  uses "harness boundary" for a **different seam**: the AILANG-core ↔ TS-host process boundary
  where the system prompt / tool schemas are materialized into the provider request. This ADR is
  scoped explicitly against that: here "boundary" means the **extension/policy seam** (the
  `ExtensionHooks` ABI), not the process/request-materialization seam. See §Scope.
- `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` — the phase-oriented core (pure
  step machine returning decisions-as-data; driver owns effects; compaction policy is
  extension-resident, operator decision **D9**). This ADR extends D9's "policy is
  extension-resident" principle from compaction to **finalize/pre-step guards**.
- `../004_phase_core_refactor/NOTE-harness-spawn-boundary-in-core-policy-vs-mechanism.md` — the
  policy-vs-mechanism split for the spawn boundary ("move the *policy*, not the *mechanism*").
  This ADR applies the same split to the finalize gate.
- `packages/motoko-ext-abi/types.ail` — the `ExtensionHooks` interface and the decision types
  (`FinalizeDecision`, `PreStepDecision`, `ToolPolicyDecision`) that **are** this boundary in code.

---

## TL;DR

**Decision.** Behavioral policy at the harness's per-step decision points — finalize ("should
this stop be honored?"), pre-step (compaction), tool approval, response intercept — lives on the
**extension** side of the `ExtensionHooks` ABI. The **core** keeps only (a) the *mechanism* — the
step loop, provider/tool dispatch, and the act of invoking each hook and honoring its returned
decision-as-data — and (b) a small set of **safety-floor invariants** that must hold with **zero
extensions loaded**, chief among them: *an empty-response finalize is never silent.*

Concretely, for the motivating case:
1. The **empty-stop guard** is a new extension implementing `on_solver_candidate`; it returns
   `ContinueWithFeedback(...)` on a blank candidate, with its own bounded budget counted from
   history. **No core change is needed for the reactive behavior** — the seam already exists.
2. Core gains one **policy-free floor**: on an empty `"stop"` finalize (blank content, no tool
   calls) it emits a distinct ledger event so the outcome is observable even when no guard is
   loaded.
3. The existing **persist-nudge** (currently hardcoded coding-task policy in `session.ail` /
   `recovery.ail`) is recognized as policy on the wrong side of the boundary and is slated to
   **migrate** to the same `on_solver_candidate` seam (follow-on, not this ADR's change).

This is the principle that governs the empty-stop guard, the persist-nudge migration, and every
future finalize/pre-step guard. It is **not** the compaction-persistence decision (open;
separate) and **not** the affine token-calibration change (already shipped on this branch).

---

## Context

Three live `make live_qwen36_compaction_heavy_headless` runs (model
`openrouter/qwen/qwen3.6-35b-a3b`) drove this out:

1. A calibration bug made the compactors over-fire; the context was elided to `keep_last=3`
   stubs (~650 of 655 messages) and the reasoning model, handed an incoherent context, returned
   `finish_reason: "stop"` with **empty content and no tool calls** at step 96. The step machine
   treats any `"stop"` as `Finalize({reason:"model_stop", output: last_response_text})`, so the
   run ended with `done{output:""}` — a clean, silent, empty "success" (`silent-empty-stop-finalize.md`).
2. Investigating the finalize path surfaced that **there is no empty-response guard anywhere** in
   `session.ail` / `step_machine.ail`, and the one mechanism that could catch a premature stop —
   the persist-nudge — is (a) disabled by default (`MOTOKO_PERSIST_RETRIES=0`), (b) gated on
   `not any_writefile_attempt(...)` with a hardcoded *"use the WriteFile tool to save your
   solution"* message (`recovery.ail:48`), i.e. coding-task-specific, and (c) aimed at the wrong
   symptom (lazy prose, not empty output).
3. The finalize gate **already exposes an extension seam** built for exactly this decision:
   `on_solver_candidate(ctx, candidate) -> FinalizeDecision`
   (`packages/motoko-ext-abi/types.ail:159`), where
   `FinalizeDecision = Accept(string) | ContinueWithFeedback(string) | NoDecision` (`types.ail:133`).
   `ContinueWithFeedback(msg)` means "don't finalize — inject `msg` and continue"; core already
   loops on it (`ContinueWithFeedback` → `solver_feedback` finish_reason → `InjectUserMessage` →
   next model call, `session.ail:1819`). `merge_finalize_decisions` gives `ContinueWithFeedback`
   precedence over `Accept` over `NoDecision` (`ext/runtime.ail:314`).

So the reactive fix requires **no new core mechanism**; the only real question is *where the
policy lives*. That is a boundary decision, which is why it belongs in an ADR rather than
straight in a plan.

## The boundary

"Harness" = the runtime that turns a token-emitting model into an agent: `c2_loop`
(`session.ail`), the pure `decide` (`step_machine.ail`), tool dispatch, provider calls,
compaction, the finalize gate, ledger/telemetry. The **policy boundary** is the line between:

| **Core mechanism** (invariant machinery) | **Policy / behavior** (pluggable) |
|---|---|
| The step loop, provider/tool dispatch | *Whether/how* to compact |
| *Invoking* pre-step and finalize hooks and honoring the result | *Whether* an empty stop should continue, and with what message |
| The decision **types** (`FinalizeDecision`, `PreStepDecision`, `ToolPolicyDecision`) | *Which* decision to return at each hook |
| Safety/observability invariants (emit a ledger event; never silently finalize) | Tool-approval rules; nudge budgets; summarization strategy |

In code, **this boundary is the `ExtensionHooks` interface** (`packages/motoko-ext-abi/types.ail`):
`on_pre_step`, `on_solver_candidate`, `on_tool_policy`, `on_tool_handle`,
`on_response_intercept`, `on_build_system_prompt`, `on_budget_plan`, `on_describe_tools`. Core
owns *when* a decision point is reached and *that* the returned decision is honored; the
extension owns *what* the decision is.

Compaction is already on the correct (extension) side — `compaction_ai` /
`compaction_structural` implement `on_pre_step` and return `PreStepDecision`. That is the model
for where the finalize/pre-step guards belong. The persist-nudge is the counter-example: the same
*shape* of decision, but baked into core.

## Decision

**D1. Finalize/pre-step behavioral policy is extension-resident.** New guards at these decision
points are implemented as extensions against `ExtensionHooks`, not added to `session.ail` /
`step_machine.ail` / `recovery.ail`. The empty-stop guard is the first instance: an extension
`on_solver_candidate` that returns `ContinueWithFeedback(...)` when the candidate is blank.

**D2. Loop-safety/budget for a guard lives in the guard.** A guard that always continues on
empty would spin forever. The budget is the guard's own concern and is stored the same way
persist-nudge stores it today: count the guard's marker messages in `ctx.history_slice` and cap
at N. The transcript is the state; core adds no counter.

**D3. Core retains exactly two things at this boundary.**
   (a) *Mechanism*: the hooks, the decision types, invoking the hook chain at each decision
   point, and honoring the merged decision (all already present).
   (b) *A safety floor that does not depend on any extension being loaded*: **an empty-`stop`
   finalize (blank content, no tool calls) must never be silent.** Core emits a distinct ledger
   event (e.g. `EmptyStopFinalize`) and/or marks `run_summary` at that point. This is a
   policy-free observability invariant — ~one event emission, no task-specific logic — so a
   profile with **no** guard extension still fails *loud*, not silent.

**D4. The persist-nudge migrates to this seam (follow-on).** The hardcoded, WriteFile-specific
persist-nudge in `session.ail:1828-1857` / `recovery.ail:44-55` is policy on the mechanism side.
It is reimplemented as a coding-task guard extension on `on_solver_candidate` and removed from
core. Not part of this ADR's immediate change; tracked as a follow-on plan.

## Alternatives considered

- **Put the empty-stop guard in core** (mirror persist-nudge). Rejected: it repeats the exact
  mistake this ADR names — task-specific policy accreting in a 2455-line `session.ail`, invisible
  to composition, un-swappable per profile. The seam already exists; using it costs less.
- **Just raise `MOTOKO_PERSIST_RETRIES`.** Rejected: persist-nudge is coding-specific in gating
  and message, and targets lazy-prose, not empty output. It cannot express "continue this
  research task" and would inject a nonsensical "write a solution file" nudge.
- **Do nothing (accept empty stops as success).** Rejected: the failure is silent — no error, no
  signal — and recurs whenever context degrades or a provider hiccups. Even without a guard,
  D3(b) makes it observable.
- **Push *everything*, including the safety floor, into an extension.** Rejected: safety that
  depends on an extension being present in `extensions.order` is not safety. "Never silently
  finalize" must hold with zero extensions, so it stays a core invariant (mechanism), while the
  *reaction* (retry/nudge/continue) is policy (extension).

## Consequences

Positive:
- One reusable principle governs the empty-stop guard, the persist-nudge migration, and future
  guards; `session.ail` stops accreting task-specific policy.
- Profiles compose the guards they want (`extensions.order`); different task shapes (coding vs
  research) get different finalize policies without core edits.
- The reactive change needs **no** new core mechanism; only the thin floor is new.

Negative / costs:
- "Loaded-ness" risk: a guard only protects when it is in the profile. Mitigated by D3(b) (loud
  even when unloaded) and by making the empty-stop guard part of the default profile order.
- One more extension in the chain; `on_solver_candidate` ordering across multiple finalize hooks
  is registry-order via `first_continue` (`ext/runtime.ail`) — predictable, but must be
  documented when >1 finalize guard is active.
- Small core change for D3(b) (a new ledger event) touches the finalize path and the event
  schema; needs a golden/DST update.

## Scope

**In scope:** the *policy boundary* = the `ExtensionHooks` ABI seam; specifically finalize
(`on_solver_candidate`) and, by the same principle, pre-step / tool-policy / response-intercept
guards.

**Explicitly not** the process/request-materialization boundary of `001_DST/ADR-003` (AILANG core
↔ TS host, system-prompt/tool-schema materialization). Both are "what the harness owns and
guarantees vs what flows through it," but they are different seams; this ADR does not touch the
process boundary.

## Non-goals

- **Compaction-persistence decision** (ephemeral re-compaction vs persist-into-history vs
  result-based tier selection) — a real, open fork tracked in
  `ephemeral-compaction-and-ai-noop-thrash.md`. It is a *strategy* decision for an
  already-extension-resident concern, not a boundary decision. Deliberately left undecided here.
- **Affine token calibration** — already shipped on this branch (`src/core/compaction.ail`
  `affine_calibrate` / `delta_token_density_permille`, mirrored in the compaction extensions).
  Rationale belongs in the calibration NOTE, not this ADR.
- **Provider-hang / timeout handling** — separate concern (`free-tier-hang-no-timeout.md`).

## Open questions

- **OQ1.** Does `on_solver_candidate`'s `ctx` expose enough to detect "empty stop" precisely? The
  hook receives the candidate *text* and is only reached when the model wants to stop (no tool
  calls), so blank text ⟺ empty stop — believed sufficient, to be confirmed when the guard is
  built.
- **OQ2.** Default-profile inclusion: should the empty-stop guard ship in the default
  `extensions.order`, or be opt-in with only the D3(b) floor on by default? (Leaning: floor
  always; guard in default order.)
- **OQ3.** Should D3(b)'s event also carry the calibrated/actual context-window sizes at finalize,
  to make "died because context was gutted" self-diagnosing?

## Follow-on (to be authored fresh, bridged by HANDOFFs from the authoring session)

- `PLAN-empty-stop-guard.md` — the guard extension (blank-candidate detection + history-counted
  continue budget via `on_solver_candidate`) **plus** the D3(b) core safety-floor event.
- `PLAN-persist-nudge-migration.md` — move the persist-nudge from core to a coding-task guard
  extension on the same seam (D4).
- (Separate project/issue) the compaction-persistence decision, once made.
