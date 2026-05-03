# F# to AILANG Transpiler — Feasibility Evaluation

**Date:** 2026-04-17
**Input:** `.agent/research/FSharp_to_AILANG_transript.md`, `.agent/research/AILANG_performance_evidence_gates.md`, AILANG source (`ailang/`)

## Summary

The F# transpiler idea correctly identifies a real problem (Gemma 4 26B A4B-it cannot reliably produce valid AILANG) but proposes a solution that is heavier, riskier, and less capable than alternatives already designed in the evidence-gates research. Structured tool-call authoring (lever 2 in the evidence-gates doc) achieves the same goal — removing AILANG syntax from the model's responsibilities — with lower cost, better deployability, and native support for AILANG-specific features the transpiler cannot represent.

---

## The Problem Is Real

Gemma 4 26B A4B-it (3.8B active MoE) struggles with AILANG syntax. This is a distribution-shift problem, not a reasoning problem. Symptoms: recurrent parse failures, effect-row type errors, Python/JS/Go syntax leaking into output (`def`, `for`, `while`, `class`, method-call syntax). The evidence-gates doc diagnoses this precisely.

Frontier models (GPT-5-4, Claude Opus 4.6, Claude Sonnet 4.6) handle AILANG at 80-87% pass / 96-98% compile despite AILANG also being outside *their* training distribution. The evidence-gates doc hypothesizes this is because frontier models have stronger ML-family priors (Haskell/OCaml/F#) and greater in-context learning capacity — a plausible explanation, but not verified against training data we don't have access to.

AILANG's existing teaching infrastructure — 1,877-line prompt, `ailang check` feedback, MCP tools, eval harness — is already achieving high compile rates on frontier models, confirming the infrastructure works when the model has sufficient capability. The gap is model capability, not tooling.

## What the Transcript Proposes

Use F# as a "High-Level IR": Gemma 4 generates F# (claimed to be well-represented in its training data), a transpiler converts F# to AILANG using F# Compiler Services (FCS), and transpilation errors are fed back to the model for self-correction. The transcript frames this as a "double-lock safety system" where F# validates logic and AILANG validates determinism/effects.

## Where the Transcript's Analysis Is Sound

1. **Both languages are ML-family.** ADTs, pattern matching, type inference, immutability-by-default are shared. The "semantic distance" for pure functional core constructs is genuinely short.
2. **The feedback loop architecture is sound.** Source-mapped transpilation errors fed back to the model is a good pattern (though it is not unique to this approach — `ailang check` already provides it).
3. **The "pure subset" constraint is correctly identified as necessary.** The transcript acknowledges full .NET F# is not feasible and scopes to a restricted pure-functional subset.

## Where the Transcript's Analysis Fails

### 1. Unverified premise: Gemma 4's F# capability is unknown

The transcript claims Gemma 4 is "surprisingly good at writing F#." No public evidence supports or contradicts this:

- **LiveCodeBench v6**: Python-only (competitive programming). No F# testing.
- **Aider Polyglot**: 6 languages (C++, Go, Java, JavaScript, Python, Rust). No F#.
- **MultiPL-E**: Translates HumanEval/MBPP into 18 languages *including F#*, but no published Gemma 4 results.
- **Gemma 4 model card**: Lists "140+ languages" (natural languages). No programming-language-specific benchmarks.
- **Gemma 4 training mix**: Unknown. The evidence-gates doc hypothesizes it is "presumably heavier on Python/JS/Go" — this is an LLM's speculative explanation for the observed frontier-vs-Gemma gap, not established fact.

The state of knowledge is genuinely unknown. Gemma 4 might be passable at F#, or it might struggle for the same distribution reasons it struggles with AILANG (F# is ~0.3% of GitHub). The entire transpiler approach hinges on this being favorable, and it has not been tested.

**This is a testable question.** Before investing in transpiler infrastructure, run Gemma 4 on MultiPL-E's F# split (or a comparable F# benchmark) and measure its pass rate against Python. If F# performance is materially better than AILANG performance, the transpiler premise holds. If not, it collapses.

The evidence-gates doc's recommended levers (structured tool-call authoring, retrieval few-shot) rely on capabilities known to be strong in Gemma 4: native tool calling and JSON schema adherence. The F# transpiler relies on an unverified capability. That asymmetry in evidence is the risk — not a certainty that Gemma 4 is bad at F#.

### 2. AILANG-specific features have no F# representation

AILANG's distinguishing features — the features that justify its existence — are not expressible in F#:

- **Row-polymorphic algebraic effects** (`! {IO, FS @limit=5, e}`): F# has no effect system. Computation expressions are monadic, not algebraic, and don't compose via row polymorphism.
- **Effect budgets** (`@limit=N`, `@min=N`): Novel to AILANG. No source-language representation.
- **Capability-based security** (`--caps IO,FS`): Runtime capability gating has no F# parallel.
- **Inline tests/properties** (`func f(x) tests [(1,1), (5,120)] { ... }`): No F# equivalent.
- **AILANG module system**: Path-based (`module std/list`), not F# namespaces.

A transpiler that strips these produces code that doesn't use AILANG's value proposition. Effect-row mismatches (`TYP_EFFECT_ROW_MISMATCH`) are a top failure class per the evidence-gates doc — a transpiler that cannot represent effects addresses everything *except* the hardest problem.

The transpiler must either:
- **Infer effects** from the F# code (requires whole-program analysis of which builtins are called and which AILANG effects they map to — itself a type-inference problem over the transpiler's own symbol table).
- **Require annotations** in F# comments or attributes (at which point the model is learning AILANG's effect vocabulary anyway, just spelled differently).

### 3. Toolchain fragmentation

FCS is .NET-only. AILANG's toolchain is Go. The transpiler creates a .NET build step producing code for a Go runtime. This means:
- Two runtimes in the inference pipeline (.NET + Go)
- FCS is a heavyweight dependency with its own versioning and performance characteristics
- Deployment complexity increases (container size, dependency management, cold-start time)

### 4. The "constrained F# subset" is barely F#

Once you ban: mutation, .NET BCL, classes, interfaces, computation expressions, async, pipe operator (`|>`), active patterns, type providers, SRTP, method overloading — what remains is a tiny ML core expressible in any language. The model must learn the constraints of this subset, which is itself a "new language" cognitive load. The distance from "learn constrained F# subset" to "learn AILANG directly" is shorter than the transcript implies.

### 5. Moving target

AILANG is at v0.10.1 with rapid feature additions (Map, bitwise ops, cons expressions, streaming, process spawning added in recent versions). No formal spec — semantics defined by implementation. The type system is mid-migration (TFunc to TFunc2, TRecord to TRecord2). A transpiler built today requires updates with every AILANG release. Grammar-drift detection (transpiler rejects valid AILANG, or produces AILANG the parser rejects) is an ongoing maintenance burden.

## Head-to-Head: F# Transpiler vs. Structured Tool-Call Authoring

The evidence-gates doc identifies structured tool-call authoring as the primary near-term candidate. Both approaches share the same insight: remove AILANG syntax from the model's responsibilities. The implementation differs fundamentally.

| Dimension | F# Transpiler | Structured Tool-Call Authoring |
|-----------|--------------|-------------------------------|
| Removes AILANG syntax from model | Yes (writes F#) | Yes (writes JSON tool calls) |
| Leverages model's strength | F# knowledge (unverified) | Native tool calling (confirmed strong) |
| Dependency weight | FCS/.NET runtime | JSON schemas + AILANG pretty-printer |
| Deployment | Requires .NET in inference pipeline | All existing hosted endpoints |
| Handles effects | No (must infer or annotate separately) | Yes (`effects` field in `define_func`) |
| Handles budgets, capabilities | No | Yes (dispatcher validates) |
| Error feedback quality | Source-mapped transpilation errors | Typed, localized, actionable per-tool errors |
| Granularity of control | Whole-program | Per-construct |
| Incremental adoption | All-or-nothing | Additive (fallback to free-text) |
| Integration with existing infra | New stack | Extends `author_tools` pattern |
| Fine-tuning synergy | Train on F# to AILANG pairs | Train on tool-call sequences (higher signal/noise) |
| Maintenance under AILANG evolution | Transpiler tracks every syntax change | Schemas additive; new tools for new constructs |

Tool-call authoring is superior on nearly every axis. The one area where the transpiler has an advantage — holistic program generation where the model reasons about the program as a coherent whole — is addressed by composite/template tools in the tool-call design (`scaffold_main`, `scaffold_analyze_main`).

## Against the Full Lever Set

The evidence-gates doc proposes 7 levers, ordered by leverage vs. effort. The F# transpiler idea maps to the same conceptual space as levers 1-3 (syntax correctness via prior substitution) but is dominated by each:

- **Grammar-constrained decoding (lever 1):** Eliminates parse errors at token level by construction. Strictly higher ceiling. Deferred for endpoint-control reasons, not theoretical weakness. When available, obsoletes any transpiler.
- **Structured tool-call authoring (lever 2):** Same goal, deployable today, plays to confirmed model strengths, handles AILANG-specific features natively. Strictly better on deployment and capability axes.
- **Retrieval few-shot (lever 3):** Directly provides closer priors by showing correct AILANG for similar intents. Cheap, composable, complementary to everything. A transpiler does not help here.
- **Error-to-hint table (lever 4):** Cheap, deterministic, partially subsumed by tool-call authoring. Addresses a different failure mode.
- **Fine-tuning/LoRA (lever 7):** The only approach that moves actual model priors. If heavy investment is justified, LoRA on tool-call sequences is more efficient than LoRA on F# to AILANG pairs, and doesn't require a runtime transpiler in the pipeline.

## Conclusion

The F# transpiler idea is **technically feasible for a pure-functional subset** but **strategically risky** given the alternatives already identified in the evidence-gates research:

1. **The core insight is correct** — remove AILANG syntax from the model's responsibilities — but the execution vehicle (F# + FCS transpiler) is the wrong one unless Gemma 4's F# capability is verified.
2. **The F# premise is unverified, not disproven.** No public benchmark tests Gemma 4 on F#. Gemma 4's training mix is unknown — the "Python/JS/Go-heavy" characterization is speculative. The question is empirically testable and should be tested before committing to either direction.
3. **Structured tool-call authoring is the same insight, with lower risk.** It uses JSON (universally known), leverages Gemma 4's confirmed-strong tool-calling capability, handles AILANG-specific features natively, deploys on existing infrastructure, and composes with every other lever. It does not depend on an unverified model capability.
4. **The effect system problem is blocking and unaddressed.** The transcript's claim that effects can be handled by "effect analysis" understates the difficulty. Tool-call authoring handles this by construction — effects are a structured field the dispatcher validates.

### Recommendation

Do not build the F# transpiler as a first investment. The research time would be better spent on:

1. **Testing the F# premise.** Run Gemma 4 on MultiPL-E's F# split or a comparable benchmark. Measure F# pass rate vs. AILANG pass rate. This is cheap and answers the foundational question. If Gemma 4's F# is materially better than its AILANG (e.g., >85% HumanEval pass@1 on F# vs. current AILANG compile rates), the transpiler premise is validated and warrants further investment.
2. **Implementing structured tool-call authoring** (lever 2) — the primary near-term candidate per the evidence-gates analysis. This is deployable today, relies on verified model strengths, and addresses the same problem.
3. **Building the retrieval index** (lever 3) for known-good AILANG snippets, keyed by intent-kind, effects, and imports.
4. **Quantifying Gemma 4 failure modes** (`scripts/analyze_compose_meta.py`) to confirm whether syntactic or semantic errors dominate.

If the F# benchmark shows strong results AND the tool-call approach plateaus below acceptable validity rates, the transpiler idea should be revisited as a complementary lever. The two approaches are not mutually exclusive — a transpiler for expression bodies could compose with tool-call authoring for program structure.

### If the Transpiler Is Pursued Anyway

Should the decision be made to build it despite the above, the minimum-viable scope is:

- **Target**: Pure-functional F# subset only (no mutation, no BCL, no classes, no computation expressions, no pipes)
- **Effects**: Require explicit annotations via F# custom attributes (`[<Effect("IO", "FS")>]`) — do not attempt inference
- **Implementation**: F# script (.fsx) using FCS `getParseResults` for AST access, emitting AILANG text. Keep it self-contained — do not introduce a persistent .NET service
- **Validation**: Every transpiler output runs through `ailang check`; transpiler bugs are caught, not shipped
- **Scope**: Expression-level constructs only (functions, ADTs, pattern matching, let bindings, lambdas, records). Do not attempt modules, imports, or effects — generate those as a fixed skeleton around the transpiled body
- **Pin AILANG version**: Target a specific release. Do not track HEAD

This minimized version converges toward "skeleton-first, then hole-fill" (lever 6 in the evidence-gates doc) with F# as the hole-fill language — a less ambitious but more defensible position.
