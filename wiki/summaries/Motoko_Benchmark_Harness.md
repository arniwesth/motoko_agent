---
doc_type: short
full_text: sources/Motoko_Benchmark_Harness.md
---

This document outlines a plan to build a **Motoko Benchmark Harness** that reuses little-coder's framework to evaluate Motoko against the Aider Polyglot and Terminal‑Bench benchmarks. The core insight is that little-coder's Python harness is mostly agent‑agnostic; only the RPC layer and subprocess spawning need to change because Motoko already communicates via JSONL over stdin/stdout.

## Key Design

- **JSONL output mode** (`Phase 0`): Add a `JsonlLogger` to Motoko's TUI that emits raw `JSON.stringify(event)` lines when `MOTOKO_JSONL_OUTPUT=1` is set. Guard the ASCII banner to preserve a clean JSONL stream. The existing non‑TTY detection (`process.stdout.isTTY` false) automatically activates the headless path.
- **`MotokoRpc` Python client** (`Phase 0`): Spawns Motoko as a subprocess, passes the task via the `TASK` env var, reads structured events from stdout, and returns a `MotokoResult` with steps, thinking text, and elapsed time. Handles port allocation, process‑group cleanup, and a background reader thread.
- **Polyglot driver** (`Phase 1`): Fork `aider_polyglot.py` to use `MotokoRpc`. For retries, spawn a new Motoko process with a task that includes test failure output; note that this lacks conversation memory compared to little‑coder's in‑session retries.
- **Terminal‑Bench adapter** (`Phase 2`): A Python HTTP sidecar wraps TB's `TmuxSession` and exposes a `POST /exec` endpoint. The TypeScript env server forwards commands to this sidecar when `TB_EXEC_PROXY` is set, keeping the AILANG runtime untouched. CWD persistence is handled by the sidecar.
- **Configuration** (`Phase 3`): Step budget (`AI_MAX_STEPS`) and model are already controlled via environment variables; a `MOTOKO_BENCHMARK` var is added for tagging. Benchmark‑specific system prompts (e.g., for TB) are passed via `SYSTEM_MD`.
- **Reporting** (`Phase 4`): Consistent JSON result schema and a `status.sh` script for live pass‑rate summaries.
- **Smoke test & CI** (`Phase 5`): Pre‑flight checks and a trivial `echo hello world` end‑to‑end verify, plus a single‑exercise CI gate.

## Architecture Highlights

```
Python harness  →  spawns  →  node src/tui/dist/index.js
                     (env: TASK, MODEL, MOTOKO_JSONL_OUTPUT=1, …)
                          ├── Env server  POST /exec
                          └── AILANG core
```

Motoko's event protocol is mapped: `session_start`, `thinking`, `proposed_cmd`/`obs`, `done`/`error`, etc.

## Open Issues
- Token counting is not yet per‑step; only cumulative estimates are available. Needed for cost analysis.
- GAIA benchmark deferred; web access via `curl` may not suffice.
- Parallel runs may require rate‑limit handling (if models have concurrency quotas).
- Polyglot system prompt might need tailoring for Exercism exercises.

This harness enables direct comparison of Motoko with other coding agents on standard benchmarks, reusing existing test runners and scoring logic.

Related: [[concepts/benchmark-harness]], [[concepts/motoko-jsonl-protocol]], [[concepts/agent-subprocess-spawning]]