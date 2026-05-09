---
doc_type: short
full_text: sources/RunPod_Additive_Integration_Plan.md
---

# RunPod Additive Integration Plan Summary

## Objective
Add RunPod as an **alternative execution backend** for `training/grpo_pilot`, preserving the existing Modal workflow unchanged. This follows an [[concepts/alternative-backend-architecture]] approach where ML logic remains shared and provider wrappers are thin.

## Design Principles
- **Single source of truth**: Shared Python modules (`training_core.py`, `sft_core.py`, `evaluate.py`, `reward_functions.py`) stay provider-agnostic ([[concepts/shared-ml-core]]).
- **Thin wrappers**: Backend-specific code only for orchestration, environment wiring, and storage mounts.
- **Incremental rollout**: Start with minimal serverless scaffold, smoke-test before parity.

## Architecture
### Shared Core (unchanged)
- Core training, SFT, evaluation, and reward files remain identical for both backends.

### Modal Backend (existing)
- `modal_train.py` handles Modal launch.

### New RunPod Backend
- `runpod_worker.py` – CLI dispatcher invoked inside the RunPod container; subcommands: `train-grpo`, `eval`, `train-sft`, `build-sft-dataset`.
- `runpod_serverless_handler.py` – Serverless endpoint handler that maps job input to the worker.
- `runpod_serverless.py` – Local control-plane launcher for Serverless submission and polling.
- Shell scripts (`scripts/runpod_serverless_*.sh`, `scripts/runpod_*.sh`) for practical submission and SSH fallback.

### Storage Model
- Persistent volume mounted at `/workspace/checkpoints` (environment variable `CHECKPOINT_ROOT`).
- Checkpoint subdirectory naming compatible with Modal output for [[concepts/checkpoint-parity]].

### Bootstrap Contract
Every RunPod environment must satisfy preflight checks: `ailang` on `PATH`, docs file present, training code importable via `PYTHONPATH`, writable checkpoint root, and Hugging Face auth (`HF_TOKEN`). This ensures a consistent [[concepts/bootstrap-contract]] across runs.

## Phase Plan
1. **Phase 1 – Backend scaffold**: Minimal `runpod_worker.py` + Serverless wrappers for one-command worker inside Serverless; local launcher can submit/poll.
2. **Phase 2 – Launch scripts**: Shell scripts for reproducible operations, `.env.example`, log capture, and existing-pod SSH fallback.
3. **Phase 3 – Profile parity**: Mirror Modal experiment profiles (E4B GRPO, full-doc H200-style, SFT bootstrap) on RunPod, matching eval arguments.
4. **Phase 4 – Validation and docs**: Smoke tests (short GRPO/SFT trains, eval with summary metrics), README updates, and provider difference documentation.

## Key Files to Create
- `training/grpo_pilot/runpod_worker.py`
- `training/grpo_pilot/runpod_serverless_handler.py`
- `training/grpo_pilot/runpod_serverless.py`
- Serverless and SSH fallback shell scripts
- `training/grpo_pilot/.env.runpod.example`
- Updated `README.md` with RunPod commands

## Acceptance Criteria
- Modal commands remain unchanged.
- RunPod backend completes smoke GRPO, SFT, and eval runs with structured output (e.g., base/adapter pass counts, delta).
- Artifacts saved under `CHECKPOINT_ROOT/<subdir>`.
- README includes copy-paste commands for both backends.

## Risks and Mitigations
- **Provider differences** → Isolate RunPod API usage to scripts/launcher.
- **Environment drift** → Pin dependency versions and document a known-good container baseline.
- **Storage path mismatches** → Enforce `CHECKPOINT_ROOT` contract with explicit prints.
- **Secret handling** → Env-based injection only; no hardcoded tokens.

## Rollback Plan
RunPod path is self-contained; unstable paths remain behind dedicated scripts; removing RunPod scripts does not affect Modal or shared core.