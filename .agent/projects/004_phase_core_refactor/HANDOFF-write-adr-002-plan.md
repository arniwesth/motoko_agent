# Handoff: write the ADR-002 implementation plan

Date: 2026-07-05 (written by the ADR-002 authoring/review session)
Audience: a fresh agent session. You are deliberately fresh, same discipline as
`NOTE-plan-authoring-session-choice.md`: **if you cannot produce this plan from ADR-002 plus the
committed source at HEAD, the ADR has a gap — report it in an "ADR gaps found" section, don't
guess around it.** ADR-002 is small and heavily grounded, so the bar for "gap" is high; most of
your work is sequencing and re-verifying anchors.

## Mission

Write `PLAN-adr-002-send-gate.md` in this directory: the implementation plan for
`ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` — the `seal_compacted_payload`
send-gate changes (typed `SealError`, `system_prefix_chars`, `require_system_prompt`) and the two
Layer-1 scenarios. **Do NOT implement.** **Do NOT plan** the host-side env-manifest work
(`NOTE-env-manifest-single-source-and-drift-guard.md` — separate WI), the `project` cleanup, or
#75.1/#75.3 (compactor-extension conformance, ADR-001 D9).

## Reading order

1. `ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` — **normative and nearly
   complete**. Its "Decision detail" 1–4 is the change; the "Blast radius" table is your
   file-level change list in embryo; "Acceptance criteria" is your gate checklist; the "Decision
   log" (D1–D5) is settled, not yours to re-litigate. §5 and the NOTE mark what is out of scope.
2. The source under change, in this order — read each function whole, don't trust the ADR's line
   numbers blind (verify, see discipline):
   - `src/core/phase_vocab.ail` — `seal_compacted_payload` (`~:131`), `ProviderCallInfo` (`~:438`),
     the `to_schema_v1` wire projection for `provider_call_prepared` (`~:611`), the golden test
     (`~:1023`), `StepPolicy` (`~:310`), `take_system_prefix` (`~:80`), the three `seal` unit
     tests (`~:857,:874,:884`).
   - `src/core/session.ail` — the `CallModel` handler (`~:1391`), the single `seal` call site
     (`~:1402`) and its `Err`→`CompactionExhausted` mapping (`~:1403-1409`), the
     `ProviderCallPrepared` emit inside the `Ok` branch (`~:1416`), `count_system_prefix`
     (`~:722`), and the three `StepPolicy` build sites (`~:968` origin, `~:989`/`~:1685` derived).
   - `src/core/step_machine.ail` — `call_model_or_fail` (`~:72`), `mk_policy` (`~:110`) and the two
     inline policy literals (`~:209,:221`).
   - `scripts/phase_c_l1_scenarios.ail` — the harness shape (`Scenario {id, run}`, `main`'s list,
     the `policy()` helper `~:99`) your two new scenarios slot into.
   - `src/core/compaction.ail` — `usage_percent_with_limit`, `exhaustion_pct`,
     `estimate_tokens_messages` (`:17-30`); the measurement law `seal` already uses.
3. `ADR-001-phase-oriented-core.md` — §3 (`[NEW]` vs `[prod]` event classes; `provider_call_prepared`
   is `[NEW]`, so the additive field is tolerated) and §4 (the single-transcript-gate principle
   ADR-002 pins to `seal`). Context only; ADR-002 is the normative doc for this work.
4. `NOTE-ailang-run-exit-code-false-alarm.md` — measurement discipline (pipefail, minimal repro
   before any substrate-defect claim, never read `$?` through a pipeline).

## Non-negotiable discipline

- **Re-verify every ADR-002 line anchor against HEAD yourself.** They were verified at the
  ADR-authoring session (HEAD `64262d1` / branch `arniwesth/mot-27-phased-core-architecture`), but
  `git log --oneline -10` first and confirm each `file:line` before it enters your plan. AILANG's
  closed record literals mean a missed `StepPolicy` construction site is a compile break, so the
  blast-radius enumeration must be **complete at HEAD**, not copied from the ADR.
- Toolchain pin is **v0.26.0 / `3b52a24`**; if `ailang --version` disagrees, STOP and flag.
- A substrate-defect claim requires a minimal repro before it enters the plan.
- Re-run before relying: `ailang check src/core/phase_vocab.ail`,
  `ailang test src/core/phase_vocab.ail`, `ailang test src/core/step_machine.ail`, and
  `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail` (the harness you extend).

## Deliverables (from ADR-002 — summary, not substitute; re-read the ADR)

1. **`SealError` typed error** — `SealError = SealExhausted(string) | SealSystemPromptEmpty(string)`;
   `seal_compacted_payload` returns `Result[ProviderPayload, SealError]`, empty-prompt check
   **before** exhaustion. New `require_system_prompt: bool` param (keeps `seal` pure).
2. **`system_prefix_chars`** — exported pure helper (sum `content` length over the head system
   run; mirrors `count_system_prefix`) + a `system_prefix_chars: int` field on `ProviderCallInfo`,
   populated at the live emit site.
3. **`require_system_prompt`** — new `StepPolicy` field, origin `true` at session init, **inherited**
   (not re-defaulted) at the two derived sites; threaded to `seal`.
