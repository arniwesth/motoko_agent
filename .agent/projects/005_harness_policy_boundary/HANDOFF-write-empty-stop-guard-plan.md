# Handoff: write the empty-stop-guard implementation plan

Audience: a fresh agent session. You are deliberately fresh — see
`../004_phase_core_refactor/NOTE-plan-authoring-session-choice.md` for why the plan is authored by a
new session and not the one that wrote `ADR-001-harness-policy-boundary.md`. Your freshness is also a
test: **if you cannot produce this plan from ADR-001 (+ the code) alone, the ADR has a gap — report
it in an "ADR gaps found" section of the plan, don't guess around it** (empty is a valid finding).

## Mission

Write `PLAN-empty-stop-guard.md` in this directory (`005_harness_policy_boundary/`): the
implementation plan for **decisions D1, D2, and D3(b)** of ADR-001. Two deliverables:

1. A new **extension** (`empty_stop_guard`, or similarly named) implementing `on_solver_candidate`
   that returns `ContinueWithFeedback(<generic continue message>)` when the model's candidate is
   blank and the guard's own continue-budget is not exhausted, else `NoDecision`.
2. A **core safety floor** (D3(b)): a distinct ledger event emitted when the run finalizes on an
   empty stop, so the outcome is never mistaken for a substantive completion **even with no guard
   loaded**.

Do NOT plan the persist-nudge migration (separate handoff), do NOT touch compaction, and do NOT
start implementing. Plan only.

## Reading order

1. `ADR-001-harness-policy-boundary.md` (this dir) — **normative**. Your acceptance criteria are
   D1/D2/D3(b) and the Open Questions OQ2–OQ5, each of which the plan must resolve or explicitly
   defer with a reason. Read §Context (the seam trace), §"The boundary", §Decision, and the OQs.
2. `../../issues/silent-empty-stop-finalize.md` — the failure and the guard-as-extension shape.
3. The seam, in code (re-verify — see discipline below):
   - `packages/motoko-ext-abi/types.ail` — `ExtensionHooks`, `on_solver_candidate`, and
     `FinalizeDecision = Accept | ContinueWithFeedback | NoDecision`.
   - `src/core/session.ail` — the finalize path: `dispatch_solver_candidate(...)` on the candidate
     `result.message.content`; the `ContinueWithFeedback` arm (emits `ExtSolverFeedback`, sets
     `solver_feedback`, loops); the `NoDecision` arm; and the `c2_after_dp7(...)` convergence where
     both finalize routes end.
   - `src/core/ext/runtime.ail` — `dispatch_solver_candidate` / `merge_finalize_decisions` /
     `first_continue` (precedence: `ContinueWithFeedback` > `Accept` > `NoDecision`).
   - An **existing extension to mirror for shape/registration**: pick one that already declares a
     no-op `on_solver_candidate` (e.g. under `packages/motoko-ext-*` or `src/core/ext/*/register.ail`)
     and follow how it is registered and added to a profile's `extensions.order`.
   - `src/core/phase_vocab.ail` — the `LedgerEvent` sum + its JSON projection + golden tests: this is
     where the D3(b) event type is added.
4. `../001_DST/ADR-004-long-qwen-compaction-session-dst.md` and its `PLAN-*` — house style for how a
   plan in this repo sequences work items and gates them on `make` targets.

## Non-negotiable discipline (verify at HEAD; anchors WILL have moved)

The ADR was grounded at branch `arniwesth/mot-35-fix-context-size-estimation`, HEAD `66a4ecb`, and it
**deliberately omits most line numbers** because they drift — `session.ail` grew from 2455 to 2523
lines *during the work that produced this ADR*. So:

- `git log --oneline -20 -- src/core/ packages/` first. Anything newer than `66a4ecb` touching
  `session.ail`, `ext/runtime.ail`, `phase_vocab.ail`, or the ext ABI → treat inherited anchors as
  suspect.
- Every source claim in YOUR plan carries a `file:line` you verified yourself at current HEAD.
- Confirm the seam still behaves as the ADR's §Context 3 states: an empty stop (`finish_reason` not
  `tool_calls`, `NoIntercept`, no hybrid bash fence) reaches `on_solver_candidate` with a blank
  candidate, and `ContinueWithFeedback` loops. If any link is broken, that's an ADR gap — record it.

## What the plan must specify

- **Guard extension:** module + `register.ail`; `on_solver_candidate` logic (blank-candidate test —
  empty *or* whitespace; budget check; `ContinueWithFeedback` message that is **task-agnostic**, not
  WriteFile-specific); the message must carry a marker phrase for budget counting.
- **Budget (D2) and its durability (OQ5):** how the guard counts its prior nudges. Resolve OQ5 —
  structural compaction spares `user`/`assistant` messages but the **AI compactor summarizes old
  turns** and can fold a marker away. Decide the counting source (full history vs a compacted
  `ctx.history_slice`), or a durable `ctx`/artifact field, or a summarizer-preserved marker. Note how
  persist-nudge counts today (`count_persist_nudges` over full `msgs`) as the precedent.
- **Core floor (D3(b)):** the new `LedgerEvent` (name it; e.g. `EmptyStopFinalize`), its JSON
  projection + golden bytes, and the single emission point at the `c2_after_dp7` finalize convergence
  gated on (blank content ∧ no tool calls). Confirm it fires on the zero-extensions path (default
  `persist_retries=0`, `NoDecision`, no nudge). Consider OQ4 (carry context-window sizes in the event).
- **Interaction correctness:** the guard runs inside the merged finalize-hook chain — verify
  `ContinueWithFeedback` still wins when other extensions return `NoDecision`; document ordering if a
  second finalize guard (the future persist-nudge migration) is co-loaded.
- **Profile/registration (OQ3):** whether the guard ships in the default `extensions.order` or is
  opt-in with only the floor on by default (ADR leans: floor always; guard in default order).
- **False positives (OQ2):** message wording + budget so a legitimately-empty final turn costs little.
- **Verification:** which `make` target(s) prove it — a DST/scenario that drives a stubbed empty
  stop and asserts (a) the guard injects + loops within budget, (b) budget exhaustion → `NoDecision`
  → the D3(b) event fires, (c) the event fires with **no** guard loaded. Prefer the stub-step /
  scripted-provider path used by the existing compaction DSTs so it's deterministic and offline.

## ADR gaps found

Add this section to your plan. If D1/D2/D3(b) + OQ2–OQ5 were sufficient to plan every work item
without guessing, say so explicitly (that is the ADR passing its freshness test).
