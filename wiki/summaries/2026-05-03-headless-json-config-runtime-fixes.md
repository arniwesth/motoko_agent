---
doc_type: short
full_text: sources/2026-05-03-headless-json-config-runtime-fixes.md
---

# 2026-05-03 Headless JSON Config Runtime Fixes

## Overview
This session resolved four runtime regressions introduced by the move to a JSON-only, headless configuration model. The fixes ensure the TUI loads the correct model, the OpenAI runtime receives proper credentials, the system prompt is found inside the sandbox, and extensions appear before user input.

## Root Causes
- The TUI still had a hardcoded model fallback ignoring the JSON profile (`anthropic/claude-sonnet-4-6` default instead of `openai/google/gemma-4-26B-A4B-it`).
- The Go AI provider required `OPENAI_BASE_URL` and `MOTOKO_AI_OPTIONS_JSON` from process environment, but these were now stored in JSON only.
- An absolute path for `SYSTEM.md` was passed while the `AILANG_FS_SANDBOX` restricted file access to the workspace directory.
- The supervisor’s config reads (`/workspaces/ailang_agent/.motoko/config/...`) failed inside the sandbox because `--workdir` was passed as an absolute path, causing fallback to defaults and no extensions.
- The TUI footer initialized extension text from the old `CORE_EXT_ORDER` environment variable, which is absent in JSON-only mode, leaving it blank until the first runtime event.

## Fixes Applied

### TUI Model & Config Loading
- `src/tui/src/index.ts` now uses `activeProfile()` to locate the correct JSON config.
- Reads `model` from `agent.model` in `.motoko/config/<profile>/config.json` unless the `MODEL` env var is explicitly set.
- Loads `extensions.order` from JSON and passes it to the `AgentUI` constructor for immediate footer display.
- Resolves `SYSTEM.md` to a workdir-relative path inside the sandbox, eliminating the false “not found” warning.
- Restricts `.env` loading to only API keys (ANTHROPIC, OPENAI, GOOGLE, EXA).

### Sandbox‑Aware Supervisor Launch
- `src/tui/src/runtime-process.ts` now spawns `src/core/supervisor.ail` (not the old `rpc.ail`) with CLI arguments for profile, model, workdir (relative when inside the current repo), port, system prompt, and task.
- Passes a constrained child environment that bridges JSON‑derived values into `OPENAI_BASE_URL` and `MOTOKO_AI_OPTIONS_JSON` as temporary env vars, allowing the Go AI provider to function until a direct JSON integration is done.
- Sets `AILANG_FS_SANDBOX` correctly and uses `.` as the workdir to keep config paths visible.

### Core Runtime Adjustments
- In `src/core/rpc.ail`, runtime settings now come from typed `RuntimeConfig`/`InvocationConfig`.
- A warning about a missing system prompt is only emitted when a non‑empty path is configured; an empty `agent.system_prompt` means “run without a system prompt” silently.

### TUI Extension Display
- `src/ui.ts` accepts an `initialExtensions` list in its constructor, so the footer can show extensions immediately (e.g., `context_mode, exa_search, omnigraph`) before the first `session_start` event.

## Verification
All core AILang checks and tests passed (`config.ail`, `backend.ail`, `supervisor.ail`, `rpc.ail`, extensions), along with 108 TUI Jest tests. A sandboxed supervisor smoke test confirmed `loaded_extensions:["context_mode","exa_search","omnigraph"]`.

## Impact
After these changes, `make run` uses the JSON default profile, selects the correct model, provides OpenAI‑compatible options, loads extensions, and shows them in the footer immediately. The bridge env vars are a temporary measure that should be replaced by a direct JSON reading in the AI provider later.

## Related Concepts
- [[concepts/json-config-runtime-bridge]] — bridging JSON config values to environment variables for legacy providers
- [[concepts/ailang-sandboxing]] — path restrictions inside `AILANG_FS_SANDBOX`
- [[concepts/tui-initialization]] — startup display and model selection from profile JSON
- [[concepts/headless-json-config]] — the broader JSON‑only, profile‑driven configuration system