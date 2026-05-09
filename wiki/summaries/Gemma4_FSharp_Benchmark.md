---
doc_type: short
full_text: sources/Gemma4_FSharp_Benchmark.md
---

This document outlines a rigorous empirical plan to determine whether the Gemma 4 26B A4B‑it model writes **F# code significantly better** than it writes **AILANG**, testing the foundational hypothesis behind a proposed F#‑to‑AILANG transpiler.  

The experiment extends the AILANG [[eval harness]] with an `FSharpRunner` that executes F# scripts via `dotnet fsi`, adds two prompt variants (unconstrained and a pure-functional constrained subset), and runs three conditions (AILANG baseline, unconstrained F#, constrained F#) across 42 problems on a local DGX Spark endpoint.  

### Key Decision Framework  
- The primary metric is **pass rate** (stdout correct), with compile rate as a diagnostic.  
- Go/no‑go bands are defined: the tranpiler premise is strong if F# pass rate >85% and surpasses AILANG by >15 percentage points; a marginal advantage (70–85% pass, 10–15pp delta) warrants re‑evaluation; below that the transpiler is rejected.  
- Both first‑attempt and self‑repair pass rates are recorded; the decision gate uses final pass rate to match existing baseline methodology.  

### Method  
- **Infrastructure**: DGX Spark endpoint (OpenAI‑compatible) and .NET 8.0 SDK for `dotnet fsi`.  
- **Code**: A new `runner_fsharp.go` mimicking the Python runner, with error classification that distinguishes compile errors (`error FS\d{4}`), runtime exceptions, and harmless warnings.  
- **Prompts**: Unconstrained F# prompt and a constrained **pure-functional subset** (no mutable variables, loops, classes, computation expressions; recursion, pipes, discriminated unions allowed) – the constrained version mirrors what a transpiler would receive.  
- **Execution**: 42 problems × 3 seeds × 3 conditions = 378 generations, run unattended with `--parallel 1` and consistent sampling parameters.  

### Expected Analysis Phases  
1. **Per‑condition aggregate metrics** (compile, runtime, pass, repair rates).  
2. **Per‑problem comparison** to classify problems as F# advantage, disadvantage, both fail, or both pass.  
3. **Failure mode categorization** (syntax vs. logic vs. semantic) to assess whether AILANG failures are syntax‑dominated (where a transpiler helps).  
4. **Constrained‑vs‑unconstrained delta** to quantify the cost of functional restrictions.  

### Contribution  
The plan provides a structured, reproducible evaluation with clear decision criteria, filling a gap (no existing Gemma 4 baseline) and testing the core **[[transpiler premise]]** that targeting a familiar language like F# yields higher‑quality generation than directly generating AILANG. The results will inform whether to invest in a full transpiler or explore other levers such as tool‑call authoring.