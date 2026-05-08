# 2026-04-19 GRPO Pilot MLflow Instrumentation Session

## Objective
Implement `.agent/plans/MLflow_Experiment_Tracking_Plan.md` end-to-end for `training/grpo_pilot` with minimal behavioral change, ensuring MLflow logging is best-effort and non-fatal.

## What Was Implemented

### 1. New MLflow helper module
Added `training/grpo_pilot/mlflow_tracker.py` with safe wrappers:
- `is_mlflow_enabled()` gated by `MLFLOW_ENABLED` (default on)
- `set_tracking_defaults()` with defaults:
  - `MLFLOW_TRACKING_URI=file:///root/checkpoints/mlruns`
  - `MLFLOW_EXPERIMENT_NAME=ailang-grpo-pilot`
- `start_run()` context manager (non-fatal on failure)
- `log_params_safe()`, `log_metrics_safe()`
- `log_text_artifact()`, `log_json_artifact()` (deterministic JSON: sorted keys + stable formatting)
- `best_effort_git_commit()`
- secret-aware param filtering (drops keys containing `token`, `secret`, `password`, `passwd`, `api_key`, `apikey`)

### 2. Modal dependency/config wiring
Updated `training/grpo_pilot/modal_train.py`:
- Added image dependency: `mlflow>=2.16.0`
- Added env defaults:
  - `MLFLOW_ENABLED=1`
  - `MLFLOW_TRACKING_URI=file:///root/checkpoints/mlruns`
  - `MLFLOW_EXPERIMENT_NAME=ailang-grpo-pilot`
  - `COMPUTE_GPU=H200`

### 3. Train logging integration (GRPO + SFT)
Updated `training/grpo_pilot/training_core.py` and `training/grpo_pilot/sft_core.py`:
- Starts MLflow run around training via `start_run(...)`
- Logs required tags:
  - `stage`, `model_base`, `checkpoint_subdir`, `compute_gpu`, `source`
  - `git_commit` (best-effort)
  - `modal_app_id`, `modal_function_id` (best-effort)
- Logs required params and train metrics
- Logs compact `train_summary.json` artifact
- Preserved training semantics (same trainer config and save flow)

### 4. Eval logging integration
Updated `training/grpo_pilot/evaluate.py`:
- Added structured summary builder with schema:
  - `base_pass_count`, `adapter_pass_count`, `total_cases`
  - `base_pass_rate`, `adapter_pass_rate`, `delta_pp`
  - `split`, `samples_per_prompt`, `checkpoint_subdir`, `base_model`, `timestamp_utc`
- Added `--summary-json-out` argument for machine-readable output

Updated `training/grpo_pilot/modal_train.py` eval functions:
- `evaluate_checkpoint` and `evaluate_e4b_profile` now pass `--summary-json-out`
- Modal side is single writer for MLflow eval runs
- Logs eval params/metrics/artifacts via helper:
  - metrics: `base_pass_rate`, `adapter_pass_rate`, `delta_pp`, `base_pass_count`, `adapter_pass_count`, `total_cases`
  - artifacts: `eval_summary.json`, `eval_summary.txt`, `eval_stdout.txt`
- All eval MLflow actions are best-effort and non-fatal

### 5. README updates
Updated `training/grpo_pilot/README.md` with:
- MLflow defaults and toggle behavior
- where runs are stored
- how to run UI
- example filters by stage/split/checkpoint
- quick start commands
- dev Docker/devcontainer 403 troubleshooting:
  - prefer `http://127.0.0.1:5000`
  - `--allowed-hosts` guidance for forwarded hosts
  - optional `--cors-allowed-origins` for HTTPS forwarded URLs

## Validation Performed
- Ran `python -m py_compile` on changed Python files:
  - `training/grpo_pilot/mlflow_tracker.py`
  - `training/grpo_pilot/modal_train.py`
  - `training/grpo_pilot/training_core.py`
  - `training/grpo_pilot/sft_core.py`
  - `training/grpo_pilot/evaluate.py`
