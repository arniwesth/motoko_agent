# Session Summary — OhMyPi Tool Integration and Hashline Benchmarking

Date: 2026-04-29  
Status: Implemented and benchmarked

## Objective

Implement `.agent/plans/OhMyPi_Tool_Integration.md` in the current codebase, then benchmark Motoko end-to-end behavior across `EDIT_MODE=hashline|replace|auto`, including adversarial stale/drift scenarios.

## Major Changes

### 1) Delegated file-tool routing and execution

- Updated core routing so `ReadFile`, `WriteFile`, `EditFile`, and `Search` are delegated when `OHMY_PI_TOOLS=1`:
  - `src/core/tool_runtime.ail`
- Added TypeScript delegated dispatcher shim and session adapter:
  - `src/tui/src/ohMyPi/dispatcher.ts`
  - `src/tui/src/ohMyPi/session-adapter.ts`
- Wired dispatcher into runtime tool handling:
  - `src/tui/src/runtime-process.ts`

### 2) Critical delegated decode fixes in core runtime

Initially, delegated results for file tools were decoded as invalid kinds, producing:
- `delegated error: invalid delegated tool kind`

Fixed in:
- `src/core/rpc.ail`

Specifically:
- Added delegated decode support for:
  - `ReadFileResult`
  - `WriteFileResult`
  - `EditFileResult`
  - `SearchResult`
- Added parsing for delegated edit metadata (`applied_edits=...`).
- Added parsing of search stdout into match entries.

### 3) System prompt/tooling instructions clarification

- Clarified in `SYSTEM.md`:
  - File tool usage guidance when available.
  - One JSON block per turn may contain **multiple** `tool_calls`.
  - Read-before-edit guidance adjusted for stale/mismatch retry behavior.

### 4) Bun runtime migration updates (repo-level)

Updated scripts/docs/build paths to Bun-based execution:
- `scripts/run-agent.sh`
- `scripts/install-prerequisites.sh`
- `Makefile`
- `src/tui/package.json`
- `README.md`
- `CLAUDE.md`

## Benchmark Harness Added

### New files

- `scripts/benchmark-motoko-hashline.sh`
  - Runs benchmark matrix across modes.
  - Emits per-run artifacts (`events.jsonl`, `stderr.log`, `timing.json`, `meta.json`).
- `scripts/summarize-hashline-benchmark.py`
  - Produces `summary.json` and `summary.csv`.
  - Includes per-mode aggregates and winners.
  - Surfaces top startup/runtime errors per mode.
- `benchmarks/hashline_tasks.tsv` (baseline suite)
- `benchmarks/hashline_tasks_stale.tsv` (adversarial stale/drift suite)

### Make target

- Added:
  - `benchmark_hashline` in `Makefile`
- Defaults now target local Gemma endpoint by default:
  - `MODEL=openai/google/gemma-4-26B-A4B-it`
  - `OPENAI_BASE_URL=http://100.79.48.75:8000/v1`

## Benchmark / Analysis Fixes During Session

### A) Run-level failure attribution

Early benchmark runs showed all-zero metrics; root cause was invalid model ID at startup.  
Summarizer now reports this clearly via `top_errors` (per mode).

### B) Tool-failure metric bugs fixed

Two bugs in summarization were corrected:
1. Counting non-`done` tool result phases as failures.
2. Coercing exit code `0` to `1` via `or 1`.

After fixes, tool failure rates reflect real failures.

## Final Benchmark Results (This Session)

Compared:
- Baseline suite: `hashline_tasks.tsv`
- Adversarial suite: `hashline_tasks_stale.tsv`

Key findings:
- All modes reached `success_rate=1.0` on adversarial suite.
- Under stale/drift pressure, `hashline` had the best recovery efficiency:
  - lowest `avg_tool_calls`
  - tied best step profile
  - best median latency
  - lowest stale-signal rate
- `replace` remained functional but incurred higher retries/tool-calls and higher failure incidence in stale suite.
- `auto` remained viable, but did not consistently beat direct `hashline`.

## Practical Conclusion

For current Motoko + Gemma 4 setup:
- Defaulting to `hashline` is justified for adversarial edit workflows.
- Keep `auto` available for adaptive fallback experiments and future telemetry tuning.

## Primary Files Modified in This Session

- `src/core/rpc.ail`
- `src/core/tool_runtime.ail`
- `src/tui/src/runtime-process.ts`
- `src/tui/src/ohMyPi/dispatcher.ts` (new)
- `src/tui/src/ohMyPi/session-adapter.ts` (new)
- `SYSTEM.md`
- `scripts/benchmark-motoko-hashline.sh` (new)
- `scripts/summarize-hashline-benchmark.py` (new)
- `benchmarks/hashline_tasks.tsv` (new)
- `benchmarks/hashline_tasks_stale.tsv` (new)
- `Makefile`
- `scripts/run-agent.sh`
- `scripts/install-prerequisites.sh`
- `src/tui/package.json`
- `README.md`
- `CLAUDE.md`
