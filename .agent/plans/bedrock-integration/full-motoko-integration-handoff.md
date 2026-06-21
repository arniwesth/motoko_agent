# Implementation Handoff: Full Motoko Bedrock Integration

You are implementing the next phase of Motoko's Bedrock integration.

Start by reading:

- `.agent/plans/bedrock-integration/full-motoko-integration-plan.md`
- `.agent/plans/bedrock-integration/litellm-first-plan.md`
- `README.md`
- `Makefile`
- `scripts/bedrock-litellm.yaml`
- `scripts/smoke_bedrock_litellm.ail`
- `.motoko/config/bedrock/config.json`
- `src/tui/src/runtime-process.ts`
- `src/tui/src/config.ts`
- `ailang/cmd/ailang/ai_handlers.go`
- `ailang/cmd/ailang/openai_local_endpoint_test.go`
- `ailang/internal/ai/openai/client.go`
- `ailang/internal/ai/openai/step.go`

## Core Constraints

Do not add native Bedrock provider code in Motoko or AILANG for this phase.

Preserve this architecture:

```text
Motoko
  -> AILANG OpenAI-compatible provider
  -> OPENAI_BASE_URL=http://127.0.0.1:4000/v1
  -> LiteLLM
  -> AWS_BEARER_TOKEN_BEDROCK + AWS_REGION
  -> Amazon Bedrock
```

The Bedrock side must use bearer-token-only auth:

```bash
AWS_BEARER_TOKEN_BEDROCK=...
AWS_REGION=...
```

Do not rely on:

```bash
AWS_PROFILE
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
~/.aws
```

Motoko/AILANG still needs an `OPENAI_API_KEY` value for the OpenAI-compatible path. For a no-auth local LiteLLM proxy, use only this dummy value:

```bash
OPENAI_API_KEY=motoko-litellm-local
```

Do not pass a real OpenAI key to LiteLLM unless the proxy is intentionally configured to require it as its own master key.

## Current Validated State

The previous validation succeeded with:

- LiteLLM installed locally in `.venv-litellm`.
- LiteLLM serving `gpt-bedrock-smoke`.
- Bedrock auth via `AWS_BEARER_TOKEN_BEDROCK` and `AWS_REGION` loaded from `.env`.
- Working LiteLLM mapping:

```yaml
model_list:
  - model_name: gpt-bedrock-smoke
    litellm_params:
      model: bedrock/eu.anthropic.claude-sonnet-4-5-20250929-v1:0
      aws_region_name: os.environ/AWS_REGION
      api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
      drop_params: true
```

This inference profile is account/region-specific. If it fails elsewhere, list available Bedrock inference profiles and update `scripts/bedrock-litellm.yaml`.

Validated smoke results:

- LiteLLM `/v1/models` returned `gpt-bedrock-smoke`.
- LiteLLM `/v1/chat/completions` returned `Bedrock smoke ok.`
- AILANG `std/ai.stepWithStream` returned `bedrock ailang ok` when run with the patched local AILANG binary.
- Motoko minimal `PROFILE=bedrock` smoke succeeded.
- Motoko tool-use smoke succeeded with `BashExec`.

## Primary Blocker To Fix First

The installed upstream `ailang` binary can ignore `OPENAI_BASE_URL` in the direct provider-guessing path for unresolved `gpt-*` aliases such as `gpt-bedrock-smoke`.

Symptom:

```bash
OPENAI_BASE_URL=http://127.0.0.1:4000/v1 \
OPENAI_API_KEY=motoko-litellm-local \
ailang run --caps AI,IO --ai gpt-bedrock-smoke --entry main scripts/smoke_bedrock_litellm.ail
```

Expected:

```text
AILANG calls http://127.0.0.1:4000/v1/chat/completions
```

Observed with the unfixed installed binary:

```text
AILANG calls the real OpenAI API and fails with the dummy key.
```

Root cause:

- `setupAIHandlerDirect` guesses `ProviderOpenAI` for `gpt-bedrock-smoke`.
- The direct OpenAI branch constructs `openai.NewClient(apiKey)` without passing `openai.WithBaseURL(customBaseURL)`.
- The configured-model path already handles `OPENAI_BASE_URL`; the direct fallback path must be fixed upstream.

Required patch shape in `ailang/cmd/ailang/ai_handlers.go`:

```go
var clientOpts []openai.ClientOption
if customBaseURL := strings.TrimSpace(os.Getenv("OPENAI_BASE_URL")); customBaseURL != "" {
	clientOpts = append(clientOpts, openai.WithBaseURL(customBaseURL))
}
client := openai.NewClient(apiKey, clientOpts...)
```

