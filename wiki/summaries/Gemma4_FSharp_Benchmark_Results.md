---
doc_type: short
full_text: sources/Gemma4_FSharp_Benchmark_Results.md
---

# Gemma 4 F# Benchmark Results Summary

This benchmark evaluated Gemma 4's ability to write F# vs AILANG for code generation tasks, serving as the gating experiment for the [[concepts/Transpiler_Feasibility|transpiler]] idea. The study compared three conditions across 42 tasks: AILANG baseline, F# unconstrained, and F# constrained, each with three seeds (42–44). Self-repair was enabled.

**Key Findings:**
- F# unconstrained improved final pass rate by +8.0 pp (66.7%) over AILANG (58.7%), with first-attempt pass rate up +21.4 pp. However, failure modes shifted from compile errors to logic mismatches.
- F# constrained (limited subset) achieved only +4.8 pp (63.5%) final pass rate, well below the “go” threshold (>85% pass and >15 pp delta).
- Neither F# variant met the decision criteria, resulting in a **No-go** decision — transpiler investment is not justified; focus shifts to lower-risk alternatives like structured tool-call authoring.

**Methodology:**
- 42 tasks × 3 seeds × 3 conditions = 378 runs. Metrics: compile rate, runtime OK, first-attempt pass, final pass, repair usage, token counts.
- Fair “teacher prompt” setup: F# prompts loaded from the [[concepts/Prompt_Registry]] (via `promptpkg.LoadPrompt("fsharp")`), distinct from AILANG’s default prompt.

**Failure Patterns:**
- AILANG failures dominated by compile errors (90.4% of failures). F# unconstrained nearly eliminated compile failures but introduced logic mismatches (59.5% of failures). F# constrained still had significant compile pressure (71.7% of failures) but fewer logic issues.

**Architecture Note:**
- Prompt assembly follows language-dependent paths (`BenchmarkSpec.PromptForLanguage`). System prompts remain generic; language teaching is carried in user prompts. (Agent mode uses language-specific system prompts from the registry.)

This benchmark directly informed the go/no-go decision and supports the broader [[concepts/LLM_Code_Generation_Evaluation|LLM evaluation]] methodology. See also [[concepts/FSharp]] and the underlying feasibility research at `.agent/research/FSharp_Transpiler_Feasibility_Evaluation.md`.

## Related Concepts
- [[concepts/code-gen-benchmark-methodology]]
- [[concepts/language-prompt-routing]]
- [[concepts/compiler-as-reward-model]]
