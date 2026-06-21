# Plan: Preserve context across ESC abort (Option A — checkpoint + rehydrate)

Fixes GitHub issue **#15 — "Aborting (Esc) in the middle of a task flushes the
context window."**

## Background

Pressing **ESC** mid-task wipes the conversation. Repro (from the issue): start a
task, ESC ~55 s in, then ask "What was my last prompt?" → the agent answers it has
no access to previous history. The follow-up runs with an empty context.

### Root cause (traced end-to-end)

The conversation history lives **only in the runtime process's memory**:

- `loop_v2` carries it as the recursive parameter `msgs: [Message]`
  (`src/core/agent_loop_v2.ail:1140+`).
- Between turns, `conversation_loop_v2` holds it as `history: [Message]`
  (`src/core/agent_loop_v2.ail:1490-1496`).

ESC is wired to a **hard kill**, not a soft abort:

- `src/tui/src/ui.ts:2140-2145` — ESC while a task runs calls `this.onInterrupt?.()`.
- `src/tui/src/index.ts:958` — `onInterrupt = () => { interrupted = true; runtimeProcess?.kill(); }` → **SIGTERM**.
- `src/tui/src/index.ts:932-935` — on process exit, the `interrupted` flag skips
  `process.exit` and calls `ui.setAwaitingTask(true)`.
- `src/tui/src/ui.ts:4000-4005` — the next plain submission routes through
  `onInitialTask` → `spawnRuntimeProcess(value, true)` — a **brand-new process with
  empty history**.

SIGTERM destroys the in-memory `[Message]` list; the respawn starts fresh. Hence the
flushed context.

### Why not "just don't kill the process" (Option B is blocked)

A soft abort that keeps the process alive would need the runtime to notice the abort
**mid-task**. It can't:

- `conversation_loop_v2` reads commands with a **blocking** `readLine()`
  (`src/core/agent_loop_v2.ail:1517`); it only runs *between* turns, and its `abort`
  handler returns `()` = **ends the session** (`:1523`).
- `loop_v2` never polls stdin between steps.
- Grounded against the AILANG docs MCP (CLI v0.24.2): **`std/io` exposes only**
  `exit`, `print`, `println`, `readLine`, `writeBytes`. `readLine() -> string ! {IO}`
  is the sole stdin primitive and it **blocks** — there is no non-blocking / poll /
  `tryRead` / fd-select variant. The in-code comment at
  `src/core/agent_loop_v2.ail:1510` confirms it ("readLine ... blocks on non-TTY
  stdin instead of returning EOF").

The legacy design (`.agent/plans/ESC_Interrupt.md`,
`.agent/plans/Abort_History_And_Omnigraph_Delete.md`) relied on a non-blocking
`check_abort()` poll in the old `src/core/rpc.ail` `rpc_loop`. That runtime is gone:
`main()` now routes `run_with_config` → `run_v2_with_conversation`
(`src/core/rpc.ail:156,237`), and the v2 rewrite dropped both the mid-step abort poll
and the abort-history preservation. So #15 is a **regression** introduced by the v2
cutover, and the original poll-based approach is not reproducible in pure AILANG today.

Conclusion: while AILANG lacks a non-blocking stdin primitive, the **only** way to
interrupt a blocking in-flight step is to kill the process. To survive that, the
history must be **persisted to disk and rehydrated on respawn**.

> A companion AILANG-side feedback item should request a non-blocking stdin / poll
> primitive so the cleaner Option B (no process churn, preserves the partial in-flight
> turn) becomes possible later. That is upstream work and out of scope for this plan.

## Goals

- After ESC, a follow-up prompt sees the full prior conversation (system + every
  user/assistant/tool message up to the last completed step).
- The fix works within current AILANG v0.24.2 — no upstream language change required.
- No behavior change to normal completion, `/abort`, Ctrl+C, `/restart`, or model
  switching.
- The checkpoint is keyed to the session so concurrent/serial sessions don't collide,
  and is cleaned up when a session ends normally.

## Non-goals

- Preserving the *partial* in-flight assistant turn (the one interrupted mid-stream).
  We checkpoint at **step boundaries**, so the interrupted step's incomplete output is
  not recovered. (Recovering it needs Option B / a non-blocking abort signal.)
- Cross-restart history for `/restart` profile changes (separate `session_suspend`
  path; can reuse the same checkpoint later but not in this plan).
- Any change to streaming, tool dispatch, or the JSONL event protocol shape.
- Multi-session history browsing / resume-by-id UX.

---

## Design overview

Three coordinated changes:

1. **Stable session id across respawn (TS).** The TUI generates one session id per
   *logical* session and passes it via `MOTOKO_SESSION_ID` to both the original and the
   ESC-respawned process. This id keys the checkpoint file. (Today
   `MOTOKO_SESSION_ID` is only set by the eval adapter; interactive runs fall back to
   `session_${now()}`, which differs per process — unusable as a stable key.)

2. **Checkpoint after each step (AILANG).** `loop_v2` serializes its `[Message]`
   history to `${workdir}/.motoko/session/<session_id>.json` after each step, and
   `conversation_loop_v2` re-checkpoints after each completed turn. Writes are
   atomic-ish (write temp + rename via two `std/fs` calls, or accept truncating
   `writeFile` since a step boundary is a consistent point).

3. **Resume on respawn (AILANG + TS).** When the TUI respawns after ESC, it sets
   `MOTOKO_RESUME=1`. `run_with_config` checks for the checkpoint; if present and
   resume is requested, it loads the persisted `[Message]` history and enters
   `conversation_loop_v2` directly (waiting for the next `user_message`) instead of
   running the fresh `init` task. The first post-ESC submission becomes a
   `user_message` appended to the restored history.

The checkpoint lives under `workdir` because the runtime's FS is sandboxed to
`AILANG_FS_SANDBOX = workdir` (`src/tui/src/runtime-process.ts:308`). The TS-side JSONL
log under `projectRoot/.motoko/logfile` is written by the TUI, not the sandboxed
runtime, so it cannot be the runtime's checkpoint target.

---

## Patch 1 — Stable, shared session id (TS)

**File:** `src/tui/src/index.ts`

In the TTY path, generate one session id up front (before the first
`spawnRuntimeProcess`) and reuse it for every respawn in the same logical session:

```ts
// One id per logical session; survives ESC respawns so the runtime checkpoint
// key is stable. New value only on /restart (fresh session).
let sessionId = `session_${new Date().toISOString().replace(/[:.]/g, "-")}`;
```

Thread it into `RuntimeProcess` so it is exported as `MOTOKO_SESSION_ID` in the child
env (extend the env allowlist block at `src/tui/src/runtime-process.ts:300-330`):

```ts
MOTOKO_SESSION_ID: process.env.MOTOKO_SESSION_ID ?? this.sessionId,
```

This also makes `SessionLogger`'s filename stem (`session-logger.ts:233-237`) and the
AILANG-side `derive_session_id()` (`agent_loop_v2.ail:255`) converge on the same id for
interactive runs — today they diverge (ISO stem vs `session_${now()}`), which is a
latent inconsistency this patch incidentally fixes.

On `/restart`, mint a new `sessionId` (it's a genuinely new session).

**Blast radius:** additive env var; the runtime already prefers an existing
`MOTOKO_SESSION_ID`. No effect on eval-harness runs (they set it themselves).

---

## Patch 2 — Checkpoint history after each step (AILANG)

**File:** `src/core/agent_loop_v2.ail`

### 2a. Message ↔ JSON round-trip

The file already serializes tool results (`tool_messages_to_result_jsons`,
`:544`) and converts `[Msg]`↔`[Message]` (`msgs_to_messages` `:342`,
`messages_to_msgs` `:468`). Add a faithful full-`Message` codec covering all four
fields (`role`, `content`, `tool_calls`, `tool_call_id`):

```ailang
func message_to_json(m: Message) -> Json { ... }      -- includes tool_calls array
func messages_to_json(ms: [Message]) -> Json { ja(map(message_to_json, ms)) }
func json_to_message(j: Json) -> Message { ... }
func json_to_messages(j: Json) -> [Message] { ... }   -- tolerant of missing fields
```

`tool_calls` must round-trip (id, name, arguments) — reuse whatever ToolCall JSON
shape `step_result_to_message` / the hybrid path already build (`:1246-1251`) so the
restored history is accepted by every provider (the Bedrock tool_use correlation note
at `:1228-1245` applies — a restored assistant message with tool_calls must keep its
`tool_call_id` correlation intact).

### 2b. Checkpoint helper

```ailang
func checkpoint_path(workdir: string, session_id: string) -> string {
  "${workdir}/.motoko/session/${session_id}.json"
}

func write_checkpoint(workdir: string, session_id: string, msgs: [Message]) -> () ! {FS} {
  let _ = mkdirAllResult("${workdir}/.motoko/session");
  let body = encode(jo([
    kv("schema_version", jnum(1.0)),
    kv("session_id", js(session_id)),
    kv("messages", messages_to_json(msgs))
  ]));
  -- writeFileResult so a checkpoint failure never aborts the task.
  let _ = writeFileResult(checkpoint_path(workdir, session_id), body);
  ()
}
```

Use the `Result` variants (`writeFileResult`, `mkdirAllResult`) so a disk error
degrades to "no checkpoint" rather than killing the run.

### 2c. Call sites

- In `loop_v2`, after each step's history is finalized and **before** the recursive
  call (every branch that recurses with `next_msgs` — e.g. `:1211`, `:1255`, and the
  typed-tool-calls dispatch branch), call
  `write_checkpoint(workdir, session_id, next_msgs)`. Centralize by writing once at the
  point `next_msgs` is computed, or wrap the recursion in a small helper that
  checkpoints then recurses.
- In `conversation_loop_v2`, after a turn returns `Ok(updated_history)` (`:1553`),
  `write_checkpoint(workdir, session_id, updated_history)` before recursing.

`loop_v2` and `conversation_loop_v2` already declare the `FS` effect, so no signature
changes. `workdir` and `session_id` are already in scope in both.

**Frequency / cost:** one truncating write per step of the full message list. For
typical step counts and message sizes this is negligible; if it ever matters, switch to
append-only JSONL deltas. Not needed now.

---

## Patch 3 — Resume from checkpoint on respawn (AILANG + TS)

### 3a. TS — request resume on ESC respawn

**File:** `src/tui/src/index.ts`

The interrupted-respawn path is the `setAwaitingTask(true)` branch at `:932-935`. The
next submission currently calls `onInitialTask → spawnRuntimeProcess(value, true)`.
Change the respawn after an interrupt to pass a resume flag so the new process
rehydrates instead of starting the task fresh:

- Set `MOTOKO_RESUME=1` in the child env for respawns that follow an interrupt
  (thread a `resume: boolean` through `spawnRuntimeProcess` / `RuntimeProcess`, exported
  alongside `MOTOKO_SESSION_ID` in `runtime-process.ts`).
- The post-ESC first submission should be delivered as a **`user_message`** on the
  resumed session, not as the initial `task`. Concretely: after an interrupt, the
  respawn happens immediately (empty task) with `MOTOKO_RESUME=1`; the runtime
  rehydrates and enters `conversation_loop_v2` waiting on stdin; the user's next line is
  sent via `runtimeProcess.sendUserMessage(...)` (the `taskDone`/follow-up path,
  `ui.ts:4009-4017`), exactly like a normal follow-up after `done`.

  This means after ESC the UI should transition to the **follow-up** state
  (`taskDone = true`) rather than the **awaiting-initial-task** state, so plain text
  routes to `onUserMessage` not `onInitialTask`. Adjust the interrupt branch at
  `index.ts:932-935` accordingly (e.g. respawn with resume immediately, then
  `ui.setTaskDone(true)` once the resumed process signals it is ready).

### 3b. AILANG — load checkpoint and enter the conversation loop

**File:** `src/core/rpc.ail` (`run_with_config`, `:156-238`)

Before building the fresh `init` task, check for resume:

```ailang
let resume = getEnvOr("MOTOKO_RESUME", "") == "1";
let session_id = getEnvOr("MOTOKO_SESSION_ID", "");
let ckpt = "${cwd}/.motoko/session/${session_id}.json";
```

If `resume && session_id != "" && fileExists(ckpt)`:

- Read + decode the checkpoint, `json_to_messages` → restored `[Message]`.
- Emit a `session_resume` event (new event type; mirror `session_start` fields plus
  `restored_messages: <count>`) so the TUI/logger can show "resumed N messages".
- Call a new exported entry `resume_v2_conversation(rt, env_url, ..., restored_history,
  ...)` that **skips the initial run** and goes straight to `conversation_loop_v2` with
  the restored history. This reuses the existing `conversation_loop_v2` verbatim.
- On decode failure or empty/missing checkpoint, **fall through** to the normal fresh
  `init` path (resume is best-effort, never fatal).

Otherwise: the existing `run_v2_with_conversation(... init ...)` path, unchanged.

Add the `resume_v2_conversation` wrapper next to `run_v2_with_conversation`
(`agent_loop_v2.ail:1576`) — it is `run_v2_with_conversation` minus the initial
`run_v2_from_messages` call:

```ailang
export func resume_v2_conversation(
  rt, env_url, hybrid_tools, budget, model,
  restored_history: [Message], workdir, step_budget, ohmy_pi,
  max_cost_millicents, cost_rates, provider, session_id
) -> () ! {AI, FS, Process, IO, Env, Net, SharedMem, Clock, Stream, Trace} {
  conversation_loop_v2(rt, env_url, hybrid_tools, budget, model,
    restored_history, workdir, step_budget, ohmy_pi,
    max_cost_millicents, cost_rates, provider, session_id)
}
```

Note: pass `session_id` explicitly (don't re-`derive_session_id()`) so the checkpoint
key stays stable across the resumed turns.

### 3c. Normal-exit cleanup

When a session ends normally (the non-interrupted exit at `index.ts:941-946`, after
`done`), delete the checkpoint so a later unrelated session with a recycled id can't
resume stale history. Either:

- TS: `fs.rm` the `${workdir}/.motoko/session/${sessionId}.json` on clean exit; or
- AILANG: `removeFileResult(checkpoint_path(...))` when `conversation_loop_v2` reads an
  `exit`/`abort` command (`:1523`) and is genuinely ending.

TS-side cleanup is simpler and keeps the AILANG abort handler untouched. Prefer TS.

---

## Event protocol additions

- New event `session_resume` (AILANG → TUI): `{ type, session_id, model,
  restored_messages }`. The TUI shows "Resumed N messages" in history; the
  SessionLogger logs it. Add the type to the `AgentEvent` union in
  `src/tui/src/runtime-process.ts` and a transcript line in
  `src/tui/src/session-logger.ts`.

No other protocol changes.

---

## Tests

### AILANG (`src/core/test/…`)

- `message_to_json` / `json_to_messages` round-trip: a `[Message]` containing a system
  msg, a user msg, an assistant msg **with tool_calls**, and a tool-role msg with a
  `tool_call_id` survives encode→decode unchanged (field-by-field).
- `write_checkpoint` then read-back: assert the file at `checkpoint_path` decodes to the
  same messages.
- Resume entry: given a checkpoint on disk and `MOTOKO_RESUME=1` +
  `MOTOKO_SESSION_ID`, `run_with_config` enters the resume path (assert a
  `session_resume` event is emitted with the right `restored_messages` count) and does
  **not** emit a fresh-task `session_start`.
- Best-effort fallback: corrupt/empty checkpoint → falls through to the normal fresh
  path (no panic, `session_start` emitted).

### TS (`src/tui/src/…`)

- `runtime-process` env: `MOTOKO_SESSION_ID` is exported and stable across a respawn;
  `MOTOKO_RESUME=1` is set only on the post-interrupt respawn.
- Stream-protocol scenario (extends the pattern in
  `runtime-process.stream-protocol.test.ts`): user_message → `tool_calls` event → ESC
  (kill) → respawn with resume → send a second user_message → assert the next
  `thinking` event's input contains the **first** prompt's content (history restored).
- UI: after an interrupt+resume, plain text routes to `onUserMessage` (follow-up), not
  `onInitialTask`.

### Manual reproduction (the issue scenario)

`make run`, start "Read README.md and run ailang prompt", ESC mid-task, then ask
"What was my last prompt?" → the agent references the README task. Confirm
`${workdir}/.motoko/session/<id>.json` exists during the run and is gone after a clean
exit.

---

## Order of work

1. **Patch 1** (stable session id) — prerequisite for any checkpoint keying. Independent,
   low risk, also fixes the latent triple-session-id divergence.
2. **Patch 2** (checkpoint writes) — additive; with Patch 1 the file appears on disk but
   nothing reads it yet. Verifiable in isolation (inspect the file).
3. **Patch 3** (resume) — wires read-back + TS respawn flag + cleanup. The user-visible
   fix lands here.

Each patch is independently testable and revertible. Patches 1–2 are safe to land
before 3.

## Blast radius / rollback

- Patch 1: one env var + one id variable. `git revert` clean.
- Patch 2: new helpers + checkpoint calls at recursion points; if `messages_to_json`
  drops a field the *restored* history could be malformed — covered by the round-trip
  test, and resume is best-effort (corrupt → fresh). No effect on a session that never
  aborts beyond a per-step file write.
- Patch 3: new resume branch in `run_with_config` + `resume_v2_conversation` wrapper +
  TS respawn flag + cleanup. The resume branch is gated on `MOTOKO_RESUME=1`, so absent
  the flag behavior is byte-for-byte the old path.

## How we'll know it worked

- The issue repro (task → ESC → "what was my last prompt?") returns the prior task.
- `session_resume` events appear in the JSONL log with a non-zero `restored_messages`.
- Normal completion leaves no `.motoko/session/<id>.json` behind.
- `make check_core` + `make test` + `cd src/tui && bun run test` green.

## Follow-up (separate, upstream)

File AILANG-side feedback (via the `ailang-feedback` skill) requesting a **non-blocking
stdin read / poll** primitive in `std/io`. With that, Option B becomes viable: ESC
sends a soft abort, `loop_v2` polls between steps, returns its `[Message]` to
`conversation_loop_v2`, and the process stays alive — preserving even the partial
in-flight turn and removing the kill/respawn churn this plan works around.
