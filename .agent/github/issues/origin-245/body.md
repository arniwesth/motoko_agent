---
repo: arniwesth/motoko_agent
issue: 245
title: "The TUI's context counter never shows: it reads context_usage, which the runtime stopped emitting in 6350b7ad"
---

## Summary

The TUI's status bar has code for a context counter (`ctx: 12.3k/200k (6%)`, yellow at 75%, red at
90%) and four tests for it. It has not been shown since 2026-05-06: the counter is filled from a
`context_usage` event, and the runtime no longer emits one. The code and its tests are dead.

Found while fixing #237 and recorded as an amendment to 013 ADR-001 D1 in #239. It has had no
issue of its own.

## Context

**On `main` @ `21a8a96a`:**

- `src/tui/src/ui.ts`: `case "context_usage"` stores `latestContextUsage`, and the status line
  appends `formatContextUsage(...)`, coloured by `colorizeContextUsageSegment(...)`, only when
  that field is set.
- `src/tui/src/runtime-process.ts`: the event is still in the `AgentEvent` union.
- `src/tui/src/ui.context-counter.test.ts`: four tests of the two formatting functions. They pass.
- No `.ail` file under `src/`, `packages/` or `scripts/` contains the string `"context_usage"`.
- `6350b7ad` ("feat(M10b): delete unreachable legacy code", 2026-05-06) removed
  `emit_context_usage` from `src/core/rpc.ail` with the loop that called it. Nothing emits the
  event today; I did not check every commit in between.

So the field is never set and the counter is never drawn.

**Why it matters more than dead code usually does.**

- 013 ADR-001 D1 named "rendering 'unmeasured' in the TUI counter" as the follow-up that would
  show an operator an unknown context limit. There was no live counter to render it in, which is
  part of why #237 went unseen. #239 used a warning instead.
- What an operator can see of the window today is the `MotokoRuntimeStatus` tool, which the model
  has to call, and nothing in the status bar.
- #32 asks for a report in the TUI each time a compaction happens. A live counter is the other
  half of the same picture.

## Expected

One of two, decided on purpose:

- **Revive it.** The runtime emits context usage once per step, with the estimate and the limit
  the compactors see. The counter then shows it, and for a limit that is `unknown` or `disabled`
  it says so, where today's `formatContextUsage` would print a bare token count. The check: a
  session shows the counter moving, and a run on a model with no window shows it marked as
  unmeasured.
- **Remove it.** The `context_usage` arm, `latestContextUsage`, the two formatting functions, the
  union member and the test file go, and the ADR's follow-up is closed as not wanted.

Reviving it adds a ledger or wire event, which has the DST vocabulary and golden consequences any
new event has; that cost is the reason to decide and not drift.
