---
sources: [summaries/Gemma4_FSharp_Benchmark_Results.md]
brief: Routing prompts by target language to load language-specific teacher content from a central registry.
---

# Language-Dependent Prompt Routing

## Definition

Language-Dependent Prompt Routing is the architecture pattern used in the AILANG evaluation harness that dynamically selects and assembles prompts based on the target programming language. Rather than using a single universal prompt, the system routes to language-specific teacher prompts loaded from the [[concepts/Prompt_Registry]], enabling fair comparisons across languages in [[summaries/Gemma4_FSharp_Benchmark_Results|benchmarking]] scenarios.

## Routing Architecture

### Entry Points

There are two distinct routing paths depending on evaluation mode:

- **Standard eval mode** (`eval-suite`, non-agent): Entry point is `BenchmarkSpec.PromptForLanguage(lang)` in `internal/eval_harness/spec.go`.
- **Agent eval mode** (`eval-suite --agent`): Entry point is `GenerateAgentPromptsWithSystemPrompt(...)` in `internal/eval_harness/agent_prompt.go`.

### Language-Specific Behavior

The routing logic maps each target language to a distinct prompt-loading strategy:

| Language | Prompt Source | Task Handling |
|---|---|---|
| `ailang` | Default prompt from registry via `promptpkg.LoadPrompt("")` | Task appended under `## Task` |
| `fsharp` | Registry key `"fsharp"` via `promptpkg.LoadPrompt("fsharp")` | Task appended under `## Task` |
| `fsharp-constrained` | Same `"fsharp"` teacher base prompt, plus constrained subset rules appended | Task appended under `## Task` |
| `python` | Existing non-teacher path (inline or language-specific default) | Varies |

### System Prompt vs User Prompt

A critical design detail of the routing architecture:

- **Standard mode**: System prompt remains a **fixed generic instruction** (from `internal/eval_harness/ai_provider.go`). All language teaching content is carried in the **user prompt**. This means the model's system-level context remains constant across languages.
- **Agent mode**: System prompt becomes **language-specific**, loaded from the [[concepts/Prompt_Registry|prompt registry]]. Task prompts come from language-specific templates in `internal/eval_harness/templates/agent_task_*.txt`.

## Role in the F# Benchmark

This routing mechanism was central to the fair comparison in the [[summaries/Gemma4_FSharp_Benchmark_Results|Gemma 4 F# Benchmark]]. Earlier benchmark runs used different prompt-loading behavior that may have disadvantaged F#. The updated "teacher-prompt fair comparison" run ensured:

1. F# received a dedicated teacher prompt teaching the model how to write correct F#.
2. AILANG used its standard prompt from the same registry system.
3. Both languages received their task descriptions in structurally equivalent ways (`## Task` section appended).

The routing design made it possible to isolate the effect of the **language itself** from the effect of **how well the model was taught** that language.

## Design Implications

- **Extensibility**: Adding a new target language requires only a new registry key and a branch in the routing function — no changes to core evaluation logic.
- **Fairness**: By routing through a shared registry, all languages receive prompts authored with equivalent care and effort, reducing prompt-engineering confounds.
- **Modality split**: The standard-mode decision to keep language teaching in user prompts (not system prompts) preserves the model's generic instruction-following baseline while allowing language-specific guidance.

## Related Pages

- [[concepts/Prompt_Registry]] — Central store from which language-specific prompts are loaded
- [[summaries/Gemma4_FSharp_Benchmark_Results]] — Benchmark that depended on this routing for fair AILANG vs F# comparison
- [[concepts/Transpiler_Feasibility]] — The broader research question motivating the language comparison
- [[concepts/LLM_Code_Generation_Evaluation]] — Evaluation methodology context