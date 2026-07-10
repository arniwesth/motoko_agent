# PLAN: compaction control capsule

**Status**: Plan (not started). This is an extension-side refinement to the AI compactor summary
format. It is deliberately separate from `.agent/issues/silent-empty-stop-finalize.md`, which covers
what core should do after the model returns a premature `stop`.

**Source issue**: `../../issues/compaction-summary-loses-task-control-state.md`.

**Observed failure**: latest live run
`.motoko/logfile/session_2026-07-10T10-35-14-469Z.jsonl` ended cleanly at step 47 with
`finish_reason:"stop"` and "What would you like to work on?" after AI compaction summarized the
working window down to 12 messages. The model interpreted the compacted context as a fresh context
handoff, not a continuation of the original stress task.

---

## TL;DR

The previous compactor-strategy fix made compaction effective, but the live stress run exposed a
new upstream control-loss problem: the AI summary shrank the sent window correctly, then Qwen read
the `[CONTEXT SUMMARY]` as a fresh-session handoff and stopped at step 47. Do **not** solve this by
changing core stop/finalize behavior here; that is already tracked by
`.agent/issues/silent-empty-stop-finalize.md`.

Fix the AI compactor summary format so task-control state is deterministic, not summarizer-dependent:
wrap the AI prose in a runtime control capsule containing `ctx.task`, current step/model, "this is not
a fresh session", active continuation/stop obligations, and mirrored runtime-status facts when
available. Harden the summarizer prompt too, but treat it as quality improvement only; correctness
comes from the deterministic capsule. Verify with direct compactor tests and a DST where the
summarizer returns hostile prose such as "What would you like to work on?".

---

## Blast Radius

| File | Kind | Change |
|------|------|--------|
| `packages/motoko-ext-compaction-ai/compaction_ai.ail` | **extension** | Replace `summary_msg(summary)` with a context-aware control-capsule builder; thread `ctx` and optional status facts into the compacted summary message; harden `summarization_prompt`; add pure extraction helpers for latest `MotokoRuntimeStatus` facts; add unit tests. |
| `scripts/long_qwen_compaction_dst.ail` | test | Add a deterministic direct-compactor scenario with a hostile/weak summarizer and a task containing explicit stop/status obligations; assert the compacted payload preserves the capsule and still passes `validate_compactor_output`. |
| `.agent/issues/compaction-summary-loses-task-control-state.md` | docs | Update status when implemented. |
| `ailang.lock` | metadata | Refresh only if package content hashes change during implementation. Do not churn it for plan-only edits. |

**Expected not to touch:**
- `src/core/step_machine.ail` and `src/core/session.ail` stop/finalize behavior. That belongs to
  `.agent/issues/silent-empty-stop-finalize.md`.
- `src/core/compaction.ail` calibration.
- structural compaction (`packages/motoko-ext-compaction-structural/**`).
- retained history persistence (`st.msgs` remains full/uncompacted).
- `packages/motoko-ext-abi/types.ail`; no ABI change is needed because `ExtCtx` already exposes the
  required state.

---

## 0. Scope

Fix the AI compactor so its inserted summary cannot erase or reframe the active control contract.

In scope:
- Add deterministic task-control text around the AI-produced summary.
- Tighten the summarizer prompt so it extracts control state too.
- Preserve/mirror recent runtime status fields when present.
- Add deterministic unit/DST coverage.

Out of scope:
- Core stop/finalize guard behavior (`silent-empty-stop-finalize.md` owns it).
- Persisting compaction into retained history.
- Context calibration.
- Retained-history bounding.
- Structural compaction strategy.

---

## 1. Grounding

Current implementation:
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:53` `summarization_prompt(old_turns, recent_turns)`
  asks for a 2-3 sentence summary and generic "Current task state".
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:170` `summary_msg(summary)` emits exactly one
  assistant message: `[CONTEXT SUMMARY] ${summary}`.
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:219` `compact_with_ai(ctx, msgs, cfg)` has the
  `ExtCtx`, so it already has `ctx.task`, `ctx.step`, `ctx.model`, `ctx.context_limit`,
  `ctx.telemetry`, and `ctx.history_slice` available without ABI changes.
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:224` halves `keep_recent` at high pressure
  (`pct >= 90`). In the live profile `keep_recent=10`, so only 5 recent messages are protected when
  compaction pressure is highest.
