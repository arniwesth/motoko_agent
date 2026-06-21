# Preserve context across ESC abort

Fixes #15

## Summary

This PR implements the Option A checkpoint/rehydrate path from
`.agent/plans/steering_capability/Abort_Context_Persistence_Option_A.md`.

Pressing ESC currently hard-kills the AILANG runtime. Because the v2 conversation
history lives in process memory, the next prompt starts from an empty context. This
change makes ESC recovery explicit:

- The TUI creates and reuses one stable `MOTOKO_SESSION_ID` for a logical session.
- The AILANG v2 loop checkpoints typed `[Message]` history to
  `.motoko/session/<session_id>.json` at step boundaries.
- After ESC, the TUI respawns the runtime with `MOTOKO_RESUME=1`.
- The runtime loads the checkpoint best-effort and emits `session_resume`.
- The UI treats the next plain input as a follow-up message, not a fresh task.
- Clean exits and restarts remove the transient checkpoint.

The checkpoint is intentionally transient crash-recovery state, not a durable session
store. A separate follow-up note captures a possible explicit persistent resume feature.

## What Changed

### TUI runtime lifecycle

- Added stable interactive session id generation and forwarding via
  `MOTOKO_SESSION_ID`.
- Added a resume flag through `spawnRuntimeProcess` / `RuntimeProcess`, exported as
  `MOTOKO_RESUME=1` only for the post-ESC respawn.
- On ESC runtime exit, respawn immediately into resume mode instead of calling
  `setAwaitingTask(true)`.
- Delete the transient checkpoint on clean exit and `/restart`.
- Ignore repeated ESC key events while the first interrupt is still pending, preventing
  duplicate `Task interrupted` lines.

### AILANG checkpoint and resume

- Added a `Message`/`ToolCall` JSON codec inside `agent_loop_v2.ail`.
- Added best-effort checkpoint writes using `mkdirAllResult` and `writeFileResult`.
- Added checkpoint loading with `readFileResult`, `std/json.repair` retry, and fallback
  to init history on missing/corrupt checkpoints.
- Added `resume_v2_conversation` and `session_resume` event emission.
- Gated `rpc.ail` so `session_start` and `session_resume` are mutually exclusive for a
  spawn.
- Kept `rpc.ail` codec-free; typed message/JSON logic stays in `agent_loop_v2.ail`.

### UI and logging

- Added `session_resume` to the TUI event protocol.
- Added UI handling that sets the run state to idle and enables follow-up routing.
- Added transcript logging for resumed sessions.
- Added a pure input-routing helper and regression coverage for the follow-up route.

### Tests and docs

- Added AILANG codec and repair-recovery tests.
- Added TUI env tests for `MOTOKO_SESSION_ID` and `MOTOKO_RESUME`.
- Added stream-protocol coverage for `session_resume`.
- Added UI routing coverage for post-resume follow-up input.
- Updated the TUI test script to run Jest under Node with ESM support via
  `bun run test`.
- Added plan and handoff docs under `.agent/plans/steering_capability/`.
- Added `Persistent_Session_Resume_Followup.md` for a future durable session resume
  feature.

### Other branch changes

- `.gitignore` now ignores `.motoko/session`.
- A few example AILANG files switch string concatenation sites to `concat([...])`.

## Validation

Automated validation run during implementation:

- `make check_core`
- `make test`
- `cd src/tui && bun run build`
- `cd src/tui && bun run test`
- Focused AILANG test: `ailang test src/core/agent_loop_v2.ail`
- Noninteractive resume smoke: pre-created `.motoko/session/<id>.json`, launched with
  `MOTOKO_RESUME=1`, and confirmed `session_resume` emitted with restored messages and
  no startup `session_start` event.

Note: `bun run test` prints an existing `test/path-guard.test.ts` diagnostic about
`process.exit(0)`, but exits successfully.

## Manual Acceptance Scenario

Expected behavior after this PR:

1. Start `make run`.
2. Ask: `Read README.md and run ailang prompt`.
3. Press ESC mid-task.
4. Ask: `What was my last prompt?`.
5. The resumed agent should reference the README task instead of reporting no prior
   context.

During the interrupted run, `.motoko/session/<id>.json` should exist. After clean exit,
the checkpoint should be removed.

## Risk Notes

- The checkpoint is a pre-step snapshot, so it does not preserve partial output from the
  interrupted in-flight step.
- Checkpoint writes are best-effort and must not abort a task.
- Corrupt/truncated checkpoint reads fall back through `json.repair`, then to init
  history if unrecoverable.
- Durable cross-session resume is explicitly out of scope for this PR.
