---
doc_type: short
full_text: sources/2026-04-25-tui-context-window-counter.md
---

# TUI Context Window Counter

Added a live context-window usage counter to the TUI status bar, using a local estimate (`characters ÷ 4`) and model-aware limits with threshold coloring (yellow at ≥75%, red at ≥90%).

## Implementation Overview

- New core module `src/core/context_usage.ail` provides `estimate_tokens` and `context_limit_for`, including stripping `openrouter/` prefixes and resolving documented models (e.g., `anthropic/claude-sonnet-4-5`).
- Tests in `src/core/context_usage_test.ail` validate token estimation with non‑empty message lists.
- Runtime wiring in `src/core/rpc.ail` emits a JSONL `context_usage` event once per loop iteration, just before the AI call, carrying `step`, `tokens_est`, and `limit`.

## TUI Integration

- `src/tui/src/ui.ts` renders the counter on the status bar: `| ctx: used/limit (%)` when a limit is known, or `| ctx: used` when the model is unrecognized (`limit = 0`).
- Segment‑by‑segment construction avoids nested chalk wrapping conflicts; threshold colours are applied via `colorizeContextUsageSegment`.
- Type updates in `runtime-process.ts` add the event to the `AgentEvent` union, and test coverage asserts rendering and threshold correctness (`ui.context-counter.test.ts`).

## Model Limits and Estimation

- Limits are sourced from a built‑in mapping inside `context_usage.ail`. Unrecognised models return `0`, causing the TUI to hide the ratio.
- Token estimation uses a fixed heuristic (`character count / 4`), which is local and does not rely on provider‑reported usage. This matches the design goal of a live, fast counter that updates before each AI turn.

## Testing and Validation

- Core unit tests pass (`ailang test`).
- TUI tests pass (17 suites, 90 tests).
- No manual runtime smoke test was performed; confidence relies on automated tests and type checks.

## Related Concepts

- [[concepts/context-window]]
- [[concepts/token-estimation]]
- [[concepts/tui-status-bar]]
- [[concepts/model-limits]]
- [[concepts/rpc-events]]
- [[concepts/openrouter-model-normalization]]