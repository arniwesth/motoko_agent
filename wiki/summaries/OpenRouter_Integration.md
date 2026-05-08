---
doc_type: short
full_text: sources/OpenRouter_Integration.md
---

# OpenRouter Integration Summary

**Goal:** Let the AILANG Agent leverage any model on OpenRouter by extending the existing [[concepts/provider-abstraction|AI provider architecture]].

## Approach

OpenRouter exposes an OpenAI-compatible REST API. Since the runtime already uses an OpenAI client with `WithBaseURL`, the integration is a thin shim—no new HTTP client code.

## Model String Convention

Models are specified as `openrouter/<model-id>` (e.g., `openrouter/meta-llama/llama-3.3-70b-instruct`). The prefix is stripped before sending to the API.

## Implementation Layers

1. **AILANG runtime** – `config.go` adds `ProviderOpenRouter` constant, `GuessProvider` parses the `openrouter/` prefix, `GetAPIKey` reads `OPENROUTER_API_KEY`. In `ai_handlers.go`, both `setupAIHandler` and `setupAIHandlerDirect` construct an OpenAI client pointed at `https://openrouter.ai/api/v1` with the stripped model name.
2. **TUI model picker** – `models.ts` fetches the live model list from OpenRouter when `OPENROUTER_API_KEY` is set, and provides a fallback list. `ui.ts` populates the `/model` overlay with these results.
3. **Documentation** – `CLAUDE.md` lists `OPENROUTER_API_KEY`.

## Key Design Decisions

- No new packages required—reuses [[concepts/openai-client-reuse|existing OpenAI client]].
- No changes to AILANG brain or `swe/rpc.ail`; model strings pass through unchanged.
- Handlers already support streaming, JSON mode, and system prompts; all features work with OpenRouter.
- Rate limits and costs are per-model on OpenRouter, with no special handling needed.

## Environment

Single variable: `OPENROUTER_API_KEY` (obtained from openrouter.ai).

## Cross-Cutting Themes

- [[concepts/provider-abstraction]] – `GuessProvider` and `ProviderFromString` extend the pluggable AI backend system.
- [[concepts/model-string-convention]] – prefix-based routing simplifies multi-provider support.
- [[concepts/tui-model-picker]] – live model fetching enriches the interactive experience.
- [[concepts/environment-variable-management]] – `GetAPIKey` centralizes key resolution.
