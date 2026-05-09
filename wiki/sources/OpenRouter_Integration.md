# OpenRouter Integration Plan

**Goal:** Enable the AILANG Agent to use any model available on OpenRouter.

OpenRouter exposes an OpenAI-compatible REST API at `https://openrouter.ai/api/v1`.
Since the AILANG runtime already has an OpenAI client that supports `WithBaseURL`,
integration is a thin shim — no new HTTP client code is needed.

---

## Model string convention

```
openrouter/<model-id>
```

Examples:
- `openrouter/meta-llama/llama-3.3-70b-instruct`
- `openrouter/mistralai/mixtral-8x7b`
- `openrouter/google/gemini-2.5-pro`

The `openrouter/` prefix is stripped before the model id is sent to the API.

---

## Architecture

```
MODEL=openrouter/meta-llama/llama-3.3-70b-instruct
        │
        ▼
ailang run --ai openrouter/meta-llama/llama-3.3-70b-instruct
        │
        ▼
setupAIHandlerDirect / setupAIHandler
  GuessProvider → ProviderOpenRouter
  openai.NewClient(OPENROUTER_API_KEY,
    WithBaseURL("https://openrouter.ai/api/v1"))
  model = "meta-llama/llama-3.3-70b-instruct"  (prefix stripped)
        │
        ▼
OpenRouter API  →  any of 300+ models
```

The TUI model picker fetches the live model list from
`https://openrouter.ai/api/v1/models` when `OPENROUTER_API_KEY` is set,
so users can pick any available model from the `/model` overlay.

---

## Todo

### Layer 1 — AILANG runtime (`ailang/`)

- [x] **`ailang/internal/ai/config.go`**
  - Add `ProviderOpenRouter ProviderType = "openrouter"` constant
  - `GuessProvider`: detect `openrouter/` prefix → return `ProviderOpenRouter`
  - `GetAPIKey`: add case reading `OPENROUTER_API_KEY`
  - `ProviderFromString`: add `"openrouter"` → `ProviderOpenRouter`

- [x] **`ailang/cmd/ailang/ai_handlers.go`**
  - Add `case ai.ProviderOpenRouter:` in `setupAIHandler`
    - Read `OPENROUTER_API_KEY`
    - `openai.NewClient(apiKey, openai.WithBaseURL("https://openrouter.ai/api/v1"))`
    - Strip `openrouter/` prefix from model name
  - Add same case in `setupAIHandlerDirect`

### Layer 2 — TUI model picker (`tui/`)

- [x] **`tui/src/models.ts`**
  - Add `fetchOpenRouterModels(apiKey: string): Promise<string[]>` — calls
    `GET https://openrouter.ai/api/v1/models`, returns ids prefixed with `openrouter/`
  - Add a small static `OPENROUTER_FALLBACK_MODELS` list for offline use

- [x] **`tui/src/ui.ts`**
  - In the `/model` overlay handler: if `OPENROUTER_API_KEY` env is set,
    call `fetchOpenRouterModels` and append results to the picker list

### Layer 3 — Documentation

- [x] **`CLAUDE.md`** — add `OPENROUTER_API_KEY` to the environment variables table

---

## Files changed (summary)

| File | Change |
|------|--------|
| `ailang/internal/ai/config.go` | New provider type + GuessProvider/GetAPIKey/ProviderFromString entries |
| `ailang/cmd/ailang/ai_handlers.go` | OpenRouter case in both handler setup functions |
| `tui/src/models.ts` | `fetchOpenRouterModels()` + static fallback list |
| `tui/src/ui.ts` | Populate model picker from OpenRouter API |
| `CLAUDE.md` | Document `OPENROUTER_API_KEY` |

---

## Environment variables

| Variable | Purpose |
|----------|---------|
| `OPENROUTER_API_KEY` | API key from openrouter.ai — required for any `openrouter/` model |

---

## Notes

- No new Go packages needed — reuses `internal/ai/openai` client with `WithBaseURL`
- No AILANG brain changes needed (`swe/rpc.ail` passes model strings through unchanged)
- No `models.yml` entries required — `setupAIHandlerDirect` handles unknown `openrouter/` strings
- OpenRouter supports streaming, JSON mode, and system prompts — all existing handler features work
- Rate limits and costs are per-model on OpenRouter; no special handling needed
