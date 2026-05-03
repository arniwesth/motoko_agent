# RunPod Additive Integration Plan (Keep Modal, Add Alternative)

## Objective
Add RunPod as an **alternative execution backend** for `training/grpo_pilot` while preserving the current Modal workflow unchanged.

## Non-Goals
- Do not remove or replace Modal.
- Do not fork training logic into provider-specific copies.
- Do not alter existing model/reward semantics.

## Success Criteria
1. Existing Modal commands continue to work exactly as today.
2. Equivalent train/eval jobs can be launched on RunPod.
3. Shared core (`training_core.py`, `sft_core.py`, `evaluate.py`) remains provider-agnostic.
4. Checkpoints and eval outputs are produced with the same structure on both backends.

---

## Design Principles
- **Single source of truth for ML logic**: keep model/reward/eval logic in shared Python modules.
- **Thin provider wrappers**: backend-specific code only for orchestration, env wiring, and storage mounts.
- **Parity first, optimization second**: match current Modal capabilities before adding extras.
- **Incremental rollout**: smoke-test small jobs before long/full-doc runs.

---

## Proposed Architecture
## Shared core (unchanged)
- `training/grpo_pilot/training_core.py`
- `training/grpo_pilot/sft_core.py`
- `training/grpo_pilot/evaluate.py`
- `training/grpo_pilot/reward_functions.py`

## Modal backend (existing)
- `training/grpo_pilot/modal_train.py`

## New RunPod backend
- `training/grpo_pilot/runpod_worker.py`
  - Pure Python CLI/dispatcher invoked inside RunPod environment.
  - Modes: `train_grpo`, `eval`, `train_sft`, `build_sft_dataset`.
- `training/grpo_pilot/runpod_serverless_handler.py`
  - Serverless endpoint handler; maps endpoint job input to `runpod_worker.py` execution.
- `training/grpo_pilot/runpod_serverless.py`
  - Local control-plane launcher for Serverless `/run`, `/runsync`, and `/status` polling.
- `training/grpo_pilot/scripts/runpod_*.sh`
  - Practical scripts for Serverless submission and existing-pod SSH fallback.

## Storage model
- Mount persistent volume path (e.g. `/workspace/checkpoints`) in RunPod.
- Keep checkpoint subdir naming compatible with Modal output naming.
- Optional sync/export helpers for moving artifacts between backends.

## Bootstrap Contract (Required Before Any Run)
Each RunPod environment must guarantee the following before invoking `runpod_worker.py`:
- `ailang` binary is available on `PATH` (or explicit `AILANG_BIN` env var).
- Docs file exists at `DOCS_PATH` (default `/workspace/ailang-v0.9.0-docs.md`).
- Training code is present and importable (`PYTHONPATH` includes `training/grpo_pilot`).
- Checkpoint root exists and is writable (`CHECKPOINT_ROOT`, default `/workspace/checkpoints`).
- Hugging Face auth is available via environment (`HF_TOKEN` or equivalent).

Bootstrap options (choose one per environment):
- Bake a custom image containing code + binary + docs.
- Or mount/sync repo assets on container startup and verify paths with a preflight check.

Mandatory preflight command (first step in scripts):
- Validate `ailang --help`, docs path existence, and writable checkpoint root.

---

## Phase Plan
## Phase 1 — Backend scaffold (minimal viable, serverless-first)
1. Add `runpod_worker.py` with argparse subcommands:
   - `train-grpo`
   - `eval`
   - `train-sft`
   - `build-sft-dataset`
2. Ensure each subcommand maps directly to existing core modules/configs.
3. Add standard env-based paths:
   - `CHECKPOINT_ROOT` default `/workspace/checkpoints`
   - `DOCS_PATH` default `/workspace/ailang-v0.9.0-docs.md`
4. Add Serverless transport wrappers:
   - endpoint handler (`runpod_serverless_handler.py`)
   - local launcher (`runpod_serverless.py`)
   - serverless profile scripts (`scripts/runpod_serverless_*.sh`)

Deliverable: one-command worker runs inside RunPod Serverless worker; local launcher can submit/poll jobs.

## Phase 2 — Launch scripts and reproducible ops
1. Add existing-pod fallback scripts:
   - `scripts/runpod_launch_pod.sh`
   - `scripts/runpod_train_e4b_profile.sh`
   - `scripts/runpod_eval_profile.sh`
2. Add shared `.env.example` for Serverless + fallback variables:
   - `RUNPOD_ENDPOINT_ID`, `RUNPOD_API_KEY`, volume path, HF token usage.
3. Add log capture to file (`run.log`) plus stdout streaming for serverless submissions.

Deliverable: repeatable shell-driven runs from local machine with serverless primary path and SSH fallback.

