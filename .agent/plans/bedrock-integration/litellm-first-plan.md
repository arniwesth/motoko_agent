# Bedrock Integration Plan: LiteLLM First

**Goal:** Verify Motoko can run against Amazon Bedrock-hosted models by placing LiteLLM in front of Bedrock and using Motoko's existing OpenAI-compatible endpoint support.

**Non-goal:** Do not implement a native AILANG Bedrock provider in this phase. Native Bedrock support needs AWS SigV4 signing, Bedrock request/response mapping, streaming translation, tool-use translation, and launcher environment forwarding. This plan is for fast end-to-end validation first.

## Current Findings

- Local `ailang/` has no native `bedrock` provider under `ailang/internal/ai/`.
- AILANG built-in providers are `openai`, `anthropic`, `gemini`, `ollama`, and `openrouter`, plus config-driven HTTP providers.
- Config-driven `[[ai_provider]]` supports simple auth shapes, but not AWS SigV4.
- Motoko already supports OpenAI-compatible endpoints through `OPENAI_BASE_URL`.
- LiteLLM can expose Bedrock through OpenAI-compatible `/v1/chat/completions`.
- LiteLLM supports Amazon Bedrock API-key authentication through `AWS_BEARER_TOKEN_BEDROCK` or `api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK` in `config.yaml`. This plan assumes bearer-token auth only; normal AWS credential-chain auth is out of scope.
- Motoko launches AILANG with `--ai <model>`. If the model is not found in AILANG's `models.yml`, AILANG uses direct provider guessing. For a `gpt-*` alias, this routes to the OpenAI provider.
- In the direct OpenAI provider path, AILANG still requires `OPENAI_API_KEY` even when `OPENAI_BASE_URL` points at a local proxy. For the LiteLLM smoke, set `OPENAI_API_KEY` to a dummy non-secret value unless the proxy is configured with a real LiteLLM master key.
- **Important upstream AILANG fix required:** the installed upstream `ailang` binary can still ignore `OPENAI_BASE_URL` in the direct provider-guessing path for unresolved `gpt-*` aliases such as `gpt-bedrock-smoke`. Symptom: `OPENAI_BASE_URL=http://127.0.0.1:4000/v1 OPENAI_API_KEY=motoko-litellm-local ailang run --ai gpt-bedrock-smoke ...` calls the real OpenAI API and fails with `Incorrect API key provided: motoko-l********ocal` instead of reaching LiteLLM. Root cause: `setupAIHandlerDirect` guesses `ProviderOpenAI` but constructs `openai.NewClient(apiKey)` without passing `openai.WithBaseURL(os.Getenv("OPENAI_BASE_URL"))`. The configured-model path already handles this; the direct fallback path must be fixed upstream. Local workaround used during validation: build the patched local AILANG source and run Motoko with `AILANG_BIN=/workspaces/motoko_agent/ailang/.bin/ailang`.

Required upstream patch shape:

```go
var clientOpts []openai.ClientOption
if customBaseURL := strings.TrimSpace(os.Getenv("OPENAI_BASE_URL")); customBaseURL != "" {
	clientOpts = append(clientOpts, openai.WithBaseURL(customBaseURL))
}
client := openai.NewClient(apiKey, clientOpts...)
```

## Proposed Architecture

```text
Motoko
  -> AILANG OpenAI-compatible client
  -> OPENAI_BASE_URL=http://127.0.0.1:4000/v1
  -> LiteLLM proxy
  -> AWS_BEARER_TOKEN_BEDROCK + AWS_REGION
  -> Amazon Bedrock Runtime
```

Motoko should see a normal OpenAI-compatible model alias. LiteLLM handles AWS credentials, Bedrock model IDs, request translation, and response translation.

## Required Inputs

