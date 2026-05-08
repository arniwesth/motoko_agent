# Local OpenAI-Compatible Endpoint Integration Plan

**Goal:** Let Motoko/AILANG use models served from a local or LAN OpenAI-compatible endpoint (for example `http://100.79.48.75:8000/v1`) and expose those models in the TUI `/model` picker.

**Target model:** `google/gemma-4-26B-A4B-it` on DGX Spark (`/v1/models`, `/v1/chat/completions`).

## Expected File Changes

Expected to modify:
- `ailang/cmd/ailang/ai_handlers.go`
- `ailang/cmd/ailang/help.go`
- `ailang/internal/ai/openai/chat.go`
- `ailang/internal/ai/openai/responses.go`
- `src/tui/src/models.ts`
- `src/tui/src/ui.ts`
- `src/tui/src/commands.ts`
- `ailang/internal/ai/openai/client_test.go`

Expected to add (if absent):
- `ailang/cmd/ailang/ai_handlers_test.go`
- `src/tui/src/models.test.ts`

Expected to update (existing tests, if needed):
- `src/tui/src/commands.test.ts`
- `src/tui/src/ui.*.test.ts`

---

## Current-State Findings

- AILANG already supports custom OpenAI-compatible base URLs via `openai.WithBaseURL(...)`, but only OpenRouter uses it in production wiring.
- OpenAI path currently requires `OPENAI_API_KEY`; local auth-none endpoints are not first-class.
- TUI dynamic discovery currently exists only for OpenRouter.
- Runtime path already accepts `provider/model` strings end-to-end (`MODEL` -> `--ai` -> handler).

---

## Design Decisions

1. Add a **generic OpenAI base URL override** for local/self-hosted endpoints.
2. Keep provider string as `openai/...` to avoid introducing a new provider unless needed.
3. Support **auth-none** endpoints safely by allowing empty API key only when a non-default OpenAI base URL is configured.
4. Add **optional local model discovery** to TUI picker/autocomplete via `GET <OPENAI_BASE_URL>/models`.
5. Keep OpenRouter behavior unchanged.
6. When API key is empty in custom-base-URL mode, **omit** the `Authorization` header (do not send `Bearer `).
7. Define strict `OPENAI_BASE_URL` normalization so config is predictable and supportable.

---

## Implementation Phases

## Phase 1: Runtime support for local OpenAI-compatible base URL

### Scope
- Add `OPENAI_BASE_URL` handling in AI handler setup for provider `openai`.
- Use `openai.NewClient(apiKey, openai.WithBaseURL(baseURL))` when override is present.
- Normalize `OPENAI_BASE_URL` consistently before use.

### Files
- `ailang/cmd/ailang/ai_handlers.go`
- `ailang/cmd/ailang/help.go` (document new env var)

### Behavior
- If `OPENAI_BASE_URL` is unset: existing behavior unchanged.
- If set: OpenAI requests go to `<OPENAI_BASE_URL>/chat/completions` or `/responses`.
- Normalization rules:
  - Trim whitespace.
  - Remove trailing `/`.
  - Require scheme `http://` or `https://`.
  - If value does not end with `/v1`, append `/v1`.
  - Effective base URL examples:
    - `http://host:8000` -> `http://host:8000/v1`
    - `http://host:8000/` -> `http://host:8000/v1`
    - `http://host:8000/v1` -> `http://host:8000/v1`

### Acceptance criteria
- `--ai openai/google/gemma-4-26B-A4B-it` reaches DGX endpoint when `OPENAI_BASE_URL=http://100.79.48.75:8000/v1`.
- Existing `openai/gpt-*` cloud usage still works unchanged when `OPENAI_BASE_URL` is not set.

---

## Phase 2: Auth handling for local auth-none endpoints

### Scope
- Relax OpenAI API key requirement only for local/custom OpenAI base URL mode.
- Continue requiring key for default OpenAI cloud endpoint.
- Support auth-none endpoints by conditionally omitting auth header when key is empty.

### Files
- `ailang/cmd/ailang/ai_handlers.go`
- `ailang/internal/ai/openai/chat.go`
- `ailang/internal/ai/openai/responses.go`

### Behavior
- Default OpenAI endpoint (`https://api.openai.com/v1`) still requires `OPENAI_API_KEY`.
- Custom base URL mode can proceed with empty key.
- Header rules:
  - Non-empty key: send `Authorization: Bearer <key>`.
  - Empty key in custom-base mode: omit `Authorization` header.

### Acceptance criteria
- DGX endpoint works without setting `OPENAI_API_KEY`.
- Missing `OPENAI_API_KEY` still fails for default OpenAI cloud path.
- Local endpoints that reject empty bearer tokens work (because header is omitted when key is empty).

---

## Phase 3: TUI local model discovery

### Scope
- Add dynamic model fetch from OpenAI-compatible `/models` when `OPENAI_BASE_URL` is set.
- Merge discovered models into picker and autocomplete lists with `openai/` prefix.

### Files
- `src/tui/src/models.ts`
- `src/tui/src/ui.ts`
- `src/tui/src/commands.ts`

### Behavior
- Existing `KNOWN_MODELS` remains baseline.
- If `OPENAI_BASE_URL` is set, fetch additional models and append as `openai/<id>`.
- OpenRouter dynamic fetch remains independent and additive.

### Acceptance criteria
- `/model` picker includes `openai/google/gemma-4-26B-A4B-it` when DGX is reachable.
- `/model <prefix>` autocomplete returns discovered local models.

---

## Phase 4: Validation and regression tests

### Runtime tests
- `ailang/internal/ai/openai/client_test.go`
  - Base URL normalization/usage cases for chat and responses endpoints.
  - Auth header present when key is set.
  - Auth header omitted when key is empty (custom endpoint mode).
- `ailang/cmd/ailang/ai_handlers_test.go` (new if needed)
  - Default OpenAI path requires `OPENAI_API_KEY`.
  - Custom `OPENAI_BASE_URL` path allows empty key.
  - OpenRouter path still requires `OPENROUTER_API_KEY`.
  - OpenRouter base URL remains unchanged.

### TUI tests
- `src/tui/src/models.test.ts` (new if needed)
  - Fetch local `/models` and prefix ids as `openai/<id>`.
  - Graceful fallback on fetch failure.
- `src/tui/src/commands.test.ts` and/or `src/tui/src/ui.*.test.ts`
  - Merge + dedupe behavior with:
  - no dynamic providers
  - OpenRouter only
  - local OpenAI only
  - both OpenRouter and local OpenAI

### Manual verification
- Run Motoko with:
  - `OPENAI_BASE_URL=http://100.79.48.75:8000/v1`
  - `MODEL=openai/google/gemma-4-26B-A4B-it`
- Confirm the runtime emits successful `thinking/obs/done` flow using DGX model.

---

## Out of Scope

- Adding a separate provider namespace like `local/` or `vllm/`.
- Automatic context-window metadata plumbing into runtime limits.
- Persisted provider registry config file format (Pi-style `providers:` block).

---

## Risks and Mitigations

1. Responses API mismatch on local backends.
- Mitigation: use non-GPT5 model IDs for local endpoints (chat-completions path), and document expected endpoint compatibility.

2. Ambiguity in auth requirements.
- Mitigation: key required for default OpenAI cloud URL; optional only when explicit custom base URL is set.

3. Duplicate model entries in picker.
- Mitigation: normalize and de-duplicate merged lists before rendering.

4. Base URL misconfiguration (`/v1` missing, trailing slash, wrong scheme).
- Mitigation: enforce normalization + clear startup error messages on invalid URLs.

---

## Rollout Strategy

1. Runtime base URL + auth behavior first.
2. TUI discovery second.
3. Tests and docs last.
4. Keep fallback to manual model entry (`/model openai/<id>`) even if discovery fails.

---

## Done Definition

- A user can run Motoko against DGX Spark model using only:
  - `OPENAI_BASE_URL=http://100.79.48.75:8000/v1`
  - `MODEL=openai/google/gemma-4-26B-A4B-it`
- `/model` picker can discover and present the same model from the local endpoint.
- Existing OpenAI, OpenRouter, Gemini, Anthropic, and Ollama flows continue to work.
