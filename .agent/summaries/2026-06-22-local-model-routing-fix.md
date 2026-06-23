# Local Model Routing Fix

## Context

`PROFILE=local make run` failed on the first model call with:

```text
openai/deepseek-v4-flash is not a valid model ID
```

The local profile used `openai/deepseek-v4-flash` as Motoko's routing/UI model
identifier and pointed `openai_base_url` at a local OpenAI-compatible endpoint.
Motoko passed that same prefixed identifier into `stepWithStream`, so the local
server received `openai/deepseek-v4-flash` instead of the API model id
`deepseek-v4-flash`.

## Changes

- Added `provider_api_model` in `src/core/agent_loop_v2.ail`.
- Normalize provider API model ids only at the `stepWithStream` call boundary.
- Strip the explicit `openrouter/` Motoko routing prefix only for pinned
  vendor/model ids while preserving OpenRouter vendor/model ids such as
  `anthropic/claude-sonnet-4-6`.
- Preserve `openrouter/auto`, which the AILANG MCP docs and AILANG OpenRouter
  tests use as the routing-policy model.
- Strip `openai/` only when `OPENAI_BASE_URL` is set, where
  `openai/<local-id>` is local OpenAI-compatible routing syntax rather than an
  OpenRouter vendor/model id.
- Keep `ollama/...` unchanged in Motoko so AILANG can route it to the native
  Ollama provider, which strips the Ollama prefix internally.
- Document the model identifier matrix in `README.md`, including that direct
  Google/Vertex uses bare `gemini-*` ids while `google/...` is an OpenRouter
  vendor/model form.
- Move the TUI baseline model catalog and OpenRouter fallback catalog to
  `.motoko/model-catalog.json`, with `MOTOKO_MODELS_FILE` as an override.
- Move concrete per-model context windows to `.motoko/model-catalog.json`
  under `context_limits`; core AILANG now keeps only broad provider-family
  fallback limits.
- Keep `.motoko/model-catalog.json` out of runtime model selection; it feeds
  picker/discovery suggestions and known context-window metadata.
- Add shared runtime model resolution for TUI and headless runs with precedence
  `MODEL` environment variable, then profile `agent.model`, then the default
  runtime model.
- Publish the resolved runtime model back to `process.env.MODEL` before runtime
  startup so env-server, scratchpad, subagents, and `RuntimeProcess` observe the
  same model.
- Update the configured direct Google/Vertex models to use bare `gemini-*` ids.
- Suppress the Motoko banner/header in headless and JSONL modes so headless
  output stays machine-readable.
- Route runtime stderr through warning events instead of inheriting it into the
  TUI prompt line.
- Kept the user-facing/profile model id intact for UI display, context
  accounting, and conversation model switching.
- Added regression tests for OpenRouter pinned models, `openrouter/auto`, local
  OpenAI-compatible models with and without slashful ids, OpenRouter
  vendor/model ids, Ollama, shared runtime model resolution, model catalog
  loading, context-limit catalog parsing, direct Gemini picker entries, and
  headless local/OpenRouter smoke paths.
- Wrote PR notes to `.agent/prs/mot-21-fix-local-model-routing.md`.

## Verification

- `ailang check src/core/agent_loop_v2.ail`
- `ailang test src/core/agent_loop_v2.ail`
- `ailang check src/core/context_usage.ail`
- `bun test src/tui/src/models.test.ts`
- `bun run --cwd src/tui build`
- Headless local smoke:

```bash
MOTOKO_CONFIG=local TASK='Reply exactly: ok' MOTOKO_HEADLESS=1 bun src/tui/src/index.ts
```

The smoke completed and returned `ok` without the invalid model id error.

## Notes

The AILANG MCP server in `.mcp.json` was consulted directly over HTTP. It
served AILANG `0.25.0` docs, including `std/ai`, `guides/ai-routing.md`, and
`guides/custom-ai-providers.md`.
