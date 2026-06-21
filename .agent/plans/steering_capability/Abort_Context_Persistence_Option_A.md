# Plan: Preserve context across ESC abort (Option A — checkpoint + rehydrate)

Fixes GitHub issue **#15 — "Aborting (Esc) in the middle of a task flushes the
context window."**

## TL;DR

- **Bug:** ESC mid-task calls `runtimeProcess.kill()` (SIGTERM). The conversation
  lives only in the runtime's memory (`loop_v2`'s `[Message]` param), so the kill
  destroys it and the next prompt respawns a fresh, empty process. Regression from the
  v2 loop rewrite.
- **Why not just keep the process alive (Option B):** grounded against the AILANG MCP,
  `std/io` has only blocking `readLine` — no non-blocking/poll stdin in v0.24.2 — so a
  blocking in-flight step can only be interrupted by killing the process. Surviving that
  requires persisting history to disk.
- **Fix (Option A):** (1) TS passes a stable `MOTOKO_SESSION_ID` across respawns;
  (2) AILANG checkpoints `[Message]` history to `${workdir}/.motoko/session/<id>.json`
  after each step via sandboxed `std/fs`; (3) on `MOTOKO_RESUME=1` respawn the runtime
  rehydrates from the checkpoint into `conversation_loop_v2`, and the post-ESC prompt
  arrives as a follow-up `user_message`. Checkpoint is deleted on clean exit.
- **Works on current AILANG v0.24.2**, no upstream change. Three independently
  landable/revertible patches. Follow-up: file upstream feedback for non-blocking stdin
  to unlock the cleaner Option B later.

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

2. **Checkpoint at each step boundary (AILANG).** `loop_v2` serializes its incoming
   `[Message]` history to `${workdir}/.motoko/session/<session_id>.json` once at the top
   of the loop (covers every step including step 0), and `conversation_loop_v2`
   re-checkpoints after each completed turn. `std/fs` has **no `rename`**, so a
   write-temp-then-rename atomic swap isn't available; we accept a truncating
   `writeFile` (a step boundary is a consistent snapshot point) and handle the only real
   risk — a SIGTERM landing mid-`writeFile` — on the **read** side via `std/json.repair`
   + best-effort fallback (Patch 2a/3b).

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

**Grounded type shapes (from the AILANG MCP, `std/ai`):**

- `Message = { role: string, content: string, tool_calls: [ToolCall], tool_call_id: string }`
- `ToolCall = { id: string, name: string, arguments: string }` — `arguments` is a
  **JSON-encoded string**, not a `Json`. (Confirmed by the record literal at
  `agent_loop_v2.ail:588-593`; do **not** confuse with `tool_contract.ToolCallEnvelope`,
  whose `arguments` is a `Json`.)

Both are plain records, so a `ToolCall` is reconstructable in user code via a record
literal — the codec is feasible. Add it to `agent_loop_v2.ail` (the only module that
imports `Message`/`ToolCall`; rpc.ail must stay codec-free, see 3b).

Write encoders/decoders as **explicit recursion**, matching the existing
`messages_to_msgs` (`:468`) idiom — avoid `map`+lambda (the file notes a match-in-lambda
parser bug at `:1125`).

```ailang
-- encode
func tool_call_to_json(tc: ToolCall) -> Json {
  jo([kv("id", js(tc.id)), kv("name", js(tc.name)), kv("arguments", js(tc.arguments))])
}
func tool_calls_to_json(tcs: [ToolCall]) -> [Json] {
  match tcs { [] => [], h :: t => tool_call_to_json(h) :: tool_calls_to_json(t) }
}
func message_to_json(m: Message) -> Json {
  jo([
    kv("role", js(m.role)),
    kv("content", js(m.content)),
    kv("tool_calls", ja(tool_calls_to_json(m.tool_calls))),
    kv("tool_call_id", js(m.tool_call_id))
  ])
}
func messages_to_json(ms: [Message]) -> [Json] {
  match ms { [] => [], h :: t => message_to_json(h) :: messages_to_json(t) }
}

-- decode (tolerant: missing fields default to "" / [])
--   reuse the file's existing msg_get_str (get + asString, "" fallback, :495);
--   add getArray to the std/json import list (:41) for the tool_calls / messages arrays.
func json_to_tool_call(j: Json) -> ToolCall {
  { id: msg_get_str(j, "id"), name: msg_get_str(j, "name"),
    arguments: msg_get_str(j, "arguments") }
}
func json_to_message(j: Json) -> Message {
  { role: msg_get_str(j, "role"), content: msg_get_str(j, "content"),
    tool_calls: <getArray(j,"tool_calls") |> recurse json_to_tool_call, [] if None>,
    tool_call_id: msg_get_str(j, "tool_call_id") }
}
func json_to_messages(j: Json) -> [Message] {
  -- getArray(j, "messages") -> Option[List[Json]]; None/empty => []; else map json_to_message via explicit recursion
  ...
}
```