- `src/core/session.ail:1628-1632` confirms the pre-step hook output is sent for this step only;
  compaction remains ephemeral. The full retained history persists at `session.ail:1710`.

Latest log evidence:
- `.motoko/logfile/session_2026-07-10T10-35-14-469Z.jsonl:7324`: structural only applied
  `tier=tier1 keep_last=10`.
- `.motoko/logfile/session_2026-07-10T10-35-14-469Z.jsonl:7506-7873`: AI summarized 158-178 turns
  every step from 39 to 47.
- `.motoko/logfile/session_2026-07-10T10-35-14-469Z.jsonl:7875`: step 47 sent `msg_count:12`.
- `.motoko/logfile/session_2026-07-10T10-35-14-469Z.jsonl:8001`: model stopped with a "new context
  window" handoff question.

Interpretation: the compactor is now effective at shrinking, but the replacement message is too
semantically lossy for control state. The model receives "summary of prior context" without a
deterministic statement that the original task remains active.

---

## 2. Design

### 2.1 Add a deterministic control capsule

Replace `summary_msg(summary)` with a context-aware builder, e.g.
`summary_msg(ctx, summary, control)`, that emits a fixed-format assistant message:

```text
[RUNTIME COMPACTION SUMMARY]
This message was inserted by Motoko compaction. It is not a new user request, not a fresh session,
and not permission to stop. Continue the original task.

ORIGINAL TASK:
<ctx.task>

RUNTIME STATE:
- current_step_before_request: <ctx.step>
- model: <ctx.model>
- compaction: active; older turns were summarized for this request only

ACTIVE CONTROL OBLIGATIONS:
- Continue satisfying ORIGINAL TASK.
- Do not ask what to work on next unless ORIGINAL TASK is complete.
- Preserve explicit stop conditions from ORIGINAL TASK.
- If ORIGINAL TASK requires tool/status cadence, continue that cadence.

LATEST RUNTIME STATUS:
<optional extracted status facts, or "not observed in compacted segment">

AI SUMMARY OF OLDER CONTEXT:
<summary>
```

The capsule is deterministic. The summarizer can produce a bad or incomplete summary and the
important control facts still survive.

### 2.2 Extract control facts cheaply

Minimum viable implementation:
- Use `ctx.task` verbatim for `ORIGINAL TASK`.
- Use `ctx.step`, `ctx.model`, and `ctx.context_limit` for `RUNTIME STATE`.
- Include static obligations exactly as strings.

Optional but recommended in the same work:
- Detect the latest `MotokoRuntimeStatus` tool result in `msgs` before splitting, parse only cheap
  string markers if full JSON parsing is awkward, and mirror:
  - `current_step`
  - `step_budget`
  - `finish_reason_so_far`
  - `stage_applied_total`
  - `compaction_ai_applied`
- If no status result exists, emit `LATEST RUNTIME STATUS: not observed in compacted segment`.

Do not make this extraction a hard dependency on well-formed status JSON; malformed/missing status
must still produce the deterministic capsule.

### 2.3 Tighten the summarizer prompt

Change `summarization_prompt` to include explicit instructions:
- Extract original task objective when present.
- Extract unresolved stop conditions and progress gates.
- Extract status/progress facts.
- Extract next required action.
- Do not describe this as a new session, fresh context window, or handoff.
- Do not ask the user what to do next unless the old turns show the task is complete.

This is a quality improvement, not the correctness boundary. The deterministic capsule remains the
correctness boundary.

### 2.4 Keep recent control messages under pressure

The high-pressure `keep_recent / 2` behavior is useful for relief, but it can drop exactly the recent
status/control facts the model needs. Prefer one of:
- **Mirror-only approach**: keep halving unchanged, but mirror latest status/control facts into the
  capsule. This is the smallest diff.
- **Protected-control-tail approach**: when the tail contains `MotokoRuntimeStatus`, move the split
  boundary earlier to keep that status result in `recent` if doing so does not violate pair symmetry
  and does not erase projected relief below `min_relief_pct`.

