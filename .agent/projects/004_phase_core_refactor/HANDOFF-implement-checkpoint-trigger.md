# Handoff: implement the checkpoint-trigger plan (Plan 3)

Date: 2026-07-08 (written by the checkpoint-trigger plan-authoring/review session)
Audience: a fresh agent session that will **implement** `PLAN-checkpoint-trigger.md`.

## Mission

Implement `PLAN-checkpoint-trigger.md` in this directory — wire the **emission** of `TakeCheckpoint`
into the live loop so a long session takes a designed, audited escape (checkpoint) instead of dying at
the seal gate (`SealExhausted`, 95%). The checkpoint **machinery** already shipped (Phases A–C) and the
live handler is already wired (`session.ail` `TakeCheckpoint(plan) => apply_checkpoint(...)`). You are
adding only the **trigger + guard + tests**, then amending ADR-001 D7.

The plan is the normative spec: it carries re-grounded `file:line` anchors, the five closed decisions
with their ADR amendment text, exact code sketches, a blast-radius list, and checkable gate commands.
Follow it work-item by work-item (§7).

Concretely you will: add two `StepPolicy` fields (`checkpoint_enabled`, `checkpoint_pct`); add three pure
helpers (`history_usage_percent`, `checkpoint_would_relieve` in `phase_vocab`; `checkpoint_summary`);
gate `TakeCheckpoint` **inside `call_model_or_fail`**; retarget one scenario + one in-module test and add
positive twins; validate checkpoint output correctly (segment through the shared law, full history through
`history_valid_transcript`); and apply the ADR-001 D7 amendment.

**Do NOT** touch the checkpoint mechanics (`checkpoint`/`apply_checkpoint`/digest-chain/resume — D7
frozen), the ABI (Plan 2, frozen), or the conformance kit (Plan 1, shipped). Do not add the
AI/telemetry-delegated summary, resume UX, or multi-checkpoint policy (all v2). See plan §8.

## Reading order

1. `PLAN-checkpoint-trigger.md` — the spec. Read **§0 (grounding)** and **§9 (risks)** first; they carry
   the corrections that make the difference between a working trigger and one that spins or never fires.
2. `PLAN-checkpoint-trigger.md` §2 — the five closed decisions (D3-1…D3-5) and the **ADR-001 D7 amendment
   text** you must apply verbatim-ish on landing. These are closed by operator sign-off — apply, do not
   re-litigate.
3. `ADR-001-phase-oriented-core.md` **D7** (`§4` bullet "The checkpoint seam", `~:215-228`) — the section
   you amend. `ADR-002-send-gate-…` §2 — the project-vs-seal fork the emission-site decision resolved.
4. Source you edit (re-ground every anchor at HEAD first, see below): `src/core/step_machine.ail`
   (`call_model_or_fail` `:67`, `decide` `:78`, `mk_policy` `:109`, the in-module test `:347`),
   `src/core/phase_vocab.ail` (`StepPolicy` `:270`, `checkpoint` `:239`, `split_for_compaction`/
   `segment_messages` `:130`/`:134`), `scripts/phase_c_l1_scenarios.ail` (the three checkpoint scenarios).
5. `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md` and the
   `verify-before-claiming-substrate-defects` memory — minimal repro discipline; never read `$?` through a
   pipe; assert on printed scenario verdicts.

## Ground truth to re-establish before you touch code

Every `file:line` in the plan is from HEAD `4371de0`. `session.ail` drifts by the dozen; `step_machine`
and `phase_vocab` drift less but re-verify. Before editing, re-run:

```bash
git rev-parse --short HEAD
grep -n "func call_model_or_fail\|export func decide\|func mk_policy\|test_v1_policy_never_returns_take_checkpoint" src/core/step_machine.ail
grep -n "export type StepPolicy\|export func checkpoint\b\|split_for_compaction\|segment_messages" src/core/phase_vocab.ail
grep -n "no_system_in_output\|validate_compactor_output" packages/motoko_ext_conformance/invariants.ail
grep -rn "step_budget:" src scripts --include=*.ail | grep -v .ailang/cache   # StepPolicy blast radius
```

Baseline the gate BEFORE you start so you know green→green: `make check_core` and
`ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail` (expect `PASS count=13`).

## The five hazards that will bite you (the review's hard-won corrections — read before coding)

These are in the plan (§0, §9) but repeated here because each one is a silent failure mode:

1. **Gate goes INSIDE `call_model_or_fail` (`:67`), NOT in `decide`'s `else` chain.** `decide` fans five
   finish-reasons (`stream_error`, `intercept_handled`, `tools_complete`, `user_injected`, final `else`)
   into `call_model_or_fail`. `tools_complete` is the dominant history-growth path. An `else`-arm would
   skip the checkpoint after every tool batch. Place it after the budget/cost `Fail` checks, before
   `project`/`CallModel`. (Plan §4.2 has the exact sketch.)

2. **`checkpoint_would_relieve` is mandatory, not an optimization — and it is the ONLY termination
   guard.** The handler keeps `step_idx: st.step_idx` (`session.ail:~1352`) — a checkpoint does **not**
   advance the step counter, so `step_budget` can never break a spin. A checkpoint that keeps a system
   prefix ≥ `checkpoint_pct` (verified: 171%→96%) would loop forever without this precondition. Emit only
   if `enabled && usage >= pct && checkpoint_would_relieve(...)`. If it wouldn't relieve, fall through to
   seal-exhaustion (the honest terminal).

