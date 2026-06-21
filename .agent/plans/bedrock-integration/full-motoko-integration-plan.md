# Full Motoko Bedrock Integration Plan

**Goal:** Turn the validated LiteLLM-first Bedrock smoke into a durable Motoko integration that works with the normal installed AILANG binary and a documented `PROFILE=bedrock` workflow.

**Non-goal:** Do not introduce a native Bedrock provider in Motoko or AILANG for this phase. Bedrock remains behind LiteLLM's OpenAI-compatible proxy.

## Current Validated State

The following path has been validated end to end with bearer-token-only Bedrock auth:

```text
Motoko
  -> AILANG OpenAI-compatible provider
  -> OPENAI_BASE_URL=http://127.0.0.1:4000/v1
  -> LiteLLM
  -> AWS_BEARER_TOKEN_BEDROCK + AWS_REGION
  -> Amazon Bedrock
```

Validated smokes:

- LiteLLM `/v1/models` returns `gpt-bedrock-smoke`.
- LiteLLM `/v1/chat/completions` succeeds.
- AILANG `std/ai.stepWithStream` succeeds when using the patched local AILANG binary.
- Motoko minimal `PROFILE=bedrock` smoke succeeds.
- Motoko native tool-use smoke succeeds: the model emits `BashExec`, Motoko dispatches it, and the follow-up model turn accepts the tool result.

Working LiteLLM model mapping:

```yaml
model_list:
  - model_name: gpt-bedrock-smoke
    litellm_params:
      model: bedrock/eu.anthropic.claude-sonnet-4-5-20250929-v1:0
      aws_region_name: os.environ/AWS_REGION
      api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
      drop_params: true
```

The inference profile may need to be changed for other AWS accounts or regions.

## Primary Blocker

The installed upstream `ailang` binary can ignore `OPENAI_BASE_URL` in the direct provider-guessing path for unresolved `gpt-*` aliases such as `gpt-bedrock-smoke`.

Symptom:

```bash
OPENAI_BASE_URL=http://127.0.0.1:4000/v1 \
OPENAI_API_KEY=motoko-litellm-local \
ailang run --caps AI,IO --ai gpt-bedrock-smoke --entry main scripts/smoke_bedrock_litellm.ail
```

Expected behavior:

```text
AILANG calls http://127.0.0.1:4000/v1/chat/completions
```

Observed installed-binary behavior:

```text
AILANG calls the real OpenAI API and fails with the dummy key.
```

Root cause:

- `setupAIHandlerDirect` guesses `ProviderOpenAI` for `gpt-bedrock-smoke`.
- That branch constructs `openai.NewClient(apiKey)` without passing `openai.WithBaseURL(customBaseURL)`.
- The configured-model path already handles `OPENAI_BASE_URL`; the direct fallback path does not.

Required upstream patch shape:

```go
var clientOpts []openai.ClientOption
if customBaseURL := strings.TrimSpace(os.Getenv("OPENAI_BASE_URL")); customBaseURL != "" {
	clientOpts = append(clientOpts, openai.WithBaseURL(customBaseURL))
}
client := openai.NewClient(apiKey, clientOpts...)
```

Local workaround until upstream is fixed:

```bash
AILANG_BIN=/workspaces/motoko_agent/ailang/.bin/ailang
```

## Implementation Plan

### Phase 1: Upstream AILANG Fix

Patch upstream AILANG:

- Update `cmd/ailang/ai_handlers.go` in `setupAIHandlerDirect`, OpenAI branch.
- Preserve the existing `OPENAI_API_KEY` guard for the direct path.
- Add `OPENAI_BASE_URL` support through `openai.WithBaseURL`.
- Do not change OpenRouter routing behavior.
- Do not add native Bedrock support.

Regression test:

- Add a test that starts a local `httptest.Server`.
- Set:

```bash
OPENAI_API_KEY=motoko-litellm-local
OPENAI_BASE_URL=<httptest-server>/v1
```

- Call `setupAIHandlerDirect(..., "gpt-bedrock-smoke", ...)`.
- Invoke `Step`.
- Assert the local server receives `/v1/chat/completions`.
- Assert the request model is `gpt-bedrock-smoke`.
- Assert the Authorization header carries the dummy key.
- Assert no request reaches OpenAI cloud.

Acceptance criteria:

- Installed AILANG can run the Bedrock AILANG smoke without `AILANG_BIN`.
- Dummy `OPENAI_API_KEY=motoko-litellm-local` is only sent to LiteLLM.
- No `OPENROUTER_API_KEY` prompt appears for `gpt-bedrock-smoke`.

### Phase 2: Motoko Profile Finalization

Keep `.motoko/config/bedrock/config.json` as the canonical Bedrock profile:

```json
{
  "agent": {
    "model": "gpt-bedrock-smoke",
    "openai_base_url": "http://127.0.0.1:4000/v1",
    "max_steps": 8
  },
  "extensions": {
    "order": [],
    "strict": false
  }
}
```

Profile requirements:

- Use `gpt-bedrock-smoke`.
- Keep `openai_base_url` pointed at LiteLLM.
- Keep extensions disabled for the baseline smoke.
- Keep `max_steps` low for smoke runs.
- Keep `tools.hybrid=true` and `tools.ohmy_pi=false`.

Acceptance criteria:

