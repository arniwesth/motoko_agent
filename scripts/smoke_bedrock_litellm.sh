#!/usr/bin/env bash
# smoke_bedrock_litellm.sh — layer 1 smoke: hit the running LiteLLM proxy
# directly (OpenAI-compatible /v1). Assumes the proxy is already up
# (`make bedrock_proxy`). Never prints the bearer token; redacts long
# token-like strings from any output.
set -euo pipefail

HOST="${BEDROCK_PROXY_HOST:-127.0.0.1}"
PORT="${BEDROCK_PROXY_PORT:-4000}"
BASE="http://$HOST:$PORT"
MODEL="${BEDROCK_SMOKE_MODEL:-gpt-bedrock-claude-sonnet-4-5}"
# Dummy local key for the no-auth proxy. Never a real OpenAI key.
DUMMY_KEY="${OPENAI_API_KEY:-motoko-litellm-local}"

# Redact "Bearer <token>" and any long token-like run before user-facing output.
redact() {
  sed -E 's/(Bearer )[A-Za-z0-9._\-]+/\1***REDACTED***/g; s/[A-Za-z0-9._\-]{40,}/***REDACTED***/g'
}

echo "smoke[litellm]: GET $BASE/v1/models"
if ! models="$(curl -sS -m 20 "$BASE/v1/models" 2>&1)"; then
  echo "smoke[litellm]: FAIL — /v1/models request failed (is the proxy running? \`make bedrock_proxy\`):" >&2
  echo "$models" | redact >&2
  exit 1
fi
if ! echo "$models" | grep -q "$MODEL"; then
  echo "smoke[litellm]: FAIL — $MODEL not present in /v1/models" >&2
  echo "$models" | redact | head -c 500 >&2; echo >&2
  exit 1
fi
echo "smoke[litellm]: ✓ $MODEL present in /v1/models"

echo "smoke[litellm]: POST $BASE/v1/chat/completions"
if ! resp="$(curl -sS -m 60 "$BASE/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $DUMMY_KEY" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Say bedrock smoke ok.\"}],\"max_tokens\":64}" 2>&1)"; then
  echo "smoke[litellm]: FAIL — chat request failed:" >&2
  echo "$resp" | redact >&2
  exit 1
fi
if echo "$resp" | grep -q '"error"'; then
  echo "smoke[litellm]: FAIL — error in chat response:" >&2
  echo "$resp" | redact | head -c 800 >&2; echo >&2
  exit 1
fi
content="$(echo "$resp" | (jq -r '.choices[0].message.content' 2>/dev/null || true))"
if [[ -z "$content" || "$content" == "null" ]]; then
  echo "smoke[litellm]: FAIL — no assistant content in response:" >&2
  echo "$resp" | redact | head -c 800 >&2; echo >&2
  exit 1
fi
echo "smoke[litellm]: ✓ assistant replied: $content"
