---
doc_type: short
full_text: sources/2026-03-30-ailang-swe-agent-debug.md
---

# SWE Agent Debugging Summary

## Overview
This document chronicles six intensive debugging sessions of the SWE (Software Engineering) agent built in the AILANG language. The primary goal was to make a `MODEL=openai/gpt-4o` agent run end‑to‑end, executing tasks via a TUI and an environment server. The debugging uncovered critical syntactic, semantic, and runtime integration flaws in both the AILANG codebase and the surrounding TypeScript scaffolding.

## Key Findings by Session

### Session 1 – Module Loading Errors
- **Problem**: Twenty‑plus parse errors across all `swe/*.ail` modules.
- **Root Cause**: The entire `swe/` module tree was auto‑generated without verification against actual AILANG rules.
- **Errors Fixed**:
  - **Expression‑body functions with `;`**: Functions using `=` must not contain semicolons; multi‑binding sequences require `let … in …`. Converted all such functions to brace‑body `{ … }`.
  - **`export let`**: AILANG does not support `export let`. Replaced with `export func` returning a constant.
  - **API mismatches**: Numerous calls to non‑existent functions (`hd`, `float()`, `::` in expressions, SharedMem with strings instead of bytes, incorrect field names, wrong imports, missing `Option` import, `main()` effect set missing `Env`).
  - **Multi‑statement match arms**: Bare `=>` with multiple statements were illegal; required wrapping in `{}`.

### Session 2 – Capability and Network Flags
- **Problem**: Runtime errors about `Env` capability and network connectivity.
- **Fixes in `brain.ts`**:
  - Added `Env` to `--caps` list because `getEnvOr` carries the `Env` effect.
  - Added `--net-allow-http` and `--net-allow-localhost` flags, as the environment server runs on `http://localhost:8080` and AILANG’s Net effect handler blocks both `http://` and localhost by default.

### Session 3 – Model ID, Trace Hijack, Hardcoded CWD
- **Bug 1 – `openai/gpt‑4o` passed verbatim to `--ai`**: The `--ai` flag expects bare model names, not `provider/model`. Stripped prefix before spawning.
- **Bug 2 – `--emit-trace` silenced JSONL pipe**: With `--emit-trace`, `println` was redirected to stderr, swallowing the agent’s JSONL protocol on stdout. Removed trace flag.
- **Bug 3 – Hardcoded `/testbed`**: `main()` ignored the `WORKDIR` variable. Fixed by reading `getEnvOr("WORKDIR", "/testbed")`.
- **Ancillary fix**: Non‑TTY environments (devcontainer) hung because of `process.stdin.resume()`. Added a `PlainLogger` that avoids stdin and exits cleanly when no TTY is present.

### Session 4 – Wrong Write Directory
- **Problem**: Agent wrote to `/testbed` despite `WORKDIR` being set to another directory.
- **Root Cause**: `brain.ts` did not pass `WORKDIR` in the spawned process’s environment; the system prompt (`base_system`) had 11 hardcoded `/testbed` references.
- **Fixes**:
  - Forwarded `WORKDIR` explicitly in `brain.ts`.
  - Parameterised `base_system(workdir: string)` and replaced all hardcoded paths.
  - Reordered `main()` to read `cwd` before calling the parameterised `base_system`.

### Session 5 – Continued Conversation After Task Completion
- **Problem**: Agent was a one‑shot tool; no follow‑up input possible after `done`.
- **Fixes**:
  - `rpc_loop` now returns `AgentState` (the full conversation history) instead of a string.
  - Added `conversation_loop` that blocks on `readLine()`, accepts `user_message` JSON commands, re‑enters `rpc_loop`, and preserves the full history.
  - Added `brain.sendUserMessage()` to send follow‑up text via stdin.
  - UI now tracks `taskDone`, routes plain text as follow‑up, and updates status hints.

### Session 6 – Rate Limit Handling
- **Problem**: `openai/gpt‑4o` rate limit (429) crashed the brain because AILANG has no try/catch.
- **Fix**: Introduced an `AI_STEP_DELAY_MS` environment variable. In `rpc_loop` and `conversation_loop`, a `std/clock.sleep(step_delay)` is inserted before every LLM call. The delay is parsed from the env var (default 0). The `Clock` effect was added to the capability set.

## Design Insights and Cross‑Cutting Concepts

### AILANG Language Nuances
- AILANG’s strict separation between expression‑body (`= expr`) and brace‑body (`{ stmts }`) has significant implications for code generation – see [[concepts/ailang-function-bodies]].
- Many standard‑library APIs (`head`, `intToFloat`, `fromString`, `foldl`, etc.) must be explicitly imported; constructors like `Some`/`None` are not globally visible – [[concepts/ailang-stdlib-imports]].
- `export let` is not a valid construct; constants require `export func` wrappers – [[concepts/ailang-export-let]].
- The `Env` effect must be declared and granted via `--caps` whenever environment variables are read – [[concepts/ailang-env-effect]].

### Runtime Configuration for SWE Agents
- The `--net-allow-http` and `--net-allow-localhost` flags are security measures that must be explicitly enabled for any local HTTP service – [[concepts/ailang-net-caps]].
- The `--ai` flag expects a bare model name, not a `provider/` prefix; the provider is auto‑detected – [[concepts/ailang-model-routing]].
- The `--emit-trace` flag redirects `println` to stderr, which breaks agents that use stdout for structured protocols like JSONL – [[concepts/ailang-emit-trace-caveat]].

### Agent Architecture
- The SWE agent follows a request‑response loop (`rpc_loop`) that takes an `AgentState`, calls the LLM, processes tool calls (bash), and returns the updated state. A surrounding `conversation_loop` captures follow‑up messages, enabling multi‑turn interactions – [[concepts/swe-agent-conversation-loop]].
- The `base_system` prompt function must be parameterised with the actual working directory to avoid hardcoded `/testbed` references – [[concepts/swe-agent-cwd-propagation]].
- Rate limiting is handled via a configurable inter‑call sleep (`AI_STEP_DELAY_MS`) because AILANG lacks exception handling – [[concepts/swe-agent-rate-limit-strategy]].

## Lessons Learned
- Always verify auto‑generated code against the target language’s grammar and runtime semantics early.
- Inspect the full execution chain: environment forwarding, capability flags, and stdout/stderr routing can silently break integrations.
- Build multi‑turn interaction into the agent from the start; a “second brain” loop with readline‑based input is straightforward and drastically improves usability.
- For language runtimes without try/catch, preventive rate limiting (sleeps) is a simple, effective alternative to retry logic inside the runtime.