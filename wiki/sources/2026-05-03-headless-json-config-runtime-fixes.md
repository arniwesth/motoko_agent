# 2026-05-03 Headless JSON Config Runtime Fixes

## Context

This session continued the implementation of `.agent/plans/Headless_JSON_Only_Config.md` after the initial JSON-only/headless config work was in place. The user reported three runtime regressions from `make run`:

- The TUI loaded `anthropic/claude-sonnet-4-6` instead of the default model from `.motoko/config/default/config.json`.
- The OpenAI runtime failed with `openai error (400): invalid model ID` for `openai/google/gemma-4-26B-A4B-it`.
- The runtime warned that `/workspaces/ailang_agent/SYSTEM.md` could not be found even though `SYSTEM.md` exists.
- Extensions did not load under `make run`, and once fixed, the footer still did not show extensions until after the first user prompt.

## Root Causes

- `src/tui/src/index.ts` still had the old hardcoded model fallback and no longer loaded the profile JSON values after the env-overlay removal.
- The AILANG Go AI provider still reads `OPENAI_BASE_URL` and `MOTOKO_AI_OPTIONS_JSON` from process env, so moving those values to JSON required a temporary child-env bridge.
- The TUI passed an absolute `SYSTEM.md` path to the child runtime while `AILANG_FS_SANDBOX` was set to the workdir. Inside that sandbox, `fileExists("/workspaces/ailang_agent/SYSTEM.md")` failed. Passing `SYSTEM.md` relative to the sandboxed workdir fixes the warning.
- The supervisor was launched with `--workdir /workspaces/ailang_agent` while `AILANG_FS_SANDBOX=/workspaces/ailang_agent` was active. Core config reads of absolute `.motoko/config/...` paths failed inside the sandbox, so the runtime silently fell back to defaults and loaded no extensions.
- The TUI footer initialized extension text from the old `CORE_EXT_ORDER` env var. In the JSON-only config path that env var is intentionally absent, so the footer stayed blank until the first runtime `session_start` event.

## Changes Made

- Updated `src/tui/src/index.ts` to:
  - Load the active profile name with `activeProfile()`.
  - Read `.motoko/config/<profile>/config.json` directly for startup-only TUI display/runtime inputs.
  - Prefer `MODEL` env when explicitly set, otherwise use `agent.model` from JSON, otherwise the legacy fallback.
  - Read `extensions.order` from JSON and pass it into `AgentUI` so the footer can show extensions before the first prompt.
  - Resolve `SYSTEM.md` to a workdir-relative path when it exists inside the workdir.
  - Restrict `.env` loading to secret keys only: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `EXA_API_KEY`.

- Updated `src/tui/src/runtime-process.ts` to:
  - Spawn `src/core/supervisor.ail` instead of `src/core/rpc.ail`.
  - Pass `--profile`, `--model`, `--workdir`, `--port`, optional `--system-prompt`, and the task through CLI args.
  - Pass a sandbox-visible supervisor workdir argument, using `.` when the configured workdir is the current repo. This keeps config reads visible under `AILANG_FS_SANDBOX`.
  - Build a constrained child env containing secrets, `PATH`, `HOME`, `AILANG_FS_SANDBOX`, and stream settings.
  - Bridge JSON-derived `openai_base_url` and `ai_options_json` into `OPENAI_BASE_URL` and `MOTOKO_AI_OPTIONS_JSON` for the existing AI provider.

- Updated `src/tui/src/ui.ts` to:
  - Accept initial extensions in the `AgentUI` constructor.
  - Continue to update extension text from runtime `session_start` events, while showing JSON profile extensions immediately at startup.

- Updated `src/core/rpc.ail` behavior earlier in the session so that:
  - Runtime settings come from typed `RuntimeConfig`/`InvocationConfig`.
  - Missing system prompt warnings are only emitted when a non-empty configured prompt path is missing.
  - Empty `agent.system_prompt` means "run without a system prompt" without warning.

- Updated `.motoko/config/default/config.json` to keep `semi_formal_verifier_mode` under `agent` and leave the legacy `verification` block empty.

## Verification

Passed:

- `ailang check src/core/config.ail`
- `ailang check src/core/backend.ail`
- `ailang check src/core/supervisor.ail`
- `ailang check src/core/rpc.ail`
- `ailang check src/core/ext/registry.ail`
- `ailang check src/core/ext/runtime.ail`
- `ailang check src/core/ext/compose.ail`
- `ailang check src/core/ext/context_mode.ail`
- `ailang check src/core/ext/exa_search.ail`
- `ailang check src/core/ext/omnigraph.ail`
- `ailang test src/core/config.ail`
- `ailang test src/core/parse_test.ail`
- `ailang test src/core/agents_md.ail`
- `cd src/tui && bun run build`
- `cd src/tui && node --experimental-vm-modules node_modules/.bin/jest --testPathPattern='src/.*\.test\.ts' --runInBand`
- Sandboxed supervisor smoke with `AILANG_FS_SANDBOX=/workspaces/ailang_agent` and `--workdir .`, which emitted `loaded_extensions:["context_mode","exa_search","omnigraph"]`.

The focused Node/Jest TUI run passed 18 suites and 108 tests.

Known caveat:

- `cd src/tui && bun run test` still fails in the existing Bun/Jest path with `Attempted to assign to readonly property`; the same tests pass under Node/Jest.

## Current Expected Behavior

Running `make run` from `/workspaces/ailang_agent` should:

- Use `.motoko/config/default/config.json` as the default profile.
- Show/load `openai/google/gemma-4-26B-A4B-it` unless `MODEL` is explicitly set.
- Provide the configured OpenAI-compatible base URL/options to the AI provider.
- Pass `SYSTEM.md` as a workdir-relative system prompt path and avoid the false "not found" warning.
- Load `context_mode`, `exa_search`, and `omnigraph` from JSON config under `make run`.
- Show `ext: context_mode, exa_search, omnigraph` in the TUI footer immediately, before the first user prompt.
