# 2026-04-19 RunPod Additive + Serverless Integration Summary

## Session Goal
Implement `.agent/plans/RunPod_Additive_Integration_Plan.md` with a strict additive approach: keep Modal untouched, keep shared ML core logic provider-agnostic, and add RunPod orchestration for Phase 1. Then revise to make RunPod Serverless the primary RunPod path.

## What Was Implemented

### 1. New RunPod worker entrypoint (additive, provider wrapper only)
- Added `training/grpo_pilot/runpod_worker.py`.
- Added subcommands:
  - `train-grpo`
  - `train-sft`
  - `build-sft-dataset`
  - `eval`
- Each subcommand maps into existing shared modules:
  - GRPO: `training_core.py`
  - SFT: `sft_core.py`
  - SFT dataset build: `sft_build_dataset.py`
  - Eval: `evaluate.py` utilities

### 2. Bootstrap contract + preflight enforcement
`runpod_worker.py` now fails fast with actionable errors if any of these are missing:
- `ailang` available on `PATH` or resolvable from `AILANG_BIN`.
- docs file exists at `DOCS_PATH` (default `/workspace/ailang-v0.9.0-docs.md`).
- writable checkpoint root at `CHECKPOINT_ROOT` (default `/workspace/checkpoints`).
- shared imports resolve through `PYTHONPATH` (`training_core`, `sft_core`, `sft_build_dataset`, `evaluate`).

### 3. Existing-pod fallback scripts (kept)
Added SSH/pod scripts under `training/grpo_pilot/scripts/`:
- `runpod_launch_pod.sh` (minimal placeholder/fallback flow)
- `runpod_train_e4b_profile.sh`
- `runpod_eval_profile.sh`

### 4. RunPod env template
Added:
- `training/grpo_pilot/.env.runpod.example`
Includes endpoint/pod host settings, remote paths, runtime paths, API key placeholders, and checkpoint root.

### 5. README docs updates
Updated `training/grpo_pilot/README.md` with a dedicated RunPod section including:
- preflight requirements
- smoke command examples
- provider differences
- explicit note that Modal remains unchanged

### 6. Plan revision to serverless-first
User requested RunPod Serverless as primary path. Updated:
- `.agent/plans/RunPod_Additive_Integration_Plan.md`
Key change:
- Phase 1 default path switched from existing pod SSH to RunPod Serverless endpoint submission.
- SSH path retained as fallback.

### 7. Serverless scaffolding added
Added serverless transport layer while preserving shared core behavior:
- `training/grpo_pilot/runpod_serverless_handler.py`
  - RunPod serverless handler that invokes `runpod_worker.py` with structured `input.command` + `input.args`.
- `training/grpo_pilot/runpod_serverless.py`
  - local launcher for RunPod API endpoints (`/run`, `/runsync`, `/status` polling).
- New serverless scripts:
  - `training/grpo_pilot/scripts/runpod_serverless_train_e4b_profile.sh`
  - `training/grpo_pilot/scripts/runpod_serverless_eval_profile.sh`
  - `training/grpo_pilot/scripts/runpod_serverless_train_sft_smoke.sh`

### 8. Serverless Dockerfile added
Added:
- `training/grpo_pilot/Dockerfile.runpod_serverless`
Purpose:
- provide a serverless worker image with required runtime/deps
- set preflight-compatible defaults (`PYTHONPATH`, `DOCS_PATH`, `CHECKPOINT_ROOT`, `AILANG_BIN`)
- entrypoint runs `runpod_serverless_handler.py`
- no hardcoded secrets

## Compatibility and Semantics
- Modal workflow intentionally not removed/replaced.
- No changes made to:
  - `training/grpo_pilot/modal_train.py`
  - `training/grpo_pilot/training_core.py`
  - `training/grpo_pilot/sft_core.py`
  - `training/grpo_pilot/evaluate.py`
- ML/reward semantics preserved (changes were orchestration + wrappers + docs only).
- Eval output compatibility retained:
  - existing summary lines still printed
  - structured JSON summary also printed for label-agnostic checks

## Validation Performed
- `python -m py_compile` passed for:
  - `training/grpo_pilot/runpod_worker.py`
  - `training/grpo_pilot/runpod_serverless.py`
  - `training/grpo_pilot/runpod_serverless_handler.py`
- `bash -n` passed for new/updated RunPod scripts.
- Diff checks confirmed no regressions in Modal/shared core files.

## Files Added/Updated in This Session
- Added:
  - `training/grpo_pilot/runpod_worker.py`
  - `training/grpo_pilot/runpod_serverless_handler.py`
  - `training/grpo_pilot/runpod_serverless.py`
  - `training/grpo_pilot/Dockerfile.runpod_serverless`
  - `training/grpo_pilot/.env.runpod.example`
  - `training/grpo_pilot/scripts/runpod_launch_pod.sh`
  - `training/grpo_pilot/scripts/runpod_train_e4b_profile.sh`
  - `training/grpo_pilot/scripts/runpod_eval_profile.sh`
  - `training/grpo_pilot/scripts/runpod_serverless_train_e4b_profile.sh`
  - `training/grpo_pilot/scripts/runpod_serverless_eval_profile.sh`
  - `training/grpo_pilot/scripts/runpod_serverless_train_sft_smoke.sh`
- Updated:
  - `training/grpo_pilot/README.md`
  - `.agent/plans/RunPod_Additive_Integration_Plan.md`

## Current Status
- RunPod integration is now additive and serverless-first with existing-pod SSH fallback.
- Ready for user-side deployment to RunPod endpoint image and smoke execution.
