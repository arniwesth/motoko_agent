---
doc_type: short
full_text: sources/2026-04-19-runpod-additive-serverless-integration.md
---

# Summary: RunPod Additive + Serverless Integration

This session implemented RunPod orchestration for GRPO training using a strict additive approach, preserving the existing Modal workflow and provider-agnostic core ML logic. The plan was revised mid-session to make RunPod Serverless the primary execution path, with existing-pod SSH as a fallback.

## Key Contributions
- **Additive wrappers**: `runpod_worker.py` maps subcommands (`train-grpo`, `train-sft`, `build-sft-dataset`, `eval`) to shared `training_core`, `sft_core`, etc., without modifying those modules.
- **Preflight contract**: The worker enforces bootstrap checks (runtime binary `ailang`, docs, checkpoint root, shared imports) and fails fast with actionable errors.
- **Serverless transport**: `runpod_serverless_handler.py` acts as a RunPod serverless handler invoking the worker; `runpod_serverless.py` provides a local launcher for the RunPod API (`/run`, `/runsync`, status polling).
- **Container image**: A `Dockerfile.runpod_serverless` defines a serverless worker image with preflight-compatible defaults and an entrypoint to the handler.
- **Scripts**: Shell scripts for launching both serverless (primary) and pod‑based (fallback) training/evaluation profiles.
- **Documentation and plan**: `README.md` updated with RunPod requirements and smoke command examples; `RunPod_Additive_Integration_Plan.md` revised to serverless‑first.

## Design Principles
This work embodies an [[concepts/additive-integration]] strategy, where new orchestration layers are added without touching existing providers. The [[concepts/serverless-ml]] deployment path uses a [[concepts/bootstrap-contract]] enforced at worker startup to guarantee runtime consistency across environments.

## Validation
- Compile‑time checks (`py_compile`, `bash -n`) passed for new scripts and handlers.
- Diff‑based verification confirmed zero changes to Modal files or shared core modules.
- Eval output compatibility preserved with both human‑readable summary lines and structured JSON.

## Current State
The integration is additive, serverless‑first, and ready for user‑side deployment to a RunPod endpoint image and smoke testing.