# MLflow Experiment Tracking Plan (GRPO/SFT on Modal)

## Goal
Add low-cost, reliable experiment tracking for `training/grpo_pilot` using MLflow OSS, with minimal operational overhead and reproducible run records.

## Why
Current tracking is split across terminal logs, manual notes, and markdown reports. This causes weak comparability across runs and makes tuning decisions slower.

MLflow gives us:
- Structured run metadata (params, metrics, tags).
- Artifact storage for eval outputs and summaries.
- Queryable experiment history without paid SaaS lock-in.

## Scope
In scope:
- Integrate MLflow logging into:
  - GRPO training entrypoints/functions.
  - SFT training entrypoints/functions.
  - Evaluation script and Modal evaluation functions.
- Use file-backed MLflow tracking in Modal volume as phase 1.
- Use **self-hosted/local MLflow UI** against file-backed runs for visualization and comparison.
- Emit consistent metrics/tags across all train/eval stages.
- Provide local command(s) to inspect runs with MLflow UI.
- Keep existing markdown ledger/report flow intact (complementary, not replaced).

Out of scope (phase 1):
- Managed/always-on hosted MLflow server deployment (HTTP endpoint with auth, Postgres-backed ops).
- Full cost accounting from provider billing APIs.
- Automated hyperparameter sweeps orchestration.

## Terminology Clarification
- **Self-hosted/local MLflow (in scope):**
  - File-backed tracking store (`mlruns` directory) + ad-hoc MLflow UI process.
  - Example: `mlflow ui --backend-store-uri /path/to/mlruns --port 5000`
  - Suitable for low-cost experiment browsing and comparison.
- **Hosted MLflow server (out of scope for phase 1):**
  - Persistent service deployment with network endpoint, auth, and operational DB/backend management.
  - Treated as a later-phase infrastructure project.

## Design
## Tracking backend (phase 1)
- `MLFLOW_TRACKING_URI=file:///root/checkpoints/mlruns` in Modal.
- Same URI pattern locally can be pointed to workspace path if needed.
- Single experiment namespace initially: `ailang-grpo-pilot`.

## Run taxonomy
Run types:
- `train_grpo`
- `train_sft`
- `eval`

Required tags (all run types):
- `stage` (`grpo`/`sft`/`eval`)
- `model_base`
- `checkpoint_subdir` (if applicable)
- `compute_gpu` (e.g. `A100-80GB`, `H200`)
- `source` (`modal`/`local`)
- `git_commit` (best-effort)
- `modal_app_id` and `modal_function_id` (best-effort)

Required params:
- Training:
  - `max_steps`, `num_generations` (grpo), `max_seq_length`, `max_prompt_length`, `max_completion_length`, `gradient_accumulation_steps`
  - `learning_rate`, `lora_r`, `lora_alpha`, `beta` where available
- Evaluation:
  - `split`, `samples_per_prompt`, `max_new_tokens`, `max_input_tokens`

Required metrics:
- Training:
  - `train_runtime_sec`
  - `train_steps_per_sec`
  - `train_samples_per_sec`
  - `train_loss_final`
- Evaluation:
  - `base_pass_rate`
  - `adapter_pass_rate`
  - `delta_pp`
  - `base_pass_count`, `adapter_pass_count`, `total_cases`

Artifacts to log:
- Eval summary text/json.
- Training config snapshot json.
- Optional: sampled completion snippets for failed cases (small, capped).

## Code Changes
Primary files:
- `training/grpo_pilot/modal_train.py`
- `training/grpo_pilot/training_core.py`
- `training/grpo_pilot/sft_core.py`
- `training/grpo_pilot/evaluate.py`
- `training/grpo_pilot/README.md`

New module(s):
- `training/grpo_pilot/mlflow_tracker.py`

Suggested `mlflow_tracker.py` API:
- `start_run(run_name: str, stage: str, tags: dict[str, str]) -> context manager`
- `log_params_safe(params: dict[str, Any])`
- `log_metrics_safe(metrics: dict[str, float], step: int | None = None)`
- `log_text_artifact(name: str, content: str)`
- `log_json_artifact(name: str, payload: dict[str, Any])`
- `set_tracking_defaults(uri: str, experiment_name: str)`
- `best_effort_git_commit()`

Implementation notes:
- MLflow logging must never crash train/eval. Wrap in try/except and warn.
- Keep log payloads small and deterministic.
- Do not log secrets.

## Execution Plan
## Phase 1 — Core plumbing
1. Add `mlflow` dependency to Modal image and local setup docs.
2. Add tracker helper module with safe wrappers and common tag builder.
3. Add tracking URI + experiment env defaults in Modal functions.

