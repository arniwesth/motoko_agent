---
doc_type: short
full_text: sources/RunPod_Additive_Integration_Kickoff.md
---

# RunPod Additive Integration Kickoff Summary

This document initiates Phase 1 of integrating RunPod as an alternative compute provider for GRPO/SFT training and evaluation. It enforces an **additive strategy**: keep the Modal workflow intact and add RunPod as a parallel option without altering shared core logic.

## Key Directives
- **Additive only** – No replacement or modification of Modal. All changes are new files/scripts that coexist.
- **Provider-agnostic core** – Shared modules (`training_core.py`, `sft_core.py`, `evaluate.py`) stay unchanged.
- **Orchestration layer** – New worker entrypoints, shell scripts, and configuration isolate RunPod differences.
- **No secrets in code** – Environment variables used via `.env.runpod.example`.

## Implementation Scope (Phase 1)
1. **RunPod worker entrypoint** (`runpod_worker.py`) with subcommands `train-grpo`, `train-sft`, `build-sft-dataset`, `eval`, each mapping to existing core modules.
2. **Preflight validation** (bootstrap contract) that checks binary availability, file paths, permissions, and Python imports before execution, failing fast with clear messages.
3. **RunPod scripts** for existing-pod interaction: launcher placeholder, train/eval profile scripts. Canonical path is SSH-based execution on an already running pod.
4. **Environment template** (`.env.runpod.example`) documenting required variables.
5. **Documentation update** adding a “RunPod Backend” section to the README with copy-paste commands and provider comparison.

## Output & Validation
- Checkpoints saved under `CHECKPOINT_ROOT/<subdir>`, eval output compatible with existing summaries.
- Smoke tests required for GRPO, SFT, and eval using minimal steps.
- No regression to Modal commands confirmed.

## Cross-Cutting Concepts
- [[concepts/backend_abstraction]] – The pattern of separating provider-specific orchestration from shared training logic.
- [[concepts/bootstrap_contract]] – Preflight checks that ensure runtime readiness.
- [[concepts/additive_integration]] – The principle of adding new capabilities without breaking or modifying existing ones.
- [[concepts/provider_differences]] – Tracking Modal vs. RunPod environment and workflow distinctions.

## Significance
This kickoff sets the strict boundaries for an initial, non-disruptive RunPod integration, reducing risk while enabling future phases to expand orchestration (e.g., full API management).