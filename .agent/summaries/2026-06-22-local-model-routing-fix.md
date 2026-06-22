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
- Normalize provider-prefixed model ids only at the `stepWithStream` call
  boundary.
- Strip `openrouter/`, `openai/`, `google/`, and `anthropic/` before provider
  API calls.
- Keep `ollama/...` unchanged in Motoko so AILANG can route it to the native
  Ollama provider, which strips the Ollama prefix internally.
- Kept the user-facing/profile model id intact for UI display, context
  accounting, and conversation model switching.
- Added regression tests for OpenRouter, local OpenAI-compatible models with
  and without slashful ids, Google, and Ollama.
- Wrote PR notes to `.agent/prs/mot-21-fix-local-model-routing.md`.

## Verification

- `ailang check src/core/agent_loop_v2.ail`
- `ailang test src/core/agent_loop_v2.ail`
- Headless local smoke:

```bash
MOTOKO_CONFIG=local TASK='Reply exactly: ok' MOTOKO_HEADLESS=1 bun src/tui/src/index.ts
```

The smoke completed and returned `ok` without the invalid model id error.

## Notes

The AILANG MCP server is configured in `.mcp.json`, but no MCP resources were
available in this Codex session. Local AILANG docs were consulted via the
vendored `ailang/std` path instead.
