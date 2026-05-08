---
sources: [summaries/Gemma4_FSharp_Benchmark_Results.md, summaries/GRPO_Pilot_AILANG.md]
brief: Using compiler pass/fail as a deterministic reward signal for RL training of code generation.
---

# Compiler as Reward Model for Code Generation

This concept describes the technique of using a compiler (or similar toolchain) as the primary reward signal in reinforcement learning for code‑generation tasks. Instead of training a learned reward model on human feedback, the compiler itself provides a deterministic, interpretable signal based on whether the generated code passes syntax checks, type checking, execution, or formal verification. This approach is especially effective when the model's primary failure mode is compilation errors, as it directly optimises for syntactic and semantic correctness.

## How It Works

In a typical RL fine‑tuning loop (e.g., GRPO), the model generates code completions for a prompt. Each completion is then fed to the compiler via subprocess calls. The compiler’s output – pass/fail status, runtime behaviour, verification result – is mapped to a scalar reward. The rewards are layered from cheapest to most expensive:
1. **Code extraction:** can the response be parsed into a code block? (binary reward)
2. **Check pass:** does `compile/check` return success? (positive for pass, penalised for parse errors)
3. **Run correctness:** does the program produce the expected output? (positive for exact match, small credit for successful execution even with wrong output)
4. **Verification:** do formal contracts (if present) verify? (large positive for full verification, negative for violations)

The rewards are independent, so the model can earn credit even if some checks are skipped because the problem doesn’t require runtime verification or has no contracts. A crucial design choice is that when a reward function cannot act (e.g., no expected output, or no contracts in the code), it returns **0.0 (neutral)**, avoiding unjustified penalties.

## Key Details from [[summaries/GRPO_Pilot_AILANG]]

- **Compiler as oracle:** The `ailang` tool is called directly via subprocess – no approximations. This removes the need for a learned reward model and guarantees a ground‑truth signal.
- **Target failure mode:** The baseline Gemma 4 model achieves 62.7% compile rate; 90.4% of its failures are compile errors. Therefore, rewarding `ailang check` pass directly addresses the most common weakness.
- **Safety:** Every compiler invocation is wrapped in a timeout and exception handler; if the compiler crashes or hangs, the reward falls back to 0.0, keeping the training loop stable.
- **Scalability:** The four functions are applied per completion, and the reward scores are summed by the GRPOTrainer. The entire pipeline runs on a single A100 GPU with QLoRA and a 32K‑token context window (system prompt ~17K tokens).
- **Comparison:** A held‑out evaluation set of new prompts will be used to compare the GRPO‑tuned model’s pass rate against the base model, proving the efficacy of compiler‑as‑reward fine‑tuning.

## Advantages

- **Deterministic & interpretable:** The reward is based on objective criteria (compilation, runtime output, verification) rather than learned, potentially biased preferences.
- **Efficient iteration:** No reward model training overhead; any improvements in the compiler automatically improve the reward signal.
- **Directly targets the problem:** Because the model struggles most with syntax/type errors, rewarding `check` pass directly pushes it toward valid code.
- **Generalizable:** This pattern can be reused for any language with a command‑line compiler/interpreter that reports structured results (e.g., `rustc`, `ghc`, `python -m py_compile`).

## Related Concepts

- [[concepts/reinforcement-learning-code-generation]] – the broader paradigm of using RL to improve code‑generating LLMs
- [[summaries/GRPO_Pilot_AILANG]] – the practical implementation of this concept in the AILANG/Gemma‑4 proof‑of‑concept

See also: [[summaries/Gemma4_FSharp_Benchmark_Results]]