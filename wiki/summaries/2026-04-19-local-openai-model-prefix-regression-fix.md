---
doc_type: short
full_text: sources/2026-04-19-local-openai-model-prefix-regression-fix.md
---

# Summary of 2026-04-19-local-openai-model-prefix-regression-fix

This document describes the investigation and fix for a runtime regression where `make run_test_local` failed immediately with a 404 error due to an incorrect model identifier sent to an OpenAI-compatible endpoint.

## Root Cause

Two issues contributed to the failure:

1. **Incorrect `api_name` in model registry:** The entry for `openai/google/gemma-4-26B-A4B-it` in `ailang/internal/eval_harness/models.yml` had an `api_name` still containing the provider prefix (`openai/google/gemma-4-26B-A4B-it`) instead of just the provider-local model id (`google/gemma-4-26B-A4B-it`).
2. **Lack of [[concepts/provider_prefix_normalization]] in configured handler path:** The function `setupAIHandler` in `ailang/cmd/ailang/ai_handlers.go` passed the raw `api_name` to API calls without stripping the provider prefix. While the fallback path (`setupAIHandlerDirect`) already performed this normalization using `stripProviderPrefix`, the configured model path did not, allowing the prefixed name to leak into requests.

The combination caused the OpenAI-compatible server to return a 404 because it received the full prefixed string instead of the expected local model id.

## Fix Applied

Two changes were made for immediate correction and long-term robustness:

- **Model configuration corrected:** In `ailang/internal/eval_harness/models.yml`, the `api_name` for the Gemma model was changed from `"openai/google/gemma-4-26B-A4B-it"` to `"google/gemma-4-26B-A4B-it"`, matching the provider-local identifier.
- **Handler normalization added:** In `ailang/cmd/ailang/ai_handlers.go`, the configured model path now derives the provider from the model entry and applies `stripProviderPrefix` to obtain the clean `apiModelName`. This normalized name is then used in handler creation for all supported providers (OpenAI, Anthropic, Google, Ollama, OpenRouter). A one-off trimming in the OpenRouter section was replaced with the shared normalization.

This aligns the configured behavior with the direct model path and prevents similar [[concepts/api_name_mismatch]] regressions.

## Validation

Focused unit tests in the vendored `ailang` package (`TestGuessProvider`, `TestProviderFromString`, etc.) passed, confirming that the normalization logic works correctly:

```
ok github.com/sunholo/ailang/cmd/ailang
```

## Notes

- The regression was introduced by a recent model entry update (Apr 18, 2026) that added the local Gemma model with the incorrect `api_name`.
- To apply the fix at runtime, the `ailang` binary used by Motoko must be rebuilt from the updated vendored source and placed on the PATH.

This fix is an example of ensuring consistency between [[concepts/model_registry]] entries and handler code when supporting [[concepts/llm_providers]] with [[concepts/openai_compatible_endpoints]].