# Self-Modifying Brain: Hot-Swap Architecture

## Overview

The agent can extend its own brain (swe/ modules and/or the AILANG binary) while running.
The TypeScript UI process never restarts. The AILANG brain subprocess is killed and respawned
with the new code. Full conversation history is preserved across the swap.

---

## Constraints (from design sessions)

- TypeScript UI: never restarts
- Brain subprocess: can be killed + respawned
- Validation: run existing `cd tui && npm test` before swapping
- Trigger: user-initiated meta-task ("extend yourself to do X")
- State continuity: new brain resumes with full prior conversation history
- Scope: can replace any swe/ module including rpc.ail itself
- AILANG extension: both pure .ail stdlib additions and Go source modifications

---

## End-to-End Flow

```
1. User sends meta-task: "add capability X to yourself"
2. Brain executes bash commands:
   - rm -rf $AGENT_DIR/swe_next      ← clean slate before staging
   - cp -r $AGENT_DIR/swe $AGENT_DIR/swe_next
   - ... edits to swe_next/ ...
   - ailang check $AGENT_DIR/swe_next/rpc.ail  [see caveat in §ailang check]
   - echo "UPGRADE_READY:$AGENT_DIR/swe_next"  ← sentinel in bash stdout
3. rpc.ail detects the sentinel in the bash observation stdout and calls emit():
   { type: "upgrade_ready", new_swe_dir: "/abs/path/swe_next", new_ailang_bin?: "..." }
   (The LLM cannot write directly to the AILANG process stdout — bash stdout is captured
   by the env server and returned as an HTTP response body, not as a raw stdout line.
   rpc.ail must re-emit the signal, mirroring the existing is_done sentinel pattern.)
4. Brain continues normally and finishes the task; emits state_snapshot then "done"

   TypeScript side (after "done", if upgrade pending):
5. BLOCK user input in UI — no messages accepted while upgrade is in progress
6. Run test suite:  AILANG_BIN=<new_bin> SWE_DIR=<new_swe_dir> cd tui && npm test
   a. FAIL: discard pending upgrade, unblock UI, report result
7. PASS test suite → communication probe:
   - Spawn probe brain with --probe flag: new_bin + swe_next/rpc.ail
     --probe mode emits session_start + done immediately WITHOUT calling the LLM
   - Wait for session_start + done  (timeout: 30 s)
   - Kill probe brain
   a. FAIL (timeout / missing events / malformed JSON): discard pending upgrade, unblock UI
      swe_next/ is NOT deleted — user can inspect the code
8. PASS probe → perform swap:
   - Write state_snapshot msgs to /tmp/brain_resume_<ts>.json
   - Set  swapping = true  in index.ts to suppress onExit → process.exit(0)
   - Kill old brain (SIGTERM)  ← brain is dead before filesystem changes begin
   - rename("swe",      "swe_backup_<ts>")  ← non-atomic; swe_next still present for recovery
   - rename("swe_next", "swe")              ← atomic on same filesystem (single rename(2) syscall)
     (new binary: update AILANG_BIN env var for future Brain spawns)
   - Spawn new brain with: RESUME_MSGS_FILE=<path>, RESUME_CWD=<cwd>, RESUME_STEP=<step>
     (BRAIN_RESUME=1 is not used — RESUME_MSGS_FILE presence is the sole gate)
   - New brain reads msgs from file, enters conversation_loop (skips rpc_loop)
   - Clear swapping flag once new brain emits session_start
9. Unblock UI; report upgrade result to user

Error event from brain clears any pending upgrade (step 6+ never reached).
```

**Rationale for the probe step:** the test suite validates module correctness but not the
live JSONL handshake. The probe catches: runtime panics in the new rpc.ail, JSONL field
renames that break the protocol, AILANG binary startup failures, and import resolution
errors that only surface at runtime. Using `--probe` mode avoids a real LLM call (no cost,
no API dependency, fast).

---

## JSONL Protocol Changes

### New brain → TypeScript events

