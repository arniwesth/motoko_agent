---
sources: [summaries/AILANG_Agent.md, summaries/think-block.md]
brief: Managing UI component state across session boundaries to prevent stale references, memory leaks, and display corruption.
---

# Session State Management

Session state management refers to the practice of correctly initializing, resetting, and transitioning UI component state when the application runtime changes context—particularly when a new session starts after a previous one has completed (e.g., follow-up tasks, task restart).

## Core Concern

Stateful UI components that accumulate data across interactions must be explicitly cleaned up on session boundaries. Failure to do so causes:

- **Stale references**: Indices or pointers into arrays that have shifted, pointing to wrong or out-of-bounds elements.
- **Unbounded growth**: Data structures accumulating content indefinitely, leaking memory.
- **Display corruption**: Old session content appearing alongside new session content.

## Manifestation in Think Block

As described in [[summaries/think-block]], the think block cycling feature is a concrete case. The `AgentUI` class maintains three pieces of state for think block navigation:

- `thinkStepOrder`: an ordered list of block identifiers
- `thinkBlocks`: a `Map` of block data keyed by identifier
- `selectedThinkIdx`: the index of the currently highlighted block (-1 when none)

On `session_start`, none of these were reset. A follow-up task would push new blocks onto `thinkStepOrder`, but `selectedThinkIdx` might still hold a value pointing to a different (or nonexistent) block from the prior session. In the worst case, this causes an out-of-bounds access.

## Fix Pattern

The fix is to hook into the session lifecycle event (`session_start`) and reset all session-scoped state:

```typescript
case "session_start":
  this.thinkStepOrder.length = 0;
  this.thinkBlocks.clear();
  this.selectedThinkIdx = -1;
  // resume existing logic
```

This also resolves a secondary issue: unbounded memory growth from retaining old think block content across sessions.

## General Principles

- **Identify session-scoped state**: Any data that logically belongs to a single session should be reset on session boundaries.
- **Prefer explicit reset over implicit**: Relying on garbage collection or overwriting is fragile; explicit zeroing communicates intent.
- **Hook into lifecycle events**: Use the `session_start` or equivalent event rather than trying to detect boundaries heuristically.
- **Consider memory**: In long-lived processes (like a TUI), unbounded accumulation leads to degraded performance.

## Related Concepts

- [[concepts/think-block]] — The UI component affected by session state mismanagement.
- [[concepts/terminal-ui-testing]] — Testing patterns that can catch state leakage across sessions.
- [[concepts/state-lifecycle]] — Broader patterns for initialization, mutation, and teardown of UI component state.
- [[summaries/think-block]] — Source document detailing the specific session reset bug.


See also: [[summaries/AILANG_Agent]]