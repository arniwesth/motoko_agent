# Context-Mode Extension for Motoko

## Goal

Integrate [context-mode](https://github.com/mksglu/context-mode) as a Motoko extension, following the same `ExtensionHooks` pattern used by omnigraph, compose, and test_dummy. Context-mode reduces context window consumption ~98% by sandboxing tool output, indexing session state in SQLite FTS5, and compressing LLM output.

## Licensing

Context-mode is licensed under the **Elastic License 2.0** (ELv2), not MIT/Apache. ELv2 prohibits offering the software as a managed service but permits internal use, modification, and distribution as part of a larger product. Confirm this is compatible with Motoko's license before starting implementation. If not, the extension must wrap context-mode as an optional, user-installed binary (similar to how omnigraph is optional), never vendoring its source.

## Background

### What context-mode does

Context-mode is a TypeScript MCP server (10k+ stars) that solves context window bloat. It has four mechanisms:

1. **Sandboxed execution** -- Raw tool output stays in a subprocess. Only compact results enter context. A 56KB Playwright snapshot becomes 299 bytes.
2. **Session persistence** -- File edits, git ops, tasks, errors indexed in SQLite FTS5. When conversations compact, relevant state is rebuilt via BM25 search.
3. **Code-generation paradigm** -- Agents write scripts that output only results, replacing 10 tool calls with 1.
4. **Output compression** -- Terse technical output, 65-75% output token reduction.

### How Pi integrates it

Context-mode already has a Pi extension (`src/pi-extension.ts`) that:
- Registers lifecycle hooks: `session_start`, `tool_call`, `tool_result`, `before_agent_start`, `session_before_compact`, `session_compact`, `session_shutdown`
- Maps Pi's tool names to PascalCase conventions
- Blocks raw `curl`/`wget`/`fetch` to prevent context flooding
- Stores events in `~/.pi/context-mode/sessions/context-mode.db`
- Exposes slash commands: `/ctx-stats`, `/ctx-doctor`

### How Motoko extensions work

Extensions implement `ExtensionHooks` (defined in `src/core/ext/types.ail`):

| Hook | Purpose |
|------|---------|
| `on_build_system_prompt` | Prepend/append to system prompt |
| `on_budget_plan` | Adjust step budget |
| `on_tool_policy` | Allow/Deny/NoOpinion on tool calls |
| `on_tool_handle` | Intercept and handle tool calls directly |
| `on_response_intercept` | Intercept LLM responses |
| `on_solver_candidate` | Accept/ContinueWithFeedback/NoDecision on final answer |

Extensions are registered in `src/core/ext/registry.ail`, activated via `CORE_EXT_ORDER=context_mode`, and packaged under `.packages/motoko_context_mode/`.

---

## Architecture

```
Motoko agent loop
  │
  ├── on_build_system_prompt
  │     Inject context-mode routing instructions + cached session snapshot
  │
  ├── on_tool_handle
  │     Route ctx_execute, ctx_search, ctx_index, ctx_stats, ctx_doctor
  │     to context-mode CLI via std/process.exec (same as omnigraph)
  │     Compress stdout/stderr in ToolResultEnvelope before returning
  │     Lazy-load session snapshot on first call, cache in SharedMem
  │
  ├── on_response_intercept
  │     NoIntercept (reserved for future use)
  │
  └── on_solver_candidate
        Index final output in session store via CLI shell-out

context-mode CLI (invoked per tool call)
  │
  ├── SQLite FTS5 session store (persists on disk between calls)
  ├── Sandboxed code executor (11 languages)
  └── BM25 search + session snapshots
```

### Process model

Context-mode communicates with the AILANG extension via **shell exec** (`std/process.exec`), the same pattern omnigraph uses. Context-mode has a CLI (`context-mode hook <platform> <hooktype>`) that can be invoked per-call. Two options were considered:

- **Option A (HTTP sidecar):** Context-mode runs as an MCP server on a TCP port. The AILANG extension calls it via `httpPost`. This would require the `Net` effect (no other extension uses it), a new sidecar lifecycle in the TUI, and a fallback path when the sidecar is down.
- **Option B (recommended):** The extension shells out to `context-mode` CLI commands via `std/process.exec`, identical to how omnigraph wraps the `omnigraph` binary. Session state persists in SQLite on disk, so no long-lived process is needed between calls.

Option B is preferred because:
1. It matches the pattern of every existing extension (omnigraph, compose)
2. No new `Net` effect dependency — only `Process` + `FS`
3. No sidecar lifecycle management in the TUI
4. No failure mode when a sidecar process crashes mid-session
5. Context-mode's SQLite store persists across invocations regardless

**Fallback behavior:** If the `context-mode` binary is not on PATH, `exec` returns a `NotFound` error. In this case, `on_tool_handle` returns `Delegate`, letting the core loop handle the tool call normally. The agent degrades gracefully to operating without context compression.

---

## Implementation Plan

### Phase 1: Package scaffold and CLI wrapper

**Source of truth:** `src/core/ext/context_mode/` is the authoring directory (like omnigraph, compose). The `.packages/motoko_context_mode/` copy is generated during packaging — do not edit `.packages/` directly.

**Files to create:**

```
src/core/ext/context_mode/
  context_mode.ail        -- register() entry point
  types.ail               -- CtxConfig, CtxSession types
  exec.ail                -- Shell exec wrapper for context-mode CLI
  prompts.ail             -- System prompt patch with routing instructions
  compress.ail            -- Output compression logic
  context_mode_test.ail   -- Inline tests
  AGENT.md                -- Package docs
  ailang.toml             -- Package manifest
```

**`ailang.toml`:**
```toml
[package]
name = "sunholo/motoko_context_mode"
version = "0.1.0"
edition = "1"
module_prefix = "src"

[exports]
modules = ["src/core/ext/context_mode/context_mode"]

[dependencies]
"sunholo/motoko_core" = { path = "../motoko_core" }

[effects]
max = ["Process", "FS", "IO", "Env"]
```

**Prerequisites:** `context-mode` must be installed on PATH (e.g., `npm install -g context-mode`). The extension does not manage the binary lifecycle — same model as omnigraph.

**Tasks:**
1. Create `src/core/ext/context_mode/` scaffold with `ailang.toml` and `AGENT.md`
2. Create `src/core/ext/context_mode/types.ail` with `CtxConfig` record
3. Create `src/core/ext/context_mode/exec.ail` with shell exec wrapper (model on `omnigraph/exec.ail`: `exec("bash", [...])` invoking the `context-mode` CLI)
4. Verify `context-mode` CLI is available at register time; log warning if missing

### Phase 2: System prompt injection

**`src/core/ext/context_mode/prompts.ail`**

Adapt context-mode's routing instructions (from `configs/CLAUDE.md` in their repo) for Motoko's system prompt format. The prompt patch tells the LLM:
- Use `ctx_execute` for code execution instead of raw bash when exploring files
- Use `ctx_search` to recall indexed session state
- Use `ctx_index` to persist important findings
- Never use raw `curl`/`wget`/`fetch` -- use `ctx_fetch_and_index` instead

The `on_build_system_prompt` hook appends these instructions plus a session snapshot (if resuming).

**Session snapshot at startup:** The `register()` function has effect signature `! {Env, FS}` — it cannot shell out (`Process` is not available). Static routing instructions are loaded from an `AGENT.md` file via `readFile` (FS is available), same pattern as omnigraph's `load_agent_prompt`. The session snapshot is **not** loaded at registration time.

Instead, the session snapshot is **lazy-loaded on the first `on_tool_handle` call** (which has full effects including `Process`). The first ctx_* tool invocation shells out to `context-mode` to get the session summary, stores it in SharedMem, and subsequent calls reuse the cached value. The `on_build_system_prompt` hook includes only the static routing instructions on the first turn; the snapshot becomes available from the second turn onward.

**Tasks:**
1. Write `prompts.ail` with `build_prompt_patch()` that returns a `PromptPatch` with context-mode routing instructions appended
2. Load and cache the routing instructions from an `AGENT.md` file via `readFile` during `register()` (same pattern as omnigraph's `load_agent_prompt`)
3. Implement lazy session snapshot loading in `on_tool_handle` — shell out to `context-mode` CLI on first call, cache result in SharedMem for subsequent `on_build_system_prompt` calls

### Phase 3: Tool routing

**`src/core/ext/context_mode/context_mode.ail`** -- the `register()` function and tool dispatch.

**Provided tools** (registered in `ExtensionHooks.provided_tools`):
```
ctx_execute, ctx_batch_execute, ctx_execute_file,
ctx_index, ctx_search, ctx_fetch_and_index,
ctx_stats, ctx_doctor, ctx_purge
```

The `on_tool_handle` hook:
1. Pattern-match on tool name
2. Extract arguments from `ToolCallEnvelope.arguments`
3. Build CLI arguments for `context-mode`
4. Shell out via `exec("bash", [...])` (same pattern as `omnigraph/exec.ail:run_omnigraph`)
5. Parse stdout, return `Handled(ToolResultEnvelope)` with compressed output
6. **Fallback:** If `exec` returns `NotFound` or `SpawnFailed`, return `Delegate` so the core loop handles the call normally. The agent degrades gracefully without context-mode.

**`on_tool_policy` hook:**
- `on_tool_policy` receives a `ToolCallEnvelope` with `{id, tool, arguments}`. It can only gate on **named tool calls** (like `ctx_execute`, `ReadFile`, `OmnigraphMutate`), not on raw bash commands embedded in LLM responses. Bash commands flow through `env_client.exec_in` as an HTTP POST — there is no `ToolCallEnvelope` for individual bash commands.
- Therefore, curl/wget blocking **cannot** be done in `on_tool_policy`. Two alternatives:
  - **(a) Prompt-based:** Include "never use raw curl/wget; use ctx_fetch_and_index instead" in the system prompt routing instructions (Phase 2). This is how context-mode handles it in most platforms — via routing instructions, not hard enforcement.
  - **(b) Future hook:** If hard enforcement is needed, a new `on_before_bash_exec` hook would need to be added to `ExtensionHooks`. Defer this — prompt-based routing is sufficient for v0.1.
- For named tool calls: return `NoOpinion` for all tools. The extension does not restrict any named tools.
- The `on_tool_policy` hook is effectively a no-op for this extension in v0.1.

**Tasks:**
1. Write `context_mode.ail` with `register()` returning `ExtensionHooks`
2. Implement `on_tool_handle` dispatching to `context-mode` CLI for each ctx_* tool, with `Delegate` fallback on binary-not-found
3. Implement `on_tool_policy` as no-op (`NoOpinion` for all calls); curl/wget blocking handled via prompt routing instructions
4. Add tool name normalization (PascalCase, snake_case, dot-notation aliases)

### Phase 4: Output compression and session indexing

**Where compression happens:** Output compression is done inside `on_tool_handle`, NOT `on_response_intercept`.

`on_response_intercept` receives the raw **LLM response text** (the model's reply), not tool output. When `InterceptHandled` fires, it replaces the entire response processing path — tool parsing is skipped, and the intercepted result becomes a new observation turn. Using it for size-gated compression would swallow normal tool-call responses above the threshold, breaking the agent loop.

Instead, compression happens at two points:
1. **In `on_tool_handle`** — when building the `ToolResultEnvelope` to return as `Handled(...)`, compress the stdout/stderr before constructing the envelope. This is where tool output enters the conversation history.
2. **In `exec.ail`** — the `run_context_mode` function (analogous to `run_omnigraph`) applies compression to CLI output before returning the envelope.

**`on_response_intercept` hook:**
- Left as `NoIntercept` for now. Could be used in the future to intercept responses that contain inline data dumps (e.g., the LLM pasting a full file), but this is a separate concern from tool output compression.

**`on_solver_candidate` hook:**
- When the agent produces a final answer, index it in the session store via `context-mode` CLI
- Return `NoDecision` (don't alter the accept/continue behavior)

**`src/core/ext/context_mode/compress.ail`:**
- Pure functions for output compression heuristics
- Strip ANSI codes, collapse whitespace, truncate repetitive output
- Called by `exec.ail` before constructing `ToolResultEnvelope`
- Target: observation text that enters `history_slice` is kept compact

**Tasks:**
1. Write `compress.ail` with `compress_output(text: string, max_chars: int) -> string`
2. Apply compression in `exec.ail` when building tool result envelopes
3. Implement `on_solver_candidate` with session indexing via CLI shell-out
4. Add inline tests for compression edge cases

### Phase 5: Registry integration and activation

**`src/core/ext/registry.ail` changes:**
1. Add import: `import pkg/sunholo/motoko_context_mode/core/ext/context_mode/context_mode (register as context_mode_register)`
2. Add `register_context_mode()` wrapper function
3. Add `"context_mode"` case to `resolve()` function
4. Update `parse_tokens_names` to recognize `"context_mode"`

**Activation:**
```bash
CORE_EXT_ORDER=context_mode make run TASK="..." MODEL=...
```

**Tasks:**
1. Add context_mode to registry.ail (import, resolve, parse_tokens_names)
2. Update registry tests for the new extension name
3. Document activation in README.md and CLAUDE.md

### Phase 6: Testing

**Unit tests (AILANG, pure):**
- `context_mode_test.ail` -- tool name normalization, prompt patch construction, compression functions, policy decisions
- Target: 15-20 inline tests

**Integration tests (AILANG, requires `context-mode` on PATH):**
- Test that `exec.ail:run_context_mode` correctly shells out and parses output
- Test fallback behavior when binary is missing (mock via invalid PATH)

**End-to-end:**
- Run agent with `CORE_EXT_ORDER=context_mode` on a sample task
- Verify ctx_execute calls are routed through context-mode CLI
- Verify context savings reported by ctx_stats

**Tasks:**
1. Write `context_mode_test.ail` with inline tests (pure: normalization, compression, prompt patch)
2. Write integration tests for `exec.ail` (requires `context-mode` binary)
3. Manual E2E smoke test with `CORE_EXT_ORDER=context_mode`

---

## File inventory

Source of truth is `src/core/ext/context_mode/`. The `.packages/motoko_context_mode/` copy is generated during packaging.

| File | Action | Purpose |
|------|--------|---------|
| `src/core/ext/context_mode/ailang.toml` | Create | Package manifest |
| `src/core/ext/context_mode/AGENT.md` | Create | Package docs |
| `src/core/ext/context_mode/context_mode.ail` | Create | register() + tool dispatch |
| `src/core/ext/context_mode/types.ail` | Create | CtxConfig, session types |
| `src/core/ext/context_mode/exec.ail` | Create | Shell exec wrapper for context-mode CLI |
| `src/core/ext/context_mode/prompts.ail` | Create | System prompt routing instructions |
| `src/core/ext/context_mode/compress.ail` | Create | Output compression (pure) |
| `src/core/ext/context_mode/context_mode_test.ail` | Create | Tests |
| `src/core/ext/registry.ail` | Edit | Add context_mode to resolve() |

---

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CTX_DB_PATH` | `~/.motoko/context-mode/sessions/` | SQLite session store location |
| `CTX_COMPRESS_THRESHOLD` | `2048` | Chars above which output is compressed |
| `CTX_SESSION_ID` | (derived from `state_key`) | Override session ID for context-mode |

---

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| `context-mode` binary not installed | `on_tool_handle` returns `Delegate` on `NotFound`/`SpawnFailed`; agent degrades gracefully |
| CLI version drift | Document minimum supported version in AGENT.md; check version in `register()` |
| SQLite FTS5 not available on all platforms | context-mode bundles its own SQLite; no host dependency |
| Elastic License 2.0 restricts managed-service use | Extension wraps context-mode as an external binary; never vendor its source |
| Shell exec overhead per tool call | Acceptable — omnigraph uses the same pattern; typical call is <100ms |

---

## Dependency on Pi's pattern

The Pi extension (`src/pi-extension.ts` in context-mode repo) maps lifecycle hooks to Pi's event model. Our Motoko extension does the equivalent mapping to `ExtensionHooks`:

| Pi lifecycle hook | Motoko ExtensionHooks equivalent |
|---|---|
| `session_start` | `on_build_system_prompt` (inject session snapshot, cached at `register()` time) |
| `tool_call` | `on_tool_policy` (block dangerous tools) |
| `tool_result` | `on_tool_handle` (compress output in the returned `ToolResultEnvelope`) |
| `before_agent_start` | `register()` (load config, check binary, cache session snapshot) |
| `session_before_compact` | `on_solver_candidate` (index before compaction) |
| `session_shutdown` | No equivalent in ExtensionHooks (not needed — no sidecar to stop) |

---

## Open questions

1. **Session ID derivation:** Pi uses SHA256 of session file path. Motoko should use the `state_key` from `ExtCtx` as session ID. Confirm this is stable across the session lifetime.
2. **Compaction event:** Motoko doesn't have an explicit compaction hook. The `on_solver_candidate` hook is the closest -- should we add a new `on_compaction` hook to `ExtensionHooks`? Defer unless needed.
3. **CLI transport:** Context-mode's CLI (`context-mode hook motoko <hooktype>`) may not exist yet — it currently supports `claude-code`, `gemini-cli`, `cursor`, etc. We may need to contribute a Motoko adapter upstream or use a generic hook interface. Verify before Phase 3.
