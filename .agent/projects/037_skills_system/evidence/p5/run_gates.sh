#!/usr/bin/env bash
# 037 P5 evidence: the gates of ADR-001 A7, one at a time, as P0 and P2 ran
# them (`make <gate>` from the worktree root), with the credential variables
# removed from the environment. One log per gate under <out dir>, ending in
# `exit=<code>`; HEAD.txt is the commit.
#
#   bash run_gates.sh <out dir> [gate ...]
set -u
OUT=${1:?out dir}; shift
ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1
mkdir -p "$OUT"
git rev-parse HEAD > "$OUT/HEAD.txt"
GATES=("$@")
[ ${#GATES[@]} -gt 0 ] || GATES=(check_core profile_definition driver_only profile_coverage conformance
  ext_call_inventory ext_call_inventory_selftest test_coverage registry_gen_check registry_multiplicity
  ext_hook_scope ext_ambient_inventory declared_vs_performed driver_plus_no_ops driver_plus_compose
  driver_plus_herdr new_contract_policy verify_skills_refusal)
for g in "${GATES[@]}"; do
  start=$(date +%s)
  env -u ANTHROPIC_API_KEY -u AWS_BEARER_TOKEN_BEDROCK -u CLAUDE_CODE_MESSAGING_TOKEN -u EXA_API_KEY \
      -u GH_TOKEN -u GOOGLE_API_KEY -u LINEAR_API_KEY -u MOTOKO_BOT_GH_TOKEN -u OBSIDIAN_MCP_TOKEN \
      -u OPENAI_API_KEY -u OPENROUTER_API_KEY \
      make "$g" > "$OUT/$g.log" 2>&1 < /dev/null
  rc=$?
  echo "exit=$rc" >> "$OUT/$g.log"
  printf '%-30s exit=%s  %ss\n' "$g" "$rc" "$(( $(date +%s) - start ))"
done
