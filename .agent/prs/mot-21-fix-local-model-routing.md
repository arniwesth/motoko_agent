# Fix Local Model Routing

Base branch: `origin/main`

## Summary

This branch fixes Motoko model routing so local OpenAI-compatible profiles, direct provider models, OpenRouter models, and Ollama models are routed through the intended provider while preserving the selected model string for UI state, context accounting, and model switching.

The main bug was that Motoko used provider-like model IDs such as `openai/deepseek-v4-flash`, `openai/gpt-4o`, `anthropic/...`, and `google/...` in multiple places with different meanings. AILANG's provider guessing treats many `vendor/model` strings as OpenRouter IDs, so local or direct-provider runs could silently route through OpenRouter. The TUI now normalizes the model used for AILANG provider selection separately from the model sent to the provider API call.

## Changes

- Add shared runtime model resolution for TUI and headless startup:
  `MODEL` env var, then profile `agent.model`, then `anthropic/claude-sonnet-4-6`.
- Keep `process.env.MODEL` synchronized with the resolved runtime model so helper paths such as env-server, scratchpad, subagents, and runtime restarts agree on the active model.
- Add TUI provider-selection normalization:
  - Local OpenAI-compatible endpoints force AILANG's OpenAI provider selection.
  - Direct `openai/`, `anthropic/`, and `google/` Motoko routing prefixes are stripped before AILANG provider guessing.
  - Explicit `openrouter/...`, `openrouter/auto`, and `ollama/...` model IDs are preserved.
- Normalize provider API model IDs at the `stepWithStream` boundary:
  - `openrouter/<vendor>/<model>` sends `<vendor>/<model>` to OpenRouter.
  - `openrouter/auto` stays intact.
  - Direct `openai/`, `anthropic/`, and `google/` prefixes are stripped for the provider request.
  - Ollama routing IDs are preserved.
- Fix blank environment overrides such as `OPENAI_BASE_URL=` so they no longer mask profile-configured local endpoint values.
- Update the local profile and local compaction config to use `openai/deepseek-v4-flash`.
- Move model picker data, OpenRouter fallback models, and concrete context limits into `.motoko/model-catalog.json`, with `MOTOKO_MODELS_FILE` as an override.
- Replace hardcoded concrete context-window entries in core AILANG with catalog lookups plus broad provider-family fallbacks.
- Use the repo-local `ailang/bin/ailang` from Make targets and package sync so local runs do not depend on an older globally installed AILANG binary.
- Make `PROFILE=local make run` verify the selected local profile extension set before startup.
- Suppress expected local-runtime warning noise in the TUI and route runtime stderr through structured warning events instead of spilling raw stderr into the input line.
- Suppress terminal title/banner output in headless and JSONL modes.
- Document model identifier rules in `README.md`, including local OpenAI-compatible models, direct Google/Vertex `gemini-*` IDs, OpenRouter pinned/routing IDs, and Ollama IDs.

## Verification

- `make build`
- `MOTOKO_CONFIG=local make check_core`
- `AILANG_STDLIB_PATH=/workspaces/motoko_agent/ailang/std ./ailang/bin/ailang test src/core/agent_loop_v2.ail`
- `cd ailang && go test ./cmd/ailang -run 'OpenAI.*(Local|Custom|KeyRelaxation|UsesCustomBaseURL)'`
- `bun test src/tui/src/runtime-process.stream-protocol.test.ts`
- `bun test src/tui/src/models.test.ts`
- `bun run --cwd src/tui build`
- Headless `MOTOKO_CONFIG=local` smoke succeeded with an intentionally bogus OpenRouter key.
- `PROFILE=local make run` smoke succeeded and verified the local profile extension set before startup.
- Local endpoint probe confirmed the remaining timeout error is TCP connectivity to `http://...:8000`, not OpenRouter routing.
