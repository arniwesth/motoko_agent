# Implementation Handoff: Motoko + Bedrock via LiteLLM

You are implementing the LiteLLM-first Bedrock integration for Motoko.

Start by reading:

- `.agent/plans/bedrock-integration/litellm-first-plan.md`
- `README.md`
- `src/tui/src/runtime-process.ts`
- `src/tui/src/config.ts`
- `src/tui/src/models.ts`
- `ailang/cmd/ailang/ai_handlers.go`
- `ailang/internal/ai/config.go`
- `ailang/internal/ai/openai/client.go`
- `ailang/internal/ai/openai/step.go`

## Core Constraint

The user cannot use the normal AWS credential chain. Do not rely on:

- `AWS_PROFILE`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- mounted `~/.aws`

The Bedrock side must use:

```bash
AWS_BEARER_TOKEN_BEDROCK=...
AWS_REGION=...
```

LiteLLM supports this by using:

```yaml
api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
aws_region_name: os.environ/AWS_REGION
```

## Architecture To Preserve

Motoko should not call Bedrock directly in this phase.

```text
Motoko
  -> AILANG OpenAI-compatible provider
  -> OPENAI_BASE_URL=http://127.0.0.1:4000/v1
  -> LiteLLM
  -> AWS_BEARER_TOKEN_BEDROCK + AWS_REGION
  -> Amazon Bedrock
```

Motoko/AILANG needs an `OPENAI_API_KEY` value because the direct OpenAI provider guard requires it. For a no-auth local LiteLLM proxy, use a dummy value:

```bash
OPENAI_API_KEY=motoko-litellm-local
```

Do not pass a real OpenAI key to LiteLLM unless the proxy is intentionally configured to require it as its own master key.

## Model Alias

Use:

```text
gpt-bedrock-smoke
```

Do not use `openai/...`; AILANG can treat vendor/model strings as OpenRouter routes.

Do not use aliases starting with `gpt-5`, `o1`, `o3`, or `codex` for the first smoke; those trigger the OpenAI Responses API path. `gpt-bedrock-smoke` should use Chat Completions.

## Implementation Scope

Prefer the smallest useful implementation:

1. Add or finalize a complete Motoko `bedrock` profile that points at LiteLLM.
2. Add a LiteLLM config/template or helper script only if useful and explicitly bearer-token based.
3. Add docs/runbook notes for the exact env vars and smoke sequence.
4. Do not modify native AILANG provider code unless the AILANG preflight proves the current path cannot work.

If files already exist from earlier partial work, inspect them before editing. Keep or revise them; do not blindly recreate.

## Required LiteLLM Config Shape

Use this shape as the baseline:

```yaml
model_list:
  - model_name: gpt-bedrock-smoke
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20240620-v1:0
      aws_region_name: os.environ/AWS_REGION
      api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
      drop_params: true
```

The Bedrock model ID may need to be changed to one available in the user's AWS account and region.

## Validation Sequence

Do not start with Motoko. Validate layer by layer.

1. **LiteLLM direct**

   ```bash
   export AWS_REGION=us-east-1
   export AWS_BEARER_TOKEN_BEDROCK=...
   litellm --config /path/to/bedrock-litellm.yaml --host 127.0.0.1 --port 4000
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

2. **AILANG preflight**

   Create a temporary or scripted smoke using `std/ai.stepWithStream`, not just `std/ai.call`, because Motoko uses the step/stream path.

   Run with:

   ```bash
   OPENAI_BASE_URL=http://127.0.0.1:4000/v1 \
   OPENAI_API_KEY=motoko-litellm-local \
   ailang run --caps AI,IO --ai gpt-bedrock-smoke --entry main <smoke-file>.ail
   ```

3. **Motoko minimal profile**

   ```bash
   OPENAI_API_KEY=motoko-litellm-local \
   PROFILE=bedrock \
   make run TASK="Reply with exactly: bedrock smoke ok"
   ```

4. **Tool-use smoke**

   ```bash
   OPENAI_API_KEY=motoko-litellm-local \
   PROFILE=bedrock \
   make run TASK="Use bash to print the current working directory, then summarize it in one sentence."
   ```

## Failure Triage

- `OPENAI_API_KEY environment variable required`: AILANG guard fired before proxy dispatch. Set dummy `OPENAI_API_KEY` or confirm profile env forwarding.
- `OPENROUTER_API_KEY environment variable required`: model alias routed incorrectly. Use `gpt-bedrock-smoke`.
- Bedrock auth failure: confirm LiteLLM sees `AWS_BEARER_TOKEN_BEDROCK`, not AWS profile credentials.
- `ResourceNotFoundException`: model ID unavailable in selected region/account.
- `ValidationException`: request shape, model capability, or tool schema issue.
- Tool-result correlation errors: isolate to the native tool-use smoke.

## Done Criteria

- The plan/runbook reflects bearer-token-only Bedrock auth.
- LiteLLM direct smoke succeeds or has a precise documented blocker.
- AILANG `stepWithStream` preflight succeeds or has a precise documented blocker.
- Motoko minimal smoke succeeds or has a precise documented blocker.
- No native Bedrock provider code is introduced unless the proxy path is proven impossible.