Recommendation: ship mirror-only first. It preserves current relief behavior and is easier to test.

---

## 3. Work Items

### WI-1: control capsule builder

Files:
- `packages/motoko-ext-compaction-ai/compaction_ai.ail`

Changes:
- Replace `summary_msg(summary)` with a helper that accepts `ctx` and optional status facts.
- Thread `ctx` into the compacted message construction at `compact_with_ai`.
- Keep `summary_msg` content as a single assistant message with no tool calls, preserving compactor
  output shape.

Tests:
- Direct compactor unit test with a hostile summary string like `"What would you like to work on?"`.
- Assert the compacted output contains:
  - `[RUNTIME COMPACTION SUMMARY]`
  - `ORIGINAL TASK`
  - `not a fresh session`
  - `Continue the original task`
  - the exact `ctx.task`

### WI-2: prompt hardening

Files:
- `packages/motoko-ext-compaction-ai/compaction_ai.ail`

Changes:
- Extend `summarization_prompt` wording to ask for task objective, stop conditions, status/progress,
  next action, and "do not frame as fresh context".

Tests:
- Unit test can inspect the prompt indirectly only if a helper is exported or made testable. If not,
  keep this covered by direct source review and DST behavior.

### WI-3: latest status/control facts

Files:
- `packages/motoko-ext-compaction-ai/compaction_ai.ail`

Changes:
- Add a pure extractor over `[Msg]` that finds the latest tool message content containing
  `"tool":"MotokoRuntimeStatus"`.
- For MVP, extract by robust `contains`/substring-style helpers or copy a bounded excerpt from that
  tool message. Avoid fragile full JSON parsing unless local helpers make it simple.
- Include extracted facts or excerpt in `LATEST RUNTIME STATUS`.

Tests:
- Direct unit test with an old `MotokoRuntimeStatus` tool result outside the preserved tail. Assert
  the final summary message still contains `current_step` / `step_budget` or the bounded status
  excerpt.

### WI-4: deterministic live-shape DST

Files:
- `scripts/long_qwen_compaction_dst.ail`

Changes:
- Add a direct compactor scenario using `summary_ports("What would you like to work on?")`.
- Use a task with explicit stop/control conditions.
- Assert `validate_compactor_output` still accepts the output and the summary capsule preserves the
  task/control fields.

Gate:
- `make compaction_dst`
- `make conformance`

---

## 4. Acceptance Criteria

- AI compaction output contains a deterministic control capsule on every `Compacted` path.
- A bad/weak summarizer cannot erase:
  - original task
  - "not a fresh session"
  - continue obligation
  - explicit stop/status cadence obligations
- Latest runtime status/progress is mirrored when available.
- Existing compactor invariants still pass:
  - system prefix preserved
  - tool pairing preserved
  - deterministic replay
  - artifact cache effective
- Latest live failure shape has a direct deterministic regression test.

Required gates:
- `make compaction_dst`
- `make conformance`

---

## 5. Non-Goals And Guardrails

- Do not change `src/core/step_machine.ail` stop finalization here. The stop guard is tracked by
  `.agent/issues/silent-empty-stop-finalize.md`.
- Do not change `src/core/session.ail` history persistence (`st.msgs` remains full/uncompacted).
- Do not change `src/core/compaction.ail` calibration.
- Do not make the summary cache persist compaction into retained history.
- Do not rely on the summarizer to obey the prompt for correctness.

---

## 6. Notes For Implementer

- `ctx.task` may be long. For live stress tasks, preserving it verbatim is valuable. If a cap is
  needed, cap from the end only after preserving the first sentence and any stop-condition lines.
- The live profile currently has `max_steps:100` while the stress prompt asks for 200
  (`.motoko/config/qwen36-compaction-live/config.json:5`). That mismatch should be fixed separately;
  do not hide it inside the compactor.
- A future rate-limit default change may reduce repeated AI compaction calls, but it does not remove
  the need for this capsule. Any compaction summary that replaces old control-bearing turns must
  preserve the control contract deterministically.
