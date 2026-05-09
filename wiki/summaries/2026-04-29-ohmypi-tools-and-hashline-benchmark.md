---
doc_type: short
full_text: sources/2026-04-29-ohmypi-tools-and-hashline-benchmark.md
---

# OhMyPi Tool Integration and Hashline Benchmarking

## Overview

This session implemented delegated file‑tool dispatch via OhMyPi and benchmarked three Motoko edit modes—`hashline`, `replace`, `auto`—under normal and adversarial stale/drift conditions. The benchmark harness and fixes are described, and results justify defaulting to `hashline` for reliable edits.

## Delegated Tool Routing

- **Core routing** (`src/core/tool_runtime.ail`) delegates `ReadFile`, `WriteFile`, `EditFile`, and `Search` when `OHMY_PI_TOOLS=1`, routing through a new TypeScript dispatcher (`src/tui/src/ohMyPi/dispatcher.ts`) and session adapter (`src/tui/src/ohMyPi/session-adapter.ts`).
- **Runtime wiring** (`src/tui/src/runtime-process.ts`) connects the dispatcher into the TUI process.
- **Decode fixes** (`src/core/rpc.ail`) added support for parsing `ReadFileResult`, `WriteFileResult`, `EditFileResult`, and `SearchResult` from delegated responses, including edit metadata and search match entries, resolving the earlier “invalid delegated tool kind” error.

These changes fully enable [[concepts/delegated-tools]] in the agent’s file‑handling pipeline, making the OhMyPi‑backed file operations indistinguishable from local ones at the tool‑call level.

## System Prompt & Editing Guidance

`SYSTEM.md` was updated to:
- Advertise file‑tool availability when OhMyPi is active.
- Clarify that a single JSON block may contain multiple `tool_calls`.
- Provide read‑before‑edit retry guidance, especially for stale/mismatch responses.

This improves the agent’s adherence to [[concepts/file-tool-protocols]] and prepares it for consistent edit workflows.

## Bun Runtime Migration

Repository‑wide paths and scripts were converted to Bun:
- `scripts/run-agent.sh`, `scripts/install-prerequisites.sh`
- `Makefile`, `src/tui/package.json`, `README.md`, `CLAUDE.md`

This migration standardises the execution environment ([[concepts/bun-migration]]) and avoids runtime inconsistencies during benchmarks.

## Benchmark Harness

### New Files

- `scripts/benchmark-motoko-hashline.sh` – runs the matrix of baseline and adversarial `EDIT_MODE` variants (`hashline`, `replace`, `auto`) against the local Gemma endpoint (`MODEL=openai/google/gemma-4-26B-A4B-it`). Produces per‑run artifacts: `events.jsonl`, `stderr.log`, `timing.json`, `meta.json`.
- `scripts/summarize-hashline-benchmark.py` – aggregates per‑mode metrics into `summary.json` and `summary.csv`, surfaces top startup/runtime errors, and identifies winners.
- `benchmarks/hashline_tasks.tsv` – baseline task suite.
- `benchmarks/hashline_tasks_stale.tsv` – adversarial suite with deliberately stale/drift content.

A `Makefile` target `benchmark_hashline` orchestrates the entire pipeline.

### Metrics & Fixes

The summarizer initially reported all‑zero metrics due to invalid model IDs. After adding `top_errors` reporting, it clearly surfaces such failures. Two bugs were corrected:
1. Tool‑phase non‑`done` results were incorrectly counted as failures – now only genuine tool errors are counted.
2. Exit‑code coercion (`or 1`) was removed to avoid marking successful runs as failed.

With fixes, tool‑failure rates reflect actual behaviour, giving a reliable picture of [[concepts/benchmark-methodology]].

## Benchmark Results

- **Adversarial suite**: all modes achieved `success_rate=1.0`.
- **Hashline** under stale/drift pressure had the best recovery efficiency:
  - lowest `avg_tool_calls`
  - best median latency
  - tied‑best step profile
  - lowest stale‑signal rate
- **Replace** remained functional but incurred higher retries and tool‑calls, with more failure incidents in the stale suite.
- **Auto** was viable but did not consistently outperform direct `hashline`.

These findings make `hashline` the recommended default for [[concepts/adversarial-testing]] edit workflows with the current Motoko + Gemma 4 setup, while keeping `auto` available for future adaptive fallback experiments ([[concepts/hashline-editing]]).

## Conclusion

The session delivered a production‑ready delegated‑file‑tool infrastructure and a rigorous benchmark framework. The quantitative evidence supports adopting `hashline` as the primary edit mode when stale content is expected, with assurance that the agent can recover reliably.