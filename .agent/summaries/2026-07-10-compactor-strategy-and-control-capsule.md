# 2026-07-10 compactor strategy and control capsule session

## Context

Branch: `arniwesth/mot-36-compactor-strategy-refinement`

Current HEAD at summary time: `b961ac6 Add compaction control capsule`

This session started from a handoff to implement `PLAN-compactor-strategy.md`, then shifted after the
user ran `make live_qwen36_compaction_heavy_headless` and asked why the latest run ended
unexpectedly.

## Implemented compactor-strategy refinement

Implemented and committed the compactor-strategy plan as:

- `7a8177c Implement compactor strategy refinement`

The implementation covered:

- Structural compaction selects the gentlest tier by resulting calibrated payload, rather than
  escalating from uncompacted percentage alone.
- Structural compaction preserves seal-side exhaustion semantics.
- AI compaction batches old turns, preserves tool-call/tool-result pairing, and adds a pre-call
  no-op relief guard.
- AI compaction rate-limit support is behind config and preserves same-step artifact-cache replay
  with the `gap > 0` guard.
- Runtime status context metrics were relabeled into `last_sent` and `uncompacted_pending`.

Verification run during that implementation:

- `make compaction_dst` passed.
- `make conformance` passed.

## Live Qwen heavy run analysis

User ran:

```bash
make live_qwen36_compaction_heavy_headless
```

Latest log analyzed:

- `.motoko/logfile/session_2026-07-10T10-35-14-469Z.jsonl`

Findings:

- The run ended cleanly with `finish_reason:"stop"` after `steps_executed:48`.
- The final model response at step 47 said, effectively, that it was in a new context window and
  asked what to work on next.
- Structural compaction was no longer the pathological over-elision problem: step 38 used
  `structural: tier=tier1 keep_last=10`.
- AI compaction was effective at shrinking: steps 39-47 summarized large batches, including final
  windows around `AI-summarized 178 turns (86% -> 3%)`.
- Final sent window at step 47 was only `msg_count:12` / about `estimated_input_tokens:9333`.
- The problem was therefore not "compaction did not shrink" or "structural emergency gutted the
  context"; it was that the `[CONTEXT SUMMARY]` replacement message did not preserve enough
  task-control state, causing Qwen to treat the compacted window as a fresh handoff.
- The run also surfaced a separate profile mismatch:
  `.motoko/config/qwen36-compaction-live/config.json` uses `max_steps:100` while the stress task asked
  for 200 steps. This was noted as separate from the summary-control issue.

## New issue and plan

Created issue:

- `.agent/issues/compaction-summary-loses-task-control-state.md`

Created and iteratively reviewed plan:

- `.agent/projects/006_compactor_strategy/PLAN-compaction-control-capsule.md`

The plan defines an extension-side AI compactor summary-format fix:

- Replace `[CONTEXT SUMMARY]` with a deterministic `[RUNTIME COMPACTION SUMMARY]` capsule.
- Include `ctx.task`, current step/model/context state, "not a fresh session" semantics, continue/stop
  obligations, and mirrored runtime-status facts when available.
- Harden the summarizer prompt, but keep correctness in deterministic capsule text rather than in
  summarizer compliance.
- Add deterministic tests with hostile summarizer prose such as "What would you like to work on?"

The plan explicitly separates this from:

- `.agent/issues/silent-empty-stop-finalize.md`, which owns core behavior after a premature model
  `stop`.

## Plan review hardening

The reviewed plan was improved with:

- TL;DR and Blast Radius sections.
- Cache guidance: cache only AI prose, not the full capsule, because the capsule contains
  request-local `ctx.task`, `ctx.step`, model, and status facts.
- Runtime-status extraction guidance: correlate assistant tool calls named `MotokoRuntimeStatus` to
  tool results by `tool_call_id`; do not rely only on content markers.
- Bounded status mirroring: use whitelisted fields or a tight excerpt, not full large tool output.
- Validation guidance: call `validate_compactor_output(input, out)` on the unpinned compaction
  segment passed to `compact_with_ai`, not on a sealed payload containing system messages.
- DST guidance: update existing direct assertions expecting `[CONTEXT SUMMARY]`; add or extend
  `direct_ctx` so exact task preservation can be tested with a non-default task string.

Plan-related commits present in current history:

- `e9eecb0 Added plan`
- `588e878 Added TL.DR and blast radius`
- `5ce2cf7 Plan review`
- `b961ac6 Add compaction control capsule`

## Handoff

Created a new implementation handoff:

- `.agent/projects/006_compactor_strategy/HANDOFF-implement-compaction-control-capsule.md`

It points the next agent at the reviewed plan and ranks the implementation traps:

- cache only AI prose;
- correlate runtime status by `tool_call_id`;
- keep capsule content bounded;
- validate compactor segments, not sealed payloads;
- update old `[CONTEXT SUMMARY]` DST assertions;
- make direct context task-aware;
- treat prompt hardening as quality, not correctness.

At summary time this handoff is untracked in `git status`; commit it if it should become part of the
handoff package.

## Current worktree state

`git status --short` at summary time:

```text
 M ailang.lock
?? .agent/projects/006_compactor_strategy/HANDOFF-implement-compaction-control-capsule.md
```

`ailang.lock` was already modified from prior/live-run state and was intentionally not edited for the
docs-only plan/handoff work.

## Recommended next step

Implement `PLAN-compaction-control-capsule.md` using
`HANDOFF-implement-compaction-control-capsule.md` as the short-form guide. Before source edits, run:

```bash
git status --short
make compaction_dst && make conformance
```

After implementation, update `.agent/issues/compaction-summary-loses-task-control-state.md` status and
run both gates again.
