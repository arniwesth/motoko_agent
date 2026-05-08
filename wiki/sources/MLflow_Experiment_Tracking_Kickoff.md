# Kick-off Prompt: MLflow Tracking Implementation

Implement `.agent/plans/MLflow_Experiment_Tracking_Plan.md` end-to-end with minimal behavioral changes.

## Constraints
- Do not change training/eval semantics; only add tracking/instrumentation.
- MLflow failures must never crash train/eval paths.
- Keep artifacts concise and deterministic.
- Do not log secrets.

## Required Deliverables
1. Add MLflow helper module:
   - `training/grpo_pilot/mlflow_tracker.py`
   - Safe wrappers for start_run, log_params, log_metrics, log_text/json artifacts, default URI/experiment setup, best-effort git commit.
2. Wire dependency/config:
   - Add `mlflow` to Modal image deps in `training/grpo_pilot/modal_train.py`.
   - Add default tracking URI `file:///root/checkpoints/mlruns` and experiment name `ailang-grpo-pilot`.
   - Gate with `MLFLOW_ENABLED` env (default on).
3. Integrate train logging:
   - `training/grpo_pilot/training_core.py`
   - `training/grpo_pilot/sft_core.py`
   - Log required params/tags/metrics from plan.
   - Log compact `train_summary.json` artifact.
4. Integrate eval logging:
   - `training/grpo_pilot/evaluate.py`
   - Produce structured summary object (counts, pass rates, delta).
   - Modal eval functions log params/metrics/artifacts using helper.
5. Docs:
   - Update `training/grpo_pilot/README.md` with MLflow usage:
     - where runs are stored
     - how to launch UI
     - example filters.
6. Validation:
   - Run `python -m py_compile` on changed python files.
   - Provide a concise summary of changed files and exact metrics/tags logged.

## Acceptance Criteria
- Any GRPO/SFT train creates an MLflow run with required tags/params/metrics.
- Eval creates MLflow run with `base_pass_rate`, `adapter_pass_rate`, `delta_pp`, and counts.
- MLflow logging is best-effort (non-fatal).
- Existing run commands continue to work.

## Return Format
- File list changed
- Example run commands
- Verification results
- Known caveats