```bash
OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock \
make run TASK="Reply with exactly: bedrock smoke ok"
```

succeeds with the installed AILANG binary after Phase 1.

### Phase 3: LiteLLM Proxy Ergonomics

Add a small script or Make target to start the proxy consistently.

Proposed target:

```bash
make bedrock_proxy
```

Behavior:

- Load `.env` if present.
- Require `AWS_REGION`.
- Require `AWS_BEARER_TOKEN_BEDROCK`.
- Refuse to use `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`, or `AWS_SECRET_ACCESS_KEY` as the documented auth path.
- Start:

```bash
.venv-litellm/bin/litellm \
  --config scripts/bedrock-litellm.yaml \
  --host 127.0.0.1 \
  --port 4000
```

Secret-handling requirements:

- Do not print `AWS_BEARER_TOKEN_BEDROCK`.
- Do not enable shell tracing.
- Redact proxy errors before writing them to user-facing smoke output.
- Keep full proxy logs local and outside committed files.

Open question:

- Whether the repo should own `.venv-litellm` creation through a script, or only document installation.

### Phase 4: Smoke Targets

Add focused smoke targets or scripts:

```bash
make smoke_bedrock_litellm
make smoke_bedrock_ailang
make smoke_bedrock_motoko
make smoke_bedrock_tools
```

`smoke_bedrock_litellm`:

- Assumes LiteLLM is already running.
- Calls `/v1/models`.
- Confirms `gpt-bedrock-smoke` is present.
- Calls `/v1/chat/completions`.
- Reports assistant text or a redacted error.

`smoke_bedrock_ailang`:

- Runs:

```bash
OPENAI_BASE_URL=http://127.0.0.1:4000/v1 \
OPENAI_API_KEY=motoko-litellm-local \
ailang run --caps AI,IO --ai gpt-bedrock-smoke --entry main scripts/smoke_bedrock_litellm.ail
```

- Uses `std/ai.stepWithStream`, not `std/ai.call`.

`smoke_bedrock_motoko`:

- Runs:

```bash
OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock \
make run TASK="Reply with exactly: bedrock smoke ok"
```

`smoke_bedrock_tools`:

- Runs:

```bash
OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock \
make run TASK="Use bash to print the current working directory, then summarize it in one sentence."
```

Acceptance criteria:

- All four smoke targets pass with the installed fixed AILANG binary.
- Any failure report includes provider layer, status, and redacted message.
- No smoke target prints bearer tokens.

### Phase 5: Documentation

Update user-facing docs:

- `README.md`
- `.agent/plans/bedrock-integration/litellm-first-plan.md`
- This plan as implementation status changes

Docs must include:

- Architecture diagram.
- Required `.env` values:

```bash
AWS_REGION=...
AWS_BEARER_TOKEN_BEDROCK=...
```

- Dummy local proxy key:

```bash
OPENAI_API_KEY=motoko-litellm-local
```

- Warning not to use:

```bash
AWS_PROFILE
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
~/.aws
```

- How to find available Bedrock model IDs and inference profiles.
- How to swap `scripts/bedrock-litellm.yaml` to a different available inference profile.

### Phase 6: Optional Proxy Lifecycle Management

After the manual flow is stable, decide whether Motoko should manage LiteLLM itself.

Option A: Manual proxy, recommended short term

- User starts LiteLLM separately.
- Motoko only talks to `OPENAI_BASE_URL`.
- Fewer lifecycle and secret-handling risks.

Option B: Motoko-managed proxy, possible later

- `PROFILE=bedrock` can spawn LiteLLM before starting AILANG.
- Requires port management, health checks, log handling, shutdown cleanup, and secret redaction.
- Must avoid printing bearer tokens.

Do not implement Option B until the manual proxy path has passed repeated local and remote smokes.

## Failure Triage

`Incorrect API key provided: motoko-l********ocal`

- Installed AILANG ignored `OPENAI_BASE_URL` and called OpenAI cloud.
- Fix upstream AILANG or use patched `AILANG_BIN`.

`OPENROUTER_API_KEY environment variable required`

- Model alias routed incorrectly.
- Use `gpt-bedrock-smoke`, not `openai/...` or a vendor/model OpenRouter route.

`The provided model identifier is invalid`

- Bedrock model ID is unavailable in the selected region/account.
- List foundation models and inference profiles.
- Update `scripts/bedrock-litellm.yaml`.

`Invocation ... with on-demand throughput isn't supported`

- Use an inference profile ID or ARN instead of the base model ID.

`UnrecognizedClientException` or auth failure

- Confirm LiteLLM sees `AWS_BEARER_TOKEN_BEDROCK`.
- Do not rely on normal AWS credential-chain variables.

Tool-result correlation errors

- Isolate with `smoke_bedrock_tools`.
- Check whether LiteLLM translated tool calls and tool results into Bedrock's expected shape.

## Done Criteria

- Upstream AILANG direct OpenAI fallback honors `OPENAI_BASE_URL`.
- Installed `ailang` can pass the AILANG `stepWithStream` smoke without local `AILANG_BIN`.
- LiteLLM proxy startup is documented or scripted.
- `PROFILE=bedrock` runs Motoko minimal smoke successfully.
- Native tool-use smoke succeeds.
- Docs clearly describe bearer-token-only Bedrock auth and inference-profile selection.
- No native Bedrock provider code is introduced.
