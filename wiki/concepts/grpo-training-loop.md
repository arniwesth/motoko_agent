---
sources: [summaries/Generate_data_for_AILANG_finetuning.md, summaries/GRPO_Pilot_AILANG.md]
brief: GRPO loop: model generates multiple completions, compiler rewards score them, policy updated via GRPO.
---

# GRPO Training Loop Architecture

The **GRPO (Group Relative Policy Optimization) training loop** is a reinforcement learning design that fine‑tunes a language model to produce code that passes a real‑compiler‑based reward suite. It is central to the [[summaries/GRPO_Pilot_AILANG]] proof‑of‑concept for AILANG code generation.

## Core Loop

```
System Prompt (full AILANG docs)
         +
User Prompt (coding task)
         ▼
   [Gemma 4 + QLoRA]
         │
         ▼
 N completions (AILANG code)
         │
         ▼
┌───────────────────────┐
│  Reward Functions     │
│ 1. code_extractable   │
│ 2. ailang_check       │
│ 3. ailang_run         │
│ 4. ailang_verify      │
└───────────────────────┘
         │
         ▼
    Reward scores
         │
         ▼
 Policy update via GRPO
```

## Key Components

1. **Model + QLoRA** – Gemma 4 (dense or MoE) with a lightweight LoRA adapter, enabling training on a single A100‑80GB GPU. The full AILANG documentation (~17K tokens) is used as the system prompt without summarization.

2. **Multi‑Sample Generation** – For each training prompt, the model produces _N_ completions (e.g., _N_=4). This group is used by GRPO to compute relative advantages — the model learns from the best completions within the group.

3. **Reward Functions** – Four independent functions, layered from cheap to expensive, that shell out to the real `ailang` binary:
   * `code_extractable` – checks if a code block was produced.
   * `ailang_check_passes` – runs the compiler’s static check.
   * `ailang_runs_correctly` – executes the program and compares output.
   * `ailang_verifies` – runs formal contract verification.
   Each function returns a numeric score (positive for success, negative for failure, 0.0 when not applicable). Scores are summed into a per‑completion reward.

4. **GRPO Update** – Unlike standard PPO, GRPO compares completions generated for the _same_ prompt to compute advantages, avoiding the need for a separate value network. The policy is updated to increase the probability of high‑reward outputs and decrease that of low‑reward outputs, while staying close to the reference model via a KL‑divergence penalty.

## Why This Architecture?

The baseline Gemma 4 model already writes decent AILANG but makes compilation errors ~90% of failure cases. The compiler itself is the perfect oracle for those errors. By making the compiler the reward signal, the model receives targeted gradients that push it toward syntactically and semantically valid code. The layered reward functions allow the model to get partial credit for passing earlier stages (e.g., `check` passes but `run` fails), providing a smoother learning signal than a binary pass/fail.

## Implementation Context

This loop is implemented using **TRL’s `GRPOTrainer`** with **Unsloth** for efficient QLoRA fine‑tuning. Training runs for a short proof‑of‑concept (60 steps) with a small set of hand‑crafted prompts. The dual‑platform design (Modal for rapid iteration, RunPod/Lambda for longer runs) keeps the pilot flexible and cost‑effective.

## Related Concepts

* [[concepts/reinforcement-learning-code-generation]] – The broader idea of using RL to improve code generation models.
* [[concepts/compiler-based-rewards]] – Reward functions that invoke a real compiler to evaluate code.
* [[summaries/GRPO_Pilot_AILANG]] – The source document detailing the entire pilot project.


See also: [[summaries/Generate_data_for_AILANG_finetuning]]