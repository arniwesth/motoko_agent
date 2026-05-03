# Plan: Gemma 4 Thinking Mode Enablement (Benchmark Path)

## Goal
Add first-class support to explicitly enable/disable Gemma 4 thinking mode in the Motoko benchmark flow, using provider-native request options (not prompt hacks), while preserving current default behavior.

## Why This Change
Current benchmark runs route `openai/google/gemma-4-26B-A4B-it` through an OpenAI-compatible endpoint and do not send a thinking control field. On the current vLLM endpoint, this defaults to non-thinking behavior. We need an explicit benchmark-level control.

## Scope
In scope:
- Add benchmark CLI switch to request thinking on/off.
- Thread this switch through benchmark runner -> Motoko RPC -> AILANG AI request options -> OpenAI provider payload.
- Map to Gemma/vLLM-compatible field: `chat_template_kwargs.enable_thinking`.
- Keep existing behavior unchanged when flag is omitted.
- Add docs and focused tests.

Out of scope:
- Global runtime UX toggles in TUI commands.
- Model-specific heuristics in prompt text (`<|think|>` injection).
- Non-OpenAI provider thinking toggles.

## Key Design Decision
Use `ai.Request.Options` as the transport for provider-specific controls, and plumb it through streaming and non-streaming OpenAI paths. This keeps the feature architecture-clean and reusable for other provider-specific knobs.

## Planned Files
Core benchmark path:
- `benchmarks/aider_polyglot.py`
- `benchmarks/motoko_rpc.py`

AILANG AI plumbing:
- `ailang/internal/ai/stream_motoko.go`
- `ailang/internal/ai/handler.go`
- `ailang/internal/ai/openai/types.go`
- `ailang/internal/ai/openai/chat.go`
- `ailang/internal/ai/openai/stream_motoko.go`

Docs/tests:
- `benchmarks/README.md`
- OpenAI provider tests in `ailang/internal/ai/openai/*_test.go` (targeted additions)

## API/Contract Changes
### Benchmark CLI
Add explicit switch(es) in `benchmarks/aider_polyglot.py`:
- `--thinking on|off|auto` (recommended), default `auto`

Semantics:
- `auto`: do not send any thinking key (preserve current behavior)
- `on`: send `chat_template_kwargs.enable_thinking = true`
- `off`: send `chat_template_kwargs.enable_thinking = false`
- `on|off` with non-OpenAI provider/model route: fail fast at CLI validation with clear error

### Motoko RPC bridge
Extend `MotokoRpc` constructor/options to accept benchmark AI options payload and pass into environment for runtime consumption.

### Runtime-to-provider transport
Introduce an env contract from benchmark harness to runtime, then decode into `ai.Request.Options` for `CallStream`/`Call` requests.

Recommended env key:
- `MOTOKO_AI_OPTIONS_JSON`

Validation ownership:
- Benchmark CLI owns mode-aware fail-fast behavior (`on|off` unsupported provider, malformed options payload for explicit thinking modes).
- Runtime performs strict JSON decode of `MOTOKO_AI_OPTIONS_JSON`; if present and malformed, returns error (no silent mutation of options).

Value example:
- `{"chat_template_kwargs":{"enable_thinking":true}}`

### OpenAI request serialization
Extend OpenAI chat request payload types to include:
- `chat_template_kwargs` object (optional)

Populate it from `req.Options["chat_template_kwargs"]` when present.

## Implementation Phases
## Phase 1 - Benchmark surface
- Add `--thinking on|off|auto` parser option.
- Add provider compatibility validation in CLI argument handling:
  - allow `auto` for all providers
  - reject `on|off` when target route is not OpenAI-compatible
- Convert mode to JSON options payload.
- Pass payload into `MotokoRpc` env for both attempt 1 and attempt 2.
- Persist selected mode in benchmark metadata (`results.meta`) for observability.

## Phase 2 - AI options plumbing
- Add optional provider options on Handler/stream call path.
- Ensure both non-streaming and streaming calls can receive `Request.Options`.
- Parse `MOTOKO_AI_OPTIONS_JSON` once in runtime setup and carry through step loop.
- Parse policy for `MOTOKO_AI_OPTIONS_JSON`:
  - strict decode; malformed JSON is an error
  - mode-dependent handling (warn/fail) is decided upstream in benchmark CLI before runtime launch

## Phase 3 - OpenAI payload mapping
- Add `chat_template_kwargs` field in OpenAI chat request structs.
- Map `req.Options` -> outbound JSON for `chat.go` and `stream_motoko.go`.
- Guard mapping to avoid panics on malformed types.

## Phase 4 - Validation and docs
- Add/extend tests asserting emitted JSON includes `chat_template_kwargs` when set and omits it when unset.
- Update benchmark README with examples:
  - `--thinking on`
  - `--thinking off`
  - `--thinking auto`
- Run targeted benchmark smoke verification against local vLLM endpoint.
- Add benchmark README note describing fail-fast behavior for unsupported providers and malformed thinking options payload.

## Validation Plan
Unit-level:
- OpenAI request marshalling test: includes `chat_template_kwargs` for on/off.
- Options absent test: payload unchanged.
- Invalid options payload tests:
  - benchmark CLI: `--thinking=auto` + malformed payload path => warning + auto fallback
  - benchmark CLI: `--thinking=on|off` + malformed payload path => hard error
  - runtime: malformed `MOTOKO_AI_OPTIONS_JSON` returns explicit decode error

Integration-level (local endpoint):
- Primary assertion: captured outbound OpenAI request JSON contains `chat_template_kwargs.enable_thinking=true|false` when requested, and omits `chat_template_kwargs` for `auto`.
- Secondary smoke check only: `on` tends to include thought-channel text on this server, `off` tends to return final-answer-only.
- `auto`: matches current default server behavior.

Regression checks:
- Existing benchmark command without `--thinking` remains behaviorally unchanged.
- Non-OpenAI model runs unaffected.
- Non-OpenAI + `--thinking on|off` exits with explicit validation error before run starts.
- Non-OpenAI providers never receive `chat_template_kwargs` in provider payload serialization.

## Risks and Mitigations
Risk: Provider rejects unknown fields on some OpenAI-compatible servers.
Mitigation: default `auto` omits field; field only sent when explicitly requested.

Risk: Stream and non-stream paths diverge.
Mitigation: add mirrored mapping/tests in both `chat.go` and `stream_motoko.go`.

Risk: Bad JSON in env option payload.
Mitigation: fail fast for requested `on|off`; warning + fallback only for `auto`.

## Acceptance Criteria
- User can run benchmark with explicit thinking control (`on|off|auto`).
- Option is carried end-to-end to OpenAI-compatible request body.
- `--thinking on|off` on non-OpenAI provider/model route fails fast with a clear error.
- Malformed `MOTOKO_AI_OPTIONS_JSON` fails fast when thinking was explicitly requested (`on|off`).
- OpenAI payload assertions are covered by tests for both chat and stream paths.
- Non-OpenAI provider paths are verified to ignore/never serialize `chat_template_kwargs`.
- On current vLLM endpoint, toggle materially changes Gemma 4 output mode.
- Default benchmark behavior is unchanged when option is not set.
- README and tests updated.

## Rollout Order
1. Land AI options plumbing + tests (including provider-gated option handling contract).
2. Land OpenAI payload + tests for both chat and stream.
3. Land benchmark CLI wiring + docs.
4. Verify on local endpoint with one exercise before full-track run.
5. Require each PR to be independently testable and behavior-preserving when feature is not enabled.
