# 2026-04-18 — GRPO Pilot (AILANG) Implementation Summary

## Context
Implemented the plan in `.agent/plans/GRPO_Pilot_AILANG.md` by creating a full pilot scaffold under `training/grpo_pilot/`.

## What Was Implemented

### 1. Dataset / Prompt Pack
Created `training/grpo_pilot/prompts.jsonl` with 40 entries:
- 30 `train` prompts
- 10 `eval` prompts
- Metadata included per prompt: `id`, `split`, `difficulty`, `caps`, `has_contracts`, `prompt`, `expected_output`

Coverage includes easy/medium/hard tasks, stdlib usage, ADTs, recursion, and contract-oriented tasks.

### 2. Shared AILANG Execution Helpers
Created `training/grpo_pilot/ailang_helpers.py`:
- Extracts AILANG code blocks from model completions (`extract_ailang_code`)
- Injects missing module line (`module benchmark/solution`)
- Writes temp `.ail` files under `/tmp/ailang_grpo`
- Wraps subprocess execution with timeout/error handling for:
  - `ailang check -json`
  - `ailang run --caps ...`
  - `ailang verify`
- Classifies check failures (`parse`, `type`, `effect`, etc.)
- Normalizes stdout and prunes temp files

### 3. Reward Functions
Created `training/grpo_pilot/reward_functions.py` with the four reward functions from plan intent:
- `code_extractable`
- `ailang_check_passes`
- `ailang_runs_correctly`
- `ailang_verifies`

Implementation details:
- Defensive completion parsing for common TRL completion shapes
- Uses per-item metadata (`expected_output`, `caps`, `has_contracts`) via `**kwargs`
- Returns neutral `0.0` on no-code, timeout, tool failure, or non-actionable cases to avoid training loop crashes
- Exports `REWARD_FNS` list for trainer wiring

### 4. Shared Training Core
Created `training/grpo_pilot/training_core.py`:
- `TrainConfig` dataclass for model/data/hyperparameters
- Loads full docs prompt from `ailang-v0.9.0-docs.md`
- Builds chat-format prompt messages (`system` + `user`)
- Creates dataset by sampling prompts for `max_steps`
- Loads model with Unsloth and applies LoRA (`r=32`, target linear layers)
- Builds GRPO config and runs `GRPOTrainer`
- Saves adapter and tokenizer artifacts

### 5. Dual Wrappers
Created:
- `training/grpo_pilot/modal_train.py`
- `training/grpo_pilot/standalone_train.py`

Modal wrapper:
- Defines image, installs deps, mounts docs + training dir
- Includes local `ailang-amd64` at `/usr/local/bin/ailang`
- Uses A100-80GB function config and modal volume for checkpoints
- Reads HF token via `huggingface-secret`

Standalone wrapper:
- `argparse` CLI over shared `TrainConfig`
- Calls shared `run_training`

### 6. Evaluation Script
Created `training/grpo_pilot/evaluate.py`:
- Loads base model + tokenizer
- Loads LoRA adapter over base model (`peft`)
- Runs eval split prompts with multiple sampled completions per prompt
- Uses `ailang check -json` compile pass as metric
- Prints base vs LoRA pass rates and delta

### 7. Setup + Documentation
Created:
- `training/grpo_pilot/setup.sh`
- `training/grpo_pilot/README.md`
- `training/grpo_pilot/__init__.py`

`setup.sh` installs deps, builds `ailang-amd64`, checks GPU visibility, and verifies binary execution.

README documents architecture, prerequisites, Modal/standalone quickstarts, and evaluation commands.

## Validation Performed
- Python syntax validation (`python -m py_compile`) for all new Python files: passed
- JSONL sanity check:
  - total rows = 40
  - split counts = 30 train / 10 eval
  - required fields `id` and `prompt` present on all entries
- Reward smoke checks:
  - extractable code returns positive
  - non-code returns negative for R1
  - `ailang_check_passes` returns neutral on non-code

## Not Executed (Pending)
- No full GRPO training run was executed
- No end-to-end `evaluate.py` benchmark run was executed
- No Modal deployment run was executed

## Deliverables Added
- `training/grpo_pilot/ailang_helpers.py`
- `training/grpo_pilot/reward_functions.py`
- `training/grpo_pilot/training_core.py`
- `training/grpo_pilot/modal_train.py`
- `training/grpo_pilot/standalone_train.py`
- `training/grpo_pilot/evaluate.py`
- `training/grpo_pilot/setup.sh`
- `training/grpo_pilot/README.md`
- `training/grpo_pilot/prompts.jsonl`
- `training/grpo_pilot/__init__.py`