- AWS account with Bedrock model access enabled in the selected region.
- `AWS_BEARER_TOKEN_BEDROCK` available to the LiteLLM process.
- `AWS_REGION` or `AWS_REGION_NAME`, for example `us-east-1` or `us-west-2`.
- Bedrock model ID to test, for example an Anthropic Claude model available in the account.
- Python environment capable of installing/running LiteLLM and `boto3`.
- A local proxy API key policy:
  - no-auth LiteLLM: use `OPENAI_API_KEY=motoko-litellm-local` only to satisfy AILANG's direct OpenAI key guard
  - LiteLLM with `master_key`: set `OPENAI_API_KEY` to that LiteLLM key

Do not forward a real OpenAI API key to the local proxy during this test. It is unnecessary and may be logged by the proxy.

Do not rely on `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, or `~/.aws` for this plan. If `AWS_BEARER_TOKEN_BEDROCK` is absent, the LiteLLM-first plan is not ready to run.

## Model Alias Strategy

Use a local alias that routes through AILANG's OpenAI provider inference cleanly.

Recommended alias:

```text
gpt-bedrock-smoke
```

Avoid `openai/<model>` for the initial smoke. In current AILANG routing, `openai/...` can be interpreted as an OpenRouter-style vendor/model string in direct provider guessing paths. A plain `gpt-*` alias routes as OpenAI.

Avoid aliases starting with `gpt-5`, `o1`, `o3`, or `codex` for the first smoke. AILANG routes those through its OpenAI Responses API path. `gpt-bedrock-smoke` should use Chat Completions.

## Phase 1: Manual LiteLLM Smoke

Start LiteLLM outside Motoko with one Bedrock model alias.

Example LiteLLM config:

```yaml
model_list:
  - model_name: gpt-bedrock-smoke
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20240620-v1:0
      aws_region_name: os.environ/AWS_REGION
      api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
      drop_params: true
```

Checked-in template:

```bash
scripts/bedrock-litellm.yaml
```

Run proxy:

```bash
export AWS_REGION=us-east-1
export AWS_BEARER_TOKEN_BEDROCK=...
litellm --config scripts/bedrock-litellm.yaml --host 127.0.0.1 --port 4000
```

Validate proxy directly:

```bash
curl -sS http://127.0.0.1:4000/v1/models
```

Then test chat completions directly:

```bash
curl http://127.0.0.1:4000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer motoko-litellm-local' \
  -d '{
    "model": "gpt-bedrock-smoke",
    "messages": [{"role": "user", "content": "Say bedrock smoke ok."}],
    "max_tokens": 64
  }'
```

Acceptance criteria:

- `/v1/models` returns the alias.
- `/v1/chat/completions` returns a valid OpenAI-shaped response.
- No Bedrock bearer-token auth, model access, or region errors.

## Phase 2: AILANG Provider Preflight

Before involving Motoko, verify AILANG's actual `--ai` path can talk to the proxy and can exercise the same `stepWithStream` primitive family Motoko uses.

Create a temporary smoke file:

```ailang
module tmp/bedrock_litellm_smoke

import std/ai (stepWithStream, Message, StreamChunk, ContentDelta, ThinkingDelta, Usage)
import std/io (print, println)

func render(chunk: StreamChunk) -> () ! {IO} {
  match chunk {
    ContentDelta(text) => print(text),
    ThinkingDelta(_) => (),
    Usage(_) => println("")
  }
}