Phase 1 canonical launch path:
- Use **RunPod Serverless endpoint submission** as the default implementation path.
- Keep existing RunPod pod + SSH/script execution as fallback.

## Phase 3 — Profile parity with Modal
1. Mirror key Modal profiles in RunPod scripts:
   - E4B quality GRPO
   - E4B full-doc H200-style profile (if equivalent GPU available)
   - SFT bootstrap profile
2. Ensure eval arguments parity (`split`, `samples_per_prompt`, `max_input_tokens`).

Deliverable: same experiment matrix can run on either backend.

## Phase 4 — Validation and docs
1. Add README section “RunPod Backend (Alternative to Modal)”.
2. Add end-to-end smoke tests:
   - short GRPO train
   - short SFT train
   - eval run with summary metrics.
3. Document known provider differences (GPU naming, startup latency, storage semantics).

Deliverable: user can choose Modal or RunPod per run with clear commands.

---

## Required Files (Planned)
- `training/grpo_pilot/runpod_worker.py` (new)
- `training/grpo_pilot/runpod_serverless_handler.py` (new)
- `training/grpo_pilot/runpod_serverless.py` (new launcher)
- `training/grpo_pilot/scripts/runpod_serverless_train_e4b_profile.sh` (new)
- `training/grpo_pilot/scripts/runpod_serverless_eval_profile.sh` (new)
- `training/grpo_pilot/scripts/runpod_serverless_train_sft_smoke.sh` (new)
- `training/grpo_pilot/scripts/runpod_launch_pod.sh` (new)
- `training/grpo_pilot/scripts/runpod_train_e4b_profile.sh` (new)
- `training/grpo_pilot/scripts/runpod_eval_profile.sh` (new)
- `training/grpo_pilot/.env.runpod.example` (new)
- `training/grpo_pilot/README.md` (update)

---

## Configuration Contract
Common runtime env vars for RunPod worker:
- `HF_TOKEN` (or existing Hugging Face auth env used by transformers/unsloth)
- `CHECKPOINT_ROOT` (default `/workspace/checkpoints`)
- `PYTHONPATH` includes `training/grpo_pilot`
- `PATH` includes `ailang` binary location

CLI contract examples (inside worker image):
- `python runpod_worker.py train-grpo --model-name unsloth/gemma-4-E4B-it --max-steps 10 ...`
- `python runpod_worker.py eval --base-model unsloth/gemma-4-E4B-it --checkpoint-subdir ...`

Serverless client contract examples (local control plane):
- `python runpod_serverless.py train-grpo --mode async --args-json '{"max-steps":2,"output-subdir":"grpo_smoke"}'`
- `python runpod_serverless.py eval --mode async --args-json '{"checkpoint-subdir":"grpo_smoke","samples-per-prompt":1}'`

---

## Acceptance Criteria
1. Modal backend remains untouched and operational.
2. RunPod backend can execute:
   - one GRPO smoke train,
   - one SFT smoke train,
   - one eval producing summary lines:
     - `Base model: X/Y`
     - `Adapter/LoRA: X/Y` (label text may vary by script version)
     - `Delta     : +/-N.nn percentage points`
   - and/or equivalent structured eval fields (`base_pass_count`, `adapter_pass_count`, `delta_pp`).
3. Artifacts saved under `CHECKPOINT_ROOT/<subdir>` with expected files.
4. README has copy-paste commands for both backends.

---

## Validation Checklist
- `python -m py_compile` passes on all new/changed Python files.
- Smoke train/eval runs complete on RunPod with small step counts.
- Results are logged in `.agent/reports/experiment-ledger.md` with `compute=RunPod`.
- No regressions in existing Modal commands.

---

## Risks and Mitigations
Risk: Provider API/CLI differences and churn.
- Mitigation: isolate RunPod API usage to scripts/launcher wrapper.

Risk: Environment drift across providers (torch/cuda/unsloth compatibility).
- Mitigation: pin dependency versions and document a known-good container baseline.

Risk: Storage path mismatch causing missing checkpoints.
- Mitigation: enforce `CHECKPOINT_ROOT` contract and explicit path prints at startup.

Risk: Secret handling inconsistencies.
- Mitigation: env-based secret injection only; no hardcoded tokens in scripts.

---

## Rollback Plan
- If RunPod path is unstable, keep it behind separate scripts only.
- No codepath in Modal backend depends on RunPod modules.
- Remove/disable RunPod scripts without touching shared core.

---

## Implementation Handoff Notes
- Start with `runpod_worker.py` minimal functionality first.
- Validate with tiny runs (`max_steps=2`) before parity profiles.
- Keep diffs focused: orchestration + docs, not ML behavior.
