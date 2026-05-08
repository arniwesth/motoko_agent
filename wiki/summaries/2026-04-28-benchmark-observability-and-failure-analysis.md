---
doc_type: short
full_text: sources/2026-04-28-benchmark-observability-and-failure-analysis.md
---

## Summary
This document describes observability and error-analysis improvements for the Motoko Polyglot benchmark run using `openai/google/gemma-4-26B-A4B-it` (local model).

## Key Outcomes
### Live Benchmark Observability
- Introduced live status file (`polyglot_live.json`) with phase, exercise, attempt, step, event, progress, and timestamps.
- Per-run event stream (`polyglot_events_<run_id>.jsonl`) for forensic analysis.
- Per-exercise attempt snapshots (`attempt1_events.json`, `attempt2_events.json`) stored in the run log tree.
- Heartbeat logging (`--heartbeat-secs`) for runner liveness.

### Status View (`status.sh`) Enhancements
- Added run metadata, liveness detection, stale-state grace period (30s).
- Pace (seconds per exercise) and ETA calculation for remaining exercises.
- Reduced false-positive stale warnings.

### Error and Tool-Failure Analysis
- [[concepts/benchmark-error-analysis|`error_breakdown.py`]]: categorizes `status=error` reasons; in this run all errors were `step_limit`.
- [[concepts/tool-failure-analysis|`tool_failures.py`]]: analyzes failures in observation/tool results; deduplicates repeated emissions; distinguishes expected policy/probe noise from actionable errors (e.g., shell syntax, missing commands).

### Run Findings
- Pass quality: 71.4% (65.7% pass_1, 5.7% pass_2).
- 26.4% error rate, all due to `step limit reached`.
- Strict tool-failure analysis revealed mostly benign native failures; actionable failures concentrated in delegated calls (quote mismatches, missing commands, empty-stderr errors).

### Local Model Routing
- Confirmed `OPENAI_BASE_URL` override and added CLI flag `--openai-base-url` to the benchmark script.

### Documentation
- Updated `benchmarks/README.md` with local run commands, extension variants, observability commands, artifact paths, and analyzer usage.

## Related Concepts
- [[concepts/benchmark-observability]]
- [[concepts/tool-failure-analysis]]
- [[concepts/local-model-routing]]
- [[concepts/motoko-extensions]]