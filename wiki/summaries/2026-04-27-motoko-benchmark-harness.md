---
doc_type: short
full_text: sources/2026-04-27-motoko-benchmark-harness.md
---

# Summary: Motoko Benchmark Harness

Implementation of a comprehensive benchmark harness for the Motoko AI coding agent, covering runtime hooks, runner scripts, and live observability. Key contributions include:
- **JSONL output mode** (`MOTOKO_JSONL_OUTPUT=1`) for non-TTY runs, emitting raw agent events via [[concepts/jsonl-output]].
- **Proxy execution** support through `TB_EXEC_PROXY` enabling sidecar command forwarding. ([[concepts/proxy-execution]])
- **Benchmark suite** with Python-based runners for polyglot exercises (`motoko_rpc.py`, `aider_polyglot.py`, `smoke.py`) and adapter modules for terminal-bench and harbor. ([[concepts/benchmark-harness]])
- **Polyglot runner** enhanced with model preflight checks, error classification, local OpenAI-compatible endpoints via `--openai-base-url`, and automatic benchmark root detection. ([[concepts/local-model-compatibility]])
- **Observability** features: heartbeat logging, live state file (`polyglot_live.json`), per-run event streams, full attempt dumps, and a status shell script with ETA and liveness detection. ([[concepts/observability-live-state]])
- **Debugging outcome**: `steps=0` bug resolved by ensuring `OPENAI_BASE_URL` is propagated; local model (Gemma 4) confirmed functional with the endpoint override.

Current support: polyglot benchmark and smoke tests are runnable; Terminal-Bench and Harbor adapters are scaffolded; additional language descriptors are not yet implemented.