# Fix Local Model Routing

Base branch: `origin/main`

## Summary

This branch fixes Motoko model resolution so interactive TUI runs and headless
runs use the same selected model and route it through the intended provider.

The critical fix is that Motoko no longer passes direct-provider model ids such
as `openai/deepseek-v4-flash`, `openai/gpt-4o`, `anthropic/...`, or `google/...`
to AILANG's `--ai` provider guessing unchanged. AILANG treats those
`vendor/model` strings as OpenRouter ids, so `PROFILE=local make run` could
silently route a local OpenAI-compatible profile through OpenRouter. The TUI
launcher now normalizes provider-selection ids separately from the model id sent
to `stepWithStream`.

Local OpenAI-compatible profiles now force AILANG's OpenAI provider selection
while preserving the real local model id for the provider request. Explicit
OpenRouter ids still use `openrouter/...`, and Ollama ids still use
`ollama/...`.

## Changes

- Add shared runtime model resolution for both TUI and headless startup:
  `MODEL` environment variable, then profile `agent.model`, then the default
  runtime model.
- Keep `process.env.MODEL` synchronized with the resolved runtime model so
  env-server, scratchpad, subagents, and the runtime process agree.
- Add TUI-side provider-selection normalization:
  - Local OpenAI-compatible endpoints use an OpenAI-shaped `--ai` selector.
  - Direct `openai/`, `anthropic/`, and `google/` profile ids are stripped
    before AILANG provider guessing.
  - Explicit `openrouter/...`, `openrouter/auto`, and `ollama/...` ids are
    preserved.
- Normalize the provider API model at the `stepWithStream` boundary while
  keeping the user-facing/profile model id intact for display, context
  accounting, and model switching.
- Fix blank environment overrides such as `OPENAI_BASE_URL=` so they no longer
  mask profile-configured local endpoint values.
- Update the local profile and local `compaction_ai` config to use
  `openai/deepseek-v4-flash` instead of OpenRouter model ids.
- Build and use the repo-local `ailang/bin/ailang` from `make run`, so branch
  behavior does not depend on an older globally installed AILANG binary.
- Make Makefile AILANG checks and package sync use the same repo-local binary,
  and make `PROFILE=local make run` verify the local profile extension set.
- Suppress expected local-runtime warning noise in the TUI:
  - AILANG stdlib version mismatch warnings from dirty local builds.
  - Informational cache-hint warnings for providers that cannot honor explicit
    cache breakpoints.
  - Duplicate `Warning: Warning:` prefixes.
- Suppress the Motoko banner/header in headless and JSONL modes.
- Route runtime stderr through structured warning events instead of letting it
  spill into the TUI input line.
- Move model picker/discovery data and concrete per-model context limits into
  `.motoko/model-catalog.json`, with `MOTOKO_MODELS_FILE` as an override.
- Replace hardcoded concrete context-window entries in core AILANG with catalog
  lookups plus broad provider-family fallbacks.
- Document model identifier rules in `README.md`, including local
  OpenAI-compatible models, direct Google/Vertex `gemini-*` ids, OpenRouter
  `vendor/model` ids, and Ollama `ollama/<model>` ids.

## Verification

- `make build`
- `MOTOKO_CONFIG=local make check_core`
- `AILANG_STDLIB_PATH=/workspaces/motoko_agent/ailang/std ./ailang/bin/ailang test src/core/agent_loop_v2.ail`
- `cd ailang && go test ./cmd/ailang -run 'OpenAI.*(Local|Custom|KeyRelaxation|UsesCustomBaseURL)'`
- `bun test src/tui/src/runtime-process.stream-protocol.test.ts`
- `bun test src/tui/src/models.test.ts`
- `bun run --cwd src/tui build`
- Headless `MOTOKO_CONFIG=local` smoke succeeded with an intentionally bogus
  OpenRouter key.
- `PROFILE=local make run` smoke succeeded and verified the local profile
  extension set before startup.
- Local endpoint probe confirmed the remaining timeout error is TCP
  connectivity to `http://100.79.48.75:8000`, not OpenRouter routing.
