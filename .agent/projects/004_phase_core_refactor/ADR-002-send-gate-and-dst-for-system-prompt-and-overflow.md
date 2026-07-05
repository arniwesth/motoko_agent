# ADR-002: The single send-gate and DST scenarios for the system-prompt and payload-overflow bug classes (PR #75 / #76)

Date: 2026-07-05
Status: Proposed
Pinned toolchain: AILANG **v0.26.0** (commit `3b52a24`); `ailang.lock` → `ailang_version: "v0.26.0"`

Relates to:
- `ADR-001-phase-oriented-core.md` (this project) — the phase-oriented core this ADR builds on.
  ADR-001 is normative for the architecture; this ADR refines its "single transcript gate"
  and "single logical emission authority" principles against the **live** control flow that
  Phase C actually shipped, and adds the two DST scenarios that turn PR #75/#76 into standing
  regression law. Citations to it are by section.
- PR **#76** (`fix(harness): serve the system prompt reliably`) and PR **#75**
  (`fix(compaction): reliable triggering`) — the two production incidents that motivated the
  core rewrite. This ADR is the DST expression of their bug classes.

---

## TL;DR

**Decision:** enforce both the empty-system-prompt bug class (#76) and the payload-overflow bug
class (#75.2) at **one function** — `seal_compacted_payload` (`src/core/phase_vocab.ail:131`),
which the live loop calls **unconditionally on every model step**
(`src/core/session.ail:1402`). Give `seal` a **typed error** (`SealError`) so an empty prompt
surfaces as a distinct `SystemPromptEmpty` failure rather than being mislabeled as context
exhaustion; carry `system_prefix_chars` (not just count) on the provider-call event so a
*present-but-empty* system message is visible; gate the refusal on a `require_system_prompt`
`StepPolicy` flag (default `true`). Land two Layer-1 scenarios: `empty_system_prompt_rejected`
(new teeth for #76) and `oversized_payload_rejected` (a regression guard for #75.2 — expected
green, because the rewrite already prevents the overflow).

The two compaction-*policy* sub-bugs of #75 (chars/4 over-count → thrash; dead cloud
summarizer) are **not** core scenarios — under ADR-001 D9 they are compactor-extension
policy and belong in the conformance kit. This ADR scopes only the core send-gate.

---

## Context

Both incidents are the same failure class: **a silent divergence between the payload the model
was actually served and the payload the code believed it served, invisible because nothing
observed the served payload.**

- **#76**: `SYSTEM_MD` was scrubbed by the host subprocess env allowlist
  (`runtime-process.ts`), so the AILANG side built a **0-char** system prefix and called the
  model with no harness instructions and no language reference. It stayed hidden for days
  because the served system prompt was never logged (`chars=0` was reported nowhere).
- **#75**: the char-based token estimate diverged from the provider's actual `input_tokens`
  (~1.9×), so compaction fired against a fictional number — premature elision → re-read thrash;
  and a single large tool *result* on top of an already-large context could push the payload
  past the window in one step (overflow > 262144). The AI summarizer, defaulted to an
  unreachable cloud model, silently never ran.

ADR-001 already commits to the structural answer: one gate builds the provider payload, one
authority emits a typed ledger event describing it, and DST invariants assert over that event.
This ADR pins **which** function is that gate in the shipped Phase C code, and closes the two
gaps that let #76 still slip through it.

## Investigation findings (grounded against the live loop)

The live entrypoint is `rpc.ail:239` → `agent_loop_v2.run_v2_with_conversation`, which is now a
thin shim delegating to `src/core/session` (`agent_loop_v2.ail:15,71`). The live loop is
therefore session's `c2_loop`. Tracing its `CallModel` handler
(`session.ail:1391`) established three facts that redirect the fix from where ADR-002's first
draft aimed it:

1. **`seal_compacted_payload` is the single, unconditional send-gate.** The handler runs
   `split_for_compaction → dispatch_pre_step_chain → seal_compacted_payload`
   (`session.ail:1394-1402`) for **every** model call, not only under pressure. `seal` gates on
   the **actual constructed payload** — `usage_percent_with_limit(split.pinned ++ chain_msgs,
   limit) >= exhaustion_pct()` (`phase_vocab.ail:133-135`). Consequently **the #75.2 overflow
   is already structurally prevented on the live path.**

2. **`project` is vestigial for the payload and for observability.** `decide` calls `project`
   (`step_machine.ail:72`) only to reach a `CallModel` vs `Fail` *decision*; the handler matches
   `CallModel(_)` and **discards `project`'s payload** (`session.ail:1391`), and
   `call_model_or_fail` **discards `projection.events`** (`step_machine.ail:74`). So `project`'s
   `system_prefix_count: 0` stub (`phase_vocab.ail:168`) is on an event that is never emitted.
   This is inherent, not a defect: `project` is pure and cannot run the effectful compactor
   chain, so it can never be the authoritative builder of the compacted payload. The authority
   is necessarily `seal`.

3. **The live #76 gap is count-vs-chars.** The emitted provider-call event
   (`session.ail:1416-1422`) records `system_prefix_count` truthfully via `count_system_prefix`
   (`session.ail:722`) but **not chars**. #76's failure was a *present-but-empty* system
   message: `count == 1`, `chars == 0`. The live event would read `system_prefix_count: 1`, look
   healthy, and the 0-char prompt would stay invisible — and nothing refuses it.

**Retraction recorded for the log:** an earlier framing claimed `project`'s stale-telemetry
guard (`phase_vocab.ail:164`, testing last step's `last_input_tokens`) let the overflow slip
through. That read `project` out of context; finding 1 shows the live path re-derives and
re-gates the payload through `seal`. The overflow is guarded. The correct DST move is a
regression scenario over `seal`, not a fix to `project`.

## Decision drivers

- One enforcement point for both bug classes, on the function every send actually passes
  through — not on a pure pre-check whose output is discarded (ADR-001 §3/§4 "single gate").
- An empty system prompt must fail **distinctly and loudly** (PR #76's intent), not be folded
  into `ContextExhausted`.
- The served system-prefix *size* (chars, not just message count) must be observable, because
  the failure shape is a non-empty count over empty content.
- The refusal must be policy-gated so genuinely-headless sessions remain expressible
  (ADR-001: config/env → `StepPolicy` at session init).
- Scenarios must run at Layer 1 under `--caps IO` or less, over pure functions, with no
  network and no registry hydration (ADR-001 core-DST gate class).

---

## Decision detail

### 1. `SealError` — a typed send-gate rejection

`seal_compacted_payload` returns `Result[ProviderPayload, SealError]` where
`SealError = SealExhausted(string) | SealSystemPromptEmpty(string)`. The empty-prompt check runs
**before** the exhaustion check (a wiring error should trump "also too big"). The live handler
(`session.ail:1402`) branches: `SealSystemPromptEmpty` → an `ErrorEvent`
(`source: "system_prompt"`, `code: "SystemPromptEmpty"`; projects to the existing production
`error` name, so no new wire type) and a result `Err` coded `SystemPromptEmpty`;
`SealExhausted` → the existing `CompactionExhausted` path unchanged.

Rationale: the pre-existing string-`Err` collapsed every `seal` failure into
`CompactionExhausted`/`ContextExhausted` at `session.ail:1403-1407`. Distinguishing #76 without
a typed error would require sniffing the error message — fragile and not DST-matchable. The
typed error is what makes the distinct failure both producible and assertable.

### 2. `system_prefix_chars` — the observable that was missing

Core exports `system_prefix_chars(msgs: [Message]) -> int` (pure; mirrors
`count_system_prefix`, summing `content` length over the leading system run). `ProviderCallInfo`
gains a `system_prefix_chars: int` field, populated at the live emit site
(`session.ail:1416`). Because `split.pinned` is exactly the head system run
(`take_system_prefix`), `system_prefix_chars(split.pinned) == 0` catches **both** #76 shapes —
a *missing* prefix and a *present-but-empty* one — with one predicate.

`provider_call_prepared` is a `[NEW]` event (ADR-001 §3), so the additive field is admitted
under the TUI unknown-type/unknown-field tolerance; a one-line check against the TUI parser is
the gate.

### 3. `require_system_prompt` — the policy seam

`StepPolicy` gains `require_system_prompt: bool`, set once at session init (default `true`) and
threaded to `seal` as a parameter (keeping `seal` pure). Only when true does an empty prefix
reject. This preserves reuse of `seal` for headless invocations and matches ADR-001's
"config/env reads happen once at session init and become `StepPolicy` data."

### 4. The two scenarios (Layer 1, `phase_c_l1_scenarios.ail`)

- **`empty_system_prompt_rejected`** — `seal` over a split whose `pinned` is empty or
  empty-content, `require_system_prompt = true` ⇒ `Err(SealSystemPromptEmpty)`. New standing
  law for #76.
- **`oversized_payload_rejected`** — `seal` over an over-limit `pinned ++ chain`,
  `require_system_prompt = false` ⇒ `Err(SealExhausted)`. Regression guard for #75.2; expected
  green on landing, which is the point: it certifies that the rewrite already prevents the
  overflow, and fails loudly if a future change regresses the send-gate.

### 5. Out of scope (owned elsewhere)

- **#75.1** (chars/4 over-count → premature thrash) and **#75.3** (dead cloud summarizer) are
  compaction *policy*, extension-resident under ADR-001 D9. Their DST home is the conformance
  kit against `ExtCtx.telemetry` and fake `ai_step` ports, not core.
- **`project` cleanup** (reducing it to a bare decision now that its payload and events are
  discarded) is a separate work item; this ADR deliberately does not touch it so the change
  stays scoped to the two bug classes.

## Blast radius (all compiler-enforced by AILANG's closed record literals and typed matches)

| Change | Sites |
|---|---|
| `StepPolicy += require_system_prompt: bool` | session `:968,:989,:1685`; step_machine `:110,:209,:221`; scenarios `:99` |
| `ProviderCallInfo += system_prefix_chars: int` | type `:438`; wire projection `:611`; `project` stub `:168`; tests `:839,:1023`; session event `:1416` |
| `seal` new param + `SealError` return | live caller `session:1402`; unit tests `phase_vocab:857,:874,:884` (pass `false` to keep them exhaustion-only); import `session:118` |

## Acceptance criteria

1. `empty_system_prompt_rejected` fails against a build without the `seal` refusal arm and
   passes with it; it names the scenario id and `SystemPromptEmpty` on failure (ADR-001 §5
   reporting contract).
2. `oversized_payload_rejected` passes on landing under `--caps IO`, no network.
3. An empty system prompt in the live loop produces an `error` event with
   `code: "SystemPromptEmpty"` and a provider-call event carrying `system_prefix_chars: 0` —
   the two observations #76 lacked.
4. `ailang check` green; existing `phase_vocab`/`step_machine` unit tests green with the
   updated literals and match arms.
5. No scenario depends on effect-handler mocking, real providers, or registry hydration.

## Consequences

Positive: both incidents become standing, `--caps IO` Layer-1 law on the exact function every
send passes through; an empty system prompt is now a distinct, observable, refused failure; the
"served size" of the system prefix is visible in the ledger. The regression guard documents, in
executable form, that the phase-core rewrite already closed the overflow.

Negative / accepted: a `StepPolicy` field and a `ProviderCallInfo` field widen two literal
surfaces (mechanical, compiler-caught); `seal`'s typed error touches its three unit tests and
its one live caller; `require_system_prompt` default `true` makes an empty prompt fatal for
every normal session, so headless callers must opt out explicitly.

## Rejected alternatives

- **Fix in `project`** — its payload and events are discarded by the live loop
  (`session.ail:1391`, `step_machine.ail:74`); editing it would change dead code. Rejected in
  favor of the real gate, `seal`.
- **String error + message-sniffing in session** — fragile and not DST-matchable; the typed
  `SealError` is the minimum that lets #76 surface distinctly. Rejected.
- **Unconditional fatal empty prompt (no policy flag)** — removes the ability to express a
  legitimately headless session and hard-codes a policy into a pure gate. Rejected for the
  `require_system_prompt` seam.
- **Gate on `system_prefix_count` instead of chars** — the failure shape is `count >= 1` over
  empty content; a count gate is blind to exactly #76. Rejected for `system_prefix_chars`.
- **New dedicated `SystemPromptEmpty` wire event** — the existing `ErrorEvent` already projects
  to the production `error` name and carries `source`/`code`/`message`; a new type widens the
  compatibility surface for no gain. Rejected.

## Decision log

- **D1** (2026-07-05): empty system prompt is **policy-gated** (`require_system_prompt`, default
  `true`), not unconditionally fatal. Operator sign-off.
- **D2** (2026-07-05): the observable is **chars**, carried alongside the existing count.
- **D3** (2026-07-05): `seal` returns a **typed `SealError`** so #76 is a distinct
  `SystemPromptEmpty` failure, not `ContextExhausted`. (Emerged from pressure-testing the
  in-`seal` placement against the session error-mapping collision at `session.ail:1403`.)
- **D4** (2026-07-05): #75.2 overflow is **already guarded**; its scenario is a regression
  guard, not a fix. #75.1/#75.3 are compactor-extension policy per ADR-001 D9, out of core
  scope. `project` cleanup deferred to a separate WI.
