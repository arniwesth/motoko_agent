---
doc_type: short
full_text: sources/MLflow_Experiment_Tracking_Plan.md
---

# MLflow Experiment Tracking Plan

This document outlines a plan to integrate **MLflow** into the GRPO/SFT training and evaluation pipelines on **Modal**, addressing weak comparability from current logging approaches (terminal logs, manual notes). The goal is **low-cost, reliable experiment tracking** with structured metadata, metrics, and artifacts.

## Key Components

- **Tracking backend** (phase 1): File-backed store (`file:///root/checkpoints/mlruns`) on Modal, with a **self-hosted MLflow UI** for local inspection—no managed server.
- **Run taxonomy**: Three run types: `train_grpo`, `train_sft`, `eval`. Every run carries required **tags** (stage, model_base, checkpoint, GPU, source, git commit, etc.), **params** (max_steps, learning_rate, lora_r, …), and **metrics** (runtime, loss, pass rates).
- **Artifacts**: Eval summaries (JSON), training config snapshots, optional completion snippets.
- **Safe instrumentation**: MLflow logic in a dedicated `mlflow_tracker.py` module, with non‑crashing wrappers (`log_params_safe`, etc.) and environment flags (`MLFLOW_ENABLED`, `MLFLOW_TRACE_ENABLED`) to disable or roll back.

## Integration Scope

Primary integration points:
- GRPO and SFT training entrypoints in `modal_train.py` and `training_core.py`
- Evaluation in `evaluate.py` (structured JSON output, single‑writer rule for MLflow logging in Modal functions)
- Smoke test checklist and README updates

Out of scope for phase 1: hosted server, cost billing, hyperparameter sweeps.

## Execution Phases

1. **Core plumbing** – dependency wiring, `mlflow_tracker.py` with safe wrappers.
2. **Train logging** – start runs, log params, metrics, artifacts.
3. **Eval logging** – structured JSON contract from `evaluate.py`, MLflow run creation in Modal.
4. **Docs & verification** – README, smoke tests.
5. **(Post‑MVP) GRPO tracing** – step‑level spans for reward components (code extractable, check passes, runs, verifies) with sampling for cost control.

## Acceptance Criteria

- Every train/eval run creates an MLflow run with required metadata.
- Eval runs record pass rates and delta.
- At least one machine‑readable summary artifact per run.
- MLflow failures do not abort training (`try/except` + warnings).
- `mlflow ui --backend-store-uri <path>` can browse runs.

## Risks & Rollback

- URI path mismatch between Modal/local – addressed by explicit configuration.
- Eval output brittleness – mitigated by structured JSON.
- Artifact growth – capped artifacts, concise summaries.
- Rollback: `MLFLOW_ENABLED=0` disables all logging; console logs and markdown ledger remain as fallback.

## Related Concepts

- [[concepts/experiment-tracking]] – The overall problem solved here, bridging terminal notes and structured runs.
- [[concepts/mlflow]] – The OSS tool chosen for tracking, its URI schemes, and UI.
- [[concepts/modal]] – The serverless execution environment driving the training pipeline.
- [[concepts/grpo]] – The reinforcement‑learning training algorithm being instrumented.
- [[concepts/sft]] – Supervised fine‑tuning path that receives identical tracking.
- [[concepts/reward-tracing]] – Phase 5 observability for RL reward components and step‑level events.

See the full execution plan in [[sources/MLflow_Experiment_Tracking_Plan.md]].