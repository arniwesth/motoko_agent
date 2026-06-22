# Fix Local Model Routing

Base branch: `origin/main`

## Summary

This branch fixes local OpenAI-compatible model routing by separating Motoko's
UI/profile model identifiers from the provider API model id sent to
`stepWithStream`.

Previously `PROFILE=local` could pass a model like
`openai/deepseek-v4-flash` all the way into the upstream request body, causing
local servers to reject it as an invalid model id. The runtime now keeps the
prefixed model for display, context accounting, and provider routing, but strips
provider routing prefixes only at the AI call boundary.

## Changes

- Switch the local profile model from `openai/google/gemma-4-26B-A4B-it` to
  `openai/deepseek-v4-flash`.
- Replace the old OpenRouter-only prefix stripping with `provider_api_model`.
- Strip `openrouter/`, `openai/`, `google/`, and `anthropic/` before
  `stepWithStream` receives the model id.
- Preserve `ollama/...` model ids so AILANG can route them to the native Ollama
  provider, which strips the Ollama prefix internally.
- Add regression tests for OpenRouter, local OpenAI-compatible, Google, and
  Ollama model id normalization.

## Verification

- `ailang check src/core/agent_loop_v2.ail`
- `ailang test src/core/agent_loop_v2.ail`
- Headless `MOTOKO_CONFIG=local` smoke returned `ok` without the invalid model
  id error.
