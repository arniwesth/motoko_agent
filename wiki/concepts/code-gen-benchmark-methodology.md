---
sources: [summaries/Generate_data_for_AILANG_finetuning.md, summaries/Gemma4_FSharp_Benchmark_Results.md]
brief: A structured approach for evaluating LLM code generation using comparative conditions, multi-seed runs, layered pass metrics, and explicit go/no-go decision bands.
---

# LLM Code Generation Benchmark Methodology

A structured evaluation framework for measuring and comparing LLM performance on code generation tasks. The methodology was developed and applied in the [[summaries/Gemma4_FSharp_Benchmark_Results|Gemma 4 F# benchmark]], where it served as the gating experiment for the [[concepts/Transpiler_Feasibility|transpiler investment decision]].

## Core Design Principles

### Comparative Conditions
Every benchmark defines a **baseline** condition and one or more **experimental** conditions. In the F# benchmark, AILANG served as the baseline, with F# unconstrained and F# constrained as experimental variants. This structure isolates the effect of the variable under test (language choice, prompt design, constraints) rather than measuring absolute model capability.

### Multi-Seed Repetition
Each condition is evaluated across multiple seeds (typically 3) to capture stochastic variance. The F# benchmark used seeds 42, 43, and 44, yielding 42 tasks × 3 seeds = 126 trials per condition. Results are reported both in aggregate (all seeds combined) and per-seed to reveal consistency patterns.

### Self-Repair
Evaluations are run with self-repair enabled: the model is given the opportunity to revise failed solutions based on error feedback. This separates **first-attempt** capability (raw generation) from **final pass** capability (generation + correction), providing a more realistic picture of iterative authoring workflows.

## Metric Hierarchy

### Primary Metrics
| Metric | Definition |
|---|---|
| **Compile Rate** | Proportion of generated solutions that compile successfully |
| **Runtime OK Rate** | Proportion of compiled solutions that execute without runtime errors |
| **First-Attempt Pass** | Solutions passing both compile and runtime on the first generation (before any repair) |
| **Final Pass** | Solutions passing both compile and runtime after self-repair (if repair was attempted) |

### Secondary Metrics
| Metric | Definition |
|---|---|
| **Repair Used** | Number of runs where self-repair was triggered |
| **Repair Success** | Proportion of repair attempts that produced a passing solution |
| **Mean Output Tokens** | Average generation size, useful for comparing verbosity/style between conditions |

### Delta Analysis
All experimental conditions are reported as **deltas vs baseline** (in percentage points), not just as raw pass rates. This frames the results in terms of _gain_ or _loss_ relative to the status quo.

## Failure Mode Classification

Failures are categorized into three mutually exclusive buckets:

1. **Compile failures** — the generated code does not parse or type-check
2. **Runtime failures** — the code compiles but crashes, hangs, or throws during execution
3. **Logic failures** — the code runs but produces incorrect results

The distribution of failure modes reveals _how_ a condition changes failure behavior, not just _whether_ it changes pass rates. In the F# benchmark, this analysis showed that F# unconstrained dramatically reduced compile failures but introduced more logic mismatches — a tradeoff invisible in aggregate pass rates alone.

### Per-Problem Majority Comparison
A 3-seed voting analysis categorizes each task into one of four outcome buckets:

- **Advantage**: experimental condition passes majority while baseline fails
- **Disadvantage**: baseline passes majority while experimental condition fails
- **Both pass**: no differential signal
- **Both fail**: no differential signal

This complements aggregate metrics by showing how many _individual problems_ flip one way or the other, rather than conflating large gains on easy problems with small gains on hard ones.

## Go / No-Go Decision Framework

The methodology includes an explicit **decision gating** structure with predefined thresholds:

| Band | Constrained Pass Rate | Delta vs Baseline | Action |
|---|---|---|---|
| **Go** | >85% | >15 pp | Proceed with investment |
| **Marginal** | 70–85% | 10–15 pp | Requires further analysis |
| **No-go** | <70% | <10 pp | Reject; pursue alternatives |

This framework ensures that benchmark results translate directly into engineering decisions, avoiding the ambiguity of "improved but insufficient" data interpretation. For the [[summaries/Gemma4_FSharp_Benchmark_Results|F# benchmark]], constrained F# (63.5%, +4.8 pp) fell clearly into the no-go band.

## Prompt Architecture

### Language-Dependent Prompt Paths
A critical methodological detail: prompts are assembled through language-specific loading paths (e.g., `BenchmarkSpec.PromptForLanguage`), ensuring each condition receives an appropriate teaching prompt. In the F# benchmark:

- **AILANG** uses the default [[concepts/Prompt_Registry|prompt registry]] version
- **F#** loads a dedicated `fsharp` key from the registry ("teacher prompt")
- **F# constrained** uses the same teacher prompt with additional constraint rules appended

System prompts remain generic; all language-teaching content is carried in the **user prompt** in standard eval mode. This design prevents the system prompt from becoming a confounding variable.

### Fairness
A "fair prompt setup" means each language receives a comparably informative teaching prompt. Prior runs that lacked this balance were deprecated in favor of teacher-prompt fairness, highlighting that prompt quality is itself a variable that must be controlled.

## Reproducibility

- `--seed` values are recorded in metrics artifacts
- However, seed propagation into provider request options may be incomplete — runs remain stochastic
- Seed labels alone do not guarantee deterministic replay unless the full generation configuration (temperature, sampling parameters) is also captured

## Related Concepts

- [[concepts/Transpiler_Feasibility]] — the investment decision this methodology gates
- [[concepts/Prompt_Registry]] — the prompt versioning system that enables language-dependent loading
- [[concepts/FSharp]] — one of the target languages benchmarked
- [[concepts/Self_Repair_in_LLM_Code_Generation]] — the repair mechanism underlying first-attempt vs final-pass distinction
- [[concepts/LLM_Code_Generation_Evaluation]] — broader evaluation paradigms beyond this specific methodology
- [[summaries/Gemma4_FSharp_Benchmark_Results]] — the concrete application of this methodology

See also: [[summaries/Generate_data_for_AILANG_finetuning]]