# M-MOTOKO-PROFILE-SWITCHING

## Summary

Add a `/profile` command to motoko that allows listing available profiles and switching between them during an active session, similar to how `/model` switches models today.

## Motivation

Motoko profiles bundle configuration presets:
- **Model selection** (`agent.model`)
- **Extension set** (`extensions.order`) — different profiles may enable/disable omnigraph, compose, context-mode, etc.
- **Tool settings** (`tools.hybrid`, `tools.ohmy_pi`, etc.)
- **Backend config** (port, command, auto-start)
- **Verification settings** (DP7 gate, custom commands)

Currently, selecting a profile requires restarting motoko with `MOTOKO_CONFIG=<profile>` or `--profile <profile>`. This is friction-heavy when:
1. Switching between "lightweight" profiles (no extensions) and "full" profiles (all extensions) for different task types
2. Testing how a task behaves under different extension configurations
3. Moving from a development profile (dogfood, verbose logging) to a production profile

A `/profile` command would make profile-switching as fluid as model-switching.

## Current Architecture

### Profile loading (startup-only)

```
src/core/config.ail:
  load_config_from_cli(args)
    → active_profile(cli.profile)           // MOTOKO_CONFIG env or --profile flag
    → resolve_profile_dir(workdir, profile) // .motoko/config/<profile>/ or fallback
    → load_agent/core/tools/extensions/etc. from config.json + *.json
    → RuntimeConfig record

src/tui/src/index.ts:
  spawnRuntimeProcess(task, logPrompt)
    → RuntimeProcess constructor reads profile once
    → childEnv.MOTOKO_HEADLESS set based on TTY
    → AILANG process started with --profile <name>
```

### Model switching (runtime)

```
src/tui/src/commands.ts:
  /model <name>  → ui.switchModel(name)
  /model         → ui.showModelPicker()

src/tui/src/ui.ts:
  switchModel(model):
    → this.model = model
    → this.onModelChange?.(model)

src/tui/src/index.ts:
  ui.onModelChange = (newModel) => runtimeProcess?.setModel(newModel)

src/tui/src/runtime-process.ts:
  setModel(model): void {
    this.send({ type: "model_change", model });
  }

src/core/agent_loop_v2.ail (conversation_loop_v2):
  cmd_type == "model_change" →
    let new_model = msg_get_str(obj, "model");
    conversation_loop_v2(..., resolved_new, ...)  // recurse with new model
```

Key insight: **Model switching is lightweight** because it only changes one field. The AILANG runtime doesn't reload extensions, backend, or tool config—it just continues the conversation loop with a different model string.

## Design Challenge: Profile Switching Is Not Like Model Switching

Switching profiles is fundamentally different because it affects:

| Config Section | Changed by Profile Switch? | Runtime Impact |
|----------------|---------------------------|----------------|
| `agent.model` | Yes | Easy — already handled by model_change |
| `extensions.order` | Yes | **Hard** — extensions have state (omnigraph DB, MCP connections) |
| `tools.hybrid` | Yes | Medium — changes bash extraction behavior |
| `backend.port` | Possibly | **Hard** — may require restarting env-server |
| `agent.workdir` | Possibly | Medium — changes FS sandbox |
| `verification.command` | Yes | Easy — only affects DP7 gate |

### The Extension State Problem

Extensions registered via `ExtensionHooks` may hold state:
- **omnigraph**: SQLite database connection, branch state
- **context_mode**: Session cache, SQLite FTS index
- **mcp**: Persistent MCP server connections
- **compose**: Subagent state

Unloading an extension mid-session is **not supported** by the current `ExtRuntime` architecture. The `ExtensionHooks` interface has no `on_unload` callback.

### The Backend Problem

If two profiles have different `backend.port` or `backend.command`, switching profiles would require:
1. Stopping the current env-server process
2. Starting a new env-server on a different port
3. Updating the AILANG runtime's `env_url` for subsequent HTTP calls

This is non-trivial coordination between the TUI (which manages the backend process) and the AILANG runtime (which calls it).

## Proposed Design

### Option A: Full Process Restart (Recommended)

The simplest and most robust approach: `/profile <name>` restarts the AILANG runtime process with the new profile, preserving conversation history.

**Mechanism:**
1. TUI sends `profile_change` command to AILANG runtime
2. AILANG runtime emits `profile_switch` event with:
   - `requested_profile`: target profile name
   - `history`: current conversation `[Message]`
   - `session_id`: for continuity
