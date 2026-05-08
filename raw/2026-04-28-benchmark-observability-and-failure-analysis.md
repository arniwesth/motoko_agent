# 2026-04-28 - Benchmark Observability and Failure Analysis

## Context
Follow-up work on the Motoko Polyglot benchmark run (`openai/google/gemma-4-26B-A4B-it`) to improve runtime observability and make tool-failure/error analysis actionable.

## Main outcomes

### 1) Local model routing clarified and stabilized
- Confirmed `openai/google/gemma-4-26B-A4B-it` is a local OpenAI-compatible model route.
- Verified successful benchmark execution requires local endpoint override:
  - `OPENAI_BASE_URL=http://100.79.48.75:8000/v1`
- Added benchmark CLI support for explicit endpoint override:
  - `--openai-base-url` in `benchmarks/aider_polyglot.py`.

### 2) Better benchmark observability
Implemented live run introspection features:
- `benchmarks/results/polyglot_live.json`
  - run phase, current exercise, attempt, step, last event, progress, timestamps.
- `benchmarks/results/polyglot_events_<run_id>.jsonl`
  - per-event stream for full-run forensic analysis.
- Per-exercise attempt event snapshots:
  - `attempt1_events.json`, `attempt2_events.json` under `benchmarks/polyglot_logs/<lang>/<exercise>/`.
- Runner heartbeat logging:
  - `--heartbeat-secs` (default 20) with periodic progress lines.

### 3) Status view improvements (`benchmarks/status.sh`)
Added:
- live run metadata (run id, phase, updated time, current exercise details)
- runner liveness detection
- stale live-state detection with grace window (to reduce false positives)
- pace and ETA:
  - `pace: <seconds per exercise>`
  - `eta: <remaining duration> (<remaining exercises>)`

Also fixed false-positive stale warning by improving process detection and adding a 30s grace period.

### 4) Error and tool-failure analyzers
Created:
- `benchmarks/error_breakdown.py`
  - summarizes `status=error` reasons by category.
  - in this run, all errors categorized as `step_limit` (`step limit reached`).
- `benchmarks/tool_failures.py`
  - analyzes failures in `obs`, `tool_results`, `native_tool_results`.
  - deduplicates repeated delegated/native failure emissions by `(exercise, request_id, tool_call_id, exit_code)`.
  - marks likely expected probe/path-policy failures.
  - supports `--strict` mode to focus on actionable failures.

## Key run findings
From the completed run:
- Pass quality was good:
  - `pass_1: 92/140 (65.7%)`
  - `pass_2: 8/140 (5.7%)`
  - `total pass: 71.4%`
- Error rate was high:
  - `37/140 (26.4%)`, all `step limit reached`.

Tool-failure analysis (`--strict`) showed:
- Native failures are mostly expected noise (path probes / read-before-edit policy checks).
- Actionable failures cluster in delegated calls, including:
  - shell quote/syntax errors (`unexpected EOF while looking for matching quote`)
  - command/environment mismatches (`lsattr: command not found`)
  - intermittent empty-stderr nonzero exits.

## Documentation updates
Updated `benchmarks/README.md` with:
- local model run command variants
- extension-enabled benchmark variants (`CORE_EXT_ORDER=context_mode,exa_search`)
- observability commands and artifact paths
- benchmark support matrix (supported vs scaffold-only)
- analyzer commands:
  - `python benchmarks/error_breakdown.py`
  - `python benchmarks/tool_failures.py`

## Notable implementation notes
- Confirmed benchmark baseline runs currently load no Motoko extensions unless `CORE_EXT_ORDER` is set.
- Existing run process ownership constraints may prevent killing historical benchmark jobs from other sessions/users; status now reports this more clearly.
