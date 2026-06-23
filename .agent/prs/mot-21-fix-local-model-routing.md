# Fix Local Model Routing

Base branch: `origin/main`

## Summary

This branch fixes local OpenAI-compatible model routing by separating Motoko's
UI/profile model identifiers from the provider API model id sent to
`stepWithStream`.

Previously `PROFILE=local` could pass a model like
`openai/deepseek-v4-flash` all the way into the upstream request body, causing
local servers to reject it as an invalid model id. The runtime now keeps the
prefixed model for display, context accounting, and provider routing, but
normalizes the provider API model id only at the AI call boundary.

It also centralizes runtime model resolution so TUI and headless runs choose the
model with the same precedence: `MODEL` environment variable, then profile
`agent.model`, then the default runtime model.

## Changes

- Switch the local profile model from `openai/google/gemma-4-26B-A4B-it` to
  `openai/deepseek-v4-flash`.
- Replace the old OpenRouter-only prefix stripping with `provider_api_model`.
- Strip the explicit `openrouter/` Motoko routing prefix only for pinned
  vendor/model ids before `stepWithStream`, preserving OpenRouter vendor/model
  ids such as `anthropic/claude-sonnet-4-6`.
- Preserve `openrouter/auto`, which AILANG documents and tests as the
  OpenRouter routing-policy model.
- Strip `openai/` only when `OPENAI_BASE_URL` is set, where
  `openai/<local-id>` is local OpenAI-compatible routing syntax rather than an
  OpenRouter vendor/model id.
- Preserve `ollama/...` model ids so AILANG can route them to the native Ollama
  provider, which strips the Ollama prefix internally.
- Document model identifier rules in `README.md`, including the direct
  Google/Vertex `gemini-*` form versus the OpenRouter `google/...` vendor/model
  form.
- Move the TUI baseline model catalog and OpenRouter fallback catalog to
  `.motoko/model-catalog.json`, with `MOTOKO_MODELS_FILE` as an override.
- Move concrete per-model context windows to `.motoko/model-catalog.json`
  under `context_limits`; core AILANG now keeps only broad provider-family
  fallback limits.
- Keep `.motoko/model-catalog.json` out of runtime model selection; it feeds
  picker/discovery suggestions and known context-window metadata.
- Add a shared `resolveRuntimeModel` helper and use it before both interactive
  and headless runtime startup.
- Publish the resolved model back to `process.env.MODEL` so env-server,
  scratchpad, subagents, and runtime process args agree on the same model.
- Suppress the Motoko banner/header in headless and JSONL modes so those bytes
  are not written into headless output.
- Route runtime stderr through warning events instead of inheriting it into the
  TUI prompt line.
- Update the configured direct Google/Vertex models to use bare `gemini-*` ids.
- Add regression tests for OpenRouter pinned models, `openrouter/auto`, local
  OpenAI-compatible models, vendor/model ids, Ollama model id normalization,
  shared runtime model resolution, model catalog loading, context-limit catalog
  parsing, direct Gemini model picker entries, and headless local/OpenRouter
  smoke paths.

## Verification

- `ailang check src/core/agent_loop_v2.ail`
- `ailang test src/core/agent_loop_v2.ail`
- `ailang check src/core/context_usage.ail`
- `bun test src/tui/src/models.test.ts`
- `bun run --cwd src/tui build`
- Headless `MOTOKO_CONFIG=local` smoke returned `ok` without the invalid model
  id error.
