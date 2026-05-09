---
doc_type: short
full_text: sources/2026-04-18-grpo-pilot-ailang.md
---

## Summary

This document details the implementation of a GRPO (Group Relative Policy Optimization) pilot for fine‑tuning language models to generate correct AILANG code. The scaffold includes a 40‑entry prompt dataset (`train`/`eval` splits), shared execution helpers for AILANG (`check`, `run`, `verify`), and four reward functions (`code_extractable`, `ailang_check_passes`, `ailang_runs_correctly`, `ailang_verifies`). A reusable training core built with Unsloth and LoRA (`r=32`) is provided, along with dual wrappers for both Modal (GPU cloud) and standalone local execution. Evaluation logic measures compile‑pass improvement before and after adapter injection.

## Key Components

- **Dataset**: 30 train + 10 eval prompts spanning easy/medium/hard tasks, ADTs, recursion, and contracts (`prompts.jsonl`).
- **Execution Helpers**: `ailang_helpers.py` extracts AILANG code from completions, writes temp files, and wraps subprocess calls for `ailang check`, `run`, and `verify` with robust timeout/error handling.
- **[[concepts/reward-functions|Reward Functions]]**: Four stages (`code_extractable` → `check_passes` → `runs_correctly` → `verifies`) that return neutral `0.0` on non‑actionable completions to avoid training crashes. They use per‑item metadata (expected output, capability flags, contract presence) via `**kwargs`.
- **Training Core**: `training_core.py` builds chat messages with full AILANG docs, creates a fixed‑step dataset, loads a model with Unsloth + LoRA, and runs `GRPOTrainer`.
- **Wrappers**: `modal_train.py` deploys on Modal with A100‑80GB, mounts an `ailang` binary, and uses a Hugging Face secret. `standalone_train.py` offers an `argparse` CLI.
- **Evaluation**: `evaluate.py` loads the base model & LoRA adapter, samples multiple completions per prompt, and reports compile‑pass rate deltas.

## Concepts & Connections

- [[concepts/grpo]] – The reinforcement‑learning‑from‑feedback algorithm used for policy optimization without a critic.
- [[concepts/ailang]] – The functional, contract‑oriented language that models are trained to generate.
- [[concepts/reward-modelling]] – Multi‑step reward design that guides the model from syntactic correctness to full verification.
- [[concepts/lora-fine-tuning]] – Parameter‑efficient fine‑tuning via low‑rank adapters, integrated with Unsloth.
- [[concepts/modal-deployment]] – Cloud‑based GPU orchestration for large‑scale training jobs.

## Status

All Python files passed syntax checks, the dataset is validated, and reward functions were smoke‑tested. No full training or evaluation run was executed—those remain pending.