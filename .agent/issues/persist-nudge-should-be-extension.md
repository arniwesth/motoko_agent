# Persist nudge is core-resident; it should be an extension

## Status
open

## Branch
arniwesth/mot-40-observable-pre-step-pass-through (noticed here; not yet scheduled)

## Description
Motoko has three "don't stop yet" nudges. Two are extensions that hook `on_solver_candidate`
and return `ContinueWithFeedback(...)`:
- `empty_stop_guard` (nudges on a blank final response),
- `progress_contract_guard` (nudges when the response self-reports the task is still in progress).

The third — the **persist nudge** ("You stopped without writing a solution file… use the WriteFile
tool…") — is baked into **core** instead. It runs as a hard-coded branch in the finalize/solver
flow *after* the extension solver chain returns `NoDecision`, carries its own marker, budget, and
counting logic in `src/core/recovery.ail`, and threads a dedicated `nudges_used` field plus a
`PersistNudge` ledger event through the loop.

This violates the north-star bias (`ailang/CLAUDE.md` / `design_docs/PROGRAM.md`: *"if it can be an
extension, it is an extension — not a core change"*). It provably *can* be an extension — it is
structurally identical to `progress_contract_guard`, which already lives in a package and uses the
exact seam the persist nudge would use. Keeping it in core means:
- a WriteFile-specific behavioral policy (the nudge prose, the `[motoko-persist-nudge]` marker, the
  `MOTOKO_PERSIST_RETRIES` budget) is frozen into the minimal core;
- the budget/marker/counting machinery is duplicated (it exists once in `recovery.ail` and again,
  separately, in `session.ail`);
- core state (`C2LoopState.nudges_used`, `StateDelta.nudges_used`) and a bespoke `PersistNudge`
  event exist only to serve this one nudge, when the guards make do with `ExtSolverFeedback` and a
  history-marker count.

## Location
Core surface to move out:
- `src/core/recovery.ail:21` `persist_nudge_marker` = `"[motoko-persist-nudge]"`
- `src/core/recovery.ail:30` `any_writefile_attempt` (the trigger predicate)
- `src/core/recovery.ail:39` `count_persist_nudges` (budget accounting)
- `src/core/recovery.ail:49` `should_inject_persist_nudge(persist_budget, nudges_used, write_attempted)`
- `src/core/recovery.ail:53` `persist_nudge_message` (the hard-coded nudge prose)
- `src/core/session.ail:1908` the injection branch: `NoDecision => if should_inject_persist_nudge(...) then …PersistNudge…`
- `src/core/session.ail:93` `PersistNudge` ledger event constructor
- `src/core/session.ail:1204-1215` `MOTOKO_PERSIST_RETRIES` parsing → `policy.step.persist_retries`
- `src/core/session.ail:1202,1268` duplicate `persist_nudge_marker` / `count_persist_nudges` (should not exist twice)
- `src/core/session.ail:353` `C2LoopState.nudges_used`, `src/core/model_phase.ail:21` `StateDelta.nudges_used`

Template to mirror (an existing guard that already does this correctly):
- `packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:110` `decide_with_budget(ctx, candidate, max_feedback)`
  → `ContinueWithFeedback(guard_message())` / `NoDecision`, budget via `count_markers(ctx.history_slice) < max_feedback`.

## Fix
- Add `packages/motoko-ext-persist-guard` mirroring `progress_contract_guard`. Its `on_solver_candidate`
  returns `ContinueWithFeedback(persist_nudge_message())` when the candidate is a stop, `ctx.history_slice`
  shows no WriteFile attempt, and its own marker count is under budget; else `NoDecision`.
- Move the nudge prose, the `[motoko-persist-nudge]` marker, `any_writefile_attempt`, and the budget/count
  logic into that package. Keep the exact nudge text and the WriteFile-attempt semantics for behavior parity.
- Delete the core `NoDecision => should_inject_persist_nudge` branch (`session.ail:1908`). The solver-candidate
  chain — now including persist-guard in registry order — handles it uniformly, so the fall-through is just
  `c2_after_dp7` (finalize).
- Remove `nudges_used` from `C2LoopState`/`StateDelta`, drop `should_inject_persist_nudge`/`persist_nudge_*`
  from `recovery.ail`, and remove the duplicate copies in `session.ail`. Budget is enforced by the extension
  counting its own marker in `ctx.history_slice`, exactly like the other two guards.
- Emit `ExtSolverFeedback` (as the guards do) and drop the dedicated `PersistNudge` event, OR keep the event
  name for ledger continuity but source it from the extension path — decide during implementation.
- Register `persist_guard` in the relevant profiles' `extensions.order`; move the `MOTOKO_PERSIST_RETRIES`
  budget into the extension's config (with a documented migration for anyone setting the env var today).
- Add package-level deterministic tests mirroring `progress_contract_guard`'s (nudges on stop-without-write
  within budget; `NoDecision` when a write was attempted, when over budget, and on a blank candidate owned by
  `empty_stop_guard`).

## Non-goals
- Do not change what the nudge *says* or when it fires — this is a relocation for architectural parity, not a
  behavior change. Live/DST output should be identical modulo the event name.
- Do not change core's stop/finalize semantics or the ordering guarantee that `empty_stop_guard` owns the
  blank-candidate case.
- Do not touch compaction, retry, or the tool-call/finalize branching.
- Do not drop `MOTOKO_PERSIST_RETRIES` support without a config-side replacement.
