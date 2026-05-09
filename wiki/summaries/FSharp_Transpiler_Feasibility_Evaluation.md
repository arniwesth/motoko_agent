---
doc_type: short
full_text: sources/FSharp_Transpiler_Feasibility_Evaluation.md
---

# F# to AILANG Transpiler Feasibility Evaluation

This document evaluates a proposal to have Gemma 4 generate F# code and then transpile it to AILANG, circumventing the model’s difficulty with AILANG syntax. It weighs the technical feasibility, risks, and compares it to the structured tool-call authoring approach from the [[concepts/evidence-gates-levers]] analysis.

## Core Insight

Both the F# transpiler and structured tool-call authoring share the same goal: remove AILANG syntax from the model’s direct output. The evaluation acknowledges this insight is correct, but argues the execution vehicle matters.

## Sound Points

- ML-family languages (F# and AILANG) share constructs like ADTs and pattern matching, making a pure functional subset translatable.
- Source-mapped transpilation feedback is a valid self-correction loop (already present in `ailang check`).

## Critical Flaws

1. **Gemma 4’s F# capability is unverified.** No public benchmark data exists; the approach hinges on an untested premise. The document suggests running Gemma 4 on MultiPL-E’s F# split before any investment.
2. **AILANG-specific features have no F# representation.** Row-polymorphic effects, effect budgets, capabilities, inline tests, and the module system cannot be expressed cleanly. This leaves the hardest failure modes (effect errors) unaddressed unless effects are annotated manually, defeating the purpose.
3. **Toolchain fragmentation.** The transpiler requires a .NET runtime alongside the Go AILANG toolchain, adding complexity and maintenance.
4. **The “constrained F# subset” is barely F#.** Removing all unsupported features yields a tiny ML core that is still a novel dialect the model must learn.
5. **Moving target.** AILANG’s rapid evolution makes a transpiler a continual maintenance burden.

## Comparison with Structured Tool-Call Authoring

The [[concepts/structured-tool-call-authoring]] approach (lever 2 in evidence-gates) is preferred across nearly every dimension: it leverages Gemma 4’s confirmed tool‑calling strength, handles effects natively, deploys on existing infrastructure, provides granular error feedback, and composes with other levers (e.g., retrieval few‑shot). The F# transpiler’s one potential advantage — holistic program generation — is mitigated by composite tools like `scaffold_main`.

## Verdict

The document recommends against building the F# transpiler as a first investment. Instead:

1. **Test the F# premise:** benchmark Gemma 4 on F# tasks (MultiPL-E HumanEval F# split).
2. **Implement structured tool-call authoring** (lever 2) as the primary near‑term solution.
3. **Build the retrieval index** (lever 3) for known‑good AILANG snippets.
4. **Quantify failure modes** to confirm where errors lie.

If Gemma 4 demonstrates strong F# ability and tool‑call authoring hits a ceiling, the transpiler could be revisited as a complementary lever.

## Minimal Viable Transpiler (If Pursued)

Should the transpiler be built despite the recommendation, the document outlines a minimal scope: pure functional subset, explicit effect annotations via attributes, F# script using FCS, `ailang check` validation, and expression‑level constructs only (not modules/effects), pinned to a specific AILANG version.

[[concepts/gemma-4-ailang-capability-gap]]
[[concepts/structured-tool-call-authoring]]
[[concepts/ailang-effects]]
[[concepts/evidence-gates-levers]]