# Fix Local Model Routing

Base branch: `origin/main`

## Summary

This branch fixes Motoko model routing so local OpenAI-compatible models are
not accidentally sent through OpenRouter, while preserving the selected Motoko
model string for UI state, profile state, context telemetry, and follow-up
turns.

The previous routing path passed Motoko's UI/profile identifiers directly to
AILANG provider selection and then partially stripped prefixes before
`std/ai.step()`. That made local models such as
`openai/deepseek-v4-flash` or `openai/google/gemma-4-26B-A4B-it` ambiguous:
the prefix was useful to Motoko, but AILANG could interpret slashful vendor
strings as OpenRouter routing ids.

## Changes

- Add a two-stage model routing split:
  - the TUI launcher maps Motoko model ids to an AILANG `--ai` provider
    selector with `providerSelectionModel`
  - the AILANG runtime maps Motoko model ids to provider API model ids with
    `provider_api_model`
- Route local OpenAI-compatible runs through AILANG's OpenAI provider when
  `OPENAI_BASE_URL` is set, while still sending the actual local model id to
  the provider request.
- Preserve explicit OpenRouter routing ids, including `openrouter/auto`, and
  strip only the outer `openrouter/` prefix for pinned OpenRouter
  vendor/model ids before the provider API call.
- Strip Motoko direct-provider prefixes for direct OpenAI, Anthropic, and
  Google model requests before AILANG provider guessing and before
  `std/ai.step()`.
- Move the static model picker catalog and known context windows into
  `.motoko/model-catalog.json`, with `MOTOKO_MODELS_FILE` support for custom
  catalogs.
- Preserve newer model context windows, such as
  `ollama/qwen3.6:35b-a3b-mxfp8`, as catalog entries rather than hardcoded
  AILANG branches.
- Update context usage, budget planning, extension context, and structural
  compaction to read catalog-backed context limits. Unknown or uncatalogued
  models have no known limit, so compaction is skipped rather than guessed from
  provider-family prefixes.
- Resolve the runtime model consistently as:
  `MODEL` env var > profile `agent.model` > `anthropic/claude-sonnet-4-6`,
  then publish the resolved value back to `process.env.MODEL` so helper paths
  observe the same model.
- Update the local profile defaults to use `openai/deepseek-v4-flash` against
  the configured local OpenAI-compatible endpoint.
- Document Motoko model identifier semantics in the README, including the
  difference between direct Gemini ids and OpenRouter `google/...` vendor ids.
- Capture AILANG runtime stderr as structured warning events, suppressing known
  local informational noise such as stdlib version mismatch and cache-hint
  warnings.
- Add focused tests for runtime model resolution, catalog loading, OpenRouter
  fallback models, local OpenAI model discovery, provider selection, warning
  normalization, and AILANG-side provider API model conversion.

## User Impact

- Local OpenAI-compatible profiles can select local model ids with the
  `openai/` Motoko routing prefix without leaking those requests to
  OpenRouter.
- Slashful local model ids are preserved after the `openai/` routing prefix is
  removed, so ids like `google/gemma-4-26B-A4B-it` still reach the local
  endpoint correctly.
- Direct Gemini / Vertex usage is clearer: use bare `gemini-*` ids for direct
  Google routing, and `openrouter/google/...` for OpenRouter.
- The `/model` picker can be updated through JSON catalog data instead of
  TypeScript edits.
- Context counters and compaction use the same catalog-backed model limits as
  the TUI model catalog.

## Verification

- `make -n build`
  - Confirms build, sync, lock, extension boot, and core check commands use
    upstream `ailang` from PATH.
- `ailang check src/core/context_usage.ail`
  - Passes.
- `ailang test src/core/context_usage.ail`
  - Passes: 11 tests.
- `jq empty .motoko/model-catalog.json`
  - Passes.
- `jq -e '.context_limits["ollama/qwen3.6:35b-a3b-mxfp8"] == 262144' .motoko/model-catalog.json`
  - Passes.
- `ailang check scripts/smoke_catalog_compaction.ail`
  - Passes.
- `ailang run --caps IO,FS,Env --entry main scripts/smoke_catalog_compaction.ail`
  - Passes and confirms:
    - `catalog_context_limit_for("test/tiny")` reads the checked-in catalog
      limit of `100`.
    - `compact_step_with_limit` reports `compaction_exhausted` when that
      catalog limit is exceeded by non-elidable history.
    - uncatalogued provider-prefixed models resolve to `0` instead of a
      guessed provider-family limit.
- `cd src/tui && bun run build`
  - Passes.
- `cd src/tui && bun run test -- src/models.test.ts src/runtime-process.stream-protocol.test.ts`
  - Does not reach test execution in this environment. Jest fails during
    startup with `TypeError: Attempted to assign to readonly property` from
    `jest-runtime` / `stack-utils`, before any test cases run.