export func main() -> () ! {AI, IO} {
  let messages: [Message] = [{
    role: "user",
    content: "Reply with exactly: bedrock ailang ok",
    tool_calls: [],
    tool_call_id: ""
  }];
  match stepWithStream("gpt-bedrock-smoke", messages, [], [], render) {
    Ok(result) => {
      println("");
      println("finish_reason=${result.finish_reason}")
    },
    Err(e) => {
      println("ERR ${e.code}: ${e.message}")
    }
  }
}
```

Checked-in smoke file:

```bash
scripts/smoke_bedrock_litellm.ail
```

Run:

```bash
OPENAI_BASE_URL=http://127.0.0.1:4000/v1 \
OPENAI_API_KEY=motoko-litellm-local \
ailang run --caps AI,IO --ai gpt-bedrock-smoke --entry main scripts/smoke_bedrock_litellm.ail
```

Acceptance criteria:

- AILANG selects the OpenAI provider, not OpenRouter.
- The request reaches LiteLLM.
- Streaming or synthetic streaming completes and prints a response.
- No `OPENAI_API_KEY environment variable required` error.
- No provider error from OpenAI `stream_options`, `tools`, message format, or Chat Completions shape.

If this fails before reaching LiteLLM, fix AILANG routing/config before attempting Motoko.

## Phase 3: Motoko Profile Smoke

Create or use a dedicated Motoko profile. The snippet below shows the important fields; in practice copy an existing complete profile and only change the Bedrock-specific fields.

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

Checked-in profile:

```bash
.motoko/config/bedrock/config.json
```

Keep extensions off for the first smoke. This isolates provider compatibility from extension tool schemas and Bedrock strictness around tool names/tool results.

Run a minimal task:

```bash
OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock \
make run TASK="Reply with exactly: bedrock smoke ok"
```

Acceptance criteria:

- Motoko starts normally.
- AILANG sends requests to LiteLLM, not OpenAI or OpenRouter.
- The task completes without provider/auth errors.
- Session log shows the selected model and successful termination.

## Phase 4: Native Tool-Use Smoke

Run a task that forces one simple tool call.

Suggested task:

```bash
OPENAI_API_KEY=motoko-litellm-local \
PROFILE=bedrock \
make run TASK="Use bash to print the current working directory, then summarize it in one sentence."
```

Acceptance criteria:

- Model emits a valid tool call.
- Motoko dispatches the tool.
- Tool result is accepted on the follow-up model turn.
- No Bedrock/LiteLLM rejection for tool-call schema or tool-result correlation.

## Phase 5: Observability and Debugging

Enable raw wire logging only when needed.

Useful checks:

- LiteLLM proxy logs for provider request/response errors.
- Motoko `.motoko/logfile/*.jsonl` session output.
- AILANG HTTP wire logging if available through `AILANG_AI_HTTP_LOG`.
- Confirm no fallback to OpenRouter by checking outbound URL/logs.
- Confirm the local proxy does not log a real OpenAI API key. Use a dummy key for no-auth LiteLLM.

Common failure modes:

- `AccessDeniedException`: bearer token lacks access to the selected Bedrock model or action.
- `UnrecognizedClientException` / auth failure: `AWS_BEARER_TOKEN_BEDROCK` is missing, expired, malformed, or not being read by LiteLLM.
- `ValidationException`: unsupported model/API shape or invalid tool schema.
- `ThrottlingException`: account or model quota too low.
- `ResourceNotFoundException`: model ID not available in selected region.
- OpenAI-style `400`: LiteLLM dropped/translated a parameter incorrectly, or model does not support the requested feature.
- `OPENAI_API_KEY environment variable required`: AILANG's direct OpenAI provider guard fired before proxy dispatch. Set a dummy local key or use a configured models.yml path that relaxes the key guard.
- `OPENROUTER_API_KEY environment variable required`: the model alias routed incorrectly. Use `gpt-bedrock-smoke`, not `openai/...` or a known OpenRouter vendor prefix.

## Phase 6: Decide Next Step

If LiteLLM smoke passes:

- Keep LiteLLM profile as the recommended Bedrock path for Motoko users.
- Add a documented setup guide.
- Add a repeatable smoke script, but keep AWS credentials outside Motoko.

If LiteLLM smoke fails due to adapter limitations:

- Try Bedrock Access Gateway as the next OpenAI-compatible adapter.
- Capture exact request and response errors before changing Motoko.

If Motoko needs direct Bedrock support:

- Design native AILANG provider:
  - provider key: `bedrock`
  - AWS credential resolution and SigV4 signing
  - Converse/ConverseStream or Messages API mapping
  - OpenAI/Anthropic tool schema conversion
  - usage/cost extraction
  - streaming event translation
  - child environment forwarding for `AWS_*`

## Rollback

This plan should initially add documentation and a profile only. No core runtime behavior should change until the manual smoke establishes that the LiteLLM path is worth formalizing.

If any profile or helper script causes confusion, remove the Bedrock-specific profile and keep only this plan.