- Compile validation passed (exit code 0).

## User-Observed Runtime Note
- User hit `HTTP 403` when opening MLflow UI in dev Docker.
- Resolved by using `http://127.0.0.1:5000/`.
- Added explicit README troubleshooting for host validation/CORS in forwarded scenarios.

## Post-Implementation Fixes (2026-04-20)

After initial instrumentation, several operational issues were found while running GRPO-from-SFT and local MLflow browsing. These were fixed:

### 1. `start_run()` context manager bug (non-fatal contract violation)
- Symptom: `RuntimeError: generator didn't stop after throw()`.
- Cause: `start_run()` yielded twice when handling exceptions.
- Fix: refactored `start_run()` to:
  - yield `None` only on run-start failure path and return immediately,
  - otherwise yield once and always close run in `finally`.
- File: `training/grpo_pilot/mlflow_tracker.py`.

### 2. GRPO-from-SFT adapter initialization
- Symptom: `Unsloth: You already added LoRA adapters to your model!` when using SFT checkpoint as GRPO init.
- Cause: LoRA was being attached again after loading an adapter checkpoint.
- Fix: added `init_adapter_path` to `TrainConfig` and skipped `get_peft_model()` when `init_adapter_path` is set.
- Files:
  - `training/grpo_pilot/training_core.py`
  - `training/grpo_pilot/modal_train.py` (new profile function using this path)

### 3. Modal artifact pull convenience tooling
- Added script to download MLflow runs/checkpoints from Modal volume:
  - `training/grpo_pilot/scripts/modal_pull_artifacts.sh`
- Fixes applied after user testing:
  - directory destination handling for `modal volume get`,
  - `--force` support,
  - `--clean` support,
  - corrected mlruns destination layout to avoid `mlruns/mlruns` nesting.

### 4. Local MLflow UI helper tooling
- Added local launcher:
  - `training/grpo_pilot/scripts/mlflow_ui_local.sh`
- Improvements after user testing:
  - nested `mlruns` auto-detection,
  - artifact URI rewrite from Modal file-store paths (`/root/checkpoints/mlruns/...`) to local paths,
  - default `--workers 1` for file-store stability.

### 5. MLflow 3.x vs 2.x file-store compatibility path
- User saw run-detail `404`/`Not Found` and metadata compatibility issues.
- Added compatibility launcher:
  - `training/grpo_pilot/scripts/mlflow_ui_compat.sh`
- Compatibility fixes:
  - supports selecting Python interpreter (`--python`) and forced venv recreate (`--recreate`),
  - auto-recreates venv when Python minor version mismatches existing venv,
  - installs `setuptools`/`wheel` pre-reqs,
  - patches run `meta.yaml` to add `run_uuid` from `run_id` for MLflow 2.x reader compatibility.

### 6. Environment note
- Debian `trixie` image did not provide apt `python3.11` packages.
- Installed `pyenv` and used Python `3.11.11` for MLflow 2.x compatibility UI launcher.

## Constraints Compliance Check
- No intentional training/eval semantic changes; instrumentation only.
- MLflow failures are guarded and do not crash train/eval paths.
- Artifacts are concise and deterministic.
- Secrets are not logged by helper key filtering.

## Files Changed During Session
- `training/grpo_pilot/mlflow_tracker.py` (new)
- `training/grpo_pilot/modal_train.py`
- `training/grpo_pilot/training_core.py`
- `training/grpo_pilot/sft_core.py`
- `training/grpo_pilot/evaluate.py`
- `training/grpo_pilot/README.md`
- `training/grpo_pilot/scripts/modal_pull_artifacts.sh` (new)
- `training/grpo_pilot/scripts/mlflow_ui_local.sh` (new)
- `training/grpo_pilot/scripts/mlflow_ui_compat.sh` (new)