`tool_calls` **must** round-trip (id, name, arguments) so restored assistant messages
keep their `tool_call_id` correlation — the Bedrock note at `:1228-1245` applies: a
restored assistant message carrying tool_calls whose ids don't match the following
tool-role messages is rejected with HTTP 400. The round-trip test (below) is the guard.

**Robustness:** if `decode` of a checkpoint truncated by a mid-write kill fails, retry
once via `std/json.repair` before giving up — `repair` handles unclosed
arrays/objects/strings, which is exactly the truncation a SIGTERM mid-`writeFile` can
produce.

### 2b. Checkpoint helper

```ailang
func checkpoint_path(workdir: string, session_id: string) -> string {
  "${workdir}/.motoko/session/${session_id}.json"
}

func write_checkpoint(workdir: string, session_id: string, msgs: [Message]) -> () ! {FS} {
  let _ = mkdirAllResult("${workdir}/.motoko/session");
  let body = encode(jo([
    kv("schema_version", jnum(_int_to_float(1))),  -- match the file's jnum idiom
    kv("session_id", js(session_id)),
    kv("messages", ja(messages_to_json(msgs)))     -- messages_to_json returns [Json]
  ]));
  -- writeFileResult so a checkpoint failure never aborts the task.
  let _ = writeFileResult(checkpoint_path(workdir, session_id), body);
  ()
}
```

Use the `Result` variants (`writeFileResult`, `mkdirAllResult`) so a disk error
degrades to "no checkpoint" rather than killing the run. `writeFile` does **not** create
parent dirs (per the std/fs doc — "future enhancement"), so the `mkdirAllResult` call is
required, not optional.

**Sandbox alignment.** The runtime's FS is restricted to `AILANG_FS_SANDBOX = workdir`
(`runtime-process.ts:308`), and `workdir` here is `cwd` from `run_with_config`
(`= inv.workdir_override || cfg.agent.workdir`). The checkpoint path is under that root,
so writes are permitted. The TS cleanup (3c) must target the **same** `workdir` the
runtime was given.

### 2c. Call site — one checkpoint at the top of `loop_v2`

`loop_v2` recurses from **seven** distinct branches (verified:
`:1211, :1255, :1283, :1299, :1322, :1338, :1374`). Checkpointing before each recursion
would mean seven edits and a standing risk that a future branch is added without one.

**Instead, checkpoint the incoming `msgs` once, at the top of `loop_v2`** — at the start
of the main `else` block (`agent_loop_v2.ail:1075`, just before
`let ctx = mk_v2_ext_ctx(...)`):

```ailang
else {
  let _ = write_checkpoint(workdir, session_id, msgs);   -- NEW: snapshot pre-step state
  let ctx = mk_v2_ext_ctx(task, step_idx, model, workdir, env_url, hybrid_tools, budget, msgs);
  ...
```

This single site captures the full history at **every** step boundary including
**step 0** (where `msgs` is the initial `[system, user-task]`). Two consequences:

1. It covers all seven recursion branches automatically — the next iteration's
   pre-step snapshot *is* the previous iteration's `next_msgs`.
2. It fixes the exact issue scenario: an ESC ~55 s in (likely during step 0/1) still
   leaves a checkpoint containing the original task + system prompt, so the follow-up
   "what was my last prompt?" can answer.

The documented non-goal stands: the checkpoint reflects state **before** the in-flight
step's LLM call, so the interrupted step's own (incomplete) output is not recovered.

**Secondary checkpoint (belt-and-suspenders):** in `conversation_loop_v2`, after a turn
returns `Ok(updated_history)` (`:1553`), call
`write_checkpoint(workdir, session_id, updated_history)` before recursing — so a
*completed* task's final assistant turn is on disk even before the next turn's first
step would re-snapshot it. Low cost, closes the "killed while idle after done" gap.

`loop_v2` and `conversation_loop_v2` already declare the `FS` effect and already have
`workdir` + `session_id` in scope, so no signature changes.

