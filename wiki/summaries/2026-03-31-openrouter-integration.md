---
doc_type: short
full_text: sources/2026-03-31-openrouter-integration.md
---

# Summary: OpenRouter Integration

This document describes the addition of **[[concepts/openrouter-integration|OpenRouter]]** model support to the AILANG SWE agent. OpenRouter exposes an OpenAI-compatible REST API, so integration reuses the existing `internal/ai/openai` client with a custom base URL, eliminating the need for new HTTP code.

## Model String Format
Models are identified by the prefix `openrouter/` followed by the model ID (e.g., `openrouter/meta-llama/llama-3.3-70b-instruct`). This prefix-based scheme enables **[[concepts/provider-abstraction|provider detection]]** in the configuration layer.

## Implementation Highlights
- **Go backend** (`config.go`, `ai_handlers.go`): Added `ProviderOpenRouter`, auto-detection of the `openrouter/` prefix, a helper `stripProviderPrefix` that removes the provider prefix (e.g., `openrouter/meta-llama/llama` → `meta-llama/llama`) before sending to the API, and mapping to the correct API key (`OPENROUTER_API_KEY`).
- **TUI** (`brain.ts`, `models.ts`, `ui.ts`, `index.ts`): Fixed a critical **[[concepts/model-string-parsing|model string parsing]]** bug in `brain.ts` where splitting on `/` and discarding the first segment corrupted OpenRouter model IDs. The fix delegates all prefix handling to Go. The model picker now fetches live OpenRouter models when `OPENROUTER_API_KEY` is set, falling back to a static list. A new `loadDotEnv` function reads `.env` or `.export` files at startup, populating environment variables like `OPENROUTER_API_KEY` without needing to `source` them manually.

## Bug Fix
Previously, the TUI stripped the first slash-separated segment, turning `openrouter/meta-llama/llama` into `meta-llama/llama` (correct), but also mangling provider strings like `anthropic/claude-sonnet` (which have only one segment after the prefix). The fix moves all prefix logic to the Go server, ensuring **[[concepts/model-string-parsing|consistent parsing]]** regardless of provider.

## Cross-Document Concepts
The integration touches several reusable patterns:
- **[[concepts/provider-abstraction|Provider Abstraction]]**: How multiple AI providers are unified under a common interface.
- **[[concepts/model-string-parsing|Model String Parsing]]**: Centralised prefix handling to avoid client-side fragility.
- **[[concepts/dotenv-loading|Dotenv Loading]]**: Auto-loading environment files to simplify configuration.
- **[[concepts/model-picker|Model Picker]]**: Dynamic model list retrieval from external APIs.

These concepts may be expanded into standalone concept pages when other providers or similar patterns are introduced.