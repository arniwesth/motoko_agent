# Migrate Motoko to upstream AILANG v0.15.0+

**Status**: Active
**Created**: 2026-05-05
**Upstream ref**: sunholo-data/ailang PR #2, design_docs/planned/motoko-agent-v0.15.0-migration.md

---

## Context

Motoko currently depends on a fork of AILANG (`sunholo-data/ailang@motoko` branch) for three features that are now available upstream in v0.15.0+:

1. OpenRouter prefix routing → built-in `openrouter` provider
2. Custom OpenAI base-URL routing → `[[ai_provider]]` blocks in `ailang.toml`
3. Token streaming (`callStreamResult`) → `callStream` from `std/ai/streaming` (v0.15.1+)

After migration, the fork (`arniwesth/ailang@motoko`) can be archived.

---

## Providers

### OpenRouter (primary)
- **Profile**: `.motoko/config/openrouter/config.json`
- **Model string**: `openrouter/deepseek/deepseek-v4-pro` (format: `openrouter/<provider>/<model>`)
- **Endpoint**: OpenRouter API (https://openrouter.ai/api/v1)
- **Auth**: Bearer token via `OPENROUTER_API_KEY` env var
- **Request shape**: `openai_chat`
- **Notes**: Model string uses `openrouter/` prefix which the fork's Go code uses for routing

### Local vLLM (secondary)
- **Profile**: `.motoko/config/local/config.json`
- **Model string**: `openai/google/gemma-4-26B-A4B-it`
- **Endpoint**: `http://100.79.48.75:8000/v1` (custom `openai_base_url`)
- **Auth**: None
- **Request shape**: `openai_chat`
- **Extra**: `ai_options_json` passes `{"chat_template_kwargs":{"enable_thinking":true,"thinking_token_budget":256}}`

---

## Affected Files (8 call sites + 1 codegen)

### Fork-specific imports to replace

| File | Import | Call sites |
|------|--------|-----------|
| `src/core/rpc.ail:3` | `import std/ai_motoko (callStreamResult, AIError)` | 1 (line 1263) |
| `src/core/ext/compose/compose.ail:3` | `import std/ai_motoko (callStreamResult)` | 2 (lines 453, 557) |
| `src/core/ext/compose/claimcheck.ail:3` | `import std/ai_motoko (callStreamResult)` | 3 (lines 135, 142, 146) |
| `src/core/ext/compose/author_loop.ail:3` | `import std/ai_motoko (callStreamResult)` | 1 (line 249) |
| `src/tui/src/env-server.ts:642,651` | String template (codegen) | 1 |

### Config/infra files

| File | Change |
|------|--------|
| `scripts/install-prerequisites.sh:355-363` | Clone upstream `dev` (later: tag) instead of `motoko` branch |
| `ailang.toml` | Add `ailang = ">=0.15.1"`, add `[[ai_provider]]` blocks |
| `ailang.lock` | Regenerate with `ailang lock` |

### Files that reference `openai_base_url` (may need rework)

| File | Lines | Role |
|------|-------|------|
| `src/core/config.ail` | 25, 298, 498 | AgentConfig record field + JSON parse/serialize |
| `src/core/supervisor.ail` | 29, 34, 49 | Secret validation (skips OPENAI_API_KEY if base_url set) |
| `src/tui/src/index.ts` | 146, 160-161 | Reads config, passes to env-server |
| `src/tui/src/config.ts` | 31, 101, 152 | Config template + env mapping |
| `src/core/ext/context_mode/context_mode.ail` | 241 | Default config stub |

---

## API Shape Migration

### Before (fork)

```ailang
import std/ai_motoko (callStreamResult, AIError)

-- callStreamResult(prompt: string, step: int, streamId: string, model: string) -> AIStreamResult
-- AIStreamResult = { ok: bool, output: string, error_message: string, provider: string,
--                    status_code: int, retryable: bool, error_code: string, chunks: [AIStreamChunk] }

let r = callStreamResult(input, step, att_stream_id, model);
if r.ok then Ok(r.output)
else Err({ message: r.error_message, provider: r.provider, statusCode: r.status_code,
           retryable: r.retryable, code: r.error_code })
```

### After (v0.15.1+ `callStream`)

```ailang
import std/ai/streaming (callStream, AIError)

-- callStream(provider: string, model: string, messagesJson: string)
--   -> Result[string, AIError] ! {AI, Stream, Net}
-- AIError = { message: string, retryable: bool, code: string }

let messagesJson = "[{\"role\":\"user\",\"content\":\"${escape(input)}\"}]";
match callStream(providerName, model, messagesJson) {
  Ok(text) => Ok(text),
  Err(e) => Err({ message: e.message, provider: providerName,
                  statusCode: 0, retryable: e.retryable, code: e.code })
}
```

### Key differences

1. `callStream` takes `(provider, model, messagesJson)` — no `step`/`streamId` args
2. `step` and `streamId` were used for trace spans; v0.15.1 handles tracing internally
3. `AIError` upstream omits `provider` and `statusCode` — fill from caller context
4. Return type is `Result[string, AIError]` instead of a record with `.ok` check
5. Effect signature adds `Stream, Net` (currently only `AI, Clock` on the retry wrapper)

---

## Provider Config (`ailang.toml` additions)

```toml
ailang = ">=0.15.1"

[[ai_provider]]
name = "openrouter"
# Built-in as of v0.15.0 — no config block needed if using upstream's
# native openrouter provider. The model string "openrouter/deepseek/deepseek-v4-pro"
# routes automatically.

[[ai_provider]]
name = "local-vllm"
schema_version = 1
request_shape = "openai_chat"
endpoint = "http://100.79.48.75:8000/v1/chat/completions"
auth_shape = "none"
models.allowed = ["google/gemma-4-26B-A4B-it"]
```

**Note**: The local provider's `ai_options_json` (thinking mode kwargs) needs investigation — v0.15.1's `[[ai_provider]]` schema may not support arbitrary request body injection yet. Fallback: pass via env var or propose schema v2 extension.

---

## Milestones

### M1: Install script + ailang.toml (30 min)

1. `scripts/install-prerequisites.sh`:
   - Line 10: Update comment
   - Line 355: Change log message
   - Line 359: `checkout motoko` → `checkout dev` (later: `v0.15.1` tag)
   - Line 360: pull
   - Line 363: `--branch motoko` → `--branch dev`
2. `ailang.toml`: Add version constraint + `[[ai_provider]]` block for local-vllm
3. Run `ailang lock` to regenerate lockfile

**Verify**: `ailang version` shows v0.15.x after fresh install

### M2: Core streaming swap — `rpc.ail` (30 min)

This is the critical path. All agent loops flow through `ai_stream_call_with_retry`.

1. Replace import: `std/ai_motoko (callStreamResult, AIError)` → `std/ai/streaming (callStream)`
2. Define local `AIError` type (or import from upstream) with motoko's extra fields
3. Rewrite `ai_stream_call_with_retry`:
   - Build `messagesJson` from `input` parameter
   - Extract provider name from model string (split on first `/`)
   - Call `callStream(provider, model, messagesJson)`
   - Map `Result` to existing error shape
   - Retry logic stays unchanged (it operates on the error result)
4. Update effect signature: add `Stream, Net` to the function's effect row

**Open question**: How does the `model` string map to provider selection? Currently:
- `openrouter/deepseek/deepseek-v4-pro` → fork's Go code strips prefix, hits OpenRouter
- `openai/google/gemma-4-26B-A4B-it` + `openai_base_url` → fork routes to local endpoint

With v0.15.1: OpenRouter is built-in (handles `openrouter/` prefix). For local, the `[[ai_provider]]` block maps model names to the custom endpoint.

**Risk**: The `openai_base_url` config field currently flows from profile JSON → supervisor → env-server → ailang runtime. With `[[ai_provider]]`, this routing moves to `ailang.toml`. We may need to either:
- (a) Generate/modify `ailang.toml` dynamically based on the active profile, or
- (b) Keep `openai_base_url` in the config but pass it as an env var that the `[[ai_provider]]` block references via `${OPENAI_BASE_URL}`

Option (b) preserves the existing multi-profile system without runtime TOML rewriting.

### M3: Compose extension (3 files, 30 min)

Mechanical swap — same pattern as M2 but simpler (no retry wrapper):

1. `src/core/ext/compose/compose.ail` — 2 call sites (lines 453, 557)
2. `src/core/ext/compose/claimcheck.ail` — 3 call sites (lines 135, 142, 146)
3. `src/core/ext/compose/author_loop.ail` — 1 call site (line 249)

Each follows:
```ailang
-- Before:
let r = callStreamResult(prompt, step, streamId, model);
if r.ok then ... r.output ... else ...

-- After:
match callStream(provider, model, buildMessages(prompt)) {
  Ok(text) => ... text ...,
  Err(e) => ...
}
```

**Note**: These files don't import `AIError` — they typically just check `.ok` and use `.output`. The migration simplifies them (Result pattern is more idiomatic).

### M4: TypeScript codegen — `env-server.ts` (20 min)

Update the inline AILANG snippet template at lines 640-658:

```typescript
// Before:
"import std/ai_motoko (callStreamResult)",
...
"  let r = callStreamResult(prompt, 0, streamId, model);",

// After:
"import std/ai/streaming (callStream)",
...
"  match callStream(provider, model, messagesJson) {",
...
```

Also update the `ailang run` invocation (line 672) if `--caps` needs `Stream,Net` added.

### M5: Config system cleanup (30 min, can defer)

Once `[[ai_provider]]` handles routing:
- `openai_base_url` field in `AgentConfig` becomes unused for AI calls
- Could deprecate or repurpose as a pass-through env var for the provider block
- `ai_options_json` needs a migration path (extra body params for local inference)
- `validate_secrets` in supervisor.ail needs updating

**Decision**: Defer M5 until M2-M4 are working. Keep `openai_base_url` in config but ignore it in the new streaming path; pass it as `OPENAI_BASE_URL` env var for the `[[ai_provider]]` block to consume via `${OPENAI_BASE_URL}`.

### M6: Tier 1 verification (20 min)

- [ ] `ailang check` passes on all `.ail` files
- [ ] `make test` passes
- [ ] `make build` (TS compiles)
- [ ] No remaining references to `std/ai_motoko` in `src/`

### M7: Tier 2 smoke test (30 min, needs live provider)

- [ ] Run agent loop with OpenRouter profile against a real model
- [ ] Run agent loop with local profile against vLLM endpoint
- [ ] Verify TUI streaming display works (token-by-token rendering)
- [ ] Compare output shape to pre-migration baseline

---

## Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| P1 | Target AILANG `dev` branch initially, swap to release tag when available | Allows immediate development; tag swap is 1-line change |
| P2 | Keep motoko's custom `AIError` shape with extra fields | Downstream code (retry logic, error reporting) depends on `provider` + `statusCode` fields |
| P3 | Use `[[ai_provider]]` with `${OPENAI_BASE_URL}` env var reference for local provider | Preserves multi-profile config system without runtime TOML generation |
| P4 | Defer config cleanup (M5) until streaming path is proven | Reduces risk; old fields become dead code temporarily |
| P5 | Keep motoko's custom tool dispatch (`tool_contract.ail`, `tool_runtime.ail`) for now | M-AI-TOOL-LOOP provides upstream equivalents but porting tool dispatch is a separate, larger effort |

---

## Open Questions

1. **Message format**: `callStream` takes `messagesJson` (full chat format). Current fork takes a raw `prompt` string. Where is the message array constructed? Is it just a single user message wrapping the prompt, or does it include conversation history?

2. **`ai_options_json` passthrough**: The local profile uses `{"chat_template_kwargs":{"enable_thinking":true}}`. Does v0.15.1's provider config support extra body params? If not, need upstream schema extension.

3. **TUI streaming events**: The fork emits `MOTOKO_STREAM_EVENTS` for token-by-token TUI rendering. Does `callStream` emit equivalent events, or does the TUI need to switch to monitoring `std/stream` events?

4. **Profile-provider mapping**: With multi-profile configs, different profiles select different providers. The `[[ai_provider]]` blocks in `ailang.toml` are static. How do we handle profile switching at runtime? Options:
   - (a) All providers declared in `ailang.toml`; profile selects model string that routes to the right one
   - (b) Generate `ailang.toml` dynamically per profile
   - (c) Pass provider config via env vars

5. **Effect row widening**: Adding `Stream, Net` to `ai_stream_call_with_retry` propagates up through `rpc_loop` and ultimately `main`. What's the current max effect set and does it already include these?

---

## Estimated Total Effort

| Milestone | Time | Blocked on |
|-----------|------|-----------|
| M1 | 30 min | Nothing |
| M2 | 30 min | Clarity on message format (Q1) |
| M3 | 30 min | M2 proven |
| M4 | 20 min | M2 pattern established |
| M5 | 30 min | M2-M4 working (deferrable) |
| M6 | 20 min | M2-M4 complete |
| M7 | 30 min | Live provider access |

**Total**: ~3 hours (M5 deferrable → ~2.5 hours critical path)
