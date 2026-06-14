#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "CHECK FAILED: $1" >&2
  exit 1
}

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="$(cd "$BENCH_DIR/.." && pwd)"
REPO_ROOT="$(cd "$FIXTURE_DIR/../../.." && pwd)"
POLYGLOT_ALLOWED_MODEL="openrouter/deepseek/deepseek-v4-pro"

verify_immutable() {
  (cd "$FIXTURE_DIR" && sha256sum -c immutable.sha256 >/dev/null)
}

kill_stray_agent() {
  local exercise="$1"
  ps -eo pid=,cmd= | while read -r pid cmd; do
    case "$cmd" in
      *"$REPO_ROOT/src/tui/dist/index.js"*"$exercise"*|*"$REPO_ROOT/src/tui/dist/index.js Respond with one short line"*)
        kill "$pid" 2>/dev/null || true
        ;;
    esac
  done
}

ensure_polyglot_env() {
  : "${MOTOKO_BENCHMARK_ROOT:=/workspaces/polyglot-benchmark}"
  export MOTOKO_BENCHMARK_ROOT
  test -d "$MOTOKO_BENCHMARK_ROOT/python/exercises/practice" \
    || fail "MOTOKO_BENCHMARK_ROOT does not contain python/exercises/practice: $MOTOKO_BENCHMARK_ROOT"

  local pyenv="${POLYGLOT_PYENV:-$REPO_ROOT/.motoko/ar_polyglot_py}"
  test -x "$pyenv/bin/python3" \
    || fail "pytest venv missing at $pyenv; create it with: uv venv $pyenv && uv pip install --python $pyenv/bin/python pytest"
  "$pyenv/bin/python3" -m pytest --version >/dev/null \
    || fail "pytest is not installed in $pyenv"
  export PATH="$pyenv/bin:$PATH"

  export SYSTEM_MD="${POLYGLOT_SYSTEM_MD:-$REPO_ROOT/benchmarks/prompts/polyglot_system.md}"
  test -f "$SYSTEM_MD" || fail "SYSTEM_MD prompt missing: $SYSTEM_MD"
}

run_subset() {
  local split_file="$1"
  local label="$2"
  verify_immutable
  ensure_polyglot_env

  local scratch="${AR_BENCH_SCRATCH:-$REPO_ROOT/.motoko/ar_bench_scratch/polyglot_${label}}"
  rm -rf "$scratch"
  mkdir -p "$scratch/results"

  local model="${POLYGLOT_MODEL:-$POLYGLOT_ALLOWED_MODEL}"
  if [ "$model" != "$POLYGLOT_ALLOWED_MODEL" ]; then
    fail "POLYGLOT_MODEL must be exactly $POLYGLOT_ALLOWED_MODEL for this fixture; got: $model"
  fi
  local retry_flag=("--no-retry")
  if [ "${POLYGLOT_RETRY:-0}" = "1" ]; then
    retry_flag=()
  fi
  local ext_order="${POLYGLOT_CORE_EXT_ORDER:-context_mode,exa_search}"
  local heartbeat="${POLYGLOT_HEARTBEAT_SECS:-0}"
  local exercise_timeout="${POLYGLOT_EXERCISE_TIMEOUT_SECS:-180}"
  local started_ns
  local ended_ns
  started_ns="$(date +%s%N)"

  while IFS= read -r exercise || [ -n "$exercise" ]; do
    case "$exercise" in
      ""|\#*) continue ;;
    esac
    if ! CORE_EXT_ORDER="$ext_order" \
      timeout "${exercise_timeout}s" \
        python3 "$REPO_ROOT/benchmarks/aider_polyglot.py" \
        --language python \
        --exercise "$exercise" \
        --model "$model" \
        --results "$scratch/results/${exercise}.json" \
        --heartbeat-secs "$heartbeat" \
        --skip-preflight \
        "${retry_flag[@]}" \
        > "$scratch/results/${exercise}.stdout"; then
      kill_stray_agent "$exercise"
      if [ ! -s "$scratch/results/${exercise}.json" ]; then
        python3 - "$scratch/results/${exercise}.json" "$exercise" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
exercise = sys.argv[2]
path.write_text(json.dumps({
    "exercises": {f"python/{exercise}": {"status": "error"}},
    "meta": {"error": "exercise runner failed or timed out"},
}, sort_keys=True))
PY
      fi
    fi
  done < "$split_file"

  ended_ns="$(date +%s%N)"
  python3 - "$scratch/results" "$(( (ended_ns - started_ns) / 1000000 ))" <<'PY'
import json
import sys
from pathlib import Path

results_dir = Path(sys.argv[1])
wall_ms = int(sys.argv[2])
total = 0
passed = 0
statuses = {}

for path in sorted(results_dir.glob("*.json")):
    data = json.loads(path.read_text())
    for name, result in sorted(data.get("exercises", {}).items()):
        status = result.get("status", "error")
        statuses[name] = status
        total += 1
        if status in {"pass_1", "pass_2"}:
            passed += 1

if total == 0:
    raise SystemExit("no exercise results aggregated")

print("STATUS_JSON " + json.dumps(statuses, sort_keys=True))
print(f"METRIC pass_rate={passed / total:.6f}")
print(f"METRIC wall_ms={wall_ms}")
PY
}