4. **Session branch** — split the single `seal` `Err` arm into `SealSystemPromptEmpty` (→
   `ErrorEvent{source:"system_prompt", code:"SystemPromptEmpty"}`, result coded `SystemPromptEmpty`,
   `retryable:false`) vs `SealExhausted` (→ existing `CompactionExhausted` path unchanged).
5. **Two L1 scenarios** in `phase_c_l1_scenarios.ail` (add imports + register in `main`):
   `empty_system_prompt_rejected` (new #76 teeth) and `oversized_payload_rejected` (#75.2
   regression guard, expected green).

**Gate (ADR-002 Acceptance criteria — re-read exact wording):** the empty-prompt scenario is
fail-then-pass; `oversized_payload_rejected` green under `--caps IO`, no network; `ailang check`
green; existing `phase_vocab`/`step_machine` unit tests green with updated literals and match arms;
the live loop emits an `error` event coded `SystemPromptEmpty` on an empty prompt.

## Session residuals worth having (things pressure-testing surfaced; the ADR states them but you'll
plan against them)

- **`seal` is the single unconditional send-gate — verify it still is.** At authoring HEAD the loop
  had **exactly one** `dispatch_step` (`session.ail:~1424`) nested in the **one** `seal` `Ok`
  branch (`~:1402`). The whole ADR hinges on this. If a later commit added a second dispatch or a
  second seal call, that is an **ADR gap** — report it, don't plan around it silently.
- **`provider_call_prepared` is emitted only on the `Ok` branch** (`session.ail:~1410,:1416`). So the
  empty-prompt rejection path has **no** prepared-event; its observability is the `ErrorEvent`.
  Do not plan a `chars:0` prepared-event on the reject path — that was a criterion-3 bug we fixed
  (see D5). The prepared-event field gives always-on served-size logging for calls that *proceed*.
- **`project` is vestigial — do not touch it beyond compile-fixing its field literal.** Its payload
  is discarded by `session.ail:~1391` (`CallModel(_)`) and its events by `step_machine.ail:~74`.
  You still add `system_prefix_chars:` to its `ProviderCallPrepared` stub (`~:168`) so it compiles,
  but do not "fix" its logic — the reduce-project-to-a-decision cleanup is a separate WI (§5).
- **The `seal` unit tests must pass `require_system_prompt = false`** to stay exhaustion-only, and
  their `Err(reason)` matches become `Err(SealExhausted(reason))`. Add a new unit test for the
  `SealSystemPromptEmpty` arm.
- **`ProviderCallInfo`'s field addition breaks the golden test** (`phase_vocab.ail:~1023`, exact JSON
  string) and the wire projection (`~:611`). Additive `[NEW]` event, so tolerated — but the golden
  string and the ledger test (`~:839`) are hard-coded and must be updated in lockstep.
- **Scenario construction:** build the `PinnedSplit` via the exported `split_for_compaction` — feed
  it a message list with no leading system message (⇒ empty `pinned`) or a `{system, ""}` head
  (⇒ present-but-empty). **Verify whether `MkSegment` is exported** before assuming you can build a
  segment directly; if not, `split_for_compaction` is the only public path. `oversized_payload_rejected`
  mirrors the existing `test_seal_compacted_payload_exhausts_with_live_reason` (`~:874`) — that is
  why it is expected green.
- **`SystemPromptEmpty` reuses `ErrorEvent`/`ErrorInfo`** (projects to the production `error` name at
  `~:639`) — no new wire event type (rejected alternative in the ADR).

## Plan output contract

House style per the prior plans (`PLAN-phase-c-full-inversion.md` / `PLAN-phase-b-phase-results.md`
are the models). Must include: ordered WIs with **file-level change lists** and per-step
**verification commands** and **rollback**; the gate checklist as the final step; a **grounding
section** with your re-verified anchor log (every `file:line` you confirmed at HEAD, and any drift
from the ADR's numbers); an **"ADR gaps found"** section (empty is a valid finding); an explicit
**out-of-scope** list (env-manifest NOTE work, `project` cleanup, #75.1/#75.3 compactor
conformance, the ABI track); and the toolchain you verified against. Strangler discipline: each WI
leaves the system `ailang check`-green and shippable — a natural cut is (WI-1) `phase_vocab` types +
helper + `seal` signature/tests, (WI-2) `StepPolicy` field + all construction sites, (WI-3) session
branch + event field, (WI-4) the two scenarios — but sequence it however keeps each step
compiling.

## Constraints

- **D1–D5 are settled** (policy-gated require; chars not count; typed `SealError`; overflow already
  guarded so its scenario is a regression guard; ErrorEvent-on-reject not a prepared-event). Do not
  re-open them; a contradiction between the ADR and HEAD is a finding, not a redesign license.
- Do not modify ADR-002, the NOTE, or any prior plan/ADR/research doc. Your plan is a new file.
- This branch is `arniwesth/mot-27-phased-core-architecture`. PRs #75/#76 live on other branches;
  your plan targets **this** tree's code. Note (don't resolve) any obvious future merge overlap —
  e.g. #76's `c5b0924` overlaps the NOTE's WI-1, not this plan.