**Consistency note (depends on Patch 1).** `loop_v2`'s `session_id` comes from
`run_v2_from_messages`'s own `derive_session_id()` call (`:1440`), while
`conversation_loop_v2`'s comes from `run_v2_with_conversation`'s separate
`derive_session_id()` (`:1591`). These agree **only** when `MOTOKO_SESSION_ID` is set —
which is exactly what Patch 1 guarantees. Without Patch 1 the two would diverge and the
secondary checkpoint would write to a different file than the primary. Patch 1 is a hard
prerequisite for Patch 2, not just Patch 3.

**Frequency / cost:** one truncating write of the full message list per step. Negligible
for typical sizes; switch to append-only deltas only if it ever shows up in profiling.

---

## Patch 3 — Resume from checkpoint on respawn (AILANG + TS)

### 3a. TS — request resume on ESC respawn

**File:** `src/tui/src/index.ts`

Currently the interrupt branch (`index.ts:932-935`) sets `interrupted=false` and calls
`ui.setAwaitingTask(true)`, so the next plain submission routes through `onInitialTask →
spawnRuntimeProcess(value, true)` — a fresh task. Two changes:

**(i) Respawn immediately with resume, instead of awaiting a fresh task.** Mirror the
existing restart branch's deferred respawn (`index.ts:931`):

```ts
} else if (interrupted) {
  interrupted = false;
  // Respawn immediately and resume the checkpointed history; the user's next
  // line will arrive as a follow-up user_message, not a new task.
  setTimeout(() => spawnRuntimeProcess("", false, /* resume */ true), 100);
}
```

Thread a third `resume?: boolean` arg through `spawnRuntimeProcess` →
`RuntimeProcess`, exported as `MOTOKO_RESUME=1` in the child env alongside
`MOTOKO_SESSION_ID` (env allowlist, `runtime-process.ts:300-330`). Default off, so every
other spawn path is unchanged.

**(ii) Enable follow-up input via the `session_resume` event, not a public setter.**
There is no public `setTaskDone` — `taskDone` is private and is flipped inside the event
handlers (e.g. the `done` path at `ui.ts:2730-2732`). So handle the new `session_resume`
event in `ui.handleEvent` the same way `done` is handled: set `taskDone = true`,
`setRunState("idle")`, render a "Resumed N messages" line. That puts the UI in the
**follow-up** state, so plain text routes to `onUserMessage → sendUserMessage(...)`
(`ui.ts:4009-4017`) — exactly a normal post-`done` follow-up. The resumed runtime is
already blocking in `conversation_loop_v2`'s `readLine()`, ready to receive it.

Do **not** call `setAwaitingTask(true)` on the interrupt path anymore (that would route
the next line to `onInitialTask`, starting a fresh task and defeating the resume).

> TTY/headless check: the respawned child's `MOTOKO_HEADLESS` is derived from the
> **parent TUI's** `process.stdin.isTTY` (`runtime-process.ts:317-319`), which stays a
> TTY across respawn — so `conversation_loop_v2` runs its `readLine()` loop (not the
> headless early-exit). Resume works in interactive mode; headless/eval runs never set
> `MOTOKO_RESUME` and are unaffected.

### 3b. AILANG — load checkpoint and enter the conversation loop

Keep all `Message`/JSON/checkpoint logic **inside `agent_loop_v2.ail`** — `rpc.ail` does
not import `Message` and must not start to. rpc.ail only decides *whether* to resume and
calls the right entry.

**`agent_loop_v2.ail` — new exports:**

```ailang
-- Best-effort load; None on missing/corrupt (after one std/json.repair retry).
export func try_load_checkpoint(workdir: string, session_id: string)
  -> Option[[Message]] ! {FS} { ... readFileResult → decode/repair → json_to_messages ... }

-- conversation_loop_v2 entry from a restored history; emits session_resume.
-- `fallback_init` is used only if the checkpoint vanished/decoded empty between
-- rpc.ail's fileExists check and this read (tiny race) — never silently start blank.
export func resume_v2_conversation(
  rt, env_url, hybrid_tools, budget, model,
  fallback_init: [Msg], workdir, step_budget, ohmy_pi,   -- [Msg] in, like run_v2_with_conversation
  max_cost_millicents, cost_rates, provider, session_id
) -> () ! {AI, FS, Process, IO, Env, Net, SharedMem, Clock, Stream, Trace} {
  let history = match try_load_checkpoint(workdir, session_id) {
    Some(restored) => restored,
    None           => msgs_to_messages(fallback_init)  -- race/corrupt: never start blank
  };
  let _ = emit_event(session_id, "session_resume", [
    kv("model", js(model)),
    kv("restored_messages", jnum(_int_to_float(List.length(history))))
  ]);
  conversation_loop_v2(rt, env_url, hybrid_tools, budget, model,
    history, workdir, step_budget, ohmy_pi,
    max_cost_millicents, cost_rates, provider, session_id)
}
```

