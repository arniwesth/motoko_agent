# 2026-06-21 Bedrock via LiteLLM Integration

## Context

Implemented and validated a LiteLLM-first Amazon Bedrock integration for Motoko. The architecture remains:

```text
Motoko
  -> AILANG OpenAI-compatible provider
  -> OPENAI_BASE_URL=http://127.0.0.1:4000/v1
  -> LiteLLM
  -> AWS_BEARER_TOKEN_BEDROCK + AWS_REGION
  -> Amazon Bedrock
```

The user cannot use the normal AWS credential chain. Bedrock auth must use:

```bash
AWS_REGION=...
AWS_BEARER_TOKEN_BEDROCK=...
```

Motoko/AILANG uses a dummy local OpenAI-compatible key:

```bash
OPENAI_API_KEY=motoko-litellm-local
```

## Files Added or Updated

Added:

- `.motoko/config/bedrock/config.json`
  - Model: `gpt-bedrock-smoke`
  - `openai_base_url`: `http://127.0.0.1:4000/v1`
  - Extensions disabled for baseline smoke.

- `scripts/bedrock-litellm.yaml`
  - LiteLLM alias: `gpt-bedrock-smoke`
  - Working model mapping after validation:

```yaml
model_list:
  - model_name: gpt-bedrock-smoke
    litellm_params:
      model: bedrock/eu.anthropic.claude-sonnet-4-5-20250929-v1:0
      aws_region_name: os.environ/AWS_REGION
      api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
      drop_params: true
```

- `scripts/smoke_bedrock_litellm.ail`
  - Uses `std/ai.stepWithStream`.
  - Prompts the model to return `bedrock ailang ok`.

- `.agent/plans/bedrock-integration/full-motoko-integration-plan.md`
  - Follow-up plan to turn validated smoke into durable integration.
  - Includes TL;DR, upstream AILANG blocker, smoke targets, Makefile profile propagation issue, proxy ergonomics, and done criteria.

- `.agent/plans/bedrock-integration/full-motoko-integration-handoff.md`
  - Implementation handoff prompt for the next agent.

Updated:

- `README.md`
  - Added Bedrock through LiteLLM docs and smoke commands.

- `.agent/plans/bedrock-integration/litellm-first-plan.md`
  - Added references to checked-in config/profile/smoke artifacts.
  - Added the critical upstream AILANG `OPENAI_BASE_URL` direct-route bug note.

- `.gitignore`
  - Added `.venv-litellm/`.

- `ailang/.gitignore`
  - Added `/.bin`.

- `ailang/cmd/ailang/ai_handlers.go`
  - Patched local AILANG source so the direct OpenAI provider fallback honors `OPENAI_BASE_URL`.

- `ailang/cmd/ailang/openai_local_endpoint_test.go`
  - Added regression coverage for direct `gpt-bedrock-smoke` routing to a local OpenAI-compatible endpoint.

## Validation Performed

Local non-secret checks:

```bash
jq empty .motoko/config/bedrock/config.json
ailang check scripts/smoke_bedrock_litellm.ail
MOTOKO_CONFIG=bedrock make verify_extensions
```

Targeted AILANG tests:

```bash
cd ailang
go test ./cmd/ailang -run 'TestSetupAIHandler(FromConfig_OpenAIKeyRelaxation|Direct_OpenAIUsesCustomBaseURL)|TestExecuteAPI_OpenAIKeyRelaxation'
```

LiteLLM install:

- System Python was PEP 668 managed.
- Installed `python3.12-venv` via apt.
- Created `.venv-litellm`.
- Installed `litellm[proxy]`.
- Verified LiteLLM `1.89.3`.

Bedrock/LiteLLM live validation:

- Loaded `AWS_REGION` and `AWS_BEARER_TOKEN_BEDROCK` from `.env` without printing values.
- Started LiteLLM on `127.0.0.1:4000`.
- `/v1/models` returned `gpt-bedrock-smoke`.
- Initial model ID `bedrock/anthropic.claude-3-5-sonnet-20240620-v1:0` failed with invalid model identifier.
- Listed available Bedrock foundation models and inference profiles without printing credentials.
- Base Sonnet 4.5 model ID was valid but rejected on-demand throughput.
- Switched to inference profile:

