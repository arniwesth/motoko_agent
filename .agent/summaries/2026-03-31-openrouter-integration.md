# OpenRouter Integration

**Date:** 2026-03-31  
**Status:** Complete and tested

## What was done

Added support for any model available on [OpenRouter](https://openrouter.ai) in the AILANG SWE agent. OpenRouter exposes an OpenAI-compatible REST API, so integration reuses the existing `internal/ai/openai` client with a custom base URL — no new HTTP client code was needed.

## Model string format

```
openrouter/<model-id>
```

Examples:
- `openrouter/meta-llama/llama-3.3-70b-instruct`
- `openrouter/qwen/qwen3.6-plus-preview:free`
- `openrouter/mistralai/mixtral-8x7b-instruct`

Usage:
```bash
MODEL=openrouter/meta-llama/llama-3.3-70b-instruct ./scripts/run-agent.sh
```

## Files changed

### `ailang/internal/ai/config.go`
- Added `ProviderOpenRouter ProviderType = "openrouter"` constant
- `GuessProvider`: detects `openrouter/` prefix → returns `ProviderOpenRouter`
- `GetAPIKey`: reads `OPENROUTER_API_KEY` for OpenRouter
- `ProviderFromString`: maps `"openrouter"` → `ProviderOpenRouter`

### `ailang/cmd/ailang/ai_handlers.go`
- Added `stripProviderPrefix(modelName, provider)` helper that strips `provider/` prefix before sending the bare model id to the API client (e.g. `openrouter/meta-llama/...` → `meta-llama/...`)
- Added `case ai.ProviderOpenRouter:` in both `setupAIHandler` (config path) and `setupAIHandlerDirect` (fallback path)
- Both cases use `openai.NewClient(apiKey, openai.WithBaseURL("https://openrouter.ai/api/v1"))`
- `stripProviderPrefix` is now applied to all providers in `setupAIHandlerDirect`, so the full `provider/model` format is accepted everywhere (not just OpenRouter)

### `tui/src/brain.ts`
- **Bug fixed**: old code did `model.split("/").slice(1).join("/")` which stripped the first path segment — correct for single-segment providers (`anthropic/claude`) but wrong for OpenRouter (`openrouter/meta-llama/llama`), which has two segments after the prefix
- Now passes `model` unchanged to `--ai`; provider-prefix stripping is handled entirely in Go

### `tui/src/models.ts`
- Added `fetchOpenRouterModels(apiKey)`: fetches live model list from `https://openrouter.ai/api/v1/models`, returns ids prefixed with `openrouter/`
- Added `OPENROUTER_FALLBACK_MODELS`: static list of ~10 popular models used if the API fetch fails

### `tui/src/ui.ts`
- Model picker (`/model`) now checks `OPENROUTER_API_KEY`; if set, fetches the live list and appends all OpenRouter models to the picker
- Extracted `openPickerWithModels(models)` helper to support async population

### `tui/src/index.ts`
- Added `loadDotEnv()`: reads `.env` or `.export` from CWD (and project root as fallback), parses `KEY=value` and `export KEY=value` lines, populates `process.env` without overriding shell-provided values
- Called at startup so `OPENROUTER_API_KEY` (and other keys) are available without `source .export`

### `CLAUDE.md`
- Added `OPENROUTER_API_KEY` to the environment variables table
- Updated supported model strings list

## Bug found and fixed

`brain.ts` was splitting the model string on `/` and taking everything after the first segment before passing it to `--ai`. This worked for `anthropic/claude-sonnet-4-6` → `claude-sonnet-4-6` but broke `openrouter/meta-llama/llama-3.3-70b-instruct` → `meta-llama/llama-3.3-70b-instruct` (lost the provider indicator). The fix moves all prefix handling to the Go side via `stripProviderPrefix`.

## Tested

- `openrouter/meta-llama/llama-3.3-70b-instruct` ✅
- `openrouter/qwen/qwen3.6-plus-preview:free` ✅
- `anthropic/claude-haiku-4-5` still resolves correctly after the brain.ts change ✅
- Full agent stack (`run-agent.sh`) with `MODEL=openrouter/...` ✅
- `.export` auto-loaded without `source` ✅
