# Handoff: write the persist-nudge migration plan

Audience: a fresh agent session. You are deliberately fresh — see
`../004_phase_core_refactor/NOTE-plan-authoring-session-choice.md`. Freshness is a test: **if you
cannot plan this from ADR-001 (+ code) alone, the ADR has a gap — record it in an "ADR gaps found"
section, don't paper over it.**

## Mission

Write `PLAN-persist-nudge-migration.md` in this directory (`005_harness_policy_boundary/`): the plan
for **decision D4** of ADR-001 — move the existing persist-nudge out of core and reimplement it as a
**coding-task guard extension** on the same `on_solver_candidate` seam, then delete the in-core
policy. This is a **behavior-preserving refactor across the harness boundary**, not a feature.

**Sequencing constraint:** this is a *follow-on* to the empty-stop guard
(`HANDOFF-write-empty-stop-guard-plan.md`). Read that plan first if it exists — the persist-nudge
guard is a *second* finalize guard, so the two must coexist correctly in the merged hook chain
(finalize-decision ordering). Do NOT start implementing. Plan only.

## What persist-nudge is today (the thing being moved)

A core-resident policy that, when the model stops without producing a solution *file*, injects a
nudge to keep going. It is coding-task-specific and disabled by default. In code (re-verify — see
discipline):

- `src/core/session.ail` — the `NoDecision` arm of the finalize path calls
  `should_inject_persist_nudge(persist_retries, nudges_used, any_writefile_attempt(...))`; on true it
  emits `PersistNudge`, sets `last_finish_reason: "persist_nudge"`, and loops. The `decide` step
  machine turns `"persist_nudge"` into an `InjectUserMessage`.
- `src/core/recovery.ail` — `should_inject_persist_nudge`, `persist_nudge_message` (the hardcoded
  *"use the WriteFile tool to save your solution"* text + `persist_nudge_marker()`),
  `count_persist_nudges`, `any_writefile_attempt`, plus their inline tests (including a
  **live-bytes golden** on the exact message string).
- `session_policy_init` — `persist_retries` from `MOTOKO_PERSIST_RETRIES` (default `0`).

## Reading order

1. `ADR-001-harness-policy-boundary.md` (this dir) — **normative**; D4 and §"The boundary". The
   principle: this is policy on the mechanism side; it belongs on the extension side like compaction.
2. `HANDOFF-write-empty-stop-guard-plan.md` + `PLAN-empty-stop-guard.md` (if authored) — the sibling
   guard whose extension shape, budget/marker mechanism (and its OQ5 durability resolution), and
   finalize-chain coexistence you should reuse rather than reinvent.
3. `src/core/recovery.ail` + the persist-nudge sites in `src/core/session.ail` — what you are moving.
4. `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` §D9 — the precedent that compaction
   *policy* is extension-resident; you are applying the same move to nudge policy.

## Non-negotiable discipline (verify at HEAD)

Grounded at HEAD `66a4ecb`; **`session.ail` line numbers drift** (it grew 2455→2523 during the ADR
work). `git log --oneline -20 -- src/core/` first; re-verify every `file:line` yourself. This is a
refactor, so the risk is *silent behavior change* — anchor on the existing tests as the contract.

## What the plan must specify

- **Behavior parity is the acceptance bar.** Enumerate current persist-nudge behavior as invariants
  the migration must preserve: fires only when `persist_retries > 0`, `nudges_used < budget`, and no
  WriteFile has been attempted; injects the exact (or intentionally revised — call it out) message;
  budget counted from history markers. The `recovery.ail` inline tests — especially the message
  **live-bytes golden** — are your contract; decide whether they move with the code or are replaced.
- **The mechanics move to the seam:** the extension returns `ContinueWithFeedback(message)` (which
  already loops, per the empty-stop handoff) instead of the core `PersistNudge`/`persist_nudge`
  path. Map the old gating (`any_writefile_attempt`, `MOTOKO_PERSIST_RETRIES`) onto the extension:
  how does the extension see WriteFile attempts (`ctx.history_slice`?) and its budget/config
  (`ctx` config / env)? Flag any gap where the extension **cannot** see what core saw — that is an
  ADR gap.
- **Core deletions:** what to remove from `session.ail`/`recovery.ail` (the `NoDecision`
  persist-nudge branch, `should_inject_persist_nudge`, `persist_nudge_message`,
  `any_writefile_attempt`, the `persist_retries` policy field, `MOTOKO_PERSIST_RETRIES` plumbing) and
  what, if anything, stays (e.g. `persist_nudge_marker`/`count_persist_nudges` may be reused by the
  extension). Note the `decide` step-machine arm for `"persist_nudge"` and whether it can go.
- **Two-guards coexistence:** persist-nudge (coding) and empty-stop (generic) are both
  `on_solver_candidate`. Specify ordering in `extensions.order` and confirm `merge_finalize_decisions`
  gives a sensible result when both would continue (first `ContinueWithFeedback` wins). Avoid
  double-nudging the same empty stop.
- **Config migration:** `MOTOKO_PERSIST_RETRIES` consumers / any profile that sets it — how does the
  budget carry to the extension without breaking existing configs?
- **Verification:** the `make` target(s) proving parity — reuse/port the existing `recovery.ail`
  persist-nudge tests into the extension, plus a scenario that a coding-task empty stop still gets
  nudged and a research-task empty stop is handled by the *generic* guard, not this one.

## ADR gaps found

Add this section. The most likely gap: the extension cannot observe something core could (WriteFile
history, budget config) via `ExtCtx`. If so, name the missing `ctx` field precisely — that is a real
ADR/ABI finding, not a reason to keep the policy in core.
