# Gemma 4 F# Benchmark Results

Date: 2026-04-18 (UTC)
Model: `openai/google/gemma-4-26B-A4B-it` via `OPENAI_BASE_URL=http://100.79.48.75:8000/v1`
Harness: `ailang eval-suite` with self-repair enabled

Research context:
- `.agent/research/FSharp_Transpiler_Feasibility_Evaluation.md`

Why we are doing this benchmark (short summary):
- The feasibility research identified an unverified core premise: Gemma 4 may write F# materially better than AILANG.
- This benchmark is the gating experiment for the transpiler idea:
  - If constrained F# is much better than AILANG, transpiler investment may be justified.
  - If gains are small, prioritize lower-risk alternatives (especially structured tool-call authoring).
- This report provides the empirical evidence for that go/no-go decision.

## Primary Run (Fair Prompt Setup)

This report now uses the completed **teacher-prompt fair comparison** run as the primary dataset.

- Log: `ailang/logs/fsharp_benchmark_20260418T065128Z_teacher_prompt.log`
- Completion marker: `ALL_DONE overall_rc=0`
- Completed at: `2026-04-18T08:11:43Z`
- Output root: `ailang/eval_results/fsharp_benchmark_teacherprompt/`

## Scope

- Benchmarks: 42 included tasks (filtered set from the benchmark plan)
- Runs: 9 total
  - AILANG baseline: seeds 42, 43, 44
  - F# unconstrained: seeds 42, 43, 44
  - F# constrained: seeds 42, 43, 44
- Total evaluated task-runs: 378 (42 × 9)
- Result artifacts: 378 JSON files

## Aggregate Metrics (All 3 Seeds Combined)

| Condition | N | Compile Rate | Runtime OK Rate | First-Attempt Pass | Final Pass | Repair Used | Repair Success | Mean Output Tokens |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| AILANG baseline | 126 | 62.7% | 61.1% | 41.3% | 58.7% | 64 | 34.4% | 458.6 |
| F# unconstrained | 126 | 86.5% | 86.5% | 62.7% | 66.7% | 11 | 45.5% | 316.4 |
| F# constrained | 126 | 73.8% | 73.8% | 55.6% | 63.5% | 15 | 66.7% | 390.8 |

## Per-Seed Final Pass Rates

| Condition | Seed 42 | Seed 43 | Seed 44 |
|---|---:|---:|---:|
| AILANG final pass | 59.5% | 57.1% | 59.5% |
| F# unconstrained final pass | 71.4% | 66.7% | 61.9% |
| F# constrained final pass | 64.3% | 64.3% | 61.9% |

## Delta vs AILANG Baseline

Final-pass deltas vs AILANG (58.7%):

- F# unconstrained: **+8.0 pp** (66.7% - 58.7%)
- F# constrained: **+4.8 pp** (63.5% - 58.7%)

First-attempt deltas vs AILANG (41.3%):

- F# unconstrained: **+21.4 pp**
- F# constrained: **+14.3 pp**

## Failure Mode Distribution

Among failed runs only:

| Condition | Failures | Compile | Runtime | Logic |
|---|---:|---:|---:|---:|
| AILANG | 52 | 47 (90.4%) | 2 (3.8%) | 3 (5.8%) |
| F# unconstrained | 42 | 17 (40.5%) | 0 (0.0%) | 25 (59.5%) |
| F# constrained | 46 | 33 (71.7%) | 0 (0.0%) | 13 (28.3%) |

Interpretation:

- AILANG failures remain mostly compile errors.
- F# unconstrained strongly improves compile success, with remaining misses mostly logic mismatches.
- F# constrained improves over AILANG but still carries significant compile-failure pressure.

## Per-Problem Majority Comparison (3-Seed Vote)

Category counts (AILANG majority pass/fail vs F# majority pass/fail):

### AILANG vs F# unconstrained
- F# advantage: 7
- F# disadvantage: 2
- Both fail: 11
- Both pass: 22

### AILANG vs F# constrained
- F# advantage: 5
- F# disadvantage: 3
- Both fail: 13
- Both pass: 21

## Prompt Loading Architecture (Language-Dependent)

### Standard eval mode (`eval-suite`, non-agent)

Prompt assembly entry point:
- `BenchmarkSpec.PromptForLanguage(lang)` in `internal/eval_harness/spec.go`

Behavior by language:
- `ailang`:
  - Base prompt always loaded from active prompt registry version via `promptpkg.LoadPrompt("")`.
  - Task text appended under `## Task` from `task_prompt` or `prompt` fallback.
- `fsharp`:
  - Base prompt loaded from prompt registry key `fsharp` via `promptpkg.LoadPrompt("fsharp")`.
  - Task text appended under `## Task`.
- `fsharp-constrained`:
  - Uses same `fsharp` teacher base prompt.
  - Appends constrained subset rules.
  - Task text appended under `## Task`.
- `python`:
  - Uses existing non-teacher path (inline prompt or language-specific prompt file/default).

System prompt in standard mode:
- Fixed generic system instruction from `internal/eval_harness/ai_provider.go`.
- Language teaching content is carried in the **user prompt**, not system prompt.

### Agent eval mode (`eval-suite --agent`)

Prompt assembly entry point:
- `GenerateAgentPromptsWithSystemPrompt(...)` in `internal/eval_harness/agent_prompt.go`

Behavior:
- System prompt is language-specific (`ailang`, `python`, `fsharp` from prompt registry)
- Task prompt comes from language templates in `internal/eval_harness/templates/agent_task_*.txt`

## Go / No-Go Decision (Primary Run)

Decision bands from plan:

- `>85%` constrained pass and `>15pp` delta: Go
- `70–85%` constrained and `10–15pp` delta: Marginal
- `<70%` constrained and `<10pp` delta: No-go

Observed constrained final pass = **63.5%**, delta vs AILANG = **+4.8 pp**.

## Final Decision: **No-go**

Even with fairer F# teacher prompting, constrained F# remains below the plan’s go/marginal thresholds.

## Reproducibility Note

`--seed` is recorded in metrics, but currently not propagated into provider request options in eval generation path. Runs are therefore still stochastic; seed labels alone do not imply deterministic replay.

## Historical Comparison (Prior Run)

Prior completed run before teacher-prompt fairness update:
- Log: `ailang/logs/fsharp_benchmark_20260417T200104Z_restart42.log`
- Output root: `ailang/eval_results/fsharp_benchmark/`

Primary difference vs this report:
- That run used earlier F# prompt-loading behavior.
- This report uses the new fairer F# teacher-prompt setup.

## Changelog

- 2026-04-18: Promoted `fsharp_benchmark_teacherprompt` run to primary dataset; updated all aggregate/seed/failure metrics and go/no-go analysis accordingly.
- 2026-04-18: Added prompt-loading architecture section (standard vs agent mode) and explicit documentation of language-dependent prompt paths.
- 2026-04-18: Added research-context pointer and short benchmark purpose summary at top of report.
- 2026-04-18: Added reproducibility caveat that `--seed` is recorded but not yet propagated into provider request options in eval generation path.
- 2026-04-17: Initial benchmark report drafted from pre-fairness run (`fsharp_benchmark` output root; log `fsharp_benchmark_20260417T200104Z_restart42.log`).
