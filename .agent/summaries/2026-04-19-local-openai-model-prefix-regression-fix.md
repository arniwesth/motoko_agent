# 2026-04-19 — Local OpenAI Model Prefix Regression Fix

## Session Goal
Investigate and fix a runtime regression where `make run_test_local` failed immediately with:

- `openai error (404): The model openai/google/gemma-4-26B-A4B-it does not exist`

## Observed Failure
Running `make run_test_local` started Motoko, but the first model call failed at step 0 with a 404 from the OpenAI-compatible endpoint.

The active model shown in TUI state was:
- `openai/google/gemma-4-26B-A4B-it`

## Root Cause
The issue was in vendored `ailang` model configuration and handler behavior.

### 1) Incorrect API model id in configured model entry
In vendored AILANG model registry:
- `ailang/internal/eval_harness/models.yml`

The entry key was:
- `openai/google/gemma-4-26B-A4B-it`

But `api_name` was also set to the prefixed string:
- `openai/google/gemma-4-26B-A4B-it`

For OpenAI-compatible servers, the request body model should be the provider-local id:
- `google/gemma-4-26B-A4B-it`

### 2) Configured-model path did not normalize provider prefixes
In:
- `ailang/cmd/ailang/ai_handlers.go`

`setupAIHandler` (configured model path via `models.yml`) passed `model.APIName` directly to handlers. The fallback path (`setupAIHandlerDirect`) already stripped provider prefixes with `stripProviderPrefix(...)`, but the configured path did not do that consistently.

That mismatch allowed bad prefixed `api_name` values to leak into API requests.

## Fix Implemented
Two changes were made for immediate correctness and future robustness.

### A) Corrected Gemma `api_name`
File:
- `ailang/internal/eval_harness/models.yml`

Change:
- `api_name: "openai/google/gemma-4-26B-A4B-it"`
- -> `api_name: "google/gemma-4-26B-A4B-it"`

### B) Normalized configured model names before handler creation
File:
- `ailang/cmd/ailang/ai_handlers.go`

Changes:
- Added provider + normalized model derivation in configured path:
  - `provider := ai.ProviderFromString(model.Provider)`
  - `apiModelName := stripProviderPrefix(model.APIName, provider)`
- Switched handler creation to use `apiModelName` for:
  - Anthropic
  - OpenAI
  - Google
  - Ollama
  - OpenRouter
- Replaced the one-off OpenRouter trim with shared normalization.

This aligns configured behavior with fallback behavior and prevents the same class of prefix regression from recurring.

## Validation
Executed focused tests in vendored AILANG:

```bash
go test ./cmd/ailang -run "TestGuessProvider|TestProviderFromString|TestNormalizeOpenAIBaseURL|TestResolveOpenAIBaseURLFromEnv|TestSetupAI"
```

Result:
- `ok github.com/sunholo/ailang/cmd/ailang`

## Notes
- The regression was introduced by a recent vendored AILANG model entry update (Apr 18, 2026) that added the local Gemma model with incorrect prefixed `api_name`.
- To take effect at runtime, the `ailang` binary used by Motoko must be rebuilt from the updated vendored source and used on PATH.
