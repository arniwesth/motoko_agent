# Bedrock Integration Plan: LiteLLM First

**Goal:** Verify Motoko can run against Amazon Bedrock-hosted models by placing LiteLLM in front of Bedrock and using Motoko's existing OpenAI-compatible endpoint support.

**Non-goal:** Do not implement a native AILANG Bedrock provider in this phase. Native Bedrock support needs AWS SigV4 signing, Bedrock request/response mapping, streaming translation, tool-use translation, and launcher environment forwarding. This plan is for fast end-to-end validation first.

## Current Findings

- Local `ailang/` has no native `bedrock` provider under `ailang/internal/ai/`.
- AILANG built-in providers are `openai`, `anthropic`, `gemini`, `ollama`, and `openrouter`, plus config-driven HTTP providers.
- Config-driven `[[ai_provider]]` supports simple auth shapes, but not AWS SigV4.
- Motoko already supports OpenAI-compatible endpoints through `OPENAI_BASE_URL`.
- LiteLLM can expose Bedrock through OpenAI-compatible `/v1/chat/completions`.

## Proposed Architecture

```text
Motoko
  -> AILANG OpenAI-compatible client
  -> OPENAI_BASE_URL=http://127.0.0.1:4000/v1
  -> LiteLLM proxy
  -> boto3 / AWS credential chain
  -> Amazon Bedrock Runtime
```

Motoko should see a normal OpenAI-compatible model alias. LiteLLM handles AWS credentials, Bedrock model IDs, request translation, and response translation.

## Required Inputs

- AWS account with Bedrock model access enabled in the selected region.
- AWS credentials available to the LiteLLM process through one of:
  - `AWS_PROFILE`
  - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
  - mounted `~/.aws`
  - another boto3-supported credential source
- AWS region, for example `us-east-1` or `us-west-2`.
- Bedrock model ID to test, for example an Anthropic Claude model available in the account.
- Python environment capable of installing/running LiteLLM and `boto3`.

## Model Alias Strategy

Use a local alias that routes through AILANG's OpenAI provider inference cleanly.

Recommended alias:

```text
gpt-bedrock-smoke
```

Avoid `openai/<model>` for the initial smoke. In current AILANG routing, `openai/...` can be interpreted as an OpenRouter-style vendor/model string in direct provider guessing paths. A plain `gpt-*` alias routes as OpenAI.

## Phase 1: Manual LiteLLM Smoke

Start LiteLLM outside Motoko with one Bedrock model alias.

Example LiteLLM config:

```yaml
model_list:
  - model_name: gpt-bedrock-smoke
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20240620-v1:0
      aws_region_name: us-east-1
      drop_params: true
```

Run proxy:

```bash
litellm --config /path/to/bedrock-litellm.yaml --host 127.0.0.1 --port 4000
```

Validate proxy directly:

```bash
curl http://127.0.0.1:4000/v1/models
```

Then test chat completions directly:

```bash
curl http://127.0.0.1:4000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer anything' \
  -d '{
    "model": "gpt-bedrock-smoke",
    "messages": [{"role": "user", "content": "Say bedrock smoke ok."}],
    "max_tokens": 64
  }'
```

Acceptance criteria:

- `/v1/models` returns the alias.
- `/v1/chat/completions` returns a valid OpenAI-shaped response.
- No AWS auth, model access, or region errors.

## Phase 2: Motoko Profile Smoke

Create or use a dedicated Motoko profile with:

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

Keep extensions off for the first smoke. This isolates provider compatibility from extension tool schemas and Bedrock strictness around tool names/tool results.

Run a minimal task:

```bash
PROFILE=bedrock make run TASK="Reply with exactly: bedrock smoke ok"
```

Acceptance criteria:

- Motoko starts normally.
- AILANG sends requests to LiteLLM, not OpenAI or OpenRouter.
- The task completes without provider/auth errors.
- Session log shows the selected model and successful termination.

## Phase 3: Native Tool-Use Smoke

Run a task that forces one simple tool call.

Suggested task:

```text
Use bash to print the current working directory, then summarize it in one sentence.
```

Acceptance criteria:

- Model emits a valid tool call.
- Motoko dispatches the tool.
- Tool result is accepted on the follow-up model turn.
- No Bedrock/LiteLLM rejection for tool-call schema or tool-result correlation.

## Phase 4: Extension Compatibility Smoke

Re-enable extensions one group at a time:

1. `context_mode`
2. `exa_search`
3. `omnigraph`
4. `compaction_ai`
5. `compose`

For each group:

```bash
PROFILE=bedrock make run TASK="Perform a one-step smoke test and stop."
```

Acceptance criteria:

- Advertised tool names are accepted.
- Tool schemas are accepted.
- Extension startup does not panic.
- Tool calls, if emitted, round-trip through LiteLLM and Bedrock.

Known risk:

- Bedrock-backed Anthropic models are strict about tool names and tool-result correlation. AILANG and packages have prior compatibility fixes, but extension-by-extension validation is still needed.

## Phase 5: Observability and Debugging

Enable raw wire logging only when needed.

Useful checks:

- LiteLLM proxy logs for provider request/response errors.
- Motoko `.motoko/logfile/*.jsonl` session output.
- AILANG HTTP wire logging if available through `AILANG_AI_HTTP_LOG`.
- Confirm no fallback to OpenRouter by checking outbound URL/logs.

Common failure modes:

- `AccessDeniedException`: IAM policy or Bedrock model access missing.
- `ValidationException`: unsupported model/API shape or invalid tool schema.
- `ThrottlingException`: account or model quota too low.
- `ResourceNotFoundException`: model ID not available in selected region.
- OpenAI-style `400`: LiteLLM dropped/translated a parameter incorrectly, or model does not support the requested feature.

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
