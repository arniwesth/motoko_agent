#!/usr/bin/env bash
# bedrock-proxy.sh — start a local LiteLLM proxy that fronts Amazon Bedrock
# with bearer-token-only auth, exposing an OpenAI-compatible endpoint at
# http://127.0.0.1:4000/v1 for Motoko / AILANG.
#
# Auth model (bearer-token ONLY):
#   AWS_REGION                 e.g. eu-west-1
#   AWS_BEARER_TOKEN_BEDROCK   Bedrock API key
#
# These may live in .env (gitignored) or the environment. Normal AWS
# credential-chain variables (AWS_PROFILE / AWS_ACCESS_KEY_ID /
# AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN) and ~/.aws are intentionally NOT
# used and are stripped from the LiteLLM subprocess environment.
#
# Secrets are never printed. The bearer token is only ever handed to the
# litellm subprocess. There is deliberately no `set -x` here.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

CONFIG="${BEDROCK_LITELLM_CONFIG:-scripts/bedrock-litellm.yaml}"
HOST="${BEDROCK_PROXY_HOST:-127.0.0.1}"
PORT="${BEDROCK_PROXY_PORT:-4000}"
LITELLM_BIN="${LITELLM_BIN:-.venv-litellm/bin/litellm}"

# read_env_value KEY — print KEY's value from .env without tracing it. Only
# used to backfill vars that aren't already present in the environment. Last
# matching assignment wins; supports "export KEY=val", "KEY=val", and shell-
# style surrounding quotes (KEY="val" / KEY='val') which a raw read would keep.
read_env_value() {
  local key="$1" val
  [[ -f .env ]] || return 0
  val="$(sed -nE "s/^[[:space:]]*(export[[:space:]]+)?${key}=(.*)$/\2/p" .env | tail -n1)"
  val="${val%$'\r'}"                 # strip trailing CR (CRLF files)
  val="${val%\"}"; val="${val#\"}"   # strip surrounding double quotes
  val="${val%\'}"; val="${val#\'}"   # strip surrounding single quotes
  printf '%s' "$val"
}

: "${AWS_REGION:=$(read_env_value AWS_REGION)}"
: "${AWS_BEARER_TOKEN_BEDROCK:=$(read_env_value AWS_BEARER_TOKEN_BEDROCK)}"

missing=0
if [[ -n "${AWS_REGION:-}" ]]; then
  echo "bedrock-proxy: AWS_REGION present ✓"
else
  echo "bedrock-proxy: AWS_REGION is not set (add it to .env or the environment)" >&2
  missing=1
fi
if [[ -n "${AWS_BEARER_TOKEN_BEDROCK:-}" ]]; then
  echo "bedrock-proxy: AWS_BEARER_TOKEN_BEDROCK present ✓ (value hidden)"
else
  echo "bedrock-proxy: AWS_BEARER_TOKEN_BEDROCK is not set (add it to .env or the environment)" >&2
  missing=1
fi
[[ "$missing" -eq 0 ]] || { echo "bedrock-proxy: missing required Bedrock auth — aborting" >&2; exit 1; }

if [[ ! -x "$LITELLM_BIN" ]]; then
  echo "bedrock-proxy: litellm not found at $LITELLM_BIN" >&2
  echo "  Install it once into a local venv (kept out of git via .venv-litellm/):" >&2
  echo "    python3 -m venv .venv-litellm && .venv-litellm/bin/pip install 'litellm[proxy]' boto3" >&2
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "bedrock-proxy: config not found at $CONFIG" >&2
  exit 1
fi

echo "bedrock-proxy: starting LiteLLM on http://$HOST:$PORT/v1 (config: $CONFIG)"
echo "bedrock-proxy: AWS credential-chain vars (PROFILE/ACCESS_KEY/SECRET/SESSION) stripped from subprocess"

# env -u strips the credential-chain variables so boto3 inside LiteLLM cannot
# silently fall back to them; only AWS_REGION + AWS_BEARER_TOKEN_BEDROCK pass.
exec env -u AWS_PROFILE \
        -u AWS_DEFAULT_PROFILE \
        -u AWS_ACCESS_KEY_ID \
        -u AWS_SECRET_ACCESS_KEY \
        -u AWS_SESSION_TOKEN \
     AWS_REGION="$AWS_REGION" \
     AWS_BEARER_TOKEN_BEDROCK="$AWS_BEARER_TOKEN_BEDROCK" \
     "$LITELLM_BIN" \
        --config "$CONFIG" \
        --host "$HOST" \
        --port "$PORT"
