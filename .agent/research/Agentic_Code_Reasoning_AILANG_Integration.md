# Agentic Code Reasoning × AILANG Core Runtime — Integration Research

**Paper:** "Agentic Code Reasoning" — Ugare & Chandra, Meta (arXiv 2603.01896v2)  
**Date:** 2026-04-04  
**Domain:** Execution-free LLM code reasoning via structured semi-formal certificates

---

## 1. Paper Summary

The paper asks: *Can LLM agents explore codebases and reason about code semantics without executing the code?*

Their answer is **semi-formal reasoning** — a structured prompting methodology where agents must construct explicit premises, trace execution paths, and derive formal conclusions. The certificate template acts as a forcing function: the agent cannot skip cases or make unsupported claims.

### Key Results (Opus-4.5)

| Task | Standard | Semi-Formal | Gain |
|---|---|---|---|
| Patch equiv (curated) | 78% | 88% | +10pp |
| Patch equiv (real-world) | 86% | 93% | +7pp |
| Fault localization Top-5 (Agentic, 90-bug) | 43% | 48% | +5pp |
| Fault localization Top-5 (fit-in-context) | 61% | 72% | +12pp |
| Code QA (RubberDuckBench) | 78% | 87% | +9pp |

Cost: **~2.8× more steps** on average (e.g., 10 → 28 steps for curated patch equiv).

### Why It Works

The structured template forces the agent to:
1. **State premises** — what each patch/file modifies, with file:line evidence
2. **Trace execution** — per-test or per-path reasoning, following function calls
3. **Write conclusions** — justified YES/NO based on traced evidence, not intuition

The motivating example (django-13670): standard reasoning assumed `format()` was Python's builtin and concluded two patches were equivalent. Semi-formal reasoning actually traced the definition, discovered a module-level `format()` that expects a `datetime` not an `int`, and correctly concluded non-equivalence.

---

## 2. Mapping to the Current AILANG Runtime

### 2.1 Current Agent Architecture

The runtime boots via `src/core/rpc.ail`:

1. Build system prompt: `base_system(WORKDIR)` → `with_agents_context(...)` → `with_cache_hint(...)`
2. Enter `rpc_loop(state, model, 50, step_delay)` → up to 50 steps of LLM call → extract bash → exec → observe → recurse
3. No semantic distinction between task types — all tasks get the same prompt structure

### 2.2 Integration Points

#### Point A: System Prompt Construction (`src/core/prompts.ail`)

Add a `with_semi_formal_template(prompt, task_type)` step. When the task involves patch equivalence, fault localization, or code understanding, append the relevant certificate template to the system prompt.

**Changes required:**
- New module or extension to `src/core/prompts.ail`: detect task type, append template
- Three template constants: patch equivalence, fault localization, code QA
- Zero breaking changes to `rpc.ail`, `types.ail`, or the TUI

#### Point B: Task Classification

Before entering `rpc_loop`, classify the task to decide whether semi-formal reasoning applies:

```
Task contains "patch", "equivalent", "fix", "bug" → Semi-formal
Task contains "explain", "what does", "how does" → Code QA template
Task contains "refactor", "implement", "add feature" → Standard (no template, too open-ended)
```

Could be simple keyword matching in the TASK string, or a lightweight single LLM classification call.

#### Point C: Verifier Mode (Separate Loop)

The paper distinguishes **agentic verifier** (explores with bash, no execution) from **solver agent** (writes and executes patches). The AILANG agent currently rolls both together. The paper's approach suggests:

```
Solver Agent (current RPC loop)
    → generates patch
    
Verifier Agent (semi-formal reasoning, reads-only)
    → reads solver's patch + test code
    → fills semi-formal certificate
    → predicts EQUIVALENT or NOT
    → feeds back to solver if non-equivalent
```

This maps naturally to the existing architecture — the verifier uses the same `env_client.ail` for bash exploration (`grep`, `find`, `read`) but never runs tests or applies diffs.

---

## 3. AILANG Language Advantages

AILANG is uniquely suited for implementing semi-formal reasoning structures beyond prompt engineering:

| AILANG Feature | Benefits Semi-Formal Reasoning |
|---|---|
| **Algebraic effects** (`! {IO, FS, Net}`) | The certificate itself can be modeled as an effectful computation — evidence is gathered (`FS` for file reads), then a conclusion is produced. Effects make it structurally impossible to "skip" evidence-gathering. |
| **Pattern matching** with `=>` | Certificate templates map to ADTs: `type Verdict = Equivalent | NotEquivalent(Reason)`. Exhaustive `match` forces complete case analysis — the agent cannot skip a case. |
| **Hindley-Milner types** | Types enforce that premises are populated before a conclusion can be derived. `conclude(p: Premises, traces: [ExecutionTrace]) -> Verdict` cannot be called with incomplete evidence. |
| **No loops, only recursion** | Forces explicit case enumeration — exactly what the paper requires. Cannot "loop through tests and skip the hard ones." |
| **Effect polymorphism** (`mapE`, `foldlE`) | `mapE`/`foldlE` guarantee left-to-right evaluation with effects — perfect for "trace each test path and collect evidence" patterns. |

### Key Insight: Typed Certificates vs. String Templates

The paper's certificates are **string-based prompts** that *hope* the LLM follows the structure. With AILANG's type system, certificates could be modeled as **ADTs**, making it structurally impossible to produce an incomplete certificate:

```ailang
type Verdict = Equivalent | NotEquivalent([string])

type Premises = {
  patch1_files: [string],
  patch2_files: [string],
  patch1_changes: string,
  patch2_changes: string
}

type ExecutionTrace = {
  test_name: string,
  file: string,
  line: int,
  observation: string
}

type Certificate = {
  premises: Premises,
  traces: [ExecutionTrace],
  verdict: Verdict
}

-- This function signature guarantees: 
-- Premises must be constructed before verdict
-- Every trace must include file:line evidence
func certify(p: Premises, traces: [ExecutionTrace]) -> Certificate ! {IO, FS}
```

This is **structural enforcement**, not prompt hoping.

---

## 4. Concrete Implementation Sketch

### Level 1: Prompt Engineering Only (Low Risk, Low Effort)

Add certificate templates to `src/core/prompts.ail`. The existing `rpc_loop` naturally produces structured reasoning output. No changes to the agent loop, types, or TUI.

```ailang
-- In src/core/prompts.ail

func semi_formal_patch_equiv_template() -> string =
  "## Semi-formal Proof of Patch Equivalence\n\n" ++
  "## DEFINITIONS:\n" ++
  "- D1: Two patches are EQUIVALENT MODULO TESTS iff executing the test suite produces identical pass/fail outcomes for both.\n\n" ++
  "## PREMISES (state what each patch does):\n" ++
  "P1: Patch 1 modifies [file(s)] by [specific change description]\n" ++
  "P2: Patch 2 modifies [file(s)] by [specific change description]\n\n" ++
  "## EVIDENCE (trace file dependencies, function definitions, test assertions):\n" ++
  "E1: ...\n" ++
  "...\n\n" ++
  "## CONCLUSION:\n" ++
  "The patches ARE / ARE NOT equivalent because [explicit reasoning grounded in evidence].\n"
```

Applied conditionally based on task classification:

```ailang
func build_system_prompt(task, workdir) -> string {
  let base = base_system(workdir);
  let with_agents = with_agents_context(base, workdir);
  let hint = get_hint(task);
  let with_cache = with_cache_hint(with_agents, hint);
  if should_use_semi_formal(task)
  then with_cache ++ "\n\n" ++ semi_formal_patch_equiv_template()
  else with_cache
}
```

### Level 2: Separate Verifier Loop (Medium Effort)

After the solver produces a patch, spin up a second agent (or re-enter `rpc_loop` with a verifier system prompt) that:
1. Reads both patches
2. Reads the test files
3. Fills a semi-formal certificate
4. Returns EQUIVALENT or NOT EQUIVALENT
5. Optionally feeds back to the solver for revision

### Level 3: Typed Certificates in AILANG (High Effort, High Integrity)

Model the entire verification process as typed AILANG code:
- ADTs for `Premises`, `ExecutionTrace`, `Certificate`, `Verdict`
- Effect-polymorphic traversals (`mapE` / `foldlE`) for evidence gathering
- The LLM produces JSON (via `callJson`) that is decoded into the certificate ADT
- Type-checking rejects incomplete certificates at the AILANG level

---

## 5. Trade-offs and Risks

### Token Cost
The paper reports **~2.8× more steps** for semi-formal reasoning. The agent's 50-step budget burns faster on reasoning itself, leaving fewer for exploration and code changes. Mitigation: apply semi-formal templates only to tasks that benefit (patch verification, fault localizing), not to open-ended implementation tasks.

### Model Dependency
Sonnet's benefit from semi-formal reasoning **plateaus** on code QA (85.3% → 84.8%). The structured template helps weaker models more and can even hurt models that already perform well in standard mode. The integration should be **model-aware** — apply more aggressive templating for models below a certain baseline, and lighter or no templating for stronger models.

### Verification vs. Action
The agent currently **acts** (writes code, runs tests). Semi-formal reasoning is about **verifying** without execution. These are complementary, not substitutes. The agent could use semi-formal reasoning to verify its own patch before declaring completion, but that costs extra steps and tokens.

### False Confidence
The paper's error analysis reveals that semi-formal agents can still produce **elaborate but incomplete reasoning chains** and reach confident wrong answers. Structured formatting reduces but does not eliminate hallucination. A typed certificate (Level 3) mitigates this more than a prompt template (Level 1).

---

## 6. Implementation Priority

| Level | What | Effort | Risk | Impact |
|---|---|---|---|---|
| **1: Prompt templates** | Add certificate templates to `prompts.ail`, conditionally applied | Low | None (additive) | Medium — improves reasoning quality on matching tasks |
| **2: Verifier loop** | Separate reads-only verification pass after solver produces patch | Medium | Moderate — new loop logic | High — execution-free feedback before declaring done |
| **3: Typed certs** | Model certificates as AILANG ADTs with effect-polymorphic evidence gathering | High | Moderate — new module, new decode path | Highest — structural guarantees, not prompt hoping |

**Recommended path:** Start with Level 1 (add templates to `prompts.ail`), validate on patch equivalence tasks, then layer Level 2 (verifier loop) if token budget allows. Level 3 is a longer-term architectural play.

---

## 7. Reference: Paper's Certificate Template (Condensed)

From the paper's Appendix A, the full patch equivalence template requires:

```
## Semi-formal Proof of Patch Equivalence

DEFINITIONS:
  D1: EQUIVALENT MODULO TESTS — identical pass/fail outcomes
  D2: Only FAIL_TO_PASS and PASS_TO_PASS tests are relevant

PREMISES:
  P1: Patch 1 modifies [files] by [description]
  P2: Patch 2 modifies [files] by [description]

EVIDENCE (per FAIL_TO_PASS test):
  T1: Test [name] checks [assertion]. Tracing execution:
    - Patch 1: [call chain with file:line locations]
    - Patch 2: [call chain with file:line locations]
    - Result: [same/different behavior because ...]

EVIDENCE (per PASS_TO_PASS test):
  T2: [same structure]

CONCLUSION:
  The patches [ARE / ARE NOT] equivalent.
  Supporting evidence: [explicit citation to traced evidence]
```

The fault localization and code QA templates follow the same structure with task-specific premises and evidence fields.

---

## 8. Repo-Grounded Extension (Deeper Integration)

This section refines the proposal using the current code paths in this repository.

### 8.1 What Already Exists (and Why It Matters)

From `src/core/rpc.ail` and `src/core/prompts.ail`:

1. Prompt assembly is already centralized:
   - `base_system(cwd)` (or `SYSTEM_MD` override)
   - `with_agents_context(system, cwd)`
   - `with_cache_hint(system, hint)`
2. The runtime already has two execution modes:
   - Legacy bash-fence mode (`extract_bash`)
   - Hybrid tool-call mode (`parse_tool_calls` + native/delegated split)
3. Step budget is fixed in code (`rpc_loop(..., 50, ...)`) and applies to both initial and follow-up tasks.
4. Delegated tools round-trip through TUI (`tool_calls` / `tool_results`) while native tools execute inside `src/core/tool_runtime.ail`.

Implication: the cleanest path is to introduce semi-formal reasoning as a **prompt policy + optional tool policy** without changing the event protocol first.

### 8.2 Task Policy Layer (Before `rpc_loop`)

Add a small classifier in `src/core/rpc.ail`:

```ailang
type ReasoningMode = Standard | SemiFormalPatchEq | SemiFormalFaultLoc | SemiFormalCodeQA

func classify_reasoning_mode(task: string) -> ReasoningMode = ...
```

Suggested heuristic (deterministic, no extra LLM call):

1. `SemiFormalPatchEq` if task contains `equivalent`, `same patch`, `compare patch`, `regression parity`
2. `SemiFormalFaultLoc` if task contains `fault`, `root cause`, `where bug`, `why failing`
3. `SemiFormalCodeQA` if task contains `explain`, `what does`, `how does`, `trace`
4. `Standard` otherwise

Use this mode to append a template in `src/core/prompts.ail`:

```ailang
export func with_reasoning_template(system: string, mode: ReasoningMode) -> string = ...
```

### 8.3 Read-Only Verifier Policy (Without New Events)

The current tool set includes mutating actions (`WriteFile`, `BashExec`, `RunTests`).  
To support verifier behavior, add a policy gate in `src/core/tool_runtime.ail`:

```ailang
type ToolPolicy = FullAccess | ReadOnly

func enforce_policy(policy: ToolPolicy, call: ToolCallReq) -> ToolResultItem = ...
```

Rules for `ReadOnly`:

1. Allow: `ReadFile`, `Search`
2. Deny: `WriteFile`, `RunTests`
3. Deny `BashExec` unless command is from a small allowlist (`cat`, `sed -n`, `rg`, `find`, `ls`, `git show`)

Why this shape:

1. No protocol changes required
2. Works in both native and delegated paths
3. Keeps verifier failures explicit as `ToolErrorResult` messages

### 8.4 Two-Pass Flow That Fits Current Loop

Implement inside `main()` / `rpc_loop` orchestration:

1. Solver pass (existing behavior, full access)
2. If task mode is semi-formal-capable and solver produced a candidate final answer:
   - Run verifier pass with:
     - verifier system template
     - read-only tool policy
     - smaller depth budget (for example 12)
3. If verifier verdict is negative/uncertain:
   - Inject verifier findings into solver messages and continue solver loop (remaining budget)
4. If verifier verdict is positive with citations:
   - emit `done`

This can be done with message-level plumbing only; no TUI changes unless you want distinct UI labels.

### 8.5 Structured Certificate Output (Practical Schema)

Before full typed ADTs, require the verifier to output JSON in final answer:

```json
{
  "verdict": "equivalent|not_equivalent|inconclusive",
  "confidence": "low|medium|high",
  "premises": [{"id":"P1","text":"..."}],
  "evidence": [
    {
      "test_or_path":"...",
      "trace":[{"file":"src/x.py","line":120,"note":"..."}],
      "delta":"same|different|unknown"
    }
  ],
  "gaps": ["..."],
  "next_actions": ["..."]
}
```

Then parse with `std/json.decode` in runtime and enforce:

1. `verdict` exists
2. At least one evidence item has `file` + `line`
3. `inconclusive` must include non-empty `gaps`

This gives most of Level 3’s value before introducing new ADTs.

---

## 9. Implementation Plan (Concrete, File-Level)

### Phase A (Prompt-only, no behavior change)

1. `src/core/prompts.ail`
   - Add `ReasoningMode` templates
   - Add `with_reasoning_template(...)`
2. `src/core/rpc.ail`
   - Add `classify_reasoning_mode(task)`
   - Insert template append in boot sequence after cache hint
3. Tests
   - `src/core/prompts_test.ail`: template activation tests

### Phase B (Read-only verifier pass, minimal risk)

1. `src/core/types.ail`
   - Add policy/verdict helper ADTs (if needed)
2. `src/core/tool_runtime.ail`
   - Policy gate for mutating tools
3. `src/core/rpc.ail`
   - Add verifier sub-loop invocation with smaller depth
   - Parse verifier JSON verdict
4. Tests
   - Policy denies `WriteFile` in verifier mode
   - Verifier JSON parse acceptance/rejection

### Phase C (Typed certificate)

1. New module `src/core/certificate.ail`
   - `Premise`, `EvidenceTrace`, `Verdict`, `Certificate`
   - `decode_certificate : string -> Result[Certificate, string]`
   - validation helpers
2. `src/core/rpc.ail`
   - Replace ad-hoc verifier JSON checks with typed decode + validators

---

## 10. Evaluation Plan

Use three benchmarks aligned to the paper and this runtime:

1. Patch equivalence tasks (small curated set from prior trajectories)
2. Fault localization on failing tests in this repo and a few external repos
3. Code QA over `src/core/*` and `src/tui/*`

Track:

1. Accuracy (task-specific)
2. Mean steps and p95 steps
3. Token/cost proxy (`thinking` event count + tool-call count)
4. False-positive verifier rate (`verifier says safe`, solver later fails tests)

Acceptance gates for adopting verifier-by-default:

1. >= +5pp on targeted tasks
2. <= +40% median step increase for solver+verifier combined
3. False-positive verifier rate < 5%

---

## 11. Key Risks and Mitigations (Updated)

1. Step budget pressure (50-step ceiling)
   - Mitigation: reserve budget (`solver 38 + verifier 12`) and short-circuit verifier on low-complexity tasks
2. Verifier over-constrains solver
   - Mitigation: treat verifier as advisory unless confidence high + cited evidence present
3. Read-only bypass via shell
   - Mitigation: strict allowlist for `BashExec` in verifier mode and reject compound shell tokens
4. Prompt bloat from AGENTS + cache + templates
   - Mitigation: compress templates and only enable by mode

---

## 12. Recommended Next Increment

The highest ROI next increment is:

1. Phase A fully (prompt templates + deterministic classifier)
2. A narrow Phase B slice:
   - read-only policy gate
   - verifier pass only for patch-equivalence tasks
   - no new TUI events

This keeps the protocol stable while generating real data on whether semi-formal verification improves outcomes in this runtime.

---

## 13. Full-Paper Grounding Notes (v2 Read-Through)

These points come directly from the full paper and should constrain implementation choices.

### 13.1 Experimental Assumptions We Should Mirror

1. The paper's verifier is **execution-free on repository code**:
   - no running repo tests
   - no dependency setup
2. It still allows static exploration and shell/file inspection, and mentions allowing small independent scripts for language probing.
3. Git/history access is explicitly disabled in their setup.

Implication for this runtime:

1. Verifier mode should deny `RunTests` and mutating tools.
2. Verifier should be configured as static-analysis-first, not mini-solver.

### 13.2 Step-Budget Mismatch Is Material

1. Paper runs with a 100-step ceiling.
2. This runtime defaults to 50 steps (`rpc_loop(..., 50, ...)`).
3. Semi-formal overhead reported in paper is ~2.8x steps on patch-equivalence curated data.

Implication:

1. Always budget-split if adding verifier pass (for example solver 38 / verifier 12).
2. Enable semi-formal mode selectively; avoid default-on for all tasks.

### 13.3 Gains Are Strong but Not Uniform Across Models/Tasks

Paper-level nuance:

1. Large gains on Opus for patch equivalence and code QA.
2. Sonnet code QA semi-formal is near-flat/slightly down in reported table.
3. Fault localization (100-bug sample) shows modest Opus gains; Sonnet can regress in some Top-K metrics.

Implication:

1. Add model-aware gating (or runtime flag) for semi-formal templates.
2. Do not claim universal improvements; track per-model deltas.

### 13.4 Dataset Construction and Ground Truth Caveats

1. Curated patch-equivalence set is intentionally hard (not random).
2. Real-world verifier experiment uses balanced 200 examples with test patches visible.
3. Fault localization uses both `All` and `Any` metrics; `All` is stricter for multi-hunk bugs.

Implication:

1. Internal evaluation should report at least:
   - strict metric (all-required)
   - relaxed metric (any-required)
2. Keep benchmark splits explicit (curated vs random-like) when reporting.

### 13.5 Failure Modes to Bake Into Runtime Checks

Paper error modes map to actionable guardrails:

1. Incomplete tracing → require evidence count and file:line citations before confident verdicts.
2. Third-party semantics guesses → require explicit "unknown external semantics" gap flags.
3. "Difference found but dismissed" → require explicit test-impact linkage per claimed difference.
4. Confident wrong chains in QA → require alternative-hypothesis check section.

Implication:

1. JSON certificate validation should reject high-confidence verdicts with weak citation coverage.
2. Verifier output should include non-empty `gaps` when unknowns remain.