`session_id` is passed in explicitly (don't re-`derive_session_id()`), keeping the
checkpoint key stable across resumed turns.

**`src/core/rpc.ail` (`run_with_config`, `:156-238`) — gate the entry:**

```ailang
let session_id = getEnvOr("MOTOKO_SESSION_ID", "");
let resume = getEnvOr("MOTOKO_RESUME", "") == "1"
          && session_id != ""
          && fileExists("${cwd}/.motoko/session/${session_id}.json");
```

- **Resume path:** skip the unconditional `session_start` emit (`rpc.ail:~180-191`) —
  emit nothing here; `resume_v2_conversation` emits `session_resume` instead. Then call
  `resume_v2_conversation(ext_runtime, env_url, ..., init, settings.workdir, ...,
  session_id)`, passing the freshly-built `init` as the fallback.
- **Normal path (unchanged):** emit `session_start` as today, then
  `run_v2_with_conversation(... init ...)`.

So `session_start` and `session_resume` are mutually exclusive — the TUI never sees both
for one respawn, and never double-counts a session.

**Required new import in `rpc.ail`:** `std/env (getEnvOr)` (rpc.ail does not currently
import it). `fileExists` is already imported (`rpc.ail:21`). rpc.ail keeps passing the
`init: [Msg]` it builds at `:228` unchanged — `resume_v2_conversation` takes `[Msg]` and
converts via `msgs_to_messages` internally (same as `run_v2_with_conversation` at
`:1591`), so rpc.ail stays codec-free.

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
- **Truncation recovery:** truncate a checkpoint mid-array, assert `try_load_checkpoint`
  recovers via `std/json.repair` (or cleanly returns `None` if unrecoverable — never
  panics).
- **Step-0 coverage:** drive `loop_v2` for a single step and assert the checkpoint
  written at the top contains the initial `[system, user-task]` (proves an abort during
  the first step still preserves the original task — the issue's exact scenario).
- Resume entry: given a checkpoint on disk, `resume_v2_conversation` emits
  `session_resume` with the right `restored_messages` count and enters
  `conversation_loop_v2` with the restored history.
- Best-effort fallback: missing/corrupt checkpoint → `resume_v2_conversation` falls back
  to `msgs_to_messages(fallback_init)` (no panic, still emits `session_resume`).

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

### At a glance

| Patch | Files touched | Lines of change | Risk | Reversibility | Effect when feature off |
|---|---|---|---|---|---|
| 1 — stable session id | `src/tui/src/index.ts`, `src/tui/src/runtime-process.ts` | small (~1 var + 1 env entry) | Low | `git revert` clean | n/a — always on, but only adds an env var the runtime already prefers |
| 2 — checkpoint writes | `src/core/agent_loop_v2.ail` (+ AILANG tests) | medium (codec + helper + **one** top-of-loop call site) | Low–Med | `git revert` clean | one best-effort per-step file write; never reads back |
| 3 — resume + cleanup | `src/core/rpc.ail`, `src/core/agent_loop_v2.ail`, `src/tui/src/index.ts`, `src/tui/src/runtime-process.ts`, `src/tui/src/session-logger.ts` (+ tests) | medium | Med | `git revert` clean | gated on `MOTOKO_RESUME=1`; absent the flag, byte-for-byte the old path |

**Scope guarantees.** No changes to streaming, tool dispatch, the JSONL event shape
(only an additive `session_resume` event type), or the legacy `/abort` / Ctrl+C /
`/restart` paths. Eval-harness runs are unaffected (they set `MOTOKO_SESSION_ID`
themselves and never set `MOTOKO_RESUME`). New on-disk artifact is confined to the
sandboxed `${workdir}/.motoko/session/` and removed on clean exit.

**Worst-case failure mode.** A bug in the `Message`↔JSON codec (Patch 2) could yield a
malformed *restored* history — bounded by: (a) the round-trip unit test, (b) resume
being best-effort (corrupt/empty checkpoint → fresh path), and (c) the gate, so a
non-aborted session is never affected beyond a per-step write.

### Per-patch detail

- Patch 1: one env var + one id variable. `git revert` clean.
- Patch 2: new codec + a single checkpoint write at the top of `loop_v2` (covers all 7
  recursion branches and step 0); if `message_to_json`/`json_to_messages` drops a field
  the *restored* history could be malformed — covered by the round-trip test, and resume
  is best-effort (corrupt → repair → fallback). No effect on a session that never aborts
  beyond a per-step file write.
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
