---
doc_type: short
full_text: sources/2026-04-19-grpo-pilot-mlflow-instrumentation.md
---

## Summary
This document records the implementation of MLflow experiment tracking for the `training/grpo_pilot` codebase, following the plan outlined in `.agent/plans/MLflow_Experiment_Tracking_Plan.md`. The work introduces a non-intrusive, best-effort logging layer that never crashes training or evaluation, while capturing essential parameters, metrics, and artifacts.

## Key additions
- **New MLflow helper module** (`mlflow_tracker.py`): provides safe wrappers like `is_mlflow_enabled()`, `start_run()` context manager, and `log_params_safe()` / `log_metrics_safe()`. Includes secret-aware filtering, deterministic JSON artifact logging, and best-effort git commit capture. See [[concepts/mlflow-safe-wrappers]].
- **Modal dependency and environment wiring** (`modal_train.py`): adds `mlflow>=2.16.0` dependency, default `MLFLOW_ENABLED`, tracking URI, experiment name, and GPU config.
- **Training integration** (`training_core.py`, `sft_core.py`): wraps GRPO and SFT training runs with `start_run()`, logging required tags (`stage`, `model_base`, `checkpoint_subdir`, `compute_gpu`, `source`, `git_commit`, Modal IDs) and train metrics, plus a compact `train_summary.json` artifact.
- **Evaluation integration** (`evaluate.py`, `modal_train.py`): evaluation now produces structured summaries (`base_pass_rate`, `adapter_pass_rate`, `delta_pp`, etc.) and passes a `--summary-json-out` path. Modal eval functions become single-writers for MLflow eval runs, logging the same metrics and artifacts (`eval_summary.json`, `eval_summary.txt`, `eval_stdout.txt`).
- **Tooling and operational fixes**: post-implementation issues were resolved, including a `start_run()` context-manager bug, adapter re-initialization for GRPO-from-SFT, and compatibility scripts (`modal_pull_artifacts.sh`, `mlflow_ui_local.sh`, `mlflow_ui_compat.sh`) for downloading runs and viewing MLflow UI across version boundaries. The troubleshooting guide covers HTTP 403 errors and host forwarding.

## Constraints and compliance
All logging is best-effort and non-fatal; secrets are filtered out; artifact content is deterministic; training/eval semantics remain unchanged.

## Related concepts
- [[concepts/mlflow-tracking]] – experiment tracking setup
- [[concepts/grpo-pilot]] – training pipeline overview
- [[concepts/modal-runner]] – Modal-specific deployment details
- [[concepts/eval-metrics]] – pass-rate metrics and summary format
- [[concepts/peft-adapter]] – adapter initialization subtleties in GRPO-from-SFT