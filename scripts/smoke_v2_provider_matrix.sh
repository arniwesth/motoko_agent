#!/usr/bin/env bash
# scripts/smoke_v2_provider_matrix.sh
#
# M9 test matrix runner: drives v2 (MOTOKO_AGENT_V2=1) against multiple
# providers × multiple benchmark tasks and tabulates pass/fail per cell.
#
# Each cell runs an existing v2 smoke (smoke_v2_policy.ail, which is the
# only smoke that actually invokes step() against a model) with a different
# --ai model. Tasks are differentiated via the prompt the smoke uses.
#
# REQUIRES auth in env (set whichever providers you want to test):
#   ANTHROPIC_API_KEY       (Claude Sonnet 4.5)
#   Gemini 2.5 Flash:       prefer Vertex AI via ADC —
#                              `gcloud auth application-default login`
#                              + GOOGLE_CLOUD_PROJECT (or GCP_PROJECT)
#                           fallback: GOOGLE_API_KEY (AI Studio key)
#   OPENAI_API_KEY          (GPT-5)
#   OPENROUTER_API_KEY      (GLM-5, MiniMax M2.7 — both via openrouter/ prefix)
#
# Compatible with macOS stock bash 3.2 (no `declare -A`).
#
# Usage:
#   cd motoko_agent
#   scripts/smoke_v2_provider_matrix.sh                 # all providers
#   scripts/smoke_v2_provider_matrix.sh anthropic gemini # subset
#   PROVIDERS="anthropic gemini" scripts/smoke_v2_provider_matrix.sh
#
# Output: a tabulated pass/fail matrix to stdout, plus per-cell logs to
# /tmp/motoko-m9/<provider>-<task-id>.log
#
# This is NOT a fully automated benchmark — it's a structural compatibility
# probe. Each cell runs ONE prompt and checks the smoke prints "PASS" in
# its output. Acceptance criteria for the M9 milestone (e.g. "Claude
# Sonnet 4.5: 5/5 benchmark tasks pass") are evaluated by the human after
# reviewing the per-cell logs for model-specific quirks.

set -euo pipefail

PROVIDERS="${PROVIDERS:-${@:-anthropic gemini openai glm minimax}}"
LOG_DIR="${LOG_DIR:-/tmp/motoko-m9}"
mkdir -p "$LOG_DIR"

# Result map: persisted to a temp file as "<provider>:<task>=<status>" lines.
# Avoids bash-4 associative arrays so this runs on macOS stock bash 3.2.
RESULT_FILE="$(mktemp -t motoko-m9-results.XXXXXX)"
trap 'rm -f "$RESULT_FILE"' EXIT

result_set() {
  # $1=key, $2=value
  printf '%s=%s\n' "$1" "$2" >> "$RESULT_FILE"
}

result_get() {
  # $1=key — prints the LAST value for that key (so re-runs of a cell win)
  local key="$1"
  local line
  line=$(grep -E "^${key}=" "$RESULT_FILE" | tail -1 || true)
  printf '%s' "${line#*=}"
}

# --- Provider → model spec ---------------------------------------------------
# IMPORTANT: these are the API names (what the provider's HTTP endpoint
# expects), NOT the AILANG aliases from models.yml. The smoke passes the
# value directly to step() which forwards it to the wire — alias→api_name
# translation only happens in the --ai flag handler, not at step() runtime.
# So Gemini needs the dotted form; OpenRouter prefixes are stripped by
# strip_provider_prefix in agent_loop_v2.ail.
model_for() {
  case "$1" in
    anthropic) echo "claude-sonnet-4-5" ;;
    gemini)    echo "gemini-2.5-flash" ;;        # API name (dots), not alias
    openai)    echo "gpt-5" ;;
    glm)       echo "openrouter/z-ai/glm-5" ;;
    minimax)   echo "openrouter/minimax/minimax-m2.7" ;;
    *)         echo "" ;;
  esac
}

# --- Provider → --ai flag value (AILANG alias) ------------------------------
# The --ai flag accepts the AILANG-friendly alias which models.yml maps to
# the API name + provider config. Use this for the CLI flag; use model_for
# above for the actual model arg passed to step().
ai_flag_for() {
  case "$1" in
    anthropic) echo "claude-sonnet-4-5" ;;
    gemini)    echo "gemini-2-5-flash" ;;        # AILANG alias (dashes)
    openai)    echo "gpt-5" ;;
    glm)       echo "openrouter/z-ai/glm-5" ;;
    minimax)   echo "openrouter/minimax/minimax-m2.7" ;;
    *)         echo "" ;;
  esac
}

# --- Provider → required env var --------------------------------------------
# Gemini is special: it has a custom availability check (ADC preferred, key
# fallback). For all others, the cell runs iff the named env var is non-empty.
key_var_for() {
  case "$1" in
    anthropic) echo "ANTHROPIC_API_KEY" ;;
    openai)    echo "OPENAI_API_KEY" ;;
    glm)       echo "OPENROUTER_API_KEY" ;;
    minimax)   echo "OPENROUTER_API_KEY" ;;
    gemini)    echo "" ;;  # handled by gemini_available below
    *)         echo "" ;;
  esac
}

# Gemini availability:
#   - Prefer Vertex AI via ADC: `gcloud auth application-default login` +
#     GOOGLE_CLOUD_PROJECT (or GCP_PROJECT) configured
#   - Fall back to AI Studio: GOOGLE_API_KEY
gemini_available() {
  if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    return 0  # Service account JSON path set — ADC will load it
  fi
  if [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
    return 0  # User ADC from `gcloud auth application-default login`
  fi
  if [ -n "${GOOGLE_API_KEY:-}" ]; then
    return 0  # AI Studio fallback
  fi
  return 1
}

gemini_auth_summary() {
  if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    echo "ADC via GOOGLE_APPLICATION_CREDENTIALS"
  elif [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
    echo "ADC via user gcloud login"
  elif [ -n "${GOOGLE_API_KEY:-}" ]; then
    echo "AI Studio (GOOGLE_API_KEY fallback)"
  else
    echo "none"
  fi
}

# Indirect env var lookup that works on bash 3.2. (`${!var}` works on 3.2
# but not in all contexts; `eval` is the portable form.)
env_get() {
  local var="$1"
  eval "printf '%s' \"\${$var:-}\""
}

# --- Tasks (smoke variants) -------------------------------------------------
# Each entry: <task-id>:<smoke-script>
TASKS=(
  "policy-default:scripts/smoke_v2_policy.ail"
  "factual:scripts/smoke_v2_factual.ail"
  "tool-write:scripts/smoke_v2_tool_write.ail"
  "tool-read:scripts/smoke_v2_tool_read.ail"
  "tool-build:scripts/smoke_v2_tool_build.ail"
)

# --- Matrix runner -----------------------------------------------------------
echo
echo "=== M9 v2 Provider × Task Matrix ==="
echo "Providers: $PROVIDERS"
echo "Tasks:     ${#TASKS[@]} (extend TASKS array in script for full 5x5)"
echo "Logs:      $LOG_DIR/"
echo

for provider in $PROVIDERS; do
  if [ "$provider" = "gemini" ]; then
    if ! gemini_available; then
      echo "skip: gemini (no ADC, no GOOGLE_API_KEY)"
      for task_entry in "${TASKS[@]}"; do
        task_id="${task_entry%%:*}"
        result_set "$provider:$task_id" "SKIP"
      done
      continue
    fi
    echo "info: gemini auth = $(gemini_auth_summary)"
  else
    key_var=$(key_var_for "$provider")
    key_val=$(env_get "$key_var")
    if [ -z "$key_val" ]; then
      echo "skip: $provider (no $key_var in env)"
      for task_entry in "${TASKS[@]}"; do
        task_id="${task_entry%%:*}"
        result_set "$provider:$task_id" "SKIP"
      done
      continue
    fi
  fi

  model=$(model_for "$provider")
  for task_entry in "${TASKS[@]}"; do
    task_id="${task_entry%%:*}"
    script="${task_entry##*:}"
    log="$LOG_DIR/${provider}-${task_id}.log"

    echo "→ ${provider} / ${task_id} (${model}) ..."
    # AILANG_SMOKE_MODEL is read by the smoke script's run_v2 model_arg so
    # the same smoke binary can drive different providers per cell. The
    # --ai flag separately configures the AI handler/auth that step()
    # routes through.
    ai_flag=$(ai_flag_for "$provider")
    if MOTOKO_AGENT_V2=1 AILANG_SMOKE_MODEL="$model" ailang run \
         --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream \
         --ai "$ai_flag" \
         --net-allow-http --net-allow-localhost \
         --entry main "$script" >"$log" 2>&1; then
      if grep -q "PASS" "$log"; then
        result_set "$provider:$task_id" "PASS"
      else
        result_set "$provider:$task_id" "ERROR (no PASS in output)"
      fi
    else
      result_set "$provider:$task_id" "FAIL (exit non-zero)"
    fi
  done
done

# --- Print matrix ------------------------------------------------------------
echo
echo "=== Results ==="
printf "%-15s" "provider"
for task_entry in "${TASKS[@]}"; do
  printf "  %-25s" "${task_entry%%:*}"
done
echo
for provider in $PROVIDERS; do
  printf "%-15s" "$provider"
  for task_entry in "${TASKS[@]}"; do
    task_id="${task_entry%%:*}"
    cell=$(result_get "$provider:$task_id")
    if [ -z "$cell" ]; then cell="-"; fi
    printf "  %-25s" "$cell"
  done
  echo
done

echo
echo "Per-cell logs: $LOG_DIR/"
echo
echo "Acceptance evaluation (manual):"
echo "  Claude Sonnet 4.5: 5/5 expected"
echo "  Gemini 2.5 Flash:  5/5 (watch for functionCall ID quirks)"
echo "  GPT-5:             5/5 expected"
echo "  GLM-5:             >=4/5 acceptable"
echo "  MiniMax M2.7:      >=4/5 acceptable"
echo
echo "If a cell fails, capture the smoking gun in the per-cell log and"
echo "open a regression issue at sunholo-data/ailang with provider-specific"
echo "label so it becomes an upstream internal/ai/<provider>/step_test.go fix."