3. **`validate_compactor_output` REJECTS system messages** (`invariants.ail:~70`). Do **not** feed the
   whole checkpoint history to it — it keeps the pinned system prefix and would fail. Validate the
   **non-system segment** (`segment_messages(split_for_compaction(msgs))`; the output segment is the
   `[summary]` message) through the shared law, and **keep** `history_valid_transcript(cp.history)` for the
   full-history system-prefix obligation. Both live in `checkpoint_output_is_valid_transcript` (plan §5.4).

4. **Negative tests must be PRESSURED or they pass for the wrong reason.** The current
   `checkpoint_never_emitted_in_v1` fixture uses `policy(0)` / `mk_policy(0)` → `context_limit = 0` →
   usage 0, which never triggers regardless of the flag. When you retarget to "policy off", give the
   fixture a real limit + history so usage ≥ `checkpoint_pct` with the flag off — otherwise the test no
   longer guards the flag. Same for the in-module test (plan §5.1, §5.5).

5. **The never-emit invariant lives in TWO places.** The scenario `checkpoint_never_emitted_in_v1`
   (`phase_c_l1_scenarios.ail:298`) AND the in-module test `test_v1_policy_never_returns_take_checkpoint`
   (`step_machine.ail:347`). Retarget both to "…by default" and add a positive twin for each.

Bonus: `Msg` (`types.ail:16`) and `Message` (std/ai) are the same record shape; the sibling
`ext_compaction_invalid_rejected` scenario already passes such records to the law directly. Use
`messages_to_msgs` only if the checker distinguishes them nominally.

## Execution order

Follow plan §7 (WI-1…WI-6). Recommended flow:

1. **WI-1 · Policy fields** — add `checkpoint_enabled`/`checkpoint_pct` to `StepPolicy`; update **every**
   literal (grep above; ~8 files); `mk_policy` defaults `false`/`90`. Gate: `make check_core` **compiles**
   (the compiler is your blast-radius backstop — a missed literal fails loudly).
2. **WI-2 · Pure helpers** — `history_usage_percent`, `checkpoint_would_relieve` (`phase_vocab`),
   `checkpoint_summary`. Gate: `ailang check`.
3. **WI-3 · Trigger gate** — `should_checkpoint`/`mk_checkpoint_plan` wired inside `call_model_or_fail`
   (hazard 1). Gate: `ailang check`; existing `decide` tests still green (default off).
4. **WI-4 · Scenarios + in-module tests** — retarget scenario #1 (pressured, hazard 4); add
   `checkpoint_emitted_under_pressure` and `checkpoint_terminates_not_spins`; fix
   `checkpoint_output_is_valid_transcript` (hazard 3); rename the in-module test + positive twin (hazard
   5). Gate: `phase_c_l1_scenarios PASS count=15` **and** `make check_core`.
5. **WI-5 · ADR-001 D7 amendment** — apply the §2 text; note the new helper surface (G2) and the no-escape
   terminal (G3).
6. **WI-6 · Full gate** — everything below green.

## Verify before you claim done (do not trust "it compiles")

Per the `verify-before-claiming-substrate-defects` memory: build a minimal repro and observe behavior, not
just types. A `scratchpad/verify_guard.ail`-style script already exists (the plan cites its numbers); adapt
it to confirm, for your actual `checkpoint_pct`:
- a pressured history (usage ≥ pct, small system prefix) → `decide` returns `TakeCheckpoint` with the flag
  on, and after `apply_checkpoint` the next `decide` returns `CallModel` (progress, not another checkpoint);
- a system-prefix-heavy history (prefix alone ≥ pct) → `decide` returns `CallModel`, never `TakeCheckpoint`
  (no spin).
Assert on the printed decision, not on exit codes read through a pipe.

## Acceptance criteria (the gate — all must be green)

```bash
ailang check src/core/step_machine.ail src/core/phase_vocab.ail
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail   # expect: phase_c_l1_scenarios PASS count=15
make check_core                                                       # includes the renamed in-module tests
grep -n "never emits by default\|checkpoint_enabled" \
  .agent/projects/004_phase_core_refactor/ADR-001-phase-oriented-core.md   # amendment applied
```

Done = all four green + the D7 amendment committed + the two behavioral checks above observed.

## What you own vs must NOT touch

**Own:** the two `StepPolicy` fields, the three helpers, the gate in `call_model_or_fail`, the scenario +
in-module test changes, the D7 amendment.

**Do NOT touch:** `checkpoint`/`apply_checkpoint`/digest-chain/resume mechanics (D7 frozen — you only
*read* `History` via the new helpers); the ABI (Plan 2); the conformance kit / `validate_compactor_output`
law (Plan 1 — reuse it, never copy it); the `TakeCheckpoint` handler in `session.ail` (already wired — but
confirm it still threads `cp.state` into `next_state` at HEAD before relying on it).

## If the plan is wrong

The plan was reviewed against code at HEAD `4371de0`, but line numbers drift and you may find a genuine gap
the review missed. If a plan claim contradicts what you observe at implementation HEAD, **stop and record
it** (append to the plan's "ADR gaps found" §1, or a short `NOTE-`), don't silently invent policy — the
five decisions and the D7 amendment are operator-signed. A drifted line number is a re-ground, not a gap; a
changed *contract* (e.g. `checkpoint` no longer keeps the system prefix, or `validate_compactor_output`
changed its system-message rule) is a gap worth surfacing before you build on it.

## Report back

Report: gate output (the `PASS count=15` line and `make check_core` result verbatim), the two behavioral
repro observations, the D7 amendment diff, and any ADR gap you recorded.
