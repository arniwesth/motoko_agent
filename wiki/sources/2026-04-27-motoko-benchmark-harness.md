# 2026-04-27 - Motoko Benchmark Harness

## Scope
Implemented `.agent/plans/Motoko_Benchmark_Harness.md` baseline across Motoko runtime hooks and a new `benchmarks/` harness tree, then added local-model compatibility and live observability improvements during integration.

## Implemented

### Runtime / TUI hooks
- Added JSONL output mode for non-TTY benchmark runs:
  - `MOTOKO_JSONL_OUTPUT=1` now emits raw `AgentEvent` JSON lines via `JsonlLogger`.
- Suppressed startup banner when JSONL mode is enabled to keep stdout parse-safe.
- Added env-server proxy execution path:
  - `TB_EXEC_PROXY=<url>` in `src/tui/src/env-server.ts` forwards `/exec` calls to an HTTP sidecar.

### Benchmark harness files
Created:
- `benchmarks/motoko_rpc.py`
- `benchmarks/aider_polyglot.py`
- `benchmarks/smoke.py`
- `benchmarks/status.sh`
- `benchmarks/tb_adapter/motoko_agent.py`
- `benchmarks/tb_adapter/shell_sidecar.py`
- `benchmarks/tb_adapter/__init__.py`
- `benchmarks/gaia_scorer.py`
- `benchmarks/prompts/tb_system.md`
- `benchmarks/prompts/polyglot_system.md`
- `benchmarks/results/.gitkeep`
- `benchmarks/harbor_adapter/motoko_agent.py` (placeholder)
- `benchmarks/harbor_adapter/__init__.py`
- `benchmarks/README.md`

### Polyglot runner behavior
- Added model preflight check before full exercise sweep.
- Added clearer `error` classification when agent fails before tool steps.
- Added local OpenAI-compatible endpoint support:
  - `--openai-base-url` CLI arg in `aider_polyglot.py`.
- Updated default benchmark root to repo-local:
  - `/workspaces/ailang_agent/polyglot-benchmark`
  - Optional override: `MOTOKO_BENCHMARK_ROOT`.

### Observability additions
- Added runner heartbeat:
  - `--heartbeat-secs` (default `20`) logs per-exercise progress line while running.
- Added live state file:
  - `benchmarks/results/polyglot_live.json`
- Added per-run event stream:
  - `benchmarks/results/polyglot_events_<run_id>.jsonl`
- Added per-attempt full event dumps:
  - `attempt1_events.json`, `attempt2_events.json` in per-exercise log dirs.
- Enhanced `benchmarks/status.sh`:
  - current exercise, attempt, step, last event
  - runner process liveness detection
  - stale-state warning with grace period
  - pace and ETA (`s/ex`, remaining duration)

### Documentation updates
- Expanded `benchmarks/README.md` with:
  - local Gemma command examples
  - extension-enabled run variants (`CORE_EXT_ORDER=context_mode,exa_search`)
  - observability usage (`watch`, live/event files)
  - support matrix (currently supported vs scaffold-only)

## Key debugging outcomes
- `steps=0` across exercises was traced to invalid model routing when `OPENAI_BASE_URL` was not applied.
- Verified local model works with endpoint override:
  - `openai/google/gemma-4-26B-A4B-it` succeeded once `OPENAI_BASE_URL=http://100.79.48.75:8000/v1` was set.
- Confirmed current benchmark baseline run uses no core extensions unless explicitly set:
  - `session_start.loaded_extensions == []`.

## Validation performed
- `cd src/tui && npm run build`
- `cd src/tui && npm test` (all suites passing at run time)
- `python -m py_compile` on benchmark Python modules
- Single-exercise live run checks with local model and status monitoring.

## Current support status
- Actively runnable:
  - Polyglot benchmark (Python descriptor)
  - Smoke test
- Present but not fully turnkey in this repo:
  - Terminal-Bench adapter integration flow
  - Harbor adapter (placeholder)
- Not yet implemented in Polyglot runner:
  - Additional language descriptors (Go/Rust/JS/Java)
