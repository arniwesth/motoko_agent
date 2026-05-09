---
doc_type: short
full_text: sources/Local_OpenAI_Endpoint_Integration.md
---

# Summary: Local OpenAI-Compatible Endpoint Integration

## Overview
This document outlines a phased plan to integrate local OpenAI-compatible endpoints (e.g., DGX Spark) into the Motoko/AILANG system. The goal is to allow users to set a custom `OPENAI_BASE_URL` environment variable, dynamically discover models from that endpoint via `/models`, and use them in the TUI model picker alongside existing providers like OpenRouter, without introducing a new provider namespace.

## Key Findings & Design Decisions
- AILANG already supports custom base URLs via `openai.WithBaseURL(...)`, but only OpenRouter uses it in production.
- The plan reuses the `openai/` namespace (e.g., `openai/google/gemma-4-26B-A4B-it`) to avoid adding a separate provider.
- For local auth-none endpoints, the API key requirement is relaxed only when a custom base URL is set, and the `Authorization` header is omitted entirely when the key is empty.
- Strict [[concepts/openai-base-url-normalization]] rules are defined: trim whitespace, remove trailing slash, require `http(s)://`, and ensure the path ends with `/v1`. This makes configuration predictable.

## Implementation Phases
- **Phase 1 (Runtime base URL):** Modify `ai_handlers.go` to consume `OPENAI_BASE_URL` and pass it to the OpenAI client. Normalize the URL before use.
- **Phase 2 (Auth relaxation):** Adjust auth logic in `chat.go` and `responses.go` so that custom base URL mode allows empty API key (no `Authorization` header), while the default cloud endpoint still requires a key.
- **Phase 3 (TUI discovery):** Enhance the frontend (`models.ts`, `ui.ts`, `commands.ts`) to fetch `/models` from the local endpoint and merge discovered models (prefixed `openai/`) into the picker and autocomplete. This coexists with OpenRouter dynamic discovery, both falling under [[concepts/dynamic-model-discovery]].
- **Phase 4 (Tests & validation):** Add unit tests for base URL normalization, auth header handling, and model list merging. Manual verification with DGX Spark.

## Concepts
- [[concepts/openai-base-url-normalization]]: The set of rules ensuring that any user-supplied `OPENAI_BASE_URL` is consistently transformed into a valid base URL for the OpenAI client.
- [[concepts/auth-none-endpoints]]: Strategy for supporting local servers that do not require API keys, including conditional omission of the `Authorization` header.
- [[concepts/dynamic-model-discovery]]: The mechanism by which the TUI fetches available models from configured endpoints (OpenRouter and local OpenAI) to populate the `/model` command interface.

## Risks & Mitigations
- Responses API mismatch on local backends? Use chat-completions path for non-GPT-5 models.
- Duplicate model entries? Deduplication after merging all sources.
- Configuration errors? Enforced normalization with clear startup error messages.