```text
bedrock/eu.anthropic.claude-sonnet-4-5-20250929-v1:0
```

- Direct LiteLLM chat completion succeeded:

```text
Bedrock smoke ok.
```

AILANG preflight:

- Installed `ailang` binary failed by calling real OpenAI with dummy key.
- Built patched local binary:

```bash
cd ailang
go build -o .bin/ailang ./cmd/ailang
```

- AILANG `stepWithStream` smoke succeeded with patched binary:

```text
bedrock ailang ok
finish_reason=stop
```

Motoko smokes:

```bash
AILANG_BIN=/workspaces/motoko_agent/ailang/.bin/ailang \
OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock \
MOTOKO_JSONL_OUTPUT=1 \
make run TASK="Reply with exactly: bedrock smoke ok"
```

Succeeded end to end through LiteLLM and Bedrock.

Tool-use smoke:

```bash
AILANG_BIN=/workspaces/motoko_agent/ailang/.bin/ailang \
OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock \
MOTOKO_JSONL_OUTPUT=1 \
make run TASK="Use bash to print the current working directory, then summarize it in one sentence."
```

Succeeded:

- Model emitted `BashExec`.
- Motoko ran `pwd`.
- Tool result was accepted in the follow-up model turn.

The temporary LiteLLM proxy was stopped after validation.

## Important Blocker

The installed upstream `ailang` binary ignores `OPENAI_BASE_URL` in the direct provider-guessing path for unresolved `gpt-*` aliases such as `gpt-bedrock-smoke`.

Symptom:

```bash
OPENAI_BASE_URL=http://127.0.0.1:4000/v1 \
OPENAI_API_KEY=motoko-litellm-local \
ailang run --caps AI,IO --ai gpt-bedrock-smoke --entry main scripts/smoke_bedrock_litellm.ail
```

Observed failure:

```text
Incorrect API key provided: motoko-l********ocal
```

That means installed AILANG called OpenAI cloud instead of LiteLLM.

Root cause:

- `setupAIHandlerDirect` guesses `ProviderOpenAI`.
- It constructs `openai.NewClient(apiKey)` without `openai.WithBaseURL(customBaseURL)`.
- The configured-model path already handles `OPENAI_BASE_URL`; the direct fallback path does not.

Local patch shape:

```go
var clientOpts []openai.ClientOption
if customBaseURL := strings.TrimSpace(os.Getenv("OPENAI_BASE_URL")); customBaseURL != "" {
	clientOpts = append(clientOpts, openai.WithBaseURL(customBaseURL))
}
client := openai.NewClient(apiKey, clientOpts...)
```

Until upstream AILANG is fixed and installed, Motoko Bedrock runs need:

```bash
AILANG_BIN=/workspaces/motoko_agent/ailang/.bin/ailang
```

## Makefile/Profile Note

During `make run`, prerequisite checks may read `MOTOKO_CONFIG` from the shell while the final run recipe sets `MOTOKO_CONFIG=$(PROFILE)`. This caused validation output where extension verification used another profile before the final runtime used `bedrock`.

Use both for deterministic Bedrock runs until this is cleaned up:

```bash
PROFILE=bedrock MOTOKO_CONFIG=bedrock
```

## Next Steps

1. Upstream the AILANG fix and regression test.
2. Install/release the fixed `ailang` binary so `AILANG_BIN` is no longer needed.
3. Add a `make bedrock_proxy` target or script that loads `.env`, sanitizes normal AWS credential-chain variables, and starts LiteLLM.
4. Add layered smoke targets:
   - `smoke_bedrock_litellm`
   - `smoke_bedrock_ailang`
   - `smoke_bedrock_motoko`
   - `smoke_bedrock_tools`
5. Fix or document Makefile profile propagation.
6. Keep Bedrock behind LiteLLM; do not introduce native Bedrock provider code in this phase.
