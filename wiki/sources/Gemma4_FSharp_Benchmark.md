# Plan: Benchmark Gemma 4 26B A4B-it on F# Code Generation

**Goal:** Empirically test whether Gemma 4 writes F# materially better than it writes AILANG. This answers the foundational question gating the F# → AILANG transpiler idea.

**Infrastructure:**
- **Inference:** Gemma 4 26B A4B-it running locally on NVIDIA DGX Spark at `http://100.79.48.75:8000/v1` (OpenAI-compatible)
- **Harness:** AILANG eval harness (`ailang/internal/eval_harness/`), extended with F# support, running on this host machine
- **F# runtime:** .NET SDK (`dotnet fsi`) installed on host machine

---

## Decision Criteria (defined before running)

The metric that matters is **pass rate** (stdout correct), not compile rate. Compile rate is a diagnostic; the transpiler premise requires *correct* F# that produces correct AILANG after transpilation. Wrong F# that compiles is useless.

For reference, the AILANG-only baseline pass rates (v0.9.0, 46 problems, 1 run per model, with self-repair) are:

| Model | AILANG Compile | AILANG Pass (stdout OK) |
|-------|---------------|------------------------|
| GPT-5-4 | 96% | 91% |
| Claude Sonnet 4.6 | 91% | 87% |
| Claude Opus 4.6 | 93% | 87% |
| GPT-5-2 Codex | 93% | 87% |
| Gemini 3.1 Pro | 83% | 83% |
| Gemini 3 Pro | 70% | 70% |

Gemma 4 26B A4B-it is comparable to Gemini 3 Pro in active parameter count. We expect its AILANG baseline to land in the **65-75% pass rate** range. The F# pass rate is compared against this measured baseline (not a guess).

### Go / No-Go Bands

| Constrained F# pass rate | Delta vs. AILANG | Interpretation |
|--------------------------|------------------|---------------|
| >85% | >15pp | **Go.** Strong transpiler premise. F# is a materially better generation target. |
| 70-85% | 10-15pp | **Marginal.** Advantage exists but may not justify transpiler cost vs. tool-call authoring. Revisit if tool-call approach plateaus. |
| <70% | <10pp | **No-go.** F# does not provide meaningful advantage. Invest in other levers. |

Both **first-attempt pass rate** and **final pass rate (after repair)** are reported. The decision gates on final pass rate to match the existing baseline methodology.

---

## Problem Set

**42 problems included** — pure-functional (IO cap only for printing, no stdin/input_files/cli_args):

| Difficulty | Count | Examples |
|-----------|-------|---------|
| easy | 1 | fizzbuzz |
| medium | 19 | adt_option, balanced_parens, gcd_lcm, json_encode, json_parse, records_book, recursion_fibonacci, run_length_encode, ... |
| hard | 20 | binary_tree_sum, expression_evaluator, graph_bfs, json_transform, lambda_calc, merge_sort, mini_interpreter, red_black_tree, symbolic_diff, type_unify, ... |
| very_hard | 2 | contract_sorted_merge, tree_transformation_pipeline |

**9 problems excluded** with reasons:

| Problem | Reason |
|---------|--------|
| api_call_json | Requires Net effect (HTTP POST) |
| cli_args | Requires FS + Env effects, input_files, cli_args |
| config_file_parser | Requires FS effect |
| csv_to_json_converter | Requires FS effect |
| effect_composition | Requires FS effect |
| effect_tracking_io_fs | Requires FS effect |
| inline_tests | AILANG-specific feature (inline test annotations) |
| log_file_analyzer | Requires FS effect |
| pipeline | Uses stdin field |

---

## Phase 0: Infrastructure Setup

### 0a. Install .NET SDK on host machine

```bash
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 8.0
# Add to PATH per installer instructions, then verify:
dotnet fsi --version
```

F# Interactive (`dotnet fsi`) executes `.fsx` scripts without a project file. No `dotnet new`, no NuGet packages needed. `System.Text.Json` is part of the SDK and available to `.fsx` via `open System.Text.Json`.

### 0b. Wire eval harness to DGX Spark endpoint

**Problem:** The eval harness's `guessProvider("google/gemma-4-26B-A4B-it")` routes to Vertex AI (Google provider). The main runtime's `OPENAI_BASE_URL` support (see `ailang/cmd/ailang/ai_handlers.go`) was never ported to the eval harness.

**Fix:** Modify `ailang/internal/eval_harness/ai_provider.go`:

1. In `newProviderAdapter()`, for the `"openai"` case, mirror `cmd/ailang/ai_handlers.go`'s `newOpenAIClient()`: read `OPENAI_BASE_URL`, normalize it, and pass via `openai.WithBaseURL(baseURL)`.
2. In `getAPIKeyForProvider()`, when `OPENAI_BASE_URL` is set and provider is `"openai"`, allow empty API key (same auth-none handling as the main runtime).
3. Use model string `openai/google/gemma-4-26B-A4B-it` so `guessProvider()` routes to the `"openai"` case (it matches `strings.Contains(lower, "openai")`), and the base URL override takes effect.

**Files:** `ailang/internal/eval_harness/ai_provider.go`

### 0c. Smoke test

Before running the full suite, verify the entire pipeline end-to-end:

1. **DGX Spark connectivity:** Send a single AILANG fizzbuzz to Gemma 4 via the eval harness. Confirm a response comes back and executes correctly.
2. **F# execution:** Manually write a trivial F# script (`printfn "hello"`), run `dotnet fsi hello.fsx`, confirm output.
3. **FSharpRunner error detection:** Test with a script containing a compile error (`let x : int = "wrong"`) and a runtime error (`failwith "boom"`) to confirm `CompileOk` and `RuntimeOk` are set correctly.
4. **Full pipeline:** Run fizzbuzz on Gemma 4 in all three conditions (AILANG, F# unconstrained, F# constrained). Verify results manually.

**Acceptance:** All four checks pass before proceeding to Phase 3.

---

## Phase 1: Add F# Language Runner

### 1a. Implement `FSharpRunner`

**File:** `ailang/internal/eval_harness/runner_fsharp.go` (new file)

```go
type FSharpRunner struct {
    spec *BenchmarkSpec
}

func (r *FSharpRunner) Language() string { return "fsharp" }

func (r *FSharpRunner) Run(code string, timeout time.Duration) (*RunResult, error) {
    // 1. Create temp dir
    // 2. Write code to solution.fsx
    // 3. Write any input_files from spec
    // 4. Execute: dotnet fsi solution.fsx [cli_args...]
    //    - Use process groups for timeout enforcement (same as PythonRunner)
    //    - Capture stdout/stderr with LimitedWriter (same as PythonRunner)
    // 5. Classify exit status:
    //    - CompileOk: stderr does NOT match `error FS\d{4}:`
    //    - RuntimeOk: CompileOk AND (exit code 0 OR stderr does NOT match
    //      `System\.\w+Exception|Unhandled exception|StackOverflowException`)
    //    - Note: F# warnings (`warning FS\d{4}:`) do NOT indicate failure
    // 6. Return RunResult
}
```

**Error classification detail for `dotnet fsi`:**
- **Compile errors:** stderr contains `error FS\d{4}:` (e.g., `error FS0039: The value or constructor 'xyz' is not defined`). Exit code 1. Typically no stdout.
- **Runtime errors:** stderr contains `System.\w+Exception` or `Unhandled exception` with stack trace. May have partial stdout from `printfn` calls before the error.
- **Warnings:** stderr contains `warning FS\d{4}:`. These do NOT prevent execution — the program still runs. Do not count as failures.
- **Timeout:** same handling as Python — kill process group after timeout.

### 1b. Register in `GetRunnerWithContext()`

Add `"fsharp"` case to the language switch. The constrained variant uses the same runner — only the prompt differs.

```go
case "fsharp", "fsharp-constrained":
    return &FSharpRunner{spec: spec}, nil
```

### 1c. Add F# to benchmark specs

Add `"fsharp"` to the `languages` array in each of the 42 included benchmark YAMLs:

```yaml
languages: ["python", "ailang", "fsharp"]
```

Do NOT add `"fsharp-constrained"` to YAML specs. The constrained variant is a prompt-level variation that uses the same runner and the same specs. The harness runs it via `--lang fsharp-constrained`, which passes `SupportsLanguage()` by checking the runner registration, not the YAML `languages` array. (If `SupportsLanguage` does a strict YAML check, override it: either add a `--force-lang` flag or have `SupportsLanguage("fsharp-constrained")` return true when `"fsharp"` is in the list.)

**Files:**
- `ailang/internal/eval_harness/runner_fsharp.go` (new)
- `ailang/internal/eval_harness/runner.go` (register in factory)
- `ailang/internal/eval_harness/spec.go` (language support check)
- `ailang/benchmarks/*.yml` (42 files — mechanical YAML edit)

---

## Phase 2: F# Base Prompts

### 2a. Unconstrained F# prompt

Short and permissive. Lets Gemma 4 use whatever F# it knows — mutation, loops, BCL, pipes, etc.

```
You are writing F# (.fsx script format).
Write a complete F# script that can be executed with `dotnet fsi`.
Use `printfn` for output. Do not use any NuGet packages.
Output only the code, no explanations.
```

### 2b. Constrained pure-functional F# prompt

This mirrors what a transpiler would actually receive. The constraints ban features that **cannot be transpiled to AILANG**, not features that are merely syntactically different. Pipes (`|>`) and standard library functions are allowed because a transpiler handles them trivially.

```
You are writing F# (.fsx script format) in a PURE FUNCTIONAL subset.
Write a complete F# script that can be executed with `dotnet fsi`.

RULES — what you MUST NOT use:
- NO mutable variables (no `let mutable`, no `ref`)
- NO imperative loops (no `for`, `while`, `do` loops) — use recursion instead
- NO classes, interfaces, structs, or object expressions
- NO computation expressions (no `async { }`, `task { }`, `seq { }`)
- NO .NET BCL beyond what is listed below
- Do not use any NuGet packages

RULES — what you SHOULD use:
- Use `printfn` for output, `sprintf` for formatting
- Use recursion for all iteration
- Use discriminated unions for algebraic data types
- Use pattern matching with `match ... with`
- Use pipe operator (|>) freely
- You MAY use: List, Array, String, Option, Result, Map, Set module functions
- You MAY use: System.Text.Json for JSON tasks

Output only the code, no explanations.
```

### 2c. Implementation

Add to `getDefaultPrompt()` in `spec.go`:

```go
case "fsharp":
    return fsharpUnconstrainedPrompt
case "fsharp-constrained":
    return fsharpConstrainedPrompt
```

**Files:**
- `ailang/internal/eval_harness/spec.go`

---

## Phase 3: Run the Benchmark

All three conditions use **self-repair enabled** (the `eval-suite` default). Both `first_attempt_ok` and final `stdout_ok` are recorded so we can report raw and repaired numbers.

Sampling: use Gemma 4 recommended defaults (`temperature=1.0, top_p=0.95, top_k=64`) for all conditions. If the eval harness has its own sampling defaults, override them to match — consistency across conditions is essential.

**Concurrency note:** The DGX Spark serves a single model — set `--parallel 1` to avoid overloading it with concurrent requests. This increases wall-clock time but ensures stable results.

**Multiple runs:** The harness has no `--runs` flag. For 3 runs per condition, execute the suite 3 times with different seeds (`--seed 42`, `--seed 43`, `--seed 44`). Each run auto-discovers all benchmarks in the `benchmarks/` directory and filters by `--langs`.

### 3a. AILANG baseline for Gemma 4 (required — no existing baseline)

The v0.9.0 baselines cover GPT-5, Claude, and Gemini models but NOT the local Gemma 4.

```bash
for SEED in 42 43 44; do
  OPENAI_BASE_URL=http://100.79.48.75:8000/v1 \
  ailang eval-suite \
    --models openai/google/gemma-4-26B-A4B-it \
    --langs ailang \
    --seed $SEED \
    --parallel 1 \
    --timeout 120s \
    --output eval_results/fsharp_benchmark/ailang_baseline/seed_${SEED}
done
```

42 problems × 3 seeds = **126 generations**.

### 3b. Unconstrained F#

```bash
for SEED in 42 43 44; do
  OPENAI_BASE_URL=http://100.79.48.75:8000/v1 \
  ailang eval-suite \
    --models openai/google/gemma-4-26B-A4B-it \
    --langs fsharp \
    --seed $SEED \
    --parallel 1 \
    --timeout 120s \
    --output eval_results/fsharp_benchmark/fsharp_unconstrained/seed_${SEED}
done
```

42 problems × 3 seeds = **126 generations**.

### 3c. Constrained F#

```bash
for SEED in 42 43 44; do
  OPENAI_BASE_URL=http://100.79.48.75:8000/v1 \
  ailang eval-suite \
    --models openai/google/gemma-4-26B-A4B-it \
    --langs fsharp-constrained \
    --seed $SEED \
    --parallel 1 \
    --timeout 120s \
    --output eval_results/fsharp_benchmark/fsharp_constrained/seed_${SEED}
done
```

42 problems × 3 seeds = **126 generations**.

### Total: 378 generations across 3 conditions × 3 seeds

At local inference speeds on DGX Spark (~300 tok/s for 26B A4B, no rate limiting, `--parallel 1`), each seed run completes 42 problems sequentially. Expect ~30-60 min per language per seed, or **4-6 hours total** for all 9 runs. These run unattended.

For self-repair to work on F#, the `RepairRunner` must feed F# compilation/runtime errors back to the model as repair prompts. The existing repair logic passes stderr/stdout context to the model — this should work for F# errors without modification, since the model sees the error text and can reason about it regardless of language.
---

## Phase 4: Analysis

### 4a. Per-condition aggregate metrics

| Metric | AILANG baseline | F# unconstrained | F# constrained |
|--------|----------------|-------------------|----------------|
| Compile rate | ? | ? | ? |
| Runtime OK rate | ? | ? | ? |
| First-attempt pass rate | ? | ? | ? |
| Repair used | ? | ? | ? |
| Repair success rate | ? | ? | ? |
| **Final pass rate (stdout OK)** | ? | ? | ? |
| Mean generation tokens | ? | ? | ? |

### 4b. Per-problem comparison

For each problem (across all 3 runs, majority vote): did it pass in AILANG? Did it pass in F#? Classify each problem into:
- **F# advantage:** F# passes, AILANG fails (evidence for transpiler)
- **F# disadvantage:** AILANG passes, F# fails (evidence against)
- **Both fail:** Hard problem, language-independent (no signal)
- **Both pass:** Easy problem (no signal)

Count the problems in each category. If "F# advantage" problems significantly outnumber "F# disadvantage" problems, the transpiler has a case.

### 4c. Failure mode categorization

For each failure in each condition, classify:
- **Compile error (syntax)** — language familiarity issue. Transpiler helps IF the source language compiles.
- **Runtime error (logic)** — transpiler doesn't help.
- **Wrong output (semantic)** — transpiler doesn't help.

Compare the failure mode distribution across AILANG and F#. If AILANG failures are dominated by compile errors while F# failures are dominated by wrong output, that tells us Gemma 4's AILANG problem is syntax (transpiler could help) vs. logic (transpiler can't help).

### 4d. Constrained vs. unconstrained delta

Key question: does the pure-functional constraint cost significant pass rate?

If unconstrained F# pass rate is 82% but constrained drops to 65%, the restriction costs 17pp — a signal that the model struggles with the constraints the transpiler would impose. The "real" F# capability that the transpiler can use is the constrained number, not the unconstrained ceiling.

### 4e. Decision

Apply the go/no-go bands defined at the top. Write full results with tables, per-problem breakdowns, and failure examples to `.agent/research/Gemma4_FSharp_Benchmark_Results.md`.

---

## Implementation Effort Estimate

| Work item | Effort | Notes |
|-----------|--------|-------|
| Install .NET SDK | 10 min | One-liner |
| Wire eval harness to DGX Spark (`OPENAI_BASE_URL`) | 1-2 hours | Port from `cmd/ailang/ai_handlers.go` |
| FSharpRunner + error classification | 1-2 hours | Follow PythonRunner pattern |
| F# base prompts (2 variants) | 30 min | Two prompt strings |
| Add `"fsharp"` to 42 benchmark YAMLs | 15 min | Mechanical edit |
| `SupportsLanguage` fix for constrained variant | 15 min | Map `fsharp-constrained` → `fsharp` |
| Smoke test (Phase 0c) | 30 min | 4 manual checks |
| Run benchmarks (Phase 3) | 4-6 hours | 9 runs (3 conditions × 3 seeds), `--parallel 1`, unattended |
| Analysis script | 1 hour | Parse result JSONs, compute comparison tables |
| **Total** | **~1 day** | Most time is waiting for benchmark runs |

---

## Risk Mitigations

1. **`dotnet fsi` not available or wrong version**: Verify during Phase 0a. Need .NET 8.0+ for current F# Interactive support.
2. **DGX Spark endpoint flaky**: Smoke test (Phase 0c) catches this before the full run.
3. **F# warnings vs. errors**: `warning FS\d{4}` does not indicate failure. Only `error FS\d{4}` is a compile failure.
4. **`dotnet fsi` cold-start latency**: First invocation JIT-compiles the F# compiler. Subsequent runs are faster but still ~2-5s startup overhead. The 120-second timeout on hard problems should be sufficient, but monitor for timeouts in the results.
5. **JSON problems need `System.Text.Json`**: Part of the .NET SDK, no NuGet needed. `open System.Text.Json` works in `.fsx` out of the box.
6. **Model routing**: Use `openai/google/gemma-4-26B-A4B-it` as the model string to force the OpenAI provider path, combined with `OPENAI_BASE_URL`. This avoids modifying `guessProvider()`.
7. **Repair on F# errors**: The `RepairRunner` passes error text to the model generically. F# compile errors (`error FS0039: The value or constructor 'xyz' is not defined`) are clear enough for the model to act on. No F#-specific repair logic needed.
8. **Sampling consistency**: Explicitly set `temperature=1.0, top_p=0.95, top_k=64` for all conditions. If the harness overrides these, verify they match across AILANG and F# runs.

---

## What This Does NOT Test

- Transpiler implementation feasibility (this only tests the input premise — whether Gemma 4 produces good F#)
- Gemma 4's ability to write F# that composes with AILANG effects (a transpiler design question, not a model capability question)
- Whether tool-call authoring outperforms F# transpilation (separate comparison, not in scope)
- Performance of the 31B Dense variant (only 26B A4B-it is tested — the 31B Dense may show different results)
- Multi-turn agentic evaluation (this uses 0-shot + single self-repair, matching existing standard eval methodology)