3. AILANG runtime exits cleanly (code 0)
4. TUI catches the exit, sees `profile_switch` event in the final JSONL output
5. TUI spawns a new AILANG process with `--profile <name> --resume <session_id>`
6. New AILANG process loads the new profile config, restores history, continues

**Pros:**
- Clean extension lifecycle (full init in new process)
- Backend can change (new process = new backend port)
- No complex state migration logic
- Works with any profile difference

**Cons:**
- Slight delay on switch (process restart)
- Requires implementing session persistence/resume
- Env-server may need restart if port changes

**Implementation:**

```typescript
// src/tui/src/runtime-process.ts
switchProfile(profile: string): void {
  this.send({ type: "profile_change", profile });
}

// src/core/agent_loop_v2.ail (conversation_loop_v2)
else if cmd_type == "profile_change" then {
  let new_profile = msg_get_str(obj, "profile");
  // Emit event with history for resume
  let _ = emit_event(session_id, "profile_switch", [
    kv("requested_profile", js(new_profile)),
    kv("history", ja(messages_to_json(history))),
    kv("model", js(model))
  ]);
  // Exit cleanly — TUI will respawn with new profile
  ()
}
```

**Session resume mechanism:**
- Option A1: Pass history via stdin on respawn (limited by OS pipe buffer)
- Option A2: Write history to temp file, pass path via `--resume-file`
- Option A3: Use session_id to load from `.motoko/logfile/` JSONL

Option A3 is preferred — session JSONL already exists for logging.

### Option B: In-Process Config Reload

Reload config without restarting the process. Only works for a subset of config changes.

**Mechanism:**
1. TUI sends `profile_change` command
2. AILANG runtime:
   - Reads new profile config from `.motoko/config/<profile>/`
   - Updates `RuntimeConfig` in memory
   - For safe changes (model, verification, tools.hybrid): apply immediately
   - For unsafe changes (extensions, backend): return error, require restart

**Safe changes:**
- `agent.model` (already handled)
- `agent.max_steps`, `agent.max_cost_millicents`
- `tools.hybrid`
- `verification.enabled`, `verification.command`

**Unsafe changes (require restart):**
- `extensions.order` (cannot unload extensions)
- `backend.port`, `backend.command` (TUI-managed)
- `agent.workdir` (AILANG_FS_SANDBOX set at process start)

**Pros:**
- No process restart
- Instant switch for safe changes

**Cons:**
- Two code paths (safe vs unsafe) increases complexity
- User confusion: "why can't I switch to dogfood profile?"
- Extensions still cannot be changed

### Option C: Profile-Supported Changes Only

Restrict `/profile` to profiles that only differ in "safe" fields. Detect incompatible profiles and reject the switch.

**Mechanism:**
1. TUI scans all profiles at startup, caches their config
2. `/profile <name>` compares current profile vs target profile
3. If only safe fields differ → send `profile_change`, apply in-process
4. If unsafe fields differ → show warning: "Profile 'dogfood' requires restart. Use /restart dogfood to switch."

**Pros:**
- Clear user expectations
- No partial state corruption

**Cons:**
- Limited utility (most interesting profile differences are in extensions)
- Still need `/restart` command for full switches

## Recommended Approach: Option A (Full Process Restart)

With session persistence already in place (`.motoko/logfile/` JSONL), the implementation path is:

### Phase 1: `/restart` Command

Add a `/restart` command that restarts the current session with optional profile change:

```
/restart              → Restart with current profile (clear state, keep model)
/restart <profile>    → Restart with new profile
```

This is the foundation for profile switching without needing complex in-process reload.

### Phase 2: Session Resume

Implement session resume so the conversation history survives the restart:

1. On restart, emit `session_suspend` event with `session_id`
2. TUI spawns new process with `--resume <session_id>`
3. New process loads last N turns from `.motoko/logfile/session_<id>.jsonl`
4. Conversation continues with history restored

### Phase 3: `/profile` Command (Sugar over `/restart`)

```
/profile              → Show profile picker
/profile <name>       → Switch to profile (alias: /restart <name>)
```

Autocomplete lists available profiles from `.motoko/config/*/config.json`.

## Implementation Plan

### Phase 1: `/restart` command (M-MOTOKO-RESTART-COMMAND)

**Files to modify:**
- `src/tui/src/commands.ts`: Add `restartCommand`
- `src/tui/src/ui.ts`: Add `restart()` method, `onRestart` callback
- `src/tui/src/index.ts`: Wire `onRestart` to respawn runtime process
- `src/core/agent_loop_v2.ail`: Handle `restart` command type

**Behavior:**
1. `/restart` sends `{ type: "restart" }` to AILANG
2. AILANG emits `session_suspend` event with session_id
3. AILANG exits with code 0
4. TUI sees exit, respawns with same args + `--resume <session_id>`

**Estimated effort:** 2-3 hours

### Phase 2: Session resume (M-MOTOKO-SESSION-RESUME)

**Files to modify:**
- `src/core/config.ail`: Add `--resume` CLI arg, `InvocationConfig.resume_session_id`
- `src/core/agent_loop_v2.ail`: On resume, load history from JSONL, continue conversation

**History loading:**
```ailang
func load_session_history(session_id: string, max_turns: int) -> [Message] ! {FS, IO} {
  let path = ".motoko/logfile/session_${session_id}.jsonl";
  let lines = readLines(path);  // Read last N lines
  // Parse user_message and assistant turns, reconstruct [Message]
  ...
}
```

**Estimated effort:** 4-6 hours

### Phase 3: `/profile` command (M-MOTOKO-PROFILE-COMMAND)

**Files to modify:**
- `src/tui/src/commands.ts`: Add `profileCommand`, autocomplete for profile names
- `src/tui/src/ui.ts`: Add `showProfilePicker()`, `switchProfile()`
- `src/tui/src/models.ts`: Add `fetchAvailableProfiles()` (scan `.motoko/config/`)
- `src/core/agent_loop_v2.ail`: Handle `profile_change` → emit `session_suspend` with target profile

**Profile picker:**
- List directories under `.motoko/config/`
- Show profile name + current model + extension count
- On select: `/restart <profile>`

**Estimated effort:** 2-3 hours

## UI Design

### `/profile` picker

```
┌─────────────────────────────────────────────────────────────┐
│  Select profile:                                            │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  default         deepseek-v4-pro | ext: context_mode,exa,… │
│  dogfood         deepseek-v4-pro | ext: context_mode,exa,… │
│  local           (no extensions)                          │
│  openrouter      gemini-2.5-flash | ext: omnigraph        │
│  ailang          claude-sonnet-4-6 | ext: compose,omni…   │
└─────────────────────────────────────────────────────────────┘
```

### Status bar

Current status bar shows model and extensions:
```
    model: deepseek-v4-pro | branch: main | ext: context_mode,exa_search,omnigraph
```

Add profile:
```
    profile: default | model: deepseek-v4-pro | branch: main | ext: context_mode,…
```

### History message on switch

```
[19:45:32] Profile → dogfood (max_steps: 600, ext: compose,omnigraph)
```

## Open Questions

1. **Should `/profile` require confirmation when extensions differ?**
   - Pro: User knows that omnigraph DB won't be available
   - Con: Extra friction
   - Recommendation: Show warning in history, don't block

2. **Should history survive profile switches?**
   - Pro: Seamless continuation
   - Con: Extension-specific tool results may not make sense
   - Recommendation: Yes, but emit warning if history contains tool results from extensions not in new profile

3. **What about workdir changes?**
   - If profiles have different workdirs, should FS sandbox change?
   - Recommendation: Ignore workdir in profile switches; workdir is a session-level concept set at startup

4. **Backend port conflicts?**
   - If new profile uses a different backend port, TUI needs to manage the transition
   - Recommendation: In Phase 1, require same backend port across profiles. In Phase 2+, support backend migration.

## Alternatives Considered

### In-place extension hot-swap

Add `on_unload` to `ExtensionHooks` and support runtime extension changes.

**Rejected because:**
- Complex implementation (state serialization for each extension)
- Risk of resource leaks (DB connections, MCP sockets)
- No clear use case justifies the complexity

### Profile inheritance

Allow profiles to extend other profiles, reducing duplication.

**Deferred because:**
- Not blocking for `/profile` command
- Can be added later without affecting the command design

## Success Metrics

1. **Time to switch profiles:** < 3 seconds for typical profiles
2. **History preservation:** 100% of user/assistant turns survive a switch
3. **Error rate:** < 1% of switches fail due to state inconsistencies

## Timeline

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Phase 1: `/restart` | 2-3h | None |
| Phase 2: Session resume | 4-6h | Phase 1 |
| Phase 3: `/profile` picker | 2-3h | Phase 1, 2 |
| **Total** | **8-12h** | |

## References

- Current profile loading: `src/core/config.ail` L450-L550
- Model switching: `src/tui/src/commands.ts` L47-L58
- Conversation loop command handling: `src/core/agent_loop_v2.ail` L1230-L1270
