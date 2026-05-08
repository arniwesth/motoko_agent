---
doc_type: short
full_text: sources/TUI_Wait_State_Clarity.md
---

# TUI Wait State Clarity

This plan (2026-04-04) improves the terminal UI (TUI) to make wait states—model reasoning, delegated tool execution, and task completion—immediately clear to users.

Goal: Replace ambiguous delays with a visible state machine, spinners, elapsed timers, and phase transition messages. It spans three phases.

## Phase 1: Quick Wins
- Define a `run state` enum: `idle`, `thinking`, `tools_wait`, `tools_run`, `done`, `error`.
- Show a status spinner + timer in `thinking`, `tools_wait`, `tools_run` states.
- On `done`, append a clear handoff message: "Task complete. You can now type a follow-up."
- During active task, block plain-text input with "Input locked: task still running." (avoid misleading "Unknown command").

## Phase 2: Tool Progress Clarity
- Introduce batch counters: `total`, `running`, `done`, `failed` for delegated tools.
- Emit `tool_results` events with `phase: "progress"` after each tool finishes, updating counters incrementally.
- Add explicit phase markers in history: "Brain is reasoning...", "Waiting for delegated tool results...", etc.
- Slow-operation hints: if thinking >10s or tools batch >20s.
- Keep execution sequential in `brain.ts`; no concurrency changes yet.
- Extend `AgentEvent` to include `phase: "running" | "progress" | "done"` and ensure all consumers handle it.

## Phase 3: Polish & Observability
- Add a "last update Ns ago" indicator in status bar.
- Color accents: blue thinking, yellow tools, green done, red error.
- Optional feature-flagged compact activity log pane.

## Validation
Tests cover state transitions, counter math under mixed success/failure, input lock, timer resets, and one-hint-per-phase behavior. Integration with `npm test` ensures automation.

## Out of Scope
Future levels: concurrent tool execution and live single-tool progress streaming.

This plan aligns with the agent’s event model ([[concepts/agent-event-model]]) and state management ([[concepts/tui-run-state-machine]]). The incremental progress reporting ([[concepts/delegated-tool-progress]]) and transition markers ([[concepts/ui-transition-markers]]) ensure users always understand what the system is doing.