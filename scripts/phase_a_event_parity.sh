#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <output-dir>" >&2
  exit 2
fi

out_dir="$1"
rm -rf "$out_dir"
mkdir -p "$out_dir"
new_dir="${out_dir}.new"
rm -rf "$new_dir"
if [ -n "${PARITY_STRIP_TYPES:-}" ]; then
  mkdir -p "$new_dir"
fi

FULL_CAPS="Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace"

filter_new_types() {
  local name="$1"
  local new_out="$new_dir/${name}.jsonl"
  if [ -z "${PARITY_STRIP_TYPES:-}" ]; then
    cat
  else
    awk -v allow="${PARITY_STRIP_TYPES}" -v new_out="$new_out" '
      BEGIN {
        n = split(allow, raw, ",");
        for (i = 1; i <= n; i++) {
          gsub(/^[ \t]+|[ \t]+$/, "", raw[i]);
          if (raw[i] != "") allowed[raw[i]] = 1;
        }
      }
      {
        if (match($0, /"type":"[^"]+"/)) {
          typ = substr($0, RSTART + 8, RLENGTH - 9);
          if (typ in allowed) {
            print $0 >> new_out;
            next;
          }
        }
        print $0;
      }
    '
  fi
}

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
      | awk '/^\{/' \
      | filter_new_types "$name"
  else
    MOTOKO_SESSION_ID=phase-a-parity \
      ailang run --caps "$caps" --net-allow-http --net-allow-localhost --entry main "$file" \
      | sed -E 's/"duration_ms":[0-9]+/"duration_ms":0/g; s/make\[[0-9]+\]/make[0]/g' \
      | awk '/^\{/' \
      | filter_new_types "$name"
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

  if [ "$name" = "smoke_v2_ext_fixture_parity" ]; then
    grep -q '"type":"ext_tool_handled"' "$out"
    grep -q '"type":"ext_solver_feedback"' "$out"
    grep -q '"type":"ext_intercept_handled"' "$out"
    grep -q '"type":"compaction_extension".*"note":"fixture_prestep sys=1"' "$out"
  fi

  if [ "$name" = "smoke_v2_stream_parity" ]; then
    awk '
      /"type":"thinking_stream_start"/ { if (state != 0) exit 1; state = 1; next }
      /"type":"thinking_delta"/ {
        if (state == 1 && $0 ~ /"text_delta":"chunk-a"/) { state = 2; next }
        if (state == 2 && $0 ~ /"text_delta":"chunk-b"/) { state = 3; next }
        if (state == 3 && $0 ~ /"text_delta":"chunk-c"/) { state = 4; next }
        exit 1
      }
      /"type":"thinking_stream_end"/ {
        if (state == 4 && $0 ~ /"status":"completed"/) { state = 5; next }
        exit 1
      }
      /"type":"thinking"/ {
        if (state == 5) { state = 6; next }
      }
      END { exit(state == 6 ? 0 : 1) }
    ' "$out"
  fi
}

bash scripts/setup_dp7_smoke_workdirs.sh >/dev/null

run_json_smoke smoke_v2_cost_budget_full_loop scripts/smoke_v2_cost_budget_full_loop.ail "$FULL_CAPS" full normal
run_json_smoke smoke_v2_compaction_full_loop scripts/smoke_v2_compaction_full_loop.ail "$FULL_CAPS" full normal
run_json_smoke smoke_v2_pending_full_loop scripts/smoke_v2_pending_full_loop.ail "$FULL_CAPS" full devnull
run_json_smoke smoke_v2_dp7_gate scripts/smoke_v2_dp7_gate.ail "$FULL_CAPS" full normal
run_json_smoke smoke_phase_a_tool_parity scripts/smoke_phase_a_tool_parity.ail "$FULL_CAPS" full normal
run_json_smoke smoke_v2_ext_fixture_parity scripts/smoke_v2_ext_fixture_parity.ail "$FULL_CAPS" full normal
run_json_smoke smoke_v2_stream_parity scripts/smoke_v2_stream_parity.ail "$FULL_CAPS" full normal
run_json_smoke smoke_v2_handle scripts/smoke_v2_handle.ail "IO,Env,Clock" unit normal
run_json_smoke smoke_v2_hybrid scripts/smoke_v2_hybrid.ail "IO,Env,Clock" unit normal

echo "check scripts/smoke_v2_compaction_tiers.ail"
ailang check scripts/smoke_v2_compaction_tiers.ail >/dev/null
echo "run smoke_v2_compaction_tiers"
ailang run --caps IO --entry main scripts/smoke_v2_compaction_tiers.ail > "$out_dir/tiers.txt"
