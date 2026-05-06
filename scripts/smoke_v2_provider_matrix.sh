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

# --- Provider → model spec ---------------------------------------------------
declare -A MODEL
MODEL[anthropic]="claude-sonnet-4-5"
MODEL[gemini]="gemini-2-5-flash"
MODEL[openai]="gpt-5"
MODEL[glm]="openrouter/z-ai/glm-5"
MODEL[minimax]="openrouter/minimax/minimax-m2.7"

# --- Provider → required env var --------------------------------------------
# Gemini is special: it has a custom availability check (ADC preferred, key
# fallback) so we leave KEY_VAR[gemini] empty and gate it via gemini_available()
# below.
declare -A KEY_VAR
KEY_VAR[anthropic]="ANTHROPIC_API_KEY"
KEY_VAR[gemini]=""
KEY_VAR[openai]="OPENAI_API_KEY"
KEY_VAR[glm]="OPENROUTER_API_KEY"
KEY_VAR[minimax]="OPENROUTER_API_KEY"

# Gemini availability:
#   - Prefer Vertex AI via ADC: `gcloud auth application-default login` +
#     GOOGLE_CLOUD_PROJECT (or GCP_PROJECT) configured
#   - Fall back to AI Studio: GOOGLE_API_KEY
gemini_available() {
  if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
    return 0  # Service account JSON path set — ADC will load it
  fi
  if [[ -f "$HOME/.config/gcloud/application_default_credentials.json" ]]; then
    return 0  # User ADC from `gcloud auth application-default login`
  fi
  if [[ -n "${GOOGLE_API_KEY:-}" ]]; then
    return 0  # AI Studio fallback
  fi
  return 1
}

gemini_auth_summary() {
  if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
    echo "ADC via GOOGLE_APPLICATION_CREDENTIALS"
  elif [[ -f "$HOME/.config/gcloud/application_default_credentials.json" ]]; then
    echo "ADC via user gcloud login"
  elif [[ -n "${GOOGLE_API_KEY:-}" ]]; then
    echo "AI Studio (GOOGLE_API_KEY fallback)"
  else
    echo "none"
  fi
}

# --- Tasks (smoke variants) -------------------------------------------------
# Each entry: <task-id>:<smoke-script>
TASKS=(
  "policy-default:scripts/smoke_v2_policy.ail"
  # The remaining 4 tasks are placeholders for the human to add — they
  # require minimal smoke variants that exercise tool-use against varied
  # prompts (e.g. write a file, read a file, run a build, ask a factual
  # question). Add them by copying smoke_v2_policy.ail and changing the
  # prompt, then list them here:
  #   "tool-write:scripts/smoke_v2_tool_write.ail"
  #   "tool-read:scripts/smoke_v2_tool_read.ail"
  #   "tool-build:scripts/smoke_v2_tool_build.ail"
  #   "factual:scripts/smoke_v2_factual.ail"
)

# --- Matrix runner -----------------------------------------------------------
declare -A RESULT
echo
echo "=== M9 v2 Provider × Task Matrix ==="
echo "Providers: $PROVIDERS"
echo "Tasks:     ${#TASKS[@]} (extend TASKS array in script for full 5x5)"
echo "Logs:      $LOG_DIR/"
echo

for provider in $PROVIDERS; do
  if [[ "$provider" == "gemini" ]]; then
    if ! gemini_available; then
      echo "skip: gemini (no ADC, no GOOGLE_API_KEY)"
      for task_entry in "${TASKS[@]}"; do
        task_id="${task_entry%%:*}"
        RESULT["$provider:$task_id"]="SKIP"
      done
      continue
    fi
    echo "info: gemini auth = $(gemini_auth_summary)"
  else
    key_var="${KEY_VAR[$provider]:-}"
    if [[ -z "${!key_var:-}" ]]; then
      echo "skip: $provider (no $key_var in env)"
      for task_entry in "${TASKS[@]}"; do
        task_id="${task_entry%%:*}"
        RESULT["$provider:$task_id"]="SKIP"
      done
      continue
    fi
  fi

  model="${MODEL[$provider]}"
  for task_entry in "${TASKS[@]}"; do
    task_id="${task_entry%%:*}"
    script="${task_entry##*:}"
    log="$LOG_DIR/${provider}-${task_id}.log"

    echo "→ ${provider} / ${task_id} (${model}) ..."
    if MOTOKO_AGENT_V2=1 ailang run \
         --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream \
         --ai "$model" \
         --net-allow-http --net-allow-localhost \
         --entry main "$script" >"$log" 2>&1; then
      if grep -q "PASS" "$log"; then
        RESULT["$provider:$task_id"]="PASS"
      else
        RESULT["$provider:$task_id"]="ERROR (no PASS in output)"
      fi
    else
      RESULT["$provider:$task_id"]="FAIL (exit non-zero)"
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
    printf "  %-25s" "${RESULT[$provider:$task_id]:--}"
  done
  echo
done

echo
echo "Per-cell logs: $LOG_DIR/"
echo
echo "Acceptance evaluation (manual):"
echo "  Claude Sonnet 4.5: 5/5 expected"
echo "  Gemini 3 Pro:      5/5 (watch for functionCall ID quirks)"
echo "  GPT-5:             5/5 expected"
echo "  GLM-5:             >=4/5 acceptable"
echo "  MiniMax M2.7:      >=4/5 acceptable"
echo
echo "If a cell fails, capture the smoking gun in the per-cell log and"
echo "open a regression issue at sunholo-data/ailang with provider-specific"
echo "label so it becomes an upstream internal/ai/<provider>/step_test.go fix."