| Event | Fields | When |
|---|---|---|
| `state_snapshot` | `step: number`, `msgs: Msg[]`, `cwd: string` | Once, just before the `done` event |
| `upgrade_ready` | `new_swe_dir: string`, `new_ailang_bin?: string` | Once, when brain has staged new code |

### New TypeScript → brain commands

No new commands needed. TypeScript either:
- Kills the process (upgrade accepted) — brain receives SIGTERM
- Does nothing (upgrade rejected) — brain is already blocking on `readLine()` in `conversation_loop`

### TypeScript-internal UI notifications (not JSONL — never emitted by the brain)

| Event | Fields | Produced by | When |
|---|---|---|---|
| `upgrade_result` | `status: "passed"\|"failed"`, `stage: string`, `message: string` | `UpgradeManager.onDone()` | After test suite + probe complete |

`upgrade_result` is produced inside TypeScript by `UpgradeManager` and passed directly
to `ui.handleEvent`. It is never written to the brain's stdin and never appears on the
brain's stdout. It must be defined as a separate type (`UpgradeResultEvent`) and
`AgentEvent` in `brain.ts` must remain pure — only events the brain actually emits on
stdout belong there. See Phase 4 for how `handleEvent` is widened to accept both.

---

## File Layout After a Swap

```
swe/                  ← active backend (swapped in after tests + probe pass)
swe_backup_<ts>/      ← previous backend snapshot (rollback target)
swe_next/             ← staging area; preserved after failed probe for inspection
ailang                ← active binary (symlink or path tracked in UpgradeManager)
ailang_backup_<ts>    ← previous binary snapshot
```

The old brain is killed before any filesystem changes. The final placement —
`rename("swe_next", "swe")` — is a single atomic `rename(2)` syscall on the same
filesystem. The intermediate step `rename("swe", "swe_backup_<ts>")` is not atomic,
but `swe_next/` is always present as a recovery target if the process crashes
in the gap between the two renames.

---

## Components to Build

### Phase 0 — upgrade_ready sentinel detection (swe/parse.ail + swe/rpc.ail)

**Why this is needed:** The LLM cannot write directly to the AILANG process stdout. Bash
commands execute via `POST /exec` on the env server; their stdout is captured and returned
in the HTTP response body, arriving in AILANG as `result.stdout` inside `exec_in`. The only
way the LLM can trigger a `upgrade_ready` emission is to include a detectable sentinel in
a bash command's output, which `rpc.ail` then re-emits — exactly the same pattern as the
existing `is_done` / `COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT` sentinel.

**1. Add to `swe/parse.ail`:**

```ailang
-- Returns Some(absolute_path) when stdout contains "UPGRADE_READY:<path>"
export func extract_upgrade_ready(stdout: string) -> Option[string] {
  -- scan for prefix "UPGRADE_READY:", return the remainder of that line trimmed
  -- return None if prefix absent
}
```

**2. In `rpc.ail` rpc_loop, after `exec_in` and after emitting the `obs` event, before
the `is_done` check:**

```ailang
-- NEW: re-emit upgrade_ready if sentinel found in bash stdout
let _ = match extract_upgrade_ready(result.stdout) {
  None       => (),
  Some(path) =>
    emit(encode(jo([
      kv("type",        js("upgrade_ready")),
      kv("new_swe_dir", js(path))])))
};

-- EXISTING: check for task completion
if is_done(result.stdout) then { ... }
```

The `upgrade_ready` emission does not terminate the loop — the brain continues to the next
step normally. TypeScript stores the event as `pendingUpgrade` and acts on it after `done`.

Note: if the agent also needs to signal a new AILANG binary, the sentinel should be
`echo "UPGRADE_READY:$AGENT_DIR/swe_next BIN:$AGENT_DIR/ailang_next_bin"` and
`extract_upgrade_ready` must parse both fields.

### Phase 1 — state_snapshot emission (swe/rpc.ail)

Emit once per task, just before emitting `done` (both in the "no bash block" and
"is_done sentinel" branches of `rpc_loop`). Not after every step — the full `msgs`
array can be 100KB+ by step 20 and sending it on every step is wasteful.

