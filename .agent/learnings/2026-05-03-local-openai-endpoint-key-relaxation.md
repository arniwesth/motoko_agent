# Local OpenAI Endpoint: API Key Relaxation (2026-05-03)

## Symptom
`make run` with local profile (`openai/google/gemma-4-26B-A4B-it` + `OPENAI_BASE_URL=http://100.79.48.75:8000/v1`) failed:
```
Error: OPENAI_API_KEY environment variable required
```
The model routes to a local DGX endpoint that doesn't need authentication.

## Root Cause
`/opt/ailang/cmd/ailang/ai_handlers.go` unconditionally required `OPENAI_API_KEY` for any model matching `ProviderOpenAI`. The check happened during handler setup, before the request-level routing code in `openrouter_motoko.go` could apply `OPENAI_BASE_URL` and strip the `openai/` prefix.

The routing code (`routeOpenAIBaseURLFromEnvMotoko`, `routeOpenAIPrefixMotoko`) only runs inside `Client.Generate()` — which is never reached because handler creation fails first.

## Fix
In both `setupAIHandler` (line 110) and `setupAIHandlerDirect` (line 188):

```go
// Allow empty API key when OPENAI_BASE_URL is set (custom/local endpoint).
customBaseURL := strings.TrimSpace(os.Getenv("OPENAI_BASE_URL"))
if apiKey == "" && customBaseURL == "" {
    // error as before
}
```

When `OPENAI_BASE_URL` is set and non-empty, the API key requirement is skipped. The default OpenAI cloud endpoint (`https://api.openai.com/v1`) still requires a key.

## Design Decision
Per `Local_OpenAI_Endpoint_Integration.md` plan (Phase 2):
- Default OpenAI endpoint → require `OPENAI_API_KEY`
- Custom base URL → allow empty key (auth-none local endpoints)
- OpenRouter behavior unchanged

## Files Changed
- `/opt/ailang/cmd/ailang/ai_handlers.go` — relaxed key check in both handler setup paths
