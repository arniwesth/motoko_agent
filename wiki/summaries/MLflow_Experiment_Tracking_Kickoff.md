---
doc_type: short
full_text: sources/MLflow_Experiment_Tracking_Kickoff.md
---

## Summary

This document is a kick-off prompt for implementing MLflow experiment tracking in the AILang GRPO pilot training and evaluation pipeline. The plan specifies a minimal-change approach: inject tracking instrumentation without altering training/eval logic, enforce non-fatal failures so MLflow issues never crash the system, and maintain artifact conciseness with no secret leakage.

## Constraints
- No semantic changes to training or evaluation.
- MLflow errors must be handled without interrupting the pipeline ([[concepts/failure resilience]]).
- Artifacts must be small and deterministic.
- No logging of sensitive data ([[concepts/secret management]]).

## Deliverables
1. **Helper module** (`training/grpo_pilot/mlflow_tracker.py`) with safe wrappers for run management, parameter/metric logging, artifact storage, and best-effort Git commit recording.
2. **Configuration** – add `mlflow` dependency, set default tracking URI (`file:///root/checkpoints/mlruns`), experiment name (`ailang-grpo-pilot`), and environment gate `MLFLOW_ENABLED` (default on).
3. **Training integration** – modify `training_core.py` and `sft_core.py` to log required tags, parameters, metrics, and a compact `train_summary.json` artifact.
4. **Evaluation integration** – update `evaluate.py` to produce a structured summary and log `base_pass_rate`, `adapter_pass_rate`, `delta_pp`, and event counts as MLflow artifacts/metrics.
5. **Documentation** – update the GRPO pilot README with run storage location, UI launch instructions, and filter examples.
6. **Validation** – compile-check all changed Python files and summarize logged metrics/tags.

## Acceptance Criteria
- Any training run (GRPO or SFT) automatically creates an MLflow run with required tags/params/metrics.
- Evaluation runs log pass rates and deltas.
- MLflow logging is best-effort; failures do not propagate.
- Existing run commands remain unchanged.

## Cross-Cutting Concepts
- [[concepts/mlflow tracking]] – core tracking capabilities and run lifecycle.
- [[concepts/experiment management]] – organizing runs, comparing trials.
- [[concepts/configuration gating]] – using `MLFLOW_ENABLED` to toggle features.
- [[concepts/training instrumentation]] – non-intrusive record keeping during training.
- [[concepts/eval metrics]] – structured logging of evaluation outcomes.