`encode_msgs` is a new helper that manually serialises `[Msg]` to a JSON array.
AILANG has no generic record serialiser; each `{ role, content }` must be encoded
field-by-field using `jo`/`kv`/`js`. This is non-trivial — it is a significant
AILANG implementation task, not a one-liner. Allocate time accordingly.

```ailang
import std/json (ja, jo, kv, js, encode)  -- ja and jo are both in std/json
import std/list (map)                      -- map is in std/list

func encode_msg(m: Msg) -> Json {
  jo([kv("role", js(m.role)), kv("content", js(m.content))])
}

func encode_msgs(msgs: [Msg]) -> Json {
  ja(map(msgs, encode_msg))
}
```

`ja` (`[Json] -> Json`) and `map` (`(a->b) -> [a] -> [b]`) are both present in the
AILANG stdlib and backed by Go builtins. No binary changes needed — only add `ja` to
the `std/json` import line and add `import std/list (map)` in `swe/rpc.ail`.

### Phase 2 — probe entry point (swe/rpc.ail)

Add a `probe_main` exported function to `swe/rpc.ail`:

```ailang
export func probe_main() -> () ! {IO, Env} {
  let model = getEnvOr("MODEL", "anthropic/claude-sonnet-4-6");
  let _ = emit(encode(jo([kv("type", js("session_start")),
                          kv("task", js("(probe)")),
                          kv("model", js(model))])));
  let _ = emit(encode(jo([kv("type", js("done")),
                          kv("step", jnum(0.0)),
                          kv("output", js("probe ok"))])));
  ()
}
```

TypeScript spawns the probe brain with `--entry probe_main`. The `--entry` flag is
already implemented in the AILANG CLI (`ailang run --entry <fn> ...`) and is already
used by `tui/src/brain.ts` (currently hardcoded to `"main"`). The `BrainOptions`
interface (Phase 4) exposes `entryPoint?: string` so the probe spawn can pass
`"probe_main"`. No env var gating needed — the separate entry point is cleaner.
No LLM call, no env server call, no SharedMem — just a protocol smoke test.

### Phase 3 — brain resume path (swe/rpc.ail main)

`RESUME_MSGS_FILE` is the sole gate for resume mode — no separate `BRAIN_RESUME` flag.
A non-empty path that exists → resume; absent or missing file → normal boot. This is
unambiguous: if the caller sets `RESUME_MSGS_FILE` but the file is missing (e.g. write
failed), `fileExists` falls through to normal boot rather than crashing.

`main()` gains a resume branch at the top (checked before normal boot):

```ailang
let resume_file = getEnvOr("RESUME_MSGS_FILE", "");
if resume_file != "" && fileExists(resume_file) then {
  let raw_json = readFile(resume_file);
  let msgs     = parse_msgs(raw_json);   -- see note on parse_msgs below
  let cwd      = getEnvOr("RESUME_CWD",  "/testbed");
  let step     = parse_int_or(getEnvOr("RESUME_STEP", "0"), 0);
  let state    = { env_url: env_url, msgs: msgs, cwd: cwd, step: step };
  let _ = emit(encode(jo([kv("type", js("session_start")),
                          kv("task", js("(resumed)")),
                          kv("model", js(model))])));
  conversation_loop(state, model, step_delay)
} else {
  -- Normal boot path (unchanged)
  ...
}
```

`parse_msgs` is the inverse of `encode_msgs`. `asArray`, `getString`, and `getArray`
all exist in `std/json`, so no stdlib gaps. Full implementation:

```ailang
import std/json (decode, asArray, getString)
import std/list (map)

func json_to_msg(j: Json) -> Option[Msg] {
  match getString(j, "role") {
    None        => None,
    Some(role)  => match getString(j, "content") {
      None            => None,
      Some(content)   => Some({ role: role, content: content })
    }
  }
}

func collect_msgs(opts: [Option[Msg]]) -> Result[[Msg], string] {
  match opts {
    []              => Ok([]),
    None :: _       => Err("message missing role or content"),
    Some(m) :: rest => match collect_msgs(rest) {
      Err(e)   => Err(e),
      Ok(msgs) => Ok(m :: msgs)
    }
  }
}

export func parse_msgs(raw: string) -> Result[[Msg], string] {
  match decode(raw) {
    Err(e) => Err("decode failed: " ++ e),
    Ok(j)  => match asArray(j) {
      None      => Err("expected JSON array"),
      Some(arr) => collect_msgs(map(json_to_msg, arr))
    }
  }
}
```

The resume branch in `main()` must handle the `Err` case — emit an `error` event
and fall back to normal boot rather than crashing.

**Known limitation:** the resumed brain's `msgs[0]` is the system prompt generated
by the *old* `prompts.ail`. If the upgrade modified `prompts.ail`, the behavioural
change only takes effect in the next fresh session, not in the resumed one.

### Phase 4 — Brain class changes (tui/src/brain.ts) + UI type widening (tui/src/ui.ts)

Add optional `BrainOptions`:

```typescript
interface BrainOptions {
  ailangBin?: string;   // default: "ailang"
  sweFile?: string;     // default: "swe/rpc.ail"
  entryPoint?: string;  // default: "main"  (set to "probe_main" for probe spawn)
  resumeFile?: string;
  resumeCwd?: string;
  resumeStep?: number;
}
```

Extend `AgentEvent` with the two new **brain-emitted** events only:

```typescript
| { type: "state_snapshot"; step: number; msgs: Msg[]; cwd: string }
| { type: "upgrade_ready";  new_swe_dir: string; new_ailang_bin?: string }
```

Where `Msg` = `{ role: string; content: string }`.

Define a separate `UpgradeResultEvent` for the TypeScript-internal notification.
This does NOT belong in `AgentEvent` — it is never emitted by the brain on stdout:

```typescript
// tui/src/upgrade-manager.ts (or a shared types file)
export type UpgradeResultEvent = {
  type: "upgrade_result";
  status: "passed" | "failed";
  stage: string;    // "test_suite" | "probe" | "rollback"
  message: string;
};
```

Widen `AgentUI.handleEvent` in `tui/src/ui.ts` to accept both:

```typescript
// Before:  handleEvent(event: AgentEvent): void
// After:
handleEvent(event: AgentEvent | UpgradeResultEvent): void {
  switch (event.type) {
    // ... existing cases unchanged ...
    case "upgrade_result":
      this.history.addChild(
        styledText(
          `Upgrade ${event.status} (${event.stage}): ${event.message}`,
          event.status === "passed" ? chalk.green : chalk.red
        )
      );
      break;
  }
  this.updateStatus();
  this.tui.requestRender();
}
```

TypeScript's exhaustiveness check will enforce that all members of the union are handled.

### Phase 5 — UpgradeManager (tui/src/upgrade-manager.ts)

```typescript
class UpgradeManager {
  onStateSnapshot(snap: StateSnapshot): void   // replaces latestSnapshot
  onUpgradeReady(event: UpgradeReady): void    // stores pendingUpgrade (replaces prior)
  onError(): void                              // clears pendingUpgrade
  hasPendingUpgrade(): boolean                 // checked by caller before blockInput()

  // Called after "done", AFTER the caller has already called ui.blockInput().
  // Returns true if swap was initiated (caller suppresses normal onExit).
  // Calls unblockUI() on both success and failure paths.
  async onDone(
    envUrl: string,
    model: string,
    spawnResumeBrain: (opts: BrainOptions) => void,
    onResult: (status: "passed" | "failed", stage: string, msg: string) => void,
    unblockUI: () => void,
    setSwapping: (v: boolean) => void
  ): Promise<boolean>

  rollback(): void
}
```

Internal steps of `onDone` (caller has already called `ui.blockInput()` synchronously):
1. If no pending upgrade or no latest snapshot: `unblockUI()`, return false
2. Run: `cd tui && npm test` with env `AILANG_BIN` + `SWE_DIR`
3. If fail: clear pending, `unblockUI()`, `onResult("failed", "test_suite", ...)`, return false
5. Spawn probe brain (`probeMode: true`, new bin + new swe)
   - Await `session_start` + `done` within 30 s; kill probe when done or on timeout
6. If probe fails: clear pending, `unblockUI()`, `onResult("failed", "probe", ...)`, return false
   - swe_next/ is NOT deleted
7. Perform swap:
   - Write `latestSnapshot.msgs` JSON to `/tmp/brain_resume_<ts>.json`
   - `setSwapping(true)`
   - Kill old brain  ← no AILANG process is running from this point
   - `fs.renameSync("swe", `swe_backup_${ts}`)`   // non-atomic; safe because swe_next exists
   - `fs.renameSync(newSweDir, "swe")`             // atomic rename(2) on same filesystem
   - If `new_ailang_bin`: backup old bin, update `this.ailangBin`
   - `spawnResumeBrain({ resumeFile, resumeCwd, resumeStep, ailangBin })`
   - Return true  (caller clears swapping on new brain's session_start)
   
   Ordering rationale: the old brain is killed before any filesystem changes. The window
   where `swe/` is absent (between the two renames) contains no running AILANG process.
   If the process crashes after rename #1 but before rename #2, recovery is:
   `swe_next/` still exists → `rename("swe_next", "swe")` on next startup.

### Phase 6 — index.ts wiring

Key changes beyond just wiring UpgradeManager:

```typescript
// Suppress process.exit(0) during swap
let swapping = false;

function spawnBrain(task: string, opts?: BrainOptions): void {
  brain = new Brain(task, envUrl, model,
    (event) => {
      if (event.type === "state_snapshot") { upgradeManager.onStateSnapshot(event); return; }
      if (event.type === "upgrade_ready")  { upgradeManager.onUpgradeReady(event);  return; }
      if (event.type === "error")          { upgradeManager.onError(); }
      if (event.type === "session_start" && swapping) { swapping = false; ui.unblockInput(); }
      if (event.type === "done" && upgradeManager.hasPendingUpgrade()) {
        // Block input SYNCHRONOUSLY before yielding to the event loop.
        // onDone() is async — if blockInput() were called inside it, JS would yield
        // first and the user could submit a message in the gap before blocking fired.
        // Editor.disableSubmit (pi-tui) prevents onSubmit from firing synchronously.
        ui.blockInput();
        upgradeManager.onDone(envUrl, model,
          (resumeOpts) => spawnBrain("(resumed)", resumeOpts),
          (status, stage, msg) => ui.handleEvent({ type: "upgrade_result", status, stage, message: msg }),
          () => ui.unblockInput(),   // called by onDone on success or failure
          (v) => { swapping = v; }
        );
      }
      ui.handleEvent(event);
    },
    () => {
      ui.brain = undefined;
      if (swapping) return;          // ← suppress exit during swap
      if (interrupted) { ... }
      else { ui.stop(); process.exit(0); }
    },
    opts
  );
  ui.brain = brain;
}
```

**Note:** `blockInput()` / `unblockInput()` must be added to `AgentUI` (see Phase 6b below).
The `blockUI` callback is removed from `onDone`'s signature — blocking is the caller's
responsibility, not the manager's.

### Phase 6b — AgentUI input blocking (tui/src/ui.ts)

pi-tui's `Editor` component already exposes `disableSubmit: boolean` which prevents
`onSubmit` from firing when the user presses Enter. Add two wrapper methods to `AgentUI`:

```typescript
blockInput(): void {
  this.cmdInput.disableSubmit = true;
}

unblockInput(): void {
  this.cmdInput.disableSubmit = false;
}
```

Update `UpgradeManager.onDone` signature — remove the `blockUI` parameter since
blocking is now the caller's responsibility:

```typescript
async onDone(
  envUrl: string,
  model: string,
  spawnResumeBrain: (opts: BrainOptions) => void,
  onResult: (status: "passed" | "failed", stage: string, msg: string) => void,
  unblockUI: () => void,
  setSwapping: (v: boolean) => void
): Promise<boolean>
```

### Phase 7 — Test suite parameterization (tui tests)

Each test file that spawns a brain or references `swe/rpc.ail` must read:

```typescript
const AILANG_BIN = process.env.AILANG_BIN ?? "ailang";
const SWE_FILE   = process.env.SWE_DIR    ?? "swe/rpc.ail";
```

Affected files: `env-server.test.ts`, `commands.test.ts` — review each before assuming scope.

### Phase 8 — AGENT_DIR env var + system prompt additions (tui/src/index.ts, swe/prompts.ail)

TypeScript sets `AGENT_DIR` to the absolute path of the agent installation directory
(the parent of `swe/`). Add self-extension instructions to `base_system()`:

```
## Self-extension

To modify your own brain:
1. rm -rf $AGENT_DIR/swe_next           ← always start clean
2. cp -r $AGENT_DIR/swe $AGENT_DIR/swe_next
3. Edit files in swe_next/ as needed
4. Type-check (see caveat below): ailang check $AGENT_DIR/swe_next/rpc.ail
5. In your final bash block, include:
       echo "UPGRADE_READY:$AGENT_DIR/swe_next"
   The brain detects this sentinel in the bash output and signals the frontend.
   Do NOT try to write JSON directly to stdout — bash output goes through the
   env server and is never seen as a raw event by the frontend.
6. Finish your task normally — the frontend will run tests and probe before swapping

To also extend the AILANG binary:
1. cp -r $AGENT_DIR/ailang $AGENT_DIR/ailang_next
2. Edit Go source, then: cd $AGENT_DIR/ailang_next && go build -o $AGENT_DIR/ailang_next_bin ./cmd/ailang/
3. $AGENT_DIR/ailang_next_bin check $AGENT_DIR/swe_next/rpc.ail
4. In your final bash block, include:
       echo "UPGRADE_READY:$AGENT_DIR/swe_next BIN:$AGENT_DIR/ailang_next_bin"
```

### Phase 9 — AILANG binary swap in UpgradeManager

Extends Phase 5 — already accounted for via the `new_ailang_bin` field.
The UpgradeManager tracks `this.ailangBin` (initially `"ailang"`) and passes it
to all future `Brain` spawns.

---

## `ailang check` Coverage Caveat

**Verify before relying on this gate.** `rpc.ail` imports 6 other modules
(`swe/types`, `swe/parse`, `swe/prompts`, `swe/env_client`, `swe/cache`,
`swe/agents_md`). If `ailang check` does not follow imports transitively, a type
error in any imported module would pass this gate undetected. Run
`ailang check swe/rpc.ail` against the current codebase and confirm it reports
errors in imported modules before trusting it as a validation step. If it does not,
either check each module individually or rely solely on the test suite + probe.

---

## Rollback

`swe_backup_<ts>/` is always preserved after every successful swap. The `/rollback`
command (handled in `tui/src/commands.ts`) triggers a reverse swap via `UpgradeManager`.

### Phase 10 — `/rollback` command (tui/src/commands.ts + tui/src/upgrade-manager.ts)

**`UpgradeManager.rollback()` steps:**

1. Find the most recent `swe_backup_<ts>/` directory (sort by `<ts>` descending).
   If none exists: emit error "no backup available", return.
2. `ui.blockInput()` — block input synchronously before any filesystem changes.
3. Kill current brain (SIGTERM). Set `swapping = true`.
4. `rename("swe", "swe_broken_<ts>")` — preserve current (broken) version for inspection.
5. `rename("swe_backup_<ts>", "swe")` — atomic placement of backup (same rename(2) pattern as forward swap).
6. If a `ailang_backup_<ts>` binary exists alongside the backup dir: restore it as `this.ailangBin`.
7. Write `latestSnapshot.msgs` to `/tmp/brain_resume_<ts>.json` (reuse last known snapshot).
8. `spawnResumeBrain({ resumeFile, resumeCwd, resumeStep, ailangBin })`.
9. On new brain's `session_start`: clear `swapping`, `ui.unblockInput()`, report result to UI.

**Wire into `commands.ts`:**

```typescript
case "/rollback":
  upgradeManager.rollback(
    () => ui.blockInput(),
    () => ui.unblockInput(),
    (v) => { swapping = v; },
    (opts) => spawnBrain("(rollback)", opts),
    (msg) => ui.handleEvent({ type: "upgrade_result", status: "passed", stage: "rollback", message: msg })
  );
  break;
```

**`UpgradeManager` addition:**

```typescript
rollback(
  blockUI: () => void,
  unblockUI: () => void,
  setSwapping: (v: boolean) => void,
  spawnResumeBrain: (opts: BrainOptions) => void,
  onResult: (msg: string) => void
): void
```

Note: `rollback()` is synchronous in its filesystem steps (no test suite, no probe —
the backup was already validated when it was first deployed). The brain spawn is still
async by nature, but no `await` is needed since the resume follows the same `session_start`
clearing pattern as a forward swap.

---

## Implementation Phases

| Phase | Change | Files |
|---|---|---|
| 0 | `upgrade_ready` sentinel detection + re-emit | `swe/parse.ail`, `swe/rpc.ail` |
| 1 | `state_snapshot` emission (once, before `done`) + `encode_msgs` | `swe/rpc.ail` |
| 2 | `--probe` mode (`probe_main` entry) | `swe/rpc.ail` |
| 3 | Brain resume path (`RESUME_MSGS_FILE` gate) + `parse_msgs` | `swe/rpc.ail` |
| 4 | `BrainOptions` + new event types | `tui/src/brain.ts` |
| 5 | `UpgradeManager` class | `tui/src/upgrade-manager.ts` (new) |
| 6 | Wire into index.ts: `swapping` flag, event routing, sync `blockInput()` before `onDone` | `tui/src/index.ts` |
| 6b | Add `blockInput()` / `unblockInput()` to AgentUI via `Editor.disableSubmit` | `tui/src/ui.ts` |
| 7 | Test suite env var parameterization | `tui/src/*.test.ts` |
| 8 | `AGENT_DIR` + system prompt self-extension section | `tui/src/index.ts`, `swe/prompts.ail` |
| 9 | AILANG binary swap in UpgradeManager | `tui/src/upgrade-manager.ts` |
| 10 | `/rollback` command + `UpgradeManager.rollback()` | `tui/src/commands.ts`, `tui/src/upgrade-manager.ts` |

Phases 0–7 are the MVP (swe/ hot-swap, no AILANG binary extension).
Phases 8–9 add AILANG binary extension and agent self-awareness.
Phase 10 adds rollback; should ship with Phase 5 (unsafe to deploy forward swap without it).

---

## Known Limitations

- **Old system prompt in resumed session**: the resumed brain's `msgs[0]` was generated
  by the old `prompts.ail`. If the upgrade modified the system prompt, the change takes
  effect only in the next fresh session.
- **`encode_msgs` / `parse_msgs` complexity**: both are implementable with existing
  stdlib — `ja`, `map`, `asArray`, `getString` are all available. Neither requires
  binary changes. The implementations are ~20 lines each of recursive pattern matching;
  budget time to test them against real conversation histories before relying on them
  for resume.
- **`swe_next/` preserved after failure**: intentional — the user may want to inspect
  the staged code. The brain must always start with `rm -rf swe_next/` to avoid
  conflicts on the next upgrade attempt.
- **SharedMem probe contamination**: the probe brain shares the same SharedMem namespace
  as the live session. Keys such as `swe:current_model` and trajectory cache entries are
  global, not task-scoped. A probe run that writes to SharedMem (e.g. a model-change
  command arriving on stdin during the probe window, or a cache write) could affect the
  resumed brain. In practice `probe_main` makes no SharedMem calls, but future changes
  to rpc.ail that add SharedMem side-effects on startup would silently break this
  isolation. Mitigation for v2: pass a `SHAREDMEM_NS` env var to the probe so its keys
  are namespaced separately from the live session.

---

## Open Risks

1. **`ailang check` import depth**: may not validate transitively — verify before relying on it (see §caveat).
2. **Concurrent upgrades**: a second `upgrade_ready` replaces the first pending upgrade silently. Acceptable for v1.
3. **Large msgs in state_snapshot**: by step 30+, the JSON payload can be hundreds of KB. Acceptable since it is emitted only once per task, not every step.
4. **probe timeout on slow hosts**: 30 s may be tight in resource-constrained CI. Make timeout configurable via `PROBE_TIMEOUT_MS` env var.
