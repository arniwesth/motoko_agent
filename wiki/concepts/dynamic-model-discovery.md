---
sources: [summaries/TUI_OM_Command_Patterns.md, summaries/Local_OpenAI_Endpoint_Integration.md]
brief: TUI feature that fetches available AI models from configured endpoints and merges them into the model picker.
---

# Dynamic Model Discovery

Dynamic Model Discovery is the mechanism by which the Motoko TUI automatically retrieves a list of available AI models from configured endpoints and incorporates them into the `/model` command's picker and autocomplete. This eliminates the need to manually type model identifiers for providers that support the `/models` endpoint.

## Current Implementation
- **OpenRouter** already supports dynamic discovery; when the `OPENROUTER_API_KEY` is set, the TUI fetches from `https://openrouter.ai/api/v1/models` and adds results prefixed with `openrouter/`.
- **Local OpenAI endpoints** (Phase 3) will add a second dynamic source: when `OPENAI_BASE_URL` is configured, the TUI fetches `GET <OPENAI_BASE_URL>/models` and prefixes the returned model IDs with `openai/`.

## Behavior
- The static `KNOWN_MODELS` list remains the baseline.
- Fetched models are **merged and deduplicated** across all dynamic sources. Deduplication ensures that identical model IDs from different sources don’t clutter the picker.
- The picker and autocomplete behave uniformly regardless of origin: users can type a prefix like `openai/google` and see suggestions from both static and dynamic lists.
- If a fetch fails (network error, endpoint unreachable), the TUI **gracefully falls back** to the existing model list and logs the failure, so the user can still manually enter `/model openai/<id>`.

## Relation to Other Concepts
- [[concepts/openai-base-url-normalization]] ensures the fetch URL for the local endpoint is correctly formed (e.g., `http://host:8000/v1/models`).
- [[concepts/auth-none-endpoints]] may allow model discovery from local servers that do not require an API key.
- The plan is outlined in [[summaries/Local_OpenAI_Endpoint_Integration]].

## Acceptance Criteria
- `/model` picker includes dynamically discovered models (e.g., `openai/google/gemma-4-26B-A4B-it` when a DGX Spark endpoint is reachable).
- Autocomplete returns matching dynamic models as the user types.
- Manual model entry (`/model openai/<id>`) works even if discovery fails.

See also: [[summaries/TUI_OM_Command_Patterns]]