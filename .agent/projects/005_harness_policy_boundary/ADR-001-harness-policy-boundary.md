# ADR-001: The harness policy boundary — finalize/pre-step policy belongs in extensions; core keeps mechanism + safety-floor invariants

Date: 2026-07-10
Status: Proposed
Amended by: Amendment 1 (2026-10-09, proposed): pre-finalize verification (DP7) leaves core.
See [Amendments](#amendments).
Pinned toolchain: AILANG **v0.26.0**; `ailang.lock` → `ailang_version: "v0.26.0"`
Grounded at: branch `arniwesth/mot-35-fix-context-size-estimation`, HEAD `66a4ecb`

Relates to:
- `../../issues/silent-empty-stop-finalize.md` — the motivating failure (a session that
  finalized silently on an empty model response) and the guard-as-extension proposal. This ADR
  is the decision record for that proposal's boundary question.
- `../../issues/ephemeral-compaction-and-ai-noop-thrash.md` — the compactor-strategy problems
  that gutted the context which drove the empty stop. **Out of scope here** (compaction is
  already correctly extension-resident, and ephemeral-by-design; its *strategy* fixes are a
  separate PLAN, not a decision — see Non-goals).
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
extensions loaded**, chief among them: *an empty-response finalize is never mistaken for a
substantive completion.*

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

Surfaced across live `make live_qwen36_compaction_heavy_headless` runs (model
`openrouter/qwen/qwen3.6-35b-a3b`); three findings drove this decision:

1. **The failure.** In session `2026-07-09T20-16-49-594Z`, a compactor calibration bug made the
   compactors over-fire; the context was elided to `keep_last=3` stubs (~650 of 655 messages) and
   the reasoning model, handed an incoherent context, returned `finish_reason: "stop"` with
   **empty content and no tool calls** at step 96. The step machine treats any `"stop"` as
   `Finalize({reason:"model_stop", output: last_response_text})`, so the run ended with
   `done{output:""}` — reading as a clean, empty "success" (`silent-empty-stop-finalize.md`).
   The subsequent affine-calibration fix removed *this instance's* trigger: a later run
   (`2026-07-09T20-50-38-105Z`) did **not** reproduce the empty stop, yet still gutted the context
   to ~13K tokens / 371 messages before being stopped manually at step 127. So the silent-finalize
   gap is **independent** of the (now-fixed) calibration cause — any future context degradation,
   provider hiccup, or reasoning stall re-triggers it.
2. **The gap.** Investigating the finalize path surfaced that **there is no empty-response guard
   anywhere** in `session.ail` / `step_machine.ail`, and the one mechanism that could catch a
   premature stop — the persist-nudge — is (a) disabled by default (`MOTOKO_PERSIST_RETRIES=0`),
   (b) gated on `not any_writefile_attempt(...)` with a hardcoded *"use the WriteFile tool to save
   your solution"* message (`recovery.ail:48`), i.e. coding-task-specific, and (c) aimed at the
   wrong symptom (lazy prose, not empty output).
3. **The seam already exists.** The finalize gate **already exposes an extension seam** built for
   exactly this decision:
   `on_solver_candidate(ctx: ExtCtx, candidate: string) -> FinalizeDecision`
   (`packages/motoko-ext-abi/types.ail:159`), where
   `FinalizeDecision = Accept(string) | ContinueWithFeedback(string) | NoDecision` (`types.ail:133`).
   The `candidate` passed is the raw model output — `result.message.content`
   (`session.ail:1800`) — so a blank candidate ⟺ an empty stop.
   `ContinueWithFeedback(msg)` means "don't finalize — inject `msg` and continue"; core already
   loops on it (`ContinueWithFeedback(feedback)` → emit `ExtSolverFeedback` → `solver_feedback`
   finish_reason → next `c2_loop` with the feedback injected, `session.ail:1803-1826`).
   `merge_finalize_decisions` gives `ContinueWithFeedback` precedence over `Accept` over
   `NoDecision` (`ext/runtime.ail:314`).

The hook is reached on a stop path (`finish_reason != "tool_calls"`) once two other extension
seams decline: `on_response_intercept` returns `NoIntercept`, and — with `hybrid: true`, as the
qwen profile sets — hybrid bash extraction finds no fenced command (`session.ail:1799-1800`). An
**empty** response has no bash fence and nothing to intercept, so it reliably reaches
`on_solver_candidate`. Both *finalize* routes downstream of that hook — `Accept(output)` and the
`NoDecision`-with-no-nudge fall-through — converge on `c2_after_dp7(...)` (`session.ail:1802`,
`1858`), which is the single choke point where the run actually ends.

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
   finalize (blank content, no tool calls) must never be indistinguishable from a substantive
   completion.** Today it is — the run ends with `done{output:""}` and a `finish_reason:"stop"`
   `run_summary`, i.e. present in the log but reading as an ordinary success. Core emits a distinct
   ledger event (e.g. `EmptyStopFinalize`) and/or flags `run_summary` at the finalize choke point
   (`c2_after_dp7`, where both routes converge — see Context 3), so a profile with **no** guard
   extension still ends *loud*, not as a silent empty success. This is a policy-free observability
   invariant — a ledger emission at one convergence point, no task-specific logic.
   This floor is also the backstop for D2: when a guard's continue-budget is spent it returns
   `NoDecision`, and the eventual empty finalize is then made observable by D3(b) rather than
   slipping through silently.

**D4. The persist-nudge migrates to this seam (follow-on).** The hardcoded, WriteFile-specific
persist-nudge in `session.ail:1828-1857` / `recovery.ail:44-55` is policy on the mechanism side.
It is reimplemented as a coding-task guard extension on `on_solver_candidate` and removed from
core. Not part of this ADR's immediate change; tracked as a follow-on plan.

## Alternatives considered

- **Put the empty-stop guard in core** (mirror persist-nudge). Rejected: it repeats the exact
  mistake this ADR names — task-specific policy accreting in an already-large `session.ail`
  (~2500 lines), invisible to composition, un-swappable per profile. The seam already exists;
  using it costs less.
- **Just raise `MOTOKO_PERSIST_RETRIES`.** Rejected: persist-nudge is coding-specific in gating
  and message, and targets lazy-prose, not empty output. It cannot express "continue this
  research task" and would inject a nonsensical "write a solution file" nudge.
- **Do nothing (accept empty stops as success).** Rejected: the failure raises no error and is
  indistinguishable from a real completion, and it recurs whenever context degrades or a provider
  hiccups. Even without a guard, D3(b) makes it observable.
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

- **Compaction persistence model** — *not* an open fork. Ephemeral per-step compaction (session log
  unchanged) is a **documented decision**: `design_docs/planned/m-motoko-conversation-compaction.md:52`
  ("the returned `msgs` replaces the input **for this step only**"), consistent with the phase-core
  seed/append-only history. So there is no persistence ADR to write here. The residual compactor
  problems (emergency-tier over-escalation, AI no-op thrash, shadow-vs-sent observability) are
  *strategy* refinements **within** that ephemeral model — extension-side, already covered by
  `ephemeral-compaction-and-ai-noop-thrash.md`, and are **PLAN-level, not a decision**.
- **Affine token calibration** — already shipped on this branch (`src/core/compaction.ail`
  `affine_calibrate` / `delta_token_density_permille`, mirrored in the compaction extensions).
  Rationale belongs in the calibration NOTE, not this ADR.
- **Provider-hang / timeout handling** — separate concern (`free-tier-hang-no-timeout.md`).

## Open questions

- **OQ1 (resolved during review).** Confirmed the guard has what it needs: `on_solver_candidate`
  receives the candidate string (`result.message.content`) and reliably fires on an empty stop
  (no bash fence, nothing to intercept — see Context 3). Detecting "blank candidate" is
  sufficient; no extra `ctx` plumbing is required.
- **OQ2 (false positives).** The guard treats *empty stop* as *premature stop*. That is right for
  almost all agent tasks, but a task can legitimately end with an empty final turn. The cost of a
  wrong nudge is bounded (the continue-budget caps retries, and a genuinely-finished model can
  re-affirm completion in prose on the nudge), so the default leans toward nudging — but the
  message wording and budget should make the assumption cheap to be wrong about. Decide when
  building the guard.
- **OQ3.** Default-profile inclusion: should the empty-stop guard ship in the default
  `extensions.order`, or be opt-in with only the D3(b) floor on by default? (Leaning: floor
  always; guard in default order.)
- **OQ4.** Should D3(b)'s event also carry the calibrated/actual context-window sizes at finalize,
  to make "ended because context was gutted" self-diagnosing?
- **OQ5 (budget durability under compaction).** D2 counts the guard's marker messages in the
  history to enforce its continue-budget. Structural compaction only elides `role=="tool"`
  messages, so `user`/`assistant` markers survive it — but the **AI compactor summarizes old
  `user`/`assistant` turns**, which could fold a marker into a summary and reset the budget,
  letting the guard loop more than intended (ironic, given compaction is the theme). The guard
  must count markers on a view that retains them (full history, not a compacted `ctx.history_slice`),
  use a marker phrase the summarizer is instructed to preserve, or track the count in a durable
  `ctx` field. Resolve when building the guard; note that persist-nudge today counts on the full
  `msgs`, not a slice.

## Follow-on (to be authored fresh, bridged by HANDOFFs from the authoring session)

- `PLAN-empty-stop-guard.md` — the guard extension (blank-candidate detection + history-counted
  continue budget via `on_solver_candidate`) **plus** the D3(b) core safety-floor event.
- `PLAN-persist-nudge-migration.md` — move the persist-nudge from core to a coding-task guard
  extension on the same seam (D4).
- (Separate project/issue) the compaction-persistence decision, once made.

## Amendments

Each amendment cites the artifact that forced it and supersedes the cited text without revising it.

### Amendment 1 (2026-10-09, proposed) — pre-finalize verification (DP7) is finalize policy and leaves core

Status: Proposed. Grounded at `origin/main` `36a96b1e`, AILANG v0.52.5. Line references below are
to that commit.

**Amends** D1, D2, D3 and D4. **On acceptance it also supersedes** stage 2 of the candidate
pipeline in [013 ADR-002](../013_core_architecture_for_dst/ADR-002-park-and-wake.md) D2
(`:337-366`), one sentence of
[031 ADR-001](../031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md) D4
(`:628-629`), the finalization item of
[028 ADR-001](../028_verified_runtime_closing_the_loop/ADR-001-fail-closed-verification-everywhere.md)
(`:28-31`), one control run of 011 ADR-003's gate (ruling 18), and the premise of the
[DP7 design doc](../../../design_docs/planned/m-motoko-dp7-verifier-gate.md) (`:31`).

**Ruling, 2026-10-09 (operator).** The first draft of this amendment moved the verifier into a
guard extension and asked which profiles should ship it (OQ-A6). The operator's answer: none.
There is no scenario in which Motoko's own `make check_core` should be triggered automatically
on a final answer. So the verifier is removed and nothing replaces it. #251 empties the
`verification` block of the eight profiles that enabled it. A1, the consequences, the open
questions and the follow-on below are written to that ruling.

#### The artifact: two sessions that could not finish

| | 2026-10-09 | 2026-10-08 |
|---|---|---|
| Session | `session_1791533149980-980e8a0796dab753` | `session_demo_1791478595_340711` |
| Profile and model | `default`, `openrouter/stepfun/step-5-preview` | `demo_dst`, `openrouter/xiaomi/mimo-v2.6-pro` |
| Verifier rejections | 57, the first at step 106 | 320, at steps 12 to 341 |
| How it ended | The operator interrupted after step 197. The resumed run was rejected ten more times and the log ends there. | After 342 steps the provider refused the next request: 1,052,316 tokens against a 1,050,000 window. |

Both logs are in the shared checkout's `.motoko/logfile/`, which is gitignored. The counts were
computed from the JSONL.

The cause was the same in both. DP7 ran `make check_core` after every non-blank final answer, and
that command cannot pass inside a session: the TUI sets `AILANG_FS_SANDBOX` to the workdir
(`src/tui/src/runtime-process.ts:544`), and the `verify_native_path_guard` target
(`Makefile:2819`) does not clear it. At `36a96b1e` the target exits 0 with the variable unset and
non-zero with it set to the workdir.

In the 2026-10-09 session, from the first rejection to the end:

- The model made 103 calls and read 16.8M input tokens.
- The estimated request grew from 49k to 248k tokens. Most of the growth was verifier output:
  679 KB of it, injected as `user` turns.
- The model identified the cause and said so, and had no action that would end the run. It then
  gave 30 answers that differed only in a running count and, after the interruption, 7 that were
  byte-identical.
- The repetition guard was never called. Its `ToolPolicy` half needs a tool call and these steps
  had none. Its `SolverJudge` half sits behind the verifier, so a rejected candidate never reaches
  it. The log holds 57 `dp7_verifier_rejected` events and no `ext_solver_feedback` event.

#### What core does at this decision point today

| What | Where |
|---|---|
| Runs the profile's `verification.command` in the workdir | `run_dp7_verifier`, `src/core/session.ail:2241` |
| Turns some failures into approvals by substring match on the output | `is_missing_infrastructure`, `session.ail:2231` |
| Runs first, before waits, the extension judges and the persist nudge | `classify_candidate` stage 2, `session.ail:3268-3271` |
| Runs again for a blank candidate the judges approved | stage 5, `session.ail:3298-3305` |
| Owns the feedback text and injects it as a `user` turn | `dp7_rejection_message`, `src/core/step_machine.ail:53-61`, `:130-131` |
| Emits `dp7_verifier_rejected` | `session.ail:2287`, `src/core/phase_vocab.ail:1298` |
| Carries three finish reasons: `dp7_rejected`, `dp7_approved`, `dp7_fail_open` | `step_machine.ail:130`, `:143`, `:149` |
| Counts nothing. A rejection has no budget. | |

Two facts sit beside the table:

- `dp7_gate` (`session.ail:2257`) has no caller.
- `check_core` was widened on purpose so that DP7 would catch more (`Makefile:2564-2568`). It now
  has 15 prerequisite targets (`Makefile:2570`), so the gate judges the health of the whole
  repository on every final answer, whether or not the run wrote any code.

#### Why this is policy on the wrong side of the boundary

The boundary table above puts "*whether* an empty stop should continue, and with what message" on
the policy side. DP7 makes the same kind of decision for a non-empty stop, and makes all of it in
core: which command, when to run it, how to read its result, what to tell the model, and how often
to insist. It also breaks D2, which says a guard that continues must carry its own budget.

The DP7 design doc argued the opposite: "correctness invariants belong in the runtime, not in the
extension system" (`:31`). This amendment rejects that for verification. A check whose content is
a shell command chosen by a profile is not an invariant of the runtime.

The ADR as written in July named only the persist nudge as misplaced policy. It treated
`c2_after_dp7`, where the verifier ran, as the finalize choke point (Context 3).

#### Decision

In this amendment a *continuing guard* is an atom that can return `ContinueWithFeedback`.

**A1. Verification before finalize is finalize policy, and core stops doing it (extends D1).**
Core runs no command at finalize. By the ruling above nothing replaces it: no shipped profile
verifies at finalize, and no verifier guard is built.

If one is ever wanted, it is a guard extension and not a core stage: a `SolverJudge` atom that
runs its configured command and returns `ContinueWithFeedback` with the output when the command
fails. Such a guard has to respect four things:

- It needs no ABI change. `SolverJudge` already carries `{Process}`
  (`packages/motoko-ext-abi/types.ail:1956`).
- A pass returns `NoDecision`, never `Accept`. A passing verifier has no opinion on whether the
  answer is complete.
- The command and the bound are its registration config.
- The feedback states what ran and how it exited, and carries the guard's marker as the other
  guards' feedback does. Core's current text asserts a type error for any non-zero exit, and in
  the 2026-10-09 session the model answered it as if the operator had written it.

**A2. Every continuing guard is bounded (strengthens D2).** A verifier guard, if one is ever
written, is no exception. The bound is derived from the guard's own markers in history, as
`empty_stop_guard` does (`packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:43-47`). When
the bound is reached the guard abstains. D2 described one guard; it is now a rule: a continuing
guard ships a test showing that it stops continuing. Both shipped continuing guards already have
one (`empty_stop_guard.ail:124`, `progress_contract_guard.ail:434`).

**A3. Merge precedence is unchanged, and that is why A2 is required.** `ContinueWithFeedback`
still outranks `Accept` (`src/core/ext/runtime.ail:919-925`; frozen at ABI 8.0 by 031 ADR-001 D4,
`:626`). So the repetition guard's `Accept` cannot end a run while another guard is still
continuing. What ends it is that every continuing guard runs out. Core's verifier never did,
which is how the 2026-10-09 run received 37 consecutive rejections.

**A4. Core's candidate pipeline has no verification stage.** `classify_candidate` becomes
pending, then waits, then completion policy, then finalize. The following leave core:

- `FinalizeVerification`, `is_missing_infrastructure`, `run_dp7_verifier`, `dp7_gate`,
  `Dp7Rejection` and `dp7_rejection_errors` (`session.ail:2218-2299`). The fail-open heuristic
  goes with them.
- Stage 2, the verifier run in stage 5, `CandidateRejected` and `c2_dp7_rejected_state`
  (`session.ail:2964`, `:3219`, `:3268-3271`, `:3298-3305`).
- `dp7_rejection_message` and the `dp7_rejected` arm of `decide`.
- The `dp7_approved` and `dp7_fail_open` reasons, renamed or folded into `stop`.
  `dp7_fail_open` has no producer today (013 ADR-002 `:361-362`).
- Core stops emitting `dp7_verifier_rejected` and stops reading `ExtRuntime.verification`.

Two behaviours change and are intended:

- Every non-blank candidate reaches the extension judges. Under 013 ADR-002 D2 a rejected one
  never did.
- A candidate with open waits parks. Today, with verification enabled and failing, it is
  rejected first (013 ADR-002 `:364`).

**A5. The persist nudge leaves core too (restates D4).** It is the other finalize policy in
`classify_candidate` (`src/core/recovery.ail:40-63`, `session.ail:3288`). After both changes,
stage 4 is `dispatch_solver_candidate` alone and `NoDecision` finalizes.

The plan found that it is not a small move. Its budget is an environment read that recorded
runs and the evaluation's fixtures count, and its counter is threaded through the loop and
resume. Nothing outside tests sets the budget. So the plan makes it a separate workstream and
asks first whether to migrate it, as D4 says, or delete it.

**A6. D3's floor does not grow.** Core gains no counter and no cap for finalize feedback. The step
budget, the cost cap and context exhaustion remain the ceilings against a guard that breaks A2.
The zero-extension floor loses nothing: with no extension loaded and the code default
(`verification.enabled` is false, `src/core/config.ail:505-511`), no verification runs today
either.

#### Alternatives considered

- **Move DP7 into a shipped verifier guard.** This amendment's first draft. Dropped on the
  ruling: no profile would load it.
- **Keep DP7 in core and cap its rejections.** Rejected. It fixes the loop and leaves the command,
  the timing, the wording and the cap as core policy that no profile can swap.
- **Keep DP7 in core and run the judges first.** Rejected. It restores the order before
  `a2113e85`, in which an accepted candidate still went to the verifier and was rejected.
- **Let `Accept` outrank `ContinueWithFeedback`.** Rejected. The precedence is frozen at ABI 8.0,
  and reversing it lets any accepting judge end a run that another guard is still working on.
- **A core ceiling on consecutive finalize feedback.** Rejected for now. How many rounds is too
  many is the judgement D2 gives to each guard. Revisit if a guard from outside this tree breaks
  A2 in practice.
- **Only clear `AILANG_FS_SANDBOX` in the Makefile target.** Needed, and not sufficient. It
  removes this trigger. Any other verifier command that cannot pass recreates the loop.

#### Consequences

Positive:

- The repetition guard and every other judge see every candidate.
- A final answer no longer waits for a command. Once `make check_core` could pass inside a
  session it took 164 s and 183 s on cold caches (#250).
- `session.ail` and `step_machine.ail` lose a stage, three finish reasons and a message.

Costs:

- **Nothing checks the tree before a run ends.** DP7 was added in May after a model shipped three
  hallucinated stdlib names and said it was done (`052d4c2f`). Eight tracked profiles enabled it:
  `ailang`, `default`, `demo_dst`, `dogfood`, `mark`, `observability`, `omnigraph` and `skills`.
  #251 turns it off in all eight. A model that should verify its work has to run the check
  itself.
- **A leftover `verification.enabled: true` must not be ignored silently.** Once core stops
  reading the block, the plan makes a profile that still sets it fail loudly at startup.
- **Tests go.** `scripts/smoke_v2_dp7_gate.ail` (the only executable coverage of this path,
  `Makefile:2458`), the four `w2_dp7_*` scenarios in `scripts/dst/phase_c2_wiring_scenarios.ail`,
  and the `decide` tests that name the three reasons (`step_machine.ail:348-397`, `:534-610`).
- **The corpus gate loses the branch one of its controls walks.** 011 ADR-003 ruling 18 added a
  `verifier-rejection` control run (`scripts/dst/corpus_judge_dst.ail:881-990`). The plan replaces
  it with a control on the solver-feedback branch, or drops it, on the operator's word.
- **Old wire logs still carry `dp7_verifier_rejected`.** The session journal never held it, so
  resume is unaffected, and nothing in the tree reads an old wire log against the event
  vocabulary. The variant can be deleted outright.
- **`ExtRuntime.verification` is exported by the ABI package** (`types.ail:2033-2037`). Core stops
  reading it at once. Whether the field can be dropped within 8.x or waits for 9.0 is for the plan
  to establish under the ABI header's rule.

One gap outlives the verifier. `src/tui/src` has no handler for `dp7_verifier_rejected` or for
`ext_solver_feedback`, which is why the 2026-10-09 transcript shows only the model repeating
itself. The other guards' feedback is as invisible to the operator. That is a separate change.

#### Text superseded in other records, on acceptance

| Record | Text | What replaces it |
|---|---|---|
| DP7 design doc `:31` | "correctness invariants belong in the runtime, not in the extension system" | A1 |
| 013 ADR-002 D2 `:337-366` | Stage 2, "moves DP7 ahead of solver dispatch", and the cross-product cases that name a DP7 rejection | A4 |
| 031 ADR-001 D4 `:628-629` | "Host permissions and deterministic verification remain authoritative" | Host permissions are untouched. Verification is no longer a host stage, and nothing ships one. |
| 028 ADR-001 `:28-31`, and item 1 of its PLAN-001 | `run_dp7_verifier` fails closed, and "make the gate non-configurable for shipped profiles" | A1 and the ruling. There is no gate left to make fail-closed. 028's other two boundaries are untouched. |
| 031 ADR-001 freeze evidence, item 6 `:1154` | "Composition with DP7" | Dropped. There is nothing to compose with. |
| 011 ADR-003 ruling 18 (`:484`) | The `verifier-rejection` control run | A control on the solver-feedback branch, or nothing. The plan's decision 1. |
| `SYSTEM.md:128` | "The runtime will not catch this for you — that gate is on the roadmap" | The runtime does not check this. The rule above it, that the model runs the check when it has modified AILANG source, stays. |

#### Non-goals

- **The Makefile fix.** #250 clears the variable in the recipe. It is independent of this
  amendment and can merge first.
- **Near-duplicate matching in the repetition guard.** Its exact-text rule would not have matched
  the 30 answers that differed only in a count. That is guard strategy and PLAN-level.
- **The unknown context limit** that kept compaction off in the 2026-10-09 session.

#### Open questions

- **OQ-A5 (`VerificationEvidence`).** 031 ADR-001 D3 defines it as the host's report of its
  verifier run (`types.ail:631-646`). No production call site fills it; `session.ail:1955` and
  `:5089` pass `NotReached`. After this amendment the host has no verifier run to report. Whether
  the field stays `NotReached`, becomes `Disabled` or is retired is 031's to settle.

Closed on 2026-10-09:

- **OQ-A6 (which profiles ship a verifier).** None, by the ruling. #251.
- **OQ-A1 to OQ-A4 (a verifier guard's bound, its outcome when the bound is spent, when it runs,
  and its command's environment).** Not answered. They were questions about a guard that is not
  being built, and return only if one is written.

#### Follow-on

- [`PLAN-finalize-policy-migration.md`](PLAN-finalize-policy-migration.md), written with this
  amendment. Workstream W1 removes the verifier: the removals in A4, the startup refusal for a
  leftover `verification.enabled`, the system prompt's sentence, and the edits to the records in
  the table above. Workstream W2 is the persist nudge and waits on two decisions. The plan
  replaces the unwritten `PLAN-persist-nudge-migration.md` listed above.
