# Handoff: implement the ADR-002 send-gate plan

Date: 2026-07-06 (written by the ADR-002 plan-authoring/review session)
Audience: a fresh agent session that will **implement** `PLAN-adr-002-send-gate.md`.

## Mission

Implement `PLAN-adr-002-send-gate.md` in this directory — the `seal_compacted_payload` send-gate
changes (typed `SealError`, `system_prefix_chars`, `require_system_prompt`) and the two Layer-1
scenarios. The plan is the normative spec: it carries re-verified `file:line` anchors, exact code
sketches, per-WI verification and rollback, and the acceptance gate. Follow it WI by WI.

**Do NOT** implement the out-of-scope items (they are listed in the plan and repeated below).

## Reading order

1. `PLAN-adr-002-send-gate.md` — **the spec.** Read it whole first. Its "Work breakdown"
   (WI-1..WI-5), "Plan-level decisions" (D-P1..D-P6), "ADR gaps found", and "Anchor
   re-verification log" are what you execute against.
2. `ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` — the normative decision the plan
   implements. D1–D5 are settled; do not re-open them. If HEAD contradicts the ADR, that is a
   finding to report, not a redesign licence.
3. `NOTE-ailang-run-exit-code-false-alarm.md` — measurement discipline (pipefail; never read `$?`
   through a pipeline; minimal repro before any substrate-defect claim).

## Ground truth to re-establish before you touch code

- **Toolchain pin: AILANG v0.26.0 (`3b52a24`).** Run `ailang --version`; if it disagrees, STOP and
  flag. `ailang.lock` `ailang_version` must read `"v0.26.0"`.
- **The plan's anchors are grounded at HEAD `b76dd3e`.** Run `git log --oneline -10` first. If new
  commits have landed that touch `src/core/session.ail`, `src/core/phase_vocab.ail`,
  `src/core/step_machine.ail`, or `scripts/phase_c_l1_scenarios.ail`, **re-verify every `file:line`
  in the plan's Anchor Re-Verification Log before trusting it** — the plan itself caught a −9 line
  drift in `session.ail` from a single comment-only commit, so this is not hypothetical. The
  non-session files were unchanged at authoring; confirm that still holds.
- **Green baseline (confirm before starting, so you can attribute any red to your change):**
  ```
  ailang check src/core/phase_vocab.ail
  ailang check src/core/session.ail
  ailang test src/core/phase_vocab.ail          # 25 pass / 0 fail
  ailang test src/core/step_machine.ail         # 16 pass / 0 fail
  ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail   # 10/10 PASS
  ```

## The one decision to confirm with the operator before WI-2

**D-P1 — `require_system_prompt` origin default.** The plan recommends
`require_system_prompt: !headless` at the origin site (`session.ail:959`, where a `headless` flag is
already computed from `MOTOKO_HEADLESS` at `:957`), because a hardcoded `true` leaves the
ADR's headless opt-out unreachable at runtime. ADR-002 §3 literally says "default `true`". This is
the only open interpretation point; it is a one-token change at one site either way and does not
perturb the rest of the plan. **Confirm the operator's preference (`!headless` vs literal `true`)
before landing WI-2.** Everything else in the plan is settled.

## Execution order and the strangler contract

Implement in plan order; **each WI must leave the whole tree `ailang check`-green and the test/
scenario suites green before you move on** (the plan gives per-WI verification + rollback):

- **WI-1** — `system_prefix_chars` helper (use **`Str.length`**, not `String.length` — the codebase
  imports `std/string as Str (length)`) + `ProviderCallInfo.system_prefix_chars` field. Additive.
- **WI-2** — `StepPolicy += require_system_prompt` at all **7** production literal sites (the plan
  lists them and proves completeness repo-wide; the 8th `step_budget:` grep hit is an unrelated
  standalone sketch module — do not touch it). Dormant until WI-3.
- **WI-3** — the atomic behavior change: `SealError` type, `seal` signature/body (empty-check
  **before** exhaustion), thread `require_system_prompt`, split the session `Err` arm into
  `SealSystemPromptEmpty` (→ `error` event coded `SystemPromptEmpty`) vs `SealExhausted` (existing
  path unchanged), update the 3 seal unit tests + add 1. `phase_vocab` and `session` change
  together here — that is unavoidable (AILANG has no default args), which is why the plan makes it
  one WI.
- **WI-4** — the two L1 scenarios (`empty_system_prompt_rejected`, `oversized_payload_rejected`) +
  registration. `oversized_payload_rejected` **must** pass `require_system_prompt = false` (with
  empty `pinned`, `true` would mask exhaustion behind the empty-prompt reject).
- **WI-5** — the ADR-002 acceptance gate. Includes the fail-then-pass "teeth" check for
  `empty_system_prompt_rejected` (flip its `seal(..., true)` arg to `false`, observe a named FAIL,
  flip back) and the manual TUI-tolerance / live-loop inspection items.

## Discipline (non-negotiable)

- Re-verify anchors against your HEAD before editing (see above). AILANG's closed record literals
  mean a missed construction site is a compile break — treat that as the safety net, not a
  surprise.
- A substrate-defect claim requires a **minimal repro** before you write it down; do not read `$?`
  through a pipeline (`NOTE-ailang-run-exit-code-false-alarm.md`).
- Do not modify `PLAN-adr-002-send-gate.md`, ADR-002, the NOTE, or any prior plan/ADR/research
  doc. If implementation surfaces a plan defect, report it and (if asked) fix the plan as a
  separate, explicit step.
- DST assertions match the structured `code` (`SystemPromptEmpty` / `ContextExhausted`), never the
  message text.

## Out of scope (do NOT implement — owned elsewhere)

- Host-side env-manifest work (`NOTE-env-manifest-single-source-and-drift-guard.md`,
  `runtime-process.ts` allowlist / `CORE_MAP`). Separate WI.
- `project` cleanup — only compile-fix its `ProviderCallPrepared` stub
  (`phase_vocab.ail:168`, add `system_prefix_chars: 0`); do **not** fix its logic.
- #75.1 (chars/4 over-count) and #75.3 (dead cloud summarizer) — compactor-extension policy,
  ADR-001 D9 conformance kit.
- The ABI / compactor-extension conformance track.

## Branch and merge note

This branch is `arniwesth/mot-27-phased-core-architecture`; implement against this tree. PRs
#75/#76 live on other branches — note (do not resolve) that their edits to the
`session.ail:CallModel` region and #76's `c5b0924` will overlap at merge time; that is a merge-time
concern, not part of this work.

## Definition of done

All of ADR-002's Acceptance criteria hold (plan WI-5): `empty_system_prompt_rejected` is
fail-then-pass and names its id + `SystemPromptEmpty`; `oversized_payload_rejected` green under
`--caps IO` with no network; `ailang check` green on all three core files; `phase_vocab` tests
26/26 and `step_machine` 16/16 with updated literals and typed match arms; scenarios 12/12; and the
live loop emits an `error` event coded `SystemPromptEmpty` (with no `provider_call_prepared` on the
reject path) while every proceeding call emits `provider_call_prepared` carrying
`system_prefix_chars`.
