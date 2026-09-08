# PLAN: progress-contract finalize guard extension

Implements a new sibling finalize guard under the **ADR-001 harness policy boundary**. This is **not**
the D4 persist-nudge migration: D4 is a behavior-preserving move of the WriteFile/coding-specific
persist-nudge out of core. This plan addresses a different live failure mode: a model emits a
non-empty `finish_reason:"stop"` response while its own text says the task is still in progress.

Status: Proposed
Pinned toolchain: AILANG **v0.26.0** (`ailang.lock` -> `ailang_version: "v0.26.0"`)
Grounded at: branch `arniwesth/mot-36-compactor-strategy-refinement`, HEAD observed during analysis
`127bfc3`, with local empty-stop-guard implementation changes present. Re-grep all line anchors at
implementation time.

---

## TL;DR

Add a new extension, **`progress_contract_guard`**, whose `on_solver_candidate` returns
`ContinueWithFeedback(...)` when all of these are true:

1. The task/history establishes an explicit progress contract, such as `200 phases`, `Step X/Y`,
   `continue until`, `do not stop early`, or required `MotokoRuntimeStatus` checks. The current
   candidate must not be the only source of this contract.
2. The stop candidate is non-empty but self-identifies as incomplete, for example:
   `Continuing Phase 52`, `Step 53/200`, `Context is growing`, `remaining`, `not complete`, or
   similar continuation language.
3. The stop candidate does **not** explicitly claim a valid completion or allowed stop condition
   (`reached 200/200`, `task complete`, `runtime compacted`, etc.).
4. The guard's history-counted budget is not spent.

The guard is intentionally conservative: it catches **self-contradictory stops** ("I am continuing"
plus `finish_reason:"stop"`), not every stop before an inferred target. Core stays unchanged; this is
extension-side policy using the existing `on_solver_candidate` seam.

---

## Triggering incident

Latest live run analyzed:
`.motoko/logfile/session_2026-07-10T12-29-31-126Z.jsonl`

Terminal records:

- Loaded extensions: `empty_stop_guard, compaction_ai, context_mode, exa_search,
  compaction_structural`.
- Final `thinking`: step `59`, `finish_reason:"stop"`, `tool_calls:0`, non-empty text.
- Final `done.output` begins `**Phase 51 complete.** Step 53/200...` and ends
  `Context is growing. Continuing Phase 52.`
- Event counts: `empty_stop_finalize=0`, `ext_solver_feedback=0`, `persist_nudge=0`.
- Compaction was active immediately before termination:
  - step 49-51: structural tier1
  - step 52 onward: repeated AI compaction
  - final pre-stop compaction: `AI-summarized 259 turns (79% -> 4%)`
- Final sent window was compacted (`provider_call_prepared` step 59: `msg_count:14`,
  `estimated_input_tokens:9816`) while the retained/uncompacted history was much larger.

Conclusion: the empty-stop guard behaved correctly; there was no blank response. The model stopped
prematurely with substantive text that explicitly said it was continuing. This needs a separate
progress-contract guard, not D4 persist-nudge.

Important nuance: the live task text allowed stopping after runtime compaction ("or until the runtime
compacts"). A final answer that says "runtime compaction occurred; final summary" should **not** be
rejected by this guard. The triggering bug is narrower: the model finalized while saying it was
continuing.

---

## Verified seam assumptions

Re-verify at implementation HEAD, but the empty-stop implementation just proved these seams:

- `on_solver_candidate(ctx: ExtCtx, candidate: string) -> FinalizeDecision` already runs on non-tool
  stop candidates.
- `ContinueWithFeedback(feedback)` already loops by emitting `ExtSolverFeedback`, setting
  `last_finish_reason:"solver_feedback"`, and injecting a user message on the next decision.
- `ctx.task` and `ctx.history_slice` are available to the extension.
- `ctx.history_slice` is built from the full append-only history (`st.msgs ++ [assistant]`), not the
  compacted provider payload. This is important: the guard can count its own marker messages and can
  inspect earlier `MotokoRuntimeStatus` tool outputs even after provider-side compaction.
- `ctx.history_slice` includes the current assistant candidate because the hook context is built
  after appending the assistant response. The guard must account for this and avoid using the
  candidate itself as the sole proof of a progress contract.
- `merge_finalize_decisions` gives the first `ContinueWithFeedback` in registry order precedence.

No ABI change is expected for v1. If implementation finds the extension cannot reliably observe
`MotokoRuntimeStatus` outputs through `ctx.history_slice`, record that as an ADR/ABI gap before
expanding scope.

---

## Non-goals

- Do not change core finalize semantics.
- Do not change compaction.
- Do not implement or modify D4 persist-nudge migration.
- Do not make a broad "all stops before target are invalid" rule.
- Do not parse arbitrary natural-language plans. v1 only catches explicit progress contracts and
  self-contradictory stop text.

---

## Work items

### WI-1 - Extension package `motoko-ext-progress-contract-guard`

New files under `packages/motoko-ext-progress-contract-guard/`:

- `progress_contract_guard.ail`
- `register.ail`
- `ailang.toml`
- package-local `ailang.lock` if package-local checks require it

Naming convention:

- Directory: `motoko-ext-progress-contract-guard`
- Module/package: `sunholo/motoko_ext_progress_contract_guard`
- Registry/profile token and hook id: `progress_contract_guard`
- Version: `0.1.0`

Core pure API in `progress_contract_guard.ail`:

- `guard_marker() -> string`, e.g. `[motoko-progress-contract-guard]`
- `guard_message() -> string`
- `budget() -> int`, default `2`
- `count_markers(history: [Msg]) -> int`
- `has_progress_contract(ctx: ExtCtx, candidate: string) -> bool`
- `candidate_self_reports_incomplete(candidate: string) -> bool`
- `candidate_claims_complete_or_allowed_stop(candidate: string) -> bool`
- `decide(ctx: ExtCtx, candidate: string) -> FinalizeDecision`
- `decide_with_budget(ctx: ExtCtx, candidate: string, max_feedback: int) -> FinalizeDecision`
  for deterministic DSTs

Decision rule:

```ailang
if trim(candidate) != ""
   && has_progress_contract(ctx, candidate)
   && candidate_self_reports_incomplete(candidate)
   && not candidate_claims_complete_or_allowed_stop(candidate)
   && count_markers(ctx.history_slice) < budget()
then ContinueWithFeedback(guard_message())
else NoDecision
```

Suggested feedback:

```text
You stopped while your own response indicates the task is still in progress. Continue the existing
task now. If a progress target or runtime status requirement is present, check it and keep working
until the target or stop condition is actually met. [motoko-progress-contract-guard]
```

Gate:

```bash
AILANG_RELAX_MODULES=1 ailang check packages/motoko-ext-progress-contract-guard/register.ail
ailang test packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail
```

If package-local checks are preferred, mirror the empty-stop package's local-lock workflow.

### WI-2 - Contract detection

Implement conservative string/regex-like helpers using available `std/string` primitives. Prefer
simple normalized lowercase substring checks for v1 (`toLower(trim(...))` plus `contains`).

`has_progress_contract(ctx, candidate)` should return true if either `ctx.task` or recent/full
prior history contains strong indicators. Because `ctx.history_slice` includes the current assistant
candidate, do **not** let the candidate alone establish the contract. Implement one of these
approaches:

- Prefer `ctx.task` as the primary contract source.
- Also scan prior `ctx.history_slice` messages, excluding the trailing assistant message when its
  content equals `candidate`.
- Or scan only non-assistant prior messages for v1 if that is simpler and still catches the live
  task from `ctx.task`.

Strong indicators, after lowercase normalization:

- `do not stop early`
- `continue until`
- `at least`
- `/200` or another explicit `X/Y` progress form. Do **not** attempt full numeric parsing in v1
  unless it is already cheap and well-tested; substring detection is enough for the triggering case.
- `200 phases`, `200 model turns`, `200 steps`
- `motokoruntimestatus`
- `current_step`
- `step_budget`
- `below the target`

Do not require all of these. The triggering Qwen task contains several strong markers:
`at least 200`, `do not stop early`, `STEP-GATE`, `MotokoRuntimeStatus`, `current_step`,
`step_budget`.

Open question for implementation: whether to scan all history or only the task plus recent N
messages. Full history is acceptable for v1 because the hook already receives it and the live task
sizes are modest for extension-side substring checks; cap to recent N only if performance becomes
visible in `make live_*` runs.

### WI-3 - Candidate incompleteness detection

`candidate_self_reports_incomplete(candidate)` should be narrow. It should fire on:

- `continuing`
- `continue with`
- `continue to`
- `continuing phase`
- `next phase`
- `context is growing`
- `remaining`
- `not complete`
- `not done`
- `below target`
- `step ` combined with `/`, unless completion/allowed-stop wording is also present
- `phase ` combined with `continuing` or `next`, unless completion/allowed-stop wording is also
  present

The triggering candidate contains both `Step 53/200` and `Continuing Phase 52`, so this can be
caught without sophisticated parsing.

`candidate_claims_complete_or_allowed_stop(candidate)` should be checked as an override. It should
return true on clear completion or allowed-stop language:

- `task complete`
- `complete. final`
- `final answer`
- `reached 200/200`
- `step 200/200`
- `target met`
- `runtime compacted`
- `runtime compaction occurred`
- `compaction occurred`
- `compaction has occurred`

Treat `final summary` as an override only when paired with another completion/allowed-stop marker
such as `reached`, `200/200`, `task complete`, `runtime compacted`, or `compaction occurred`. A bare
`final summary` substring is too broad because a model can mention it while saying it is *not* yet
final.

This override is required because the motivating live task permits stopping after compaction. The
guard should not force continuation when a candidate explicitly says an allowed stop condition has
been reached.

Negative examples that must return `NoDecision`:

- `Task complete. Final answer: ...`
- `Reached 200/200. Final summary: ...`
- `Runtime compaction occurred. Final summary: ...`
- ordinary short final prose with no continuation markers
- empty/blank candidate, which belongs to `empty_stop_guard`

### WI-4 - Register and profile inclusion

Add `"sunholo/motoko_ext_progress_contract_guard@0.1.0"` to `ailang.toml [dependencies]` and
`[extensions].packages`, then regenerate `src/core/ext/registry_generated.ail` with:

```bash
ailang lock
ailang generate-extension-registry
```

Profile order:

- `empty_stop_guard` first
- `progress_contract_guard` second
- compaction/search/tooling extensions after that
- future D4 `persist_nudge` coding guard should come after these and should early-return
  `NoDecision` on blank input

Add to at least:

- `.motoko/config/default/config.json`
- `.motoko/config/dogfood/config.json`
- `.motoko/config/openrouter/config.json`
- `.motoko/config/qwen36-compaction-live/config.json`
- `.motoko/config/hunyuan3-free-compaction-live/config.json`

Leave deliberately bare DST/bench profiles alone unless the test specifically constructs the hook.

Gate:

```bash
make check_core
make verify_extensions
```

### WI-5 - DST coverage

Add scenarios to `scripts/phase_c2_wiring_scenarios.ail` or a dedicated script if the file gets too
large. Use the same direct-hook pattern as the empty-stop guard DST.

Required scenarios:

1. **Catches latest failure shape**
   - task includes `Do not stop early`, `MotokoRuntimeStatus`, `current_step`, `step_budget`, and
     `at least 200`.
   - scripted candidate:
     `**Phase 51 complete.** Step 53/200. Context is growing. Continuing Phase 52.`
   - expected decisions:
     `["CallModel","InjectUserMessage","CallModel","Finalize"]` when followed by a genuine final
     candidate.
   - Implementation detail: the current `run_scripted(rt, script)` helper hardcodes task as
     `"task"`, so add a `run_scripted_task(rt, task, script)` helper or equivalent. Do not rely on
     the default `history()` user message to carry the contract unless you deliberately construct a
     contract-bearing history.

2. **Budget exhaustion finalizes**
   - same candidate repeated with budget `2`
   - first two stops inject feedback
   - third stop returns `NoDecision` and finalizes
   - no new core floor event is required; the final output is non-empty and observable in `done`.

3. **Blank candidate belongs to empty-stop guard**
   - progress guard alone returns `NoDecision` on `""`
   - combined chain with `empty_stop_guard` before progress guard produces empty-stop feedback.

4. **Legitimate final completion passes**
   - candidate says `Reached 200/200. Final summary: ...`
   - expected decisions: `["CallModel","Finalize"]`

5. **Allowed compaction stop passes**
   - task includes `continue until ... or until the runtime compacts`
   - candidate says `Runtime compaction occurred. Final summary: ...`
   - expected decisions: `["CallModel","Finalize"]`

6. **No explicit progress contract passes**
   - candidate contains `continuing` in ordinary prose but task/history has no progress contract
   - expected decisions: `["CallModel","Finalize"]`

Gate:

```bash
make phase_c_l1
```

Sequencing note: the DST imports the new package module directly, so WI-1 and the `ailang.toml` /
`ailang.lock` parts of WI-4 must land before WI-5 compiles. The profile-order edits in WI-4 are not
needed for the direct-hook DSTs.

### WI-6 - Live-run validation

After `make` gates pass, run:

```bash
make live_qwen36_compaction_heavy_headless
```

Expected behavior if the model repeats the latest failure pattern:

- The log contains `ext_solver_feedback` with the progress guard marker.
- The run does not finalize on a candidate containing `Continuing Phase` / `Step X/200`.
- If the model later genuinely completes or budget exhausts, the final `done` is non-empty and
  ordinary.

Because live model behavior is nondeterministic, this is a smoke validation, not the acceptance
gate. The DSTs are the deterministic gate.

---

## Interaction with existing and future guards

### Empty-stop guard

`empty_stop_guard` should stay first in profile order. `progress_contract_guard` must return
`NoDecision` for blank/whitespace candidates so the empty-stop guard owns that simpler case.

### Persist-nudge migration (D4)

D4 remains separate. It should not be broadened to solve progress-contract stops. When D4 is later
implemented:

- It should be loaded only in coding-oriented profiles unless a profile explicitly wants WriteFile
  behavior.
- It should come after `empty_stop_guard` and `progress_contract_guard`.
- It should preserve current WriteFile-specific behavior unless its own plan intentionally revises
  that contract.

### Accept hooks

If a future extension returns `Accept(output)` on the same candidate, any
`ContinueWithFeedback(...)` from this guard wins per current `merge_finalize_decisions` precedence.
This is desirable: a self-contradictory "I am continuing" stop should not be accepted as final.

---

## False-positive policy

The guard must bias toward low false positives:

- Do not trigger on non-empty final answers unless the answer itself indicates incompletion.
- Do not trigger when the candidate explicitly claims completion or an allowed stop condition.
- Do not trigger on continuation words without an explicit progress contract in task/history.
- Do not trigger on blank output.
- Keep a small budget, default `2`.

The intended invariant is not "the model must satisfy every inferred task target." The invariant is:
**a model should not finalize while its own stop candidate says it is continuing or below an explicit
progress target.**

---

## Blast Radius

| File | Kind | Change |
|------|------|--------|
| `packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail` | **extension (new)** | Pure guard logic: marker/message, budget, marker counting, progress-contract detection, incomplete-candidate detection, completion/allowed-stop override, `decide` / `decide_with_budget`, unit tests. |
| `packages/motoko-ext-progress-contract-guard/register.ail` | **extension (new)** | `register_with_config` returning `ExtensionHooks` with only `on_solver_candidate` active; all other hooks no-op, mirroring `empty_stop_guard` / `compaction_structural`. |
| `packages/motoko-ext-progress-contract-guard/ailang.toml` | package metadata | Package manifest for `sunholo/motoko_ext_progress_contract_guard@0.1.0`. |
| `packages/motoko-ext-progress-contract-guard/ailang.lock` | package metadata | Add only if package-local checks need it, matching the empty-stop package workflow. |
| `ailang.toml` | workspace metadata | Add path dependency and `[extensions].packages` entry for `sunholo/motoko_ext_progress_contract_guard@0.1.0`. |
| `ailang.lock` | workspace metadata | Refresh after adding the package. |
| `src/core/ext/registry_generated.ail` | **generated** | Regenerate with `ailang generate-extension-registry`; gains the `"progress_contract_guard"` resolve arm. Do not hand-edit. |
| `.motoko/config/default/config.json` | profile config | Add `progress_contract_guard` after `empty_stop_guard` in `extensions.order`. |
| `.motoko/config/dogfood/config.json` | profile config | Add `progress_contract_guard` after `empty_stop_guard` in `extensions.order`. |
| `.motoko/config/openrouter/config.json` | profile config | Add `progress_contract_guard` after `empty_stop_guard` in `extensions.order`. |
| `.motoko/config/qwen36-compaction-live/config.json` | profile config | Add `progress_contract_guard` after `empty_stop_guard` in `extensions.order`. |
| `.motoko/config/hunyuan3-free-compaction-live/config.json` | profile config | Add `progress_contract_guard` after `empty_stop_guard` in `extensions.order`. |
| `scripts/phase_c2_wiring_scenarios.ail` | test | Add direct-hook runtime, `run_scripted_task(...)`, and DST scenarios for latest failure shape, budget exhaustion, blank-candidate ownership, legitimate completion, allowed compaction stop, and no-contract pass-through. |

Expected **not** to touch:

- `packages/motoko-ext-abi/types.ail` — no ABI change expected.
- `src/core/session.ail` — no core finalize mechanism change.
- `src/core/step_machine.ail` — no decision-machine change.
- `src/core/recovery.ail` — D4 persist-nudge migration remains separate.
- `src/core/phase_vocab.ail` — no new core ledger event for non-empty progress-contract stops.
- Compaction modules/packages — this guard only reacts at the finalize seam.

---

## Verification

Required before commit:

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

---

## ADR gaps found

None known yet for v1. The existing ABI appears sufficient because the extension has `ctx.task`,
`ctx.history_slice`, and the candidate text.

Potential gap to verify during implementation: whether `MotokoRuntimeStatus` tool results in
`ctx.history_slice` remain easy enough to inspect after multiple compaction cycles. If not, the
extension can still catch the triggering failure from `ctx.task` plus the candidate text
(`Step 53/200`, `Continuing Phase 52`), but richer status-aware guarding may need structured
runtime progress in `ExtCtx` later.
