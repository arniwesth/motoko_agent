# Follow-up: Durable Session Resume

## Context

Option A for issue #15 added a transient checkpoint at
`${workdir}/.motoko/session/<session_id>.json` so an interactive TUI session can
survive an ESC hard-kill and immediately respawn with context. That checkpoint is
deleted on clean exit or restart by design.

This note tracks a possible separate feature: allowing a later agent or a new TUI
process to explicitly resume a prior session.

## Why This Is Separate From ESC Recovery

The ESC checkpoint is crash-recovery state, not a durable session store:

- It contains raw model history, including tool calls, tool results, paths, command
  output, and possibly sensitive data.
- It is keyed by an internal `MOTOKO_SESSION_ID`, not a user-facing resume id.
- It has no retention policy, index, migration story, ownership checks, or selection
  UX.
- It is a step-boundary snapshot, so it may intentionally omit the interrupted
  in-flight step's partial output.
- Automatically reusing stale checkpoints risks leaking old context into unrelated
  future work.

## Candidate Design

Implement persistent resume as an explicit workflow, not by keeping transient ESC
checkpoints indefinitely.

Possible shape:

- Add a durable session store under `.motoko/sessions/` or extend the existing
  `.motoko/logfile/` JSONL transcript system with a resumable metadata index.
- Store metadata per session: id, created/updated timestamps, workdir, profile,
  model, first prompt, last prompt, status, schema version, and checkpoint path.
- Add explicit UX: `/sessions`, `/resume <id>`, maybe `/save-session` or a config
  option controlling automatic retention.
- Keep resume opt-in. A fresh agent must never inherit a prior session only because
  a checkpoint file exists.
- Add retention and privacy controls: max age/count, manual delete, and clear
  labeling that tool outputs and file paths may be stored.
- Prefer reconstructing from a durable transcript or a dedicated validated history
  store rather than treating the transient `.motoko/session/<id>.json` file as the
  public API.

## Open Questions

- Should persistent resume preserve the full typed `[Message]` history, a compacted
  summary, or both?
- Should `/restart` become resumable across profiles, or should profile changes
  always start a new logical session?
- What should happen when extension/tool schemas changed since the saved session?
- Should saved sessions be portable across machines or strictly local to a workdir?

## Acceptance Sketch

- A user can list previous sessions with enough metadata to choose the right one.
- A user can explicitly resume one session and ask a follow-up that sees prior
  context.
- A new unrelated session does not load stale context accidentally.
- Sensitive session data can be deleted predictably.
