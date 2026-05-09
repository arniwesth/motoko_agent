---
doc_type: short
full_text: sources/Gemma4_AILANG_GRPO_Reinforcement_Learning.md
---

# Gemma-4-AILANG: GRPO Reinforcement Learning Approach

## Summary

This document proposes a two-phase training pipeline for teaching Gemma 4 to generate correct, verified AILANG code: **SFT warmup followed by GRPO refinement**. The core insight is that the AILANG compiler and Z3 verifier serve as perfect, ground-truth reward oracles, enabling the model to surpass the performance ceiling imposed by pure SFT distillation from a teacher model (Claude Opus).

## Motivation: Why RL Beats Pure SFT

- **SFT has a hard ceiling** at the teacher's performance. If Opus scores 0-17% on contract benchmarks (Contract Matrix Determinant, Contract Rle Roundtrip, Type Unify), the student cannot exceed this by imitation.
- **RL learns from ground truth**, not teacher preferences. The model discovers what actually compiles and verifies — the same insight behind DeepSeek-R1 and AlphaGo.
- **AILANG provides three deterministic oracles** of increasing power: `ailang check` (syntax/types), `ailang run` (runtime correctness), and `ailang verify` (Z3 mathematical verification for all inputs). The compiler IS the reward model.

## The Unsloth Sudoku GRPO Pattern

The approach is modeled on Unsloth's notebook that trains Gemma 4 to solve Sudoku via Group Relative Policy Optimization ([[concepts/GRPO]]):
- Model generates multiple completions per prompt at temperature=1.0
- Three layered reward functions score each completion against ground truth
- GRPO updates policy toward higher-reward completions
- Key property: rewards come from executing code, not a learned preference model

## Proposed Reward Functions for AILANG

Three graduated reward functions create a gradient the model can climb:

1. **`ailang_parses`** — Does the code parse and type-check? (-2.0 to +2.0)
2. **`ailang_correct_output`** — Does execution produce expected output? (0.0 to +5.0)
3. **`ailang_verified`** — Do Z3 contracts verify? (-3.0 to +10.0, the strongest signal)

This implements [[concepts/reward-shaping]]: a numeric gradient from "doesn't parse" (-2.0) through "correct output" (+5.0) to "verified contracts" (+10.0), giving GRPO a learnable path rather than sparse pass/fail signals.

## Training Pipeline

| Phase | Method | Goal | Hardware |
|-------|--------|------|----------|
| Phase 0 | SFT QLoRA (~500 examples) | Teach AILANG syntax shape. >40% parse rate. | 1× A100 |
| Phase 1 | GRPO QLoRA (pilot) | Refine via [[concepts/compiler-as-reward-model]]. >70% parse, first Z3 contracts. | 1× A100 |
| Phase 2 | GRPO (full) | Scale up. >90% parse, >50% on contract benchmarks. | 8× H100 |

## Practical Concerns

- **Reward latency**: Shelling out to the `ailang` binary adds ~100ms–1s per check. Mitigated by batching or persistent process.
- **Prompt diversity**: Unlike Sudoku's single fixed prompt, AILANG needs diverse tasks — the existing benchmark suite at `ailang.sunholo.com/docs/benchmarks/performance` provides this.
- **SFT warmup is mandatory**: Skipping SFT means every RL completion is pure Python scoring -2.0; GRPO learns nothing. The model must be in the "AILANG-shaped" basin of attraction first.
- **Binary availability**: The `ailang` compiler must be present in the training environment (Docker, sidecar, or vendored fork).

## Key Takeaway

The [[concepts/Z3-verification]] oracle is the killer advantage. No human annotation, no learned reward model, no teacher errors. The compiler and verifier provide mathematically perfect reward signals. The SFT + GRPO pipeline leverages the existing Unsloth Sudoku template directly, replacing game-state rewards with compiler/verifier rewards — a path to exceeding LLM frontier model performance on contract benchmarks.