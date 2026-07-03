#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <output-dir>" >&2
  exit 2
fi

out_dir="$1"
rm -rf "$out_dir"
mkdir -p "$out_dir"

FULL_CAPS="Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace"

run_json_smoke() {
  local name="$1"
  local file="$2"
  local caps="$3"
  local full_loop="$4"
  local stdin_mode="$5"
  local out="$out_dir/${name}.jsonl"

  echo "check ${file}"
  ailang check "$file" >/dev/null

  echo "run ${name}"
  if [ "$stdin_mode" = "devnull" ]; then
    MOTOKO_SESSION_ID=phase-a-parity \
      ailang run --caps "$caps" --net-allow-http --net-allow-localhost --entry main "$file" </dev/null \
      | sed -E 's/"duration_ms":[0-9]+/"duration_ms":0/g; s/make\[[0-9]+\]/make[0]/g' \
      | awk '/^\{/'
  else
    MOTOKO_SESSION_ID=phase-a-parity \
      ailang run --caps "$caps" --net-allow-http --net-allow-localhost --entry main "$file" \
      | sed -E 's/"duration_ms":[0-9]+/"duration_ms":0/g; s/make\[[0-9]+\]/make[0]/g' \
      | awk '/^\{/'
  fi > "$out"

  if [ "$full_loop" = "full" ] && [ ! -s "$out" ]; then
    echo "ERROR: ${name} emitted zero JSONL events" >&2
    exit 1
  fi

  if [ "$name" = "smoke_phase_a_tool_parity" ]; then
    grep -q '"type":"v2_tool_dispatch_start"' "$out"
    grep -q '"type":"v2_tool_dispatch_complete"' "$out"
    grep -q '"type":"native_tool_results"' "$out"
  fi
}

bash scripts/setup_dp7_smoke_workdirs.sh >/dev/null

run_json_smoke smoke_v2_cost_budget_full_loop scripts/smoke_v2_cost_budget_full_loop.ail "$FULL_CAPS" full normal
run_json_smoke smoke_v2_compaction_full_loop scripts/smoke_v2_compaction_full_loop.ail "$FULL_CAPS" full normal
run_json_smoke smoke_v2_pending_full_loop scripts/smoke_v2_pending_full_loop.ail "$FULL_CAPS" full devnull
run_json_smoke smoke_v2_dp7_gate scripts/smoke_v2_dp7_gate.ail "$FULL_CAPS" full normal
run_json_smoke smoke_phase_a_tool_parity scripts/smoke_phase_a_tool_parity.ail "$FULL_CAPS" full normal
run_json_smoke smoke_v2_handle scripts/smoke_v2_handle.ail "IO,Env,Clock" unit normal
run_json_smoke smoke_v2_hybrid scripts/smoke_v2_hybrid.ail "IO,Env,Clock" unit normal

echo "check scripts/smoke_v2_compaction_tiers.ail"
ailang check scripts/smoke_v2_compaction_tiers.ail >/dev/null
echo "run smoke_v2_compaction_tiers"
ailang run --caps IO --entry main scripts/smoke_v2_compaction_tiers.ail > "$out_dir/tiers.txt"
