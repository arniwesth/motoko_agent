# Kick-off Prompt: RunPod Additive Integration (Phase 1)

Implement `.agent/plans/RunPod_Additive_Integration_Plan.md` with a strict additive approach: keep Modal unchanged and add RunPod as an alternative backend.

## Constraints
- Do not replace/remove Modal workflow.
- Do not change ML behavior or reward semantics.
- Keep shared core logic provider-agnostic (`training_core.py`, `sft_core.py`, `evaluate.py`).
- Implement only orchestration/wrappers/scripts/docs needed for RunPod Phase 1.
- Do not log or hardcode secrets.

## Implementation Scope (Phase 1 only)
1. Add RunPod worker entrypoint:
   - `training/grpo_pilot/runpod_worker.py`
   - Subcommands:
     - `train-grpo`
     - `train-sft`
     - `build-sft-dataset`
     - `eval`
   - Map each command directly to existing shared core modules/config.

2. Enforce bootstrap contract + preflight:
   - Validate before run:
     - `ailang` binary available (`PATH` or `AILANG_BIN`)
     - docs file exists at `DOCS_PATH` (default `/workspace/ailang-v0.9.0-docs.md`)
     - writable `CHECKPOINT_ROOT` (default `/workspace/checkpoints`)
     - imports resolve via `PYTHONPATH`
   - Fail fast with clear actionable errors.

3. Add RunPod scripts for existing-pod execution:
   - `training/grpo_pilot/scripts/runpod_launch_pod.sh` (can be minimal placeholder if pod is pre-existing)
   - `training/grpo_pilot/scripts/runpod_train_e4b_profile.sh`
   - `training/grpo_pilot/scripts/runpod_eval_profile.sh`
   - Canonical path for Phase 1 is existing pod + SSH/script execution (not full API orchestration).

4. Add env template:
   - `training/grpo_pilot/.env.runpod.example`
   - Include variables for pod host/user, paths, tokens, and checkpoint root.

5. Update docs:
   - `training/grpo_pilot/README.md` with “RunPod Backend (Alternative to Modal)”
   - Provide copy-paste commands for smoke train/eval.
   - Document provider differences and preflight requirements.

## Required Output Compatibility
- Checkpoints saved under `CHECKPOINT_ROOT/<subdir>`.
- Eval output remains compatible with existing summaries.
- Acceptance checks should be label-agnostic (`Adapter/LoRA`) or use structured fields.

## Validation Requirements
- `python -m py_compile` for changed Python files.
- Demonstrate commands for:
  - GRPO smoke (`max_steps=2`)
  - SFT smoke (`max_steps` small)
  - Eval smoke (`samples-per-prompt` small)
- Confirm no regression to Modal commands.

## Return Format
- Files changed
- Exact commands to run on RunPod
- Validation results
- Known limitations and next-step recommendations (Phase 2+)
