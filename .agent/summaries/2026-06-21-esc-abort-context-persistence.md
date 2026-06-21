# ESC Abort Context Persistence Session

## Goal

Implement the plan in
`.agent/plans/steering_capability/Abort_Context_Persistence_Option_A.md` to fix issue
#15: pressing ESC mid-task killed the AILANG runtime and lost the in-memory v2
conversation history.

## Implemented

Landed Option A as separate commits on
`arniwesth/mot-17-reenable-gracefull-esc-steering-capability`:

- `9933457 tui: pass stable session id to runtime`
- `a370275 core: checkpoint v2 conversation history`
- `39f992d agent: resume v2 conversation after interrupt`
- `b9ea6c1 tui: ignore repeated escape interrupts`

Additional branch commits after implementation:

- `fa60b9e Added note on future improvements`
- `b7e3710 Implemented plan`

## Technical Summary

### Stable session id

- TUI now creates one logical `sessionId` for interactive runs.
- `RuntimeProcess` forwards `MOTOKO_SESSION_ID` to the AILANG child.
- `/restart` mints a new logical session id.

### Checkpoint writes

- `agent_loop_v2.ail` now has a `Message`/`ToolCall` JSON codec.
- The v2 loop writes `.motoko/session/<session_id>.json` at the top of `loop_v2`,
  covering step 0 and all recursive branches.
- `conversation_loop_v2` also checkpoints after a successful completed follow-up turn.
- Writes use `mkdirAllResult` and `writeFileResult`, so checkpoint failures do not abort
  the task.

### Resume after ESC

- ESC sets an interrupt flag and hard-kills the runtime as before.
- The TUI respawns immediately with `MOTOKO_RESUME=1` instead of asking for a fresh
  initial task.
- `rpc.ail` gates `session_start` so resume spawns emit only `session_resume`.
- `agent_loop_v2.ail` loads checkpoints best-effort using `readFileResult`, retries
  truncated/corrupt JSON via `std/json.repair`, and falls back to init history if
  unrecoverable.
- The UI handles `session_resume` by moving to idle/follow-up state, so the next plain
  input routes through `onUserMessage` rather than `onInitialTask`.
- Checkpoints are removed on clean exit and restart.

### Duplicate ESC line fix

- Repeated ESC key events before runtime exit could append `Task interrupted` twice.
- Added an `interruptPending` guard in `AgentUI`.
- The guard resets on `session_start`, `session_resume`, `done`, `error`, and when the
  UI is set to await a new task.

## Tests And Validation

Automated validation run during implementation:

- `make check_core`
- `make test`
- `cd src/tui && bun run build`
- `cd src/tui && bun run test`
- `ailang test src/core/agent_loop_v2.ail`
- Focused TUI tests for runtime env, stream protocol resume events, and follow-up
  routing.
- Noninteractive smoke: pre-created `.motoko/session/<id>.json`, launched with
  `MOTOKO_RESUME=1`, confirmed `session_resume` emitted with restored messages and no
  startup `session_start`.

Notes:

- `bun run test` now runs Jest via Node with `--experimental-vm-modules --runInBand`.
- The TUI suite exits successfully but still prints an existing diagnostic from
  `test/path-guard.test.ts` because that helper calls `process.exit(0)`.

## Documentation Added

- `.agent/plans/steering_capability/Abort_Context_Persistence_Option_A.md`
- `.agent/plans/steering_capability/HANDOFF_Abort_Context_Persistence.md`
- `.agent/plans/steering_capability/Persistent_Session_Resume_Followup.md`
- `.agent/prs/mot-17-preserve-context-across-esc-abort.md`

The persistent resume follow-up note explains why the current checkpoint remains
transient crash-recovery state and sketches an explicit future `/sessions` /
`/resume <id>` style feature.

## Current State

- Branch is ahead of `origin/arniwesth/mot-17-reenable-gracefull-esc-steering-capability`
  with the implementation commits.
- `.agent/prs/mot-17-preserve-context-across-esc-abort.md` is currently untracked.
- `oh-my-pi/` remains an unrelated untracked directory that was intentionally left
  untouched.

## PR Description

The PR description was written to:

`.agent/prs/mot-17-preserve-context-across-esc-abort.md`

It summarizes the branch against `origin/main`, links issue #15, lists validation, and
captures risk notes.