Add or keep a regression test in `ailang/cmd/ailang/openai_local_endpoint_test.go`:

- Start a local `httptest.Server`.
- Set `OPENAI_API_KEY=motoko-litellm-local`.
- Set `OPENAI_BASE_URL=<server>/v1`.
- Call `setupAIHandlerDirect(..., "gpt-bedrock-smoke", ...)`.
- Invoke `Step`.
- Assert the server receives `/v1/chat/completions`.
- Assert the request model is `gpt-bedrock-smoke`.
- Assert the Authorization header carries the dummy key.

This fix should be contributed to the upstream AILANG repo. Until the fixed installed AILANG binary is available, use:

```bash
AILANG_BIN=/workspaces/motoko_agent/ailang/.bin/ailang
```

## Implementation Scope

Implement the smallest durable set:

1. Ensure the AILANG direct OpenAI fallback honors `OPENAI_BASE_URL`.
2. Ensure `.motoko/config/bedrock/config.json` remains the canonical Bedrock profile.
3. Add or finalize a LiteLLM proxy start target/script that loads `.env` safely.
4. Add or finalize smoke targets/scripts for LiteLLM, AILANG, Motoko minimal, and Motoko tool-use.
5. Fix or document the Makefile profile propagation issue for `PROFILE=bedrock` versus `MOTOKO_CONFIG=bedrock`.
6. Update docs/runbooks.

Do not:

- Add native Bedrock provider code.
- Route `gpt-bedrock-smoke` through OpenRouter.
- Rename the smoke alias to `openai/...`.
- Use aliases starting with `gpt-5`, `o1`, `o3`, or `codex`; those can trigger the OpenAI Responses API path.
- Print `.env` contents or bearer tokens.

## Profile and Routing Requirements

Use:

```text
gpt-bedrock-smoke
```

This alias is intentional:

- It routes through AILANG's OpenAI provider guessing.
- It avoids OpenRouter vendor/model routing.
- It avoids OpenAI Responses API model-name triggers.
- It uses Chat Completions against LiteLLM.

The Bedrock profile must point to LiteLLM:

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

Keep extensions disabled for the baseline smoke.

## LiteLLM Proxy Target Requirements

If adding `make bedrock_proxy` or a script, it should:

- Load `.env` if present.
- Require `AWS_REGION`.
- Require `AWS_BEARER_TOKEN_BEDROCK`.
- Avoid printing either value.
- Start LiteLLM at `127.0.0.1:4000`.
- Use `scripts/bedrock-litellm.yaml`.
- Sanitize the LiteLLM subprocess environment so normal AWS credential-chain variables are not used.

Preferred launch shape:

```bash
env -u AWS_PROFILE \
    -u AWS_ACCESS_KEY_ID \
    -u AWS_SECRET_ACCESS_KEY \
    -u AWS_SESSION_TOKEN \
  AWS_REGION="$AWS_REGION" \
  AWS_BEARER_TOKEN_BEDROCK="$AWS_BEARER_TOKEN_BEDROCK" \
  .venv-litellm/bin/litellm \
  --config scripts/bedrock-litellm.yaml \
  --host 127.0.0.1 \
  --port 4000
```

If `.venv-litellm` does not exist, either document the install command or add a separate explicit install target. Do not install packages during ordinary smoke targets unless the user explicitly asks for it.

## Smoke Sequence

Validate layer by layer. Do not start with Motoko.

### 1. LiteLLM Direct

Start proxy:

```bash
make bedrock_proxy
```

Or manually:

```bash
set -a
source .env
set +a
env -u AWS_PROFILE \
    -u AWS_ACCESS_KEY_ID \
    -u AWS_SECRET_ACCESS_KEY \
    -u AWS_SESSION_TOKEN \
  AWS_REGION="$AWS_REGION" \
  AWS_BEARER_TOKEN_BEDROCK="$AWS_BEARER_TOKEN_BEDROCK" \
  .venv-litellm/bin/litellm --config scripts/bedrock-litellm.yaml --host 127.0.0.1 --port 4000
```

In another shell:

```bash
curl -sS http://127.0.0.1:4000/v1/models
```

Then:

```bash
curl -sS http://127.0.0.1:4000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer motoko-litellm-local' \
  -d '{
    "model": "gpt-bedrock-smoke",
    "messages": [{"role": "user", "content": "Say bedrock smoke ok."}],
    "max_tokens": 64
  }'
```

Acceptance:

- `/v1/models` includes `gpt-bedrock-smoke`.
- Chat completion returns assistant text.
- Errors are redacted before user-facing output.

