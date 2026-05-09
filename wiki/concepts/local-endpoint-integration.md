---
sources: [summaries/2026-05-03-local-openai-endpoint-key-relaxation.md]
brief: Strategy for routing OpenAI-compatible requests to local endpoints without authentication.
---

# Local Endpoint Integration

Local Endpoint Integration is the architectural pattern that allows an AI orchestration system to route requests to on-premise, authentication‑free OpenAI‑compatible API endpoints. This is essential for running models on private infrastructure (e.g., DGX servers) without exposing them to the public internet or requiring per‑request API keys.

## Core Mechanism

A custom base URL, set via the `OPENAI_BASE_URL` environment variable, instructs the routing layer to bypass the default `https://api.openai.com/v1` endpoint. The system then strips the `openai/` provider prefix and directs the request to the local server.

## API Key Relaxation

Per [[summaries/2026-05-03-local-openai-endpoint-key-relaxation]], the handler originally required a non‑empty `OPENAI_API_KEY` for every OpenAI provider, causing startup failures when only a local endpoint was configured. The fix relaxes this check: when `OPENAI_BASE_URL` is set and non‑empty, an empty key is allowed. The default cloud endpoint continues to require a key, preserving [[concepts/api-key-security]].

## Design Principle

- **Cloud endpoints** → mandatory authentication (`OPENAI_API_KEY`).
- **Custom base URLs** → optional authentication (auth‑none local endpoints).
- **OpenRouter** → unchanged, managed independently.

This separation ensures local deployments are simple while cloud usage remains secure.

## Related Concepts

- [[concepts/handler-routing-architecture]]: the interplay between handler setup validation (early) and request‑level routing (late) that caused the original bug.
- [[concepts/api-key-security]]: the policies that keep cloud credentials mandatory.
- [[summaries/2026-05-03-local-openai-endpoint-key-relaxation]]: the specific fix and symptom report.
