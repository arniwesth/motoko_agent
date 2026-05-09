---
sources: [summaries/Exa_Websearch_Extension.md, summaries/2026-05-03-local-openai-endpoint-key-relaxation.md]
brief: Separation of handler setup checks from runtime routing, enabling flexible endpoint configuration.
---

# Handler Routing Architecture

Handler Routing Architecture describes the layered separation between **handler‑setup validation** and **request‑level routing** in the AI provider infrastructure. In the current codebase ([[summaries/2026-05-03-local-openai-endpoint-key-relaxation]]), handlers are created during startup with checks like `OPENAI_API_KEY` requirements. Routing decisions—such as reading `OPENAI_BASE_URL`, stripping the `openai/` prefix, and actually selecting the endpoint URL—are deferred to the `Client.Generate()` method.

This split was originally designed to centralize provider‑specific configuration at handler creation, but it created a temporal gap: startup checks ran before the environment could influence where a request would go. When a local DGX endpoint was configured via `OPENAI_BASE_URL`, the unconditional key check failed even though the request would never reach OpenAI’s cloud.

## Key Characteristics
- **Handler‑level checks**: static, lifecycle‑bound. Run once during [[handler-routing-architecture|handler setup]] (e.g., `setupAIHandler`). They enforce invariants like a required API key for cloud providers.
- **Request‑level routing**: dynamic, per‑request. Considers environment variables, model prefixes, and optional overrides only after the handler is already active.
- The two layers are not currently combined; there is no re‑evaluation of the key requirement after routing decisions are made.

## Implications
- Any configuration that relaxes a startup‑time constraint (e.g., removing an API key for a local endpoint) must either be mirrored in the handler setup or be known before the handler is created. The fix in [[summaries/2026-05-03-local-openai-endpoint-key-relaxation]] took the former approach by checking `OPENAI_BASE_URL` at handler creation.
- A more robust architecture might move all routing‑sensitive validation to the request level, or allow handlers to be reconfigured dynamically. This concept is related to [[concepts/local-endpoint-integration]] where authentication requirements differ between backends.
- The current design preserves [[concepts/api-key-security]] for cloud providers but adds a conditional path for local, zero‑auth endpoints.

## Future Considerations
- Consolidating validation into a single point after routing could reduce similar bugs and simplify the codebase. However, this would require handlers to be tolerant of missing keys until a request is actually routed to a backend that needs one.
- This architecture also interacts with provider routing logic (`routeOpenAIBaseURLFromEnvMotoko`, `routeOpenAIPrefixMotoko`) that currently lives deep in the client—potential targets for abstraction.

See also: [[summaries/Exa_Websearch_Extension]]