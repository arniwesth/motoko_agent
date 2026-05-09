---
doc_type: short
full_text: sources/Agentic_Code_Reasoning_AILANG_Integration.md
---

# Agentic Code Reasoning × AILANG Integration

**Source:** Ugare & Chandra, Meta (arXiv 2603.01896v2) — analyzed 2026-04-04
**Domain:** Execution-free LLM code reasoning via structured semi-formal certificates

---

## Core Idea

The paper demonstrates that LLM agents reason more accurately about code when forced through a **semi-formal certificate template** — stating explicit premises, tracing execution paths with file:line evidence, and deriving conclusions grounded in that evidence. Gains range from +5pp to +12pp across tasks, with ~2.8× more steps on average.

This document maps the paper's methodology onto the existing AILANG runtime (`src/core/rpc.ail`, `src/core/prompts.ail`, `src/core/tool_runtime.ail`) and proposes a three-level implementation path.

---

## Key Findings from the Paper

| Task | Standard | Semi-Formal | Gain |
|---|---|---|---|
| Patch equivalence (curated) | 78% | 88% | +10pp |
| Patch equivalence (real-world) | 86% | 93% | +7pp |
| Fault localization Top-5 (fit-in-context) | 61% | 72% | +12pp |
| Code QA (RubberDuckBench) | 78% | 87% | +9pp |

Cost: **~2.8× more steps** on average. Gains are **model-dependent** — Opus benefits strongly; Sonnet plateaus or regresses on some tasks.

### Why Semi-Formal Works

The structured template acts as a **forcing function**: agents must cite file:line locations, cannot skip cases, and must ground conclusions in traced evidence. The motivating example (django-13670) shows standard reasoning incorrectly assuming `format()` is Python's builtin, while semi-formal reasoning traced the actual module-level definition and reached the correct verdict.

---

## Integration Points with AILANG Runtime

### Point A: Prompt Construction
Add `with_semi_formal_template(prompt, task_type)` to `src/core/prompts.ail`. Appends the relevant certificate template when the task involves patch equivalence, fault localization, or code QA.

### Point B: Task Classification
Classify tasks before `rpc_loop` via deterministic keyword matching (`classify_reasoning_mode`) to decide whether semi-formal reasoning applies. Avoids an extra LLM call.

### Point C: Verifier Mode
Separate **solver** (writes patches, executes) from **verifier** (reads-only, fills certificate, returns verdict). The verifier uses the same `env_client.ail` for bash exploration (`grep`, `find`, `read`) but never runs tests or applies diffs.

---

## AILANG Language Advantages

AILANG's type system enables **structural enforcement** beyond prompt engineering:

- **Algebraic effects** (`! {IO, FS}`) model evidence-gathering as effectful computation — impossible to skip
- **ADTs and pattern matching** — `type Verdict = Equivalent | NotEquivalent(Reason)` forces exhaustive case analysis
- **Hindley-Milner types** — premises must be populated before a conclusion can be derived
- **Effect polymorphism** (`mapE`, `foldlE`) guarantees left-to-right evaluation for trace collection

### Typed Certificates vs. String Templates

The paper's string-based certificates *hope* the LLM follows structure. AILANG ADTs make incomplete certificates **structurally impossible**:

```ailang
type Certificate = {
  premises: Premises,
  traces: [ExecutionTrace],
  verdict: Verdict
}
```

This is the difference between prompt hoping and type-checked guarantees.

---

## Three-Level Implementation Plan

| Level | Description | Effort | Impact |
|---|---|---|---|
| **1: Prompt Templates** | Add certificate templates to `prompts.ail`, conditionally applied | Low | Medium |
| **2: Verifier Loop** | Separate reads-only verification pass with tool policy gate | Medium | High |
| **3: Typed Certificates** | Model certificates as AILANG ADTs with decode + validation | High | Highest |

### Recommended Path
Start with Level 1 (add templates, validate on patch equivalence), layer Level 2 (verifier loop with budget split: solver 38 steps + verifier 12 steps), and reserve Level 3 as a longer-term architectural play.

---

## Concrete Design Decisions

### Tool Policy Gate
`src/core/tool_runtime.ail` gets a `ToolPolicy` type (`FullAccess | ReadOnly`):
- **ReadOnly allows:** `ReadFile`, `Search`, allowlisted `BashExec` commands (`cat`, `rg`, `find`, `ls`, `git show`)
- **ReadOnly denies:** `WriteFile`, `RunTests`, unlisted `BashExec`

### Structured Verdict Output
Before full ADTs, require the verifier to output JSON with `verdict`, `confidence`, `premises`, `evidence` (with `file` + `line`), `gaps`, and `next_actions`. Parsed with `std/json.decode` and validated against coverage requirements.

### Budget Management
Reserve step budget explicitly: solver 38 + verifier 12. Short-circuit verifier on low-complexity tasks. Apply semi-formal selectively — not default-on for all tasks.

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Step budget pressure (50-step ceiling) | Budget split; disable verifier for simple tasks |
| Verifier over-constrains solver | Treat verifier as advisory unless high confidence + cited evidence |
| Read-only bypass via shell | Strict allowlist for `BashExec`; reject compound shell tokens |
| Model-dependent gains (Sonnet plateaus/regresses) | Model-aware gating; track per-model deltas |
| False confidence from elaborate-but-wrong chains | Require evidence count + file:line citations; validate `gaps` non-empty for inconclusive |

---

## Evaluation Criteria

Track on three benchmarks (patch equivalence, fault localization, code QA over repo sources):
1. Accuracy (task-specific, strict + relaxed metrics)
2. Mean steps and p95 steps
3. Token/cost proxy
4. False-positive verifier rate (< 5% acceptance gate)

Acceptance gates for verifier-by-default: >= +5pp on targeted tasks, <= +40% median step increase, false-positive rate < 5%.

---

## Related Concepts

- [[concepts/semi-formal-reasoning]] — The core methodology: structured certificate templates that force evidence-grounded conclusions
- [[concepts/execution-free-verification]] — Reasoning about code correctness without running tests or applying patches
- [[concepts/adversarial-verification]] — Using a separate verifier agent to challenge solver output before declaring completion
- [[concepts/typed-certificates]] — Modeling verification certificates as ADTs for structural enforcement vs. prompt hoping
- [[concepts/tool-policy-gating]] — Runtime enforcement of read-only vs. full-access tool policies
- [[concepts/step-budget-management]] — Splitting agent step budgets between solver and verifier passes
- [[concepts/model-aware-prompting]] — Gating reasoning strategies based on model capability profiles
