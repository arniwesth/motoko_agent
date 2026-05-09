# TUI Wait State Clarity Plan

Date: 2026-04-04
Status: Proposed

## Expected File Changes

### Modified files

- `tui/src/ui.ts`
- `tui/src/brain.ts`
- `tui/src/index.ts`

### Added files

- `tui/src/ui.wait-state.test.ts` (new)
- `tui/src/brain.tool-progress.test.ts` (new)

## Goal

Make it obvious to users when the TUI is waiting for:

- brain/model reasoning
- delegated tool execution
- task completion handoff

## Phase 1: Quick Wins (Low Risk)

1. Add `run state` enum in UI
- States: `idle`, `thinking`, `tools_wait`, `tools_run`, `done`, `error`.
- Files: `tui/src/ui.ts`.
- Acceptance: status bar always displays one explicit state.

2. Add status spinner + elapsed timer
- Active in `thinking`, `tools_wait`, `tools_run`.
- Timer resets on state transitions.
- Files: `tui/src/ui.ts`.
- Acceptance: visible progress every 100-250ms while waiting.

3. Add completion handoff message
- On done, append: `Task complete. You can now type a follow-up.`
- Files: `tui/src/ui.ts`.
- Acceptance: users know exactly when follow-ups are accepted.

4. Improve mid-run plain-text input handling
- If task is active and user submits plain text, show:
  `Input locked: task still running. Use /abort to stop.`
- Files: `tui/src/ui.ts`.
- Acceptance: avoid misleading `Unknown command` during active task.

## Phase 2: Progress Clarity for Tools (Level 1 Scope)

5. Add delegated tool batch counters
- Track `{total, running, done, failed}` per request.
- Update from:
  - `tool_calls` (establish `total`)
  - `tool_results running` (batch entered running)
  - `tool_results progress` (new partial result event; increment `done`/`failed`)
  - `tool_results done` (batch complete)
- Files: `tui/src/ui.ts`, `tui/src/brain.ts`, `tui/src/index.ts`.
- Acceptance: status shows `tools: done/total` and `failed` count while batch is active.

6. Add explicit phase transition markers in history
- `Brain is reasoning...`
- `Waiting for delegated tool results...`
- `Tool results received. Continuing reasoning...`
- Files: `tui/src/ui.ts`.
- Acceptance: delay ownership is clear (brain vs tools).

7. Add slow-operation hints
- At >=10s thinking: `Still waiting on model...`
- At >=20s tools: `Tool batch taking longer than usual...`
- Files: `tui/src/ui.ts`.
- Acceptance: one hint per phase (no spam).

### Phase 2 Constraints (Explicitly In Scope)

- Keep delegated execution sequential in `tui/src/brain.ts` (no concurrency changes).
- Add partial progress emission from `handleToolCalls` after each tool finishes:
  - Emit `tool_results` with `phase: "progress"` and one completed result.
  - Continue emitting final `phase: "done"` with full results for compatibility.
- Update non-TTY logger to understand `phase: "progress"` (minimal line output).
- No streaming stdout/stderr changes in this phase.

### Phase 2 Protocol/Type Update Requirements

- Extend `AgentEvent` in `tui/src/brain.ts` so `tool_results.phase` is:
  - `"running" | "progress" | "done"`.
- Ensure all `tool_results` consumers handle `progress` explicitly:
  - TUI handler (`tui/src/ui.ts`)
  - Non-TTY logger (`tui/src/index.ts`)
- Preserve backward compatibility expectations in logs/UI:
  - `running` remains batch-start marker.
  - `done` remains batch-complete marker.

## Phase 3: Polish and Observability

8. Add last-update indicator
- Status bar text: `last update: Ns ago`.
- Files: `tui/src/ui.ts`.
- Acceptance: users can distinguish long-running vs stalled UI.

9. Add state color accents in status bar
- blue thinking, yellow tools, green done, red error.
- Files: `tui/src/ui.ts`.
- Acceptance: state recognized at a glance.

10. Optional compact activity log pane (feature-flagged)
- Timestamped transitions and major events.
- Files: `tui/src/ui.ts` (layout updates).
- Acceptance: toggleable; no clutter when disabled.

## Event Mapping

- `session_start` -> `idle` (or `thinking` if immediately running)
- `thinking` -> `thinking`
- `tool_calls` -> `tools_wait`
- `tool_results running` -> `tools_run`
- `tool_results progress` -> `tools_run` (update counters)
- `tool_results done` -> `thinking` (until final `done`)
- `done` -> `done`
- `error` -> `error`

## Validation Plan

1. Brain-only wait
- Prompt with long reasoning; verify spinner/timer + `thinking`.

2. Delegated tools wait
- Run 3 delegated tools with mixed durations (e.g. `sleep 3`, `sleep 7`, `sleep 11`);
  verify incremental counter updates during `tools_run` and final totals at `done`.

3. Completion handoff
- Verify follow-up accepted only after `done`.

4. Mid-run input
- Submit plain text during active run; verify `Input locked` message.

5. Abort path
- Abort mid-task; verify clear user-facing abort message and process exit.

6. Error path
- Force tool failure; verify clear error state and messaging.

7. Automated regression checks
- Add/update tests for deterministic state transitions and counters:
  - `tool_calls -> running -> progress* -> done` transition handling.
  - counter math (`total`, `done`, `failed`) under mixed success/failure.
  - input lock behavior while run is active.
  - timer reset + one-hint-per-phase behavior.
- Run `cd tui && npm test` as acceptance gate for Phase 1/2 behavior.

## Rollout Order

1. Implement Phase 1.
2. Validate with `make run_test` and long delegated batch prompt.
3. Implement Phase 2.
4. Implement Phase 3 behind small feature flags as needed.

## Future Enhancements (Out of Current Scope)

### Level 2: Concurrent delegated tool execution

- Execute independent delegated calls in parallel for faster completion and denser progress updates.
- Requires dependency/ordering policy for side-effecting tools (writes/tests/shell commands).

### Level 3: Live progress for single long-running tools

- Add streaming/heartbeat progress for an individual delegated call (stdout/stderr live updates, cancellation semantics).
- Requires execution contract changes beyond current batch-result model.
