# Handoff: implement the compaction control capsule

Date: 2026-07-10 (written after the live Qwen heavy run exposed control-state loss and after
`PLAN-compaction-control-capsule.md` was reviewed until no major issues remained).
Audience: a fresh implementer session. **The plan is the spec**:
`PLAN-compaction-control-capsule.md` in this directory. This handoff carries only the residual
context that is easy to lose: current state, reading order, guardrails, and the traps already found
during review.

## Why this work exists

The compactor-strategy refinement made AI compaction effective at shrinking the sent window, but the
latest live run (`.motoko/logfile/session_2026-07-10T10-35-14-469Z.jsonl`) exposed a new upstream
failure: after repeated AI summaries, Qwen interpreted `[CONTEXT SUMMARY]` as a fresh-session handoff
and returned `finish_reason:"stop"` with "What would you like to work on?" at step 47. This is not
the already-planned stop/finalize issue. Core still needs its separate stop guard, but this work fixes
the compactor's replacement message so task-control state survives deterministically before the model
is called.

## Current state

- Branch: `arniwesth/mot-36-compactor-strategy-refinement`.
- HEAD when this handoff was written: `5ce2cf7` (`Plan review`).
- The reviewed plan and source issue are already committed:
  - `PLAN-compaction-control-capsule.md`
  - `../../issues/compaction-summary-loses-task-control-state.md`
- The strategy implementation from the prior work is already in HEAD (`7a8177c`), including:
  structural tier-by-result, AI batching/no-op/rate-limit, and status relabeling.
- `ailang.lock` is modified in the worktree from prior/live-run state. Do not treat it as part of
  this handoff unless your implementation changes package content hashes and you intentionally
  refresh it.

## Reading order

1. `PLAN-compaction-control-capsule.md` — **the spec.** Read the TL;DR, Blast Radius, §2 design, and
   §3 work items before opening code.
2. `../../issues/compaction-summary-loses-task-control-state.md` — the normative issue and failure
   description.
3. `../../issues/silent-empty-stop-finalize.md` — only to understand the boundary. Do not implement
   that issue here.
4. Current code, re-grepping symbols at your HEAD before trusting line numbers:
   - `packages/motoko-ext-compaction-ai/compaction_ai.ail`
   - `scripts/long_qwen_compaction_dst.ail`
   - `packages/motoko_ext_conformance/invariants.ail`
   - `src/core/session.ail` only for understanding `MotokoRuntimeStatus` shape, not for edits.

## Scope guardrails

- This is an **extension-side AI compactor summary-format change** plus deterministic DST coverage.
- Do not change core stop/finalize behavior (`src/core/step_machine.ail`, `src/core/session.ail` loop
  finalization). That belongs to `silent-empty-stop-finalize.md`.
- Do not change `src/core/compaction.ail` calibration.
- Do not change structural compaction.
- Do not persist compaction into retained history or mutate the append-only `st.msgs` model.
- Do not change `packages/motoko-ext-abi/types.ail`; `ExtCtx` already exposes `task`, `step`, `model`,
  `context_limit`, telemetry, artifacts, and history slice.

## Traps ranked by cost

1. **Cache only AI prose, never the full capsule.**
   The capsule includes request-local facts (`ctx.task`, `ctx.step`, model, latest status). The
   existing cache is keyed by old-turn digest, so caching the entire capsule would replay stale
   step/status/task fields. Keep `cached_summary` / `cache_artifact` about the summarizer prose only,
   then rebuild the capsule every `Compacted` decision.

2. **Correlate runtime status by tool call id.**
   Do not search arbitrary tool content for `MotokoRuntimeStatus` and call it done. The reliable
   transcript shape is: assistant message has `tool_calls` with `name == "MotokoRuntimeStatus"`;
   the result is the tool message with matching `tool_call_id`. A content marker fallback is okay for
   legacy fixtures, but a random unrelated tool result mentioning the string must not win over a
   correlated status result.

3. **Keep the capsule bounded.**
   `ctx.task` should survive because it is the control contract, but runtime-status mirroring must not
   re-inflate context. Prefer whitelisted facts (`current_step`, `step_budget`,
   `finish_reason_so_far`, `stage_applied_total`, `compaction_ai_applied`) or a tightly bounded
   excerpt. Do not paste a full large tool result into `LATEST RUNTIME STATUS`.

4. **Validate the compactor segment, not a sealed payload.**
   `validate_compactor_output(input, out)` rejects system messages by design. Direct DST tests should
   pass the same unpinned segment given to `compact_with_ai`, not a final sealed message list that
   includes system prefix.

5. **Update existing direct DST expectations.**
   `scripts/long_qwen_compaction_dst.ail` currently has direct scenarios that assert
   `[CONTEXT SUMMARY]`. After this change they should assert `[RUNTIME COMPACTION SUMMARY]`, cached AI
   prose reuse, exact task preservation, and validator success.

6. **Make the direct context task-aware before asserting exact task text.**
   The current `direct_ctx(...)` helper hardcodes `task: "direct"`. For the hostile summarizer
   scenario, add `direct_ctx_with_task(...)` or extend the helper to accept a task string.

7. **Prompt hardening is not the correctness boundary.**
   Improve `summarization_prompt`, but tests must pass even when the summarizer returns hostile prose
   like "What would you like to work on?". Correctness comes from deterministic capsule text.

## Suggested implementation order

1. Add a pure capsule builder in `packages/motoko-ext-compaction-ai/compaction_ai.ail`.
   Keep it a single assistant message with no tool calls and empty `tool_call_id`.
2. Thread `ctx` and extracted status facts into the `compact_with_ai` construction path:
   `prefix ++ [summary_msg(ctx, summary, status)] ++ recent`.
3. Add runtime-status extraction helpers and unit coverage in the AI compactor module.
4. Harden `summarization_prompt`.
5. Update `scripts/long_qwen_compaction_dst.ail` direct scenarios:
   old wrapper assertion, artifact-cache assertion, and hostile-summary control-capsule scenario.
6. Run gates and fix any fallout.

## Verification

Required before commit:

```bash
make compaction_dst
make conformance
```

Expected coverage from the plan:

- AI compaction output contains `[RUNTIME COMPACTION SUMMARY]` on every `Compacted` path.
- Hostile/weak summarizer prose cannot erase original task, "not a fresh session", continue
  obligation, or stop/status cadence obligations.
- Latest runtime status facts are mirrored when available outside the preserved recent tail.
- Existing conformance still passes, especially deterministic replay and artifact-cache effectiveness.

## Commit and closeout

- Keep this as one focused implementation commit unless the implementation naturally splits into
  source and test commits.
- Update `../../issues/compaction-summary-loses-task-control-state.md` status when complete.
- If implementation diverges from the plan, add
  `NOTE-compaction-control-capsule-implementation-findings.md` in this directory and point to it from
  this handoff.

## Pre-flight

```bash
git rev-parse --short HEAD
git status --short
git log --oneline -12 -- packages/motoko-ext-compaction-ai scripts/long_qwen_compaction_dst.ail packages/motoko_ext_conformance src/core/session.ail
make compaction_dst && make conformance
```