## Phase 2 — Train logging
1. In GRPO train path, start MLflow run at function start.
2. Log full config params.
3. After training, log summarized trainer metrics and output checkpoint path.
4. Log `train_summary.json` artifact.

## Phase 3 — Eval logging
1. In `evaluate.py`, parse final summary into structured numbers.
2. Return structured result object in addition to console text.
3. **Single-writer rule for MLflow eval logging**:
   - `evaluate.py` is responsible for metric computation and JSON output only.
   - Modal eval functions (`modal_train.py`) are responsible for MLflow run creation and metric/artifact logging.
   - Optional standalone mode may allow `evaluate.py` to log directly only when `MLFLOW_LOG_IN_PROCESS=1`.

## Structured Eval Result Contract
`evaluate.py` must emit a machine-readable JSON result with this schema:
- `base_pass_count: int`
- `adapter_pass_count: int`
- `total_cases: int`
- `base_pass_rate: float`
- `adapter_pass_rate: float`
- `delta_pp: float`
- `split: str`
- `samples_per_prompt: int`
- `checkpoint_subdir: str | null`
- `base_model: str`
- `timestamp_utc: str` (ISO-8601)

## Phase 4 — Docs + verification
1. Update README with MLflow usage:
   - where runs are stored,
   - how to launch UI,
   - how to filter by split/model/checkpoint.
2. Add a short smoke test checklist.

## Acceptance Criteria
1. Running any train function creates an MLflow run with required tags/params/metrics.
2. Running eval creates an MLflow run with pass rates and delta.
3. MLflow artifacts contain at least one machine-readable summary per run.
4. Failures in MLflow do not abort model training/evaluation.
5. `mlflow ui --backend-store-uri <path>` can browse generated runs locally.

## Validation Checklist
- `python -m py_compile` passes on modified Python files.
- One GRPO train smoke run logs a run.
- One SFT train smoke run logs a run.
- One eval run logs base/adapter/delta metrics correctly.
- Manual inspection confirms tags and params are populated.
- `MLFLOW_ENABLED=0` disables logging without affecting train/eval success.
- Invalid/unreachable tracking URI does not fail train/eval (best-effort logging).
- Artifact logging failure is non-fatal and surfaces a warning.

## Risks and Mitigations
Risk: tracking path mismatch between Modal/local.
- Mitigation: explicit URI config and README examples.

Risk: eval output parsing brittleness.
- Mitigation: emit structured JSON in `evaluate.py`, avoid regex-only parsing.

Risk: artifact volume growth.
- Mitigation: log concise artifacts; avoid large completion dumps by default.

## Rollback Plan
- If MLflow causes regressions, disable with env flag `MLFLOW_ENABLED=0`.
- Keep existing console logs and markdown ledger as fallback source of truth.

## Phase 5 — GRPO Tracing Schema (Post-MVP)
Goal: add step-level observability for RL behavior without changing training semantics.

Trace granularity:
- One root span per train/eval run.
- Child spans per training step (sampled; e.g. every N steps) and per evaluation prompt.
- Child spans for reward component computation (`code_extractable`, `check_passes`, `runs_correctly`, `verifies`).

Suggested span names:
- `grpo.run`
- `grpo.step`
- `grpo.generate`
- `grpo.reward.code_extractable`
- `grpo.reward.ailang_check_passes`
- `grpo.reward.ailang_runs_correctly`
- `grpo.reward.ailang_verifies`
- `eval.prompt`
- `eval.sample`

Required span attributes:
- Common:
  - `run_id`, `stage`, `model_base`, `checkpoint_subdir`, `gpu`, `split`
- Generation:
  - `prompt_tokens`, `completion_tokens`, `max_new_tokens`, `num_generations`
- Reward:
  - `reward_component`, `reward_value`, `check_status`, `run_status`, `verify_status`, `timeout_hit`
- Eval:
  - `prompt_id`, `sample_idx`, `compile_pass`, `runtime_pass`, `verify_pass`

Structured events to emit on spans:
- `oom_error` with allocation/free-memory details if available.
- `tool_timeout` with tool name and timeout value.
- `invalid_completion` when no AILANG code is extractable.

Sampling policy:
- Always trace failed/OOM/timeouts.
- For healthy train steps, sample at fixed ratio (e.g. 10%) to control cost/volume.

Non-goals for this phase:
- Full token-level transcript storage by default.
- Logging full completion text for every sample.

## Handoff Notes for Separate Agent
Implementation order should be:
1. `mlflow_tracker.py` helper + dependency wiring.
2. Training path integration (GRPO + SFT).
3. Evaluation structured output + logging integration.
4. README updates and smoke validation.
5. Optional Phase 5 tracing behind `MLFLOW_TRACE_ENABLED=0/1`.

Please keep changes minimal and avoid changing training semantics while instrumenting.