### 2. AILANG `stepWithStream` Preflight

Run:

```bash
OPENAI_BASE_URL=http://127.0.0.1:4000/v1 \
OPENAI_API_KEY=motoko-litellm-local \
ailang run --caps AI,IO --ai gpt-bedrock-smoke --entry main scripts/smoke_bedrock_litellm.ail
```

Acceptance:

- Uses `std/ai.stepWithStream`.
- Reaches LiteLLM, not OpenAI cloud.
- Prints `bedrock ailang ok` or equivalent success.
- Does not require `OPENROUTER_API_KEY`.
- Does not require `AILANG_BIN` after upstream AILANG is fixed and installed.

### 3. Motoko Minimal Profile

Run:

```bash
OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock MOTOKO_CONFIG=bedrock \
make run TASK="Reply with exactly: bedrock smoke ok"
```

Acceptance:

- Motoko starts with `config_profile=bedrock`.
- Model is `gpt-bedrock-smoke`.
- Loaded extensions are empty for the baseline profile.
- Task completes without provider/auth/routing errors.

### 4. Tool-Use Smoke

Run:

```bash
OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock MOTOKO_CONFIG=bedrock \
make run TASK="Use bash to print the current working directory, then summarize it in one sentence."
```

Acceptance:

- Model emits a valid tool call.
- Motoko dispatches `BashExec`.
- Tool result is accepted in the follow-up model turn.
- No tool-result correlation errors.

## Makefile Profile Propagation Issue

Be aware of this existing behavior:

- `PROFILE=bedrock make run` passes `MOTOKO_CONFIG=bedrock` only in the `run` recipe.
- `make run` depends on `build`, and prerequisite targets can read `MOTOKO_CONFIG` directly from the outer shell.
- This can make prerequisite checks use a different profile than the final runtime.

Preferred fix:

- Propagate `PROFILE` into prerequisite recipes, especially `verify_extensions`, or make those recipes derive the active profile from `$(PROFILE)`.

Until fixed, use:

```bash
PROFILE=bedrock MOTOKO_CONFIG=bedrock
```

for deterministic Bedrock runs.

## Secret Handling

Never print:

- `.env`
- `AWS_BEARER_TOKEN_BEDROCK`
- Authorization headers
- full LiteLLM proxy logs if they might contain request metadata

Smoke scripts should:

- Report variable presence without values.
- Avoid `set -x`.
- Redact long token-like strings from error output.
- Write detailed logs only under ignored paths such as `tmp/` or `logs/`.

Ensure these remain ignored:

- `.env`
- `.venv-litellm/`
- `tmp/`
- `logs/`
- local AILANG build artifacts such as `ailang/.bin/ailang`

## Failure Triage

`Incorrect API key provided: motoko-l********ocal`

- Installed AILANG ignored `OPENAI_BASE_URL` and called OpenAI cloud.
- Fix/install upstream AILANG or use patched `AILANG_BIN`.

`OPENROUTER_API_KEY environment variable required`

- Model alias routed incorrectly.
- Use `gpt-bedrock-smoke`.
- Do not use `openai/...` or vendor/model strings for the first smoke.

`The provided model identifier is invalid`

- Bedrock model ID or inference profile is unavailable in selected region/account.
- List foundation models and inference profiles.
- Update `scripts/bedrock-litellm.yaml`.

`Invocation ... with on-demand throughput isn't supported`

- Use an inference profile ID or ARN instead of the base model ID.

`UnrecognizedClientException`, `AccessDeniedException`, or auth failure

- Confirm LiteLLM sees `AWS_BEARER_TOKEN_BEDROCK`.
- Confirm normal AWS credential-chain variables were unset for the LiteLLM subprocess.
- Confirm the bearer token has Bedrock permissions.

Tool-result correlation errors

- Isolate to the tool-use smoke.
- Check LiteLLM's tool-call/tool-result translation to Bedrock.

## Done Criteria

- Upstream AILANG direct OpenAI fallback honors `OPENAI_BASE_URL`.
- Installed `ailang` passes the AILANG `stepWithStream` smoke without `AILANG_BIN`.
- `PROFILE=bedrock` profile works with Motoko minimal smoke.
- Tool-use smoke works.
- LiteLLM proxy startup is documented or scripted.
- Smoke targets/scripts are layered and secret-safe.
- Makefile profile propagation is fixed or clearly documented.
- Docs include bearer-token-only auth, dummy local OpenAI key, and inference-profile guidance.
- No native Bedrock provider code is introduced.
