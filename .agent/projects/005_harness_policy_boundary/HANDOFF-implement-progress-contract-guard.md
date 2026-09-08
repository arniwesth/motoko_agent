# Handoff: implement the progress-contract finalize guard

Date: 2026-07-10
Audience: a fresh implementer session. **The plan is the spec**:
`PLAN-progress-contract-guard.md` in this directory. This handoff only carries residual context,
reading order, guardrails, and the traps found while reviewing the plan.

## Why this work exists

After the empty-stop guard was implemented, a live `make live_qwen36_compaction_heavy_headless` run
still ended unexpectedly, but not through an empty response.

Latest analyzed log:
`.motoko/logfile/session_2026-07-10T12-29-31-126Z.jsonl`

Terminal pattern:

- final `thinking`: step `59`, `finish_reason:"stop"`, `tool_calls:0`, **non-empty** text
- final `done.output`: begins `**Phase 51 complete.** Step 53/200...` and ends
  `Context is growing. Continuing Phase 52.`
- event counts: `empty_stop_finalize=0`, `ext_solver_feedback=0`, `persist_nudge=0`

So the empty-stop guard correctly did nothing. The failure is a **non-empty premature stop where the
candidate itself says the task is still in progress**. This should be handled by a sibling finalize
guard extension, not by broadening D4 persist-nudge migration.

## Current state

- Branch observed: `arniwesth/mot-36-compactor-strategy-refinement`.
- HEAD observed during plan review: `127bfc3`.
- Local worktree already includes the empty-stop implementation from the previous task:
  `packages/motoko-ext-empty-stop-guard/**`, `EmptyStopFinalize`, registry/profile edits, and DSTs.
- `PLAN-progress-contract-guard.md` has been reviewed and patched for major issues:
  - no core changes expected
  - no ABI change expected
  - progress contract cannot be proven solely by the current candidate
  - valid allowed-stop claims, especially runtime compaction, must pass through
  - DSTs need a task-bearing runner because existing `run_scripted(...)` hardcodes `"task"`

Re-run `git status --short` before editing; the worktree may be dirty from the empty-stop work and
this plan/handoff.

## Reading order

1. `PLAN-progress-contract-guard.md` — **the spec**. Read TL;DR, Work Items, False-positive policy,
   Blast Radius, Verification, and ADR gaps.
2. `ADR-001-harness-policy-boundary.md` — boundary principle: finalize policy belongs in
   extensions; core keeps mechanism and safety-floor invariants.
3. `PLAN-empty-stop-guard.md` and the existing implementation:
   - `packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail`
   - `packages/motoko-ext-empty-stop-guard/register.ail`
   - `scripts/phase_c2_wiring_scenarios.ail`
   Mirror its package shape, no-op hook shape, marker-counted budget pattern, and direct-hook DST
   style.
4. Current code, re-grepping at your HEAD:
   - `src/core/session.ail` — `mk_v2_ext_ctx`, `dispatch_solver_candidate`, and the
     `ContinueWithFeedback` arm.
   - `src/core/ext/runtime.ail` — `merge_finalize_decisions` / `first_continue`.
   - `packages/motoko-ext-abi/types.ail` — `ExtCtx`, `Msg`, `FinalizeDecision`, `ExtensionHooks`.
   - `scripts/phase_c2_wiring_scenarios.ail` and `src/core/test/stub_step.ail` — DST harness.

## Scope guardrails

- Extension work is extension-side only:
  `packages/motoko-ext-progress-contract-guard/**` + registry/profile config + DSTs.
- Do **not** touch `packages/motoko-ext-abi/types.ail`.
- Do **not** touch `src/core/session.ail`, `src/core/step_machine.ail`, `src/core/recovery.ail`, or
  `src/core/phase_vocab.ail` unless implementation proves a real plan/ABI gap.
- Do **not** start or modify D4 persist-nudge migration.
- Do **not** change compaction behavior.
- Do **not** create a broad "all stops before target are invalid" policy. The guard catches
  self-contradictory stop candidates only.

## Traps already found

1. **`ctx.history_slice` includes the current assistant candidate.** `mk_v2_ext_ctx` receives
   `msgs_with_assistant = st.msgs ++ [assistant]`, so `history_slice` includes the very candidate
   being judged. `has_progress_contract(ctx, candidate)` must not let the candidate alone establish
   the progress contract. Prefer `ctx.task`; if scanning history, exclude the trailing assistant
   message when its content equals `candidate`, or scan only prior non-assistant messages.

2. **The live task permits stopping after compaction.** The Qwen task says "or until the runtime
   compacts." A candidate like `Runtime compaction occurred. Final summary: ...` must pass through.
   Add `candidate_claims_complete_or_allowed_stop(...)` and make it override incompletion markers.

3. **A bare `final summary` substring is too broad.** Treat `final summary` as completion only when
   paired with stronger completion/allowed-stop wording such as `reached`, `200/200`,
   `task complete`, `runtime compacted`, or `compaction occurred`.

4. **The existing DST helper hardcodes `task`.** `run_scripted(rt, script)` in
   `scripts/phase_c2_wiring_scenarios.ail` passes `"task"` to `Session.run_v2_session_traced`.
   Add `run_scripted_task(rt, task, script)` for progress-contract scenarios, or deliberately build a
   contract-bearing history. The plan prefers the task-bearing helper.

5. **Blank candidates belong to `empty_stop_guard`.** `progress_contract_guard` must return
   `NoDecision` for `trim(candidate) == ""`. Profile order should be:
   `empty_stop_guard, progress_contract_guard, ...`.

6. **No numeric parser is required for v1.** The trigger is caught by substring checks:
   `Step 53/200` + `Continuing Phase 52` plus a task contract. Avoid overengineering numeric parsing
   unless you add focused tests for it.

7. **Package-local checks may need relaxed module mode.** The empty-stop package uses vendor module
   names from a hyphenated package directory, so strict path checks complain unless
   `AILANG_RELAX_MODULES=1` is set. Use the same workflow for this package.

## Suggested implementation order

1. Create `packages/motoko-ext-progress-contract-guard/` with:
   - `progress_contract_guard.ail`
   - `register.ail`
   - `ailang.toml`
   - package-local `ailang.lock` if needed
2. Implement pure helpers and unit tests:
   - `guard_marker`
   - `guard_message`
   - `budget`
   - `count_markers`
   - `has_progress_contract(ctx, candidate)`
   - `candidate_self_reports_incomplete`
   - `candidate_claims_complete_or_allowed_stop`
   - `decide_with_budget` / `decide`
3. Run narrow package gates:
   ```bash
   AILANG_RELAX_MODULES=1 ailang check packages/motoko-ext-progress-contract-guard/register.ail
   ailang test packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail
   ```
4. Add the package to `ailang.toml`, refresh lock, regenerate registry:
   ```bash
   ailang lock
   ailang generate-extension-registry
   ```
5. Add `progress_contract_guard` after `empty_stop_guard` in the real profile orders:
   - `.motoko/config/default/config.json`
   - `.motoko/config/dogfood/config.json`
   - `.motoko/config/openrouter/config.json`
   - `.motoko/config/qwen36-compaction-live/config.json`
   - `.motoko/config/hunyuan3-free-compaction-live/config.json`
6. Add DSTs in `scripts/phase_c2_wiring_scenarios.ail`:
   - latest failure shape injects and loops
   - budget exhaustion finalizes
   - blank candidate is ignored by progress guard / handled by empty-stop guard in combined chain
   - legitimate `Reached 200/200. Final summary` passes
   - allowed `Runtime compaction occurred. Final summary` passes
   - no explicit progress contract passes

## Verification

Required:

```bash
AILANG_RELAX_MODULES=1 ailang check packages/motoko-ext-progress-contract-guard/register.ail
ailang test packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail
make check_core
make phase_c_l1
make verify_extensions
```

Recommended:

```bash
make compaction_dst
make live_qwen36_compaction_heavy_headless
```

Expected deterministic DST behavior:

- latest failure shape:
  `["CallModel","InjectUserMessage","CallModel","Finalize"]`
- budget exhaustion with budget 2:
  two injections, then `NoDecision` -> `Finalize`
- blank candidate:
  progress guard alone `NoDecision`; combined chain with `empty_stop_guard` injects empty-stop
  feedback
- completion / allowed compaction stop:
  `["CallModel","Finalize"]`

## Commit and closeout

- Keep this separate from D4 persist-nudge migration.
- If implementation diverges materially from the plan, add
  `NOTE-progress-contract-guard-implementation-findings.md` in this directory and link it from the
  plan or this handoff.
- If a real ABI/core gap is found, document it under the plan's "ADR gaps found" before changing
  core.

