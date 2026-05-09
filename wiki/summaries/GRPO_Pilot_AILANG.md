---
doc_type: short
full_text: sources/GRPO_Pilot_AILANG.md
---

# GRPO Pilot Summary

This document presents a proof-of-concept for **GRPO (Group Relative Policy Optimization) [[concepts/reinforcement-learning-code-generation]]** to improve Gemma 4's ability to produce AILANG code that compiles, runs correctly, and passes formal verification. The core idea is to use the AILANG compiler itself (`ailang check`, `ailang run`, `ailang verify`) as the reward signal — no learned reward model, just shelling out to the real toolchain. The architecture layers four reward functions (code extraction, check pass, run correctness, contract verification) onto a QLoRA‑tuned Gemma 4 model, using TRL's `GRPOTrainer` and Unsloth for efficiency. A dual‑platform setup (Modal for rapid iteration, RunPod/Lambda for longer runs) keeps the pilot modular. The dataset is ~30 hand‑crafted prompts across three difficulty tiers, each with expected outputs where possible. The system prompt includes the full 17K‑token AILANG documentation, eliminating the need for condensation. The evaluation script compares base vs. GRPO‑tuned pass rates on a held‑out set to measure improvement over the current 62.7% compile‑rate baseline. The approach sidesteps SFT warmup by relying on Gemma 4’s existing AILANG writing ability, and it explicitly defers large‑scale dataset generation and multi‑GPU training to a later phase.

## Related Concepts
- [[concepts/compiler-as-reward-model]]
- [[concepts/grpo-training-loop]]
