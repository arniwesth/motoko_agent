# TM Integration With Evidence Gates — Connecting the Research

## Context

This document connects three prior research artifacts:

1. **Tsetlin_Machines_AILANG_Synthesis.md** — How TMs and AILANG fit together at the language level.
2. **TM_Clauses_Over_AILANG_AST_Elaboration.md** — Concrete design for TM classifiers over AILANG code features, grounded in the existing `guard.ail` hand-written classifiers.
3. **AILANG_performance_evidence_gates.md** — The seven-lever framework for improving AILANG code validity on Gemma 4, with detailed analysis of structured tool-call authoring and grammar-constrained decoding.

The question answered here: where does the TM approach land in the evidence-gates lever hierarchy, what does it replace, what does it feed, and what is the practical path to deployment?

---

## Position in the Lever Hierarchy

The evidence-gates document orders levers by leverage vs. effort:

```
1. Grammar-constrained decoding       (deferred — no endpoint control)
2. Structured tool-call authoring      (primary near-term)
3. Retrieval-conditioned few-shot      (complementary to all)
4. Error→hint table                    (cheap, targeted)
5. Thinking mode for hard intents      (conditional)
6. Skeleton-first, then hole-fill      (composable with 2)
7. Fine-tuning / LoRA                  (highest ceiling, last resort)
```

The TM is not a new lever. It is a **learning substrate** that makes levers 2, 3, and 4 more effective, and that absorbs the measurement pass the document calls for as a prerequisite.

### Lever 4: Error→Hint Table — TM Replaces the Hand-Coded Version

**Current state.** `guard.ail` contains two hand-written classifiers:

```ailang
-- classify_ailang_error: error text → category
if contains(e, "missing effect") || contains(e, "effect checking") then "effect"
else if contains(e, "expected next token") || contains(e, "unexpected token") then "parse"
else if contains(e, "undefined") || contains(e, "not found") then "import_or_symbol"
else if contains(e, "type mismatch") || contains(e, "cannot unify") then "type"
else "other"

-- targeted_hint: error text → remediation string
if contains(e, "missing effect") then "Hint: add missing effects..."
else if contains(e, "=>") || contains(e, "expected next token") then "Hint: AILANG uses match arms with =>..."
...
```

These are propositional formulas over `contains()` predicates, written by hand, operating post-hoc on compiler error messages. Limitations:

- **Post-hoc**: runs after `ailang check`, cannot predict errors before compilation.
- **Fragile**: coupled to error message wording; breaks if compiler changes phrasing.
- **Incomplete**: the `"other"` catch-all absorbs anything unanticipated.
- **Non-discoverable**: only covers patterns a developer thought to enumerate.

**TM replacement.** A TM trained on (AST features, error class) pairs from compose telemetry learns the same mapping from data:

- Operates on code structure, not error message text — decoupled from compiler message format.
- Predictive: classifies before compilation, potentially skipping `ailang check` on obvious errors.
- Complete by learning: novel patterns produce new clauses rather than falling to a catch-all.
- Self-improving: each compose run where the TM's prediction is confirmed or corrected refines the clauses.

The evidence-gates document characterizes lever 4 as "cheap, targeted" and notes that "error→hint tables only help with observed ones" while "prior-substitution levers help with every unfamiliar construct." The TM sits between these categories: it is a learned table that generalizes beyond observed cases through propositional clause logic.

The evidence-gates document also notes that lever 2 (structured tool-call authoring) "mostly subsumes" lever 4: "dispatcher errors are structured hints by design... the hint table reduces to a small residual for errors that cross the dispatcher boundary." Under structured authoring, the TM's role shifts from replacing `classify_ailang_error` entirely to handling the residual — errors that survive the dispatcher and are caught only at `ailang check` finalize time. This is a smaller but still valuable role, because the document acknowledges this residual exists: "type errors may still occur if the dispatcher's light type checking missed something."

### Lever 2: Structured Tool-Call Authoring — TM Augments the Dispatcher

**Current state.** The dispatcher in `authoring/dispatcher.ail` validates tool calls individually:

```ailang
-- dispatch_authoring_tool: routes to handle_set_module, handle_add_import,
--   handle_define_func, handle_replace_func_body, handle_add_remove_effect,
--   handle_rename_var, handle_finalize
-- Each handler validates its own arguments and returns structured errors.
```

The dispatcher's semantic validation responsibilities (from the evidence-gates document):

1. Schema validation — reject malformed tool calls
2. Reference integrity — reject dangling expr IDs
3. Import/symbol validation — reject unknown exports with `did_you_mean`
4. Effect-row well-formedness — declared effects must cover inferred effects
5. Scope checking — reject unbound variables
6. Arity checking — reject wrong argument counts
7. Rendering — canonical pretty-printer
8. Final `ailang check` — real compiler as last gate

Items 4-6 are exactly the boolean features the TM operates on. The TM can augment the dispatcher in two ways:

**A. Bootstrap validation rules.** Train a TM on historical compose data, extract the learned clauses, and translate them into dispatcher validation checks. The clauses are already propositional formulas over the same features the dispatcher tracks — effect declarations, function calls, import lists. This gives the dispatcher an empirically-grounded rule set rather than a hand-enumerated one.

**B. Cross-call pattern detection.** The dispatcher validates each tool call independently. The TM sees the accumulated program state after multiple calls. It can detect inter-call patterns: "you called `add_import("std/fs", ["readFile"])` and then `define_func(name, ..., effects: ["IO"], ...)` — the function calls readFile but the effect row is missing FS." The dispatcher would need explicit cross-call validation logic for this; the TM learns it from data.

**C. Pre-finalize screening.** Before `handle_finalize` renders and compiles, the TM evaluates the accumulated program state features. If it predicts an error class with high confidence, the dispatcher returns a structured error immediately — skipping the render + compile step. This is the latency win: `ailang check` is the slowest step in the compose loop, and every time it can be skipped, the loop tightens.

### Lever 3: Retrieval Few-Shot — TM Activations as Retrieval Keys

**Current state.** The evidence-gates document proposes indexing `.motoko-store/snippets` by intent-kind, required effects, and imports used, and retrieving top 1-3 known-good exemplars per author turn.

**TM enhancement.** When the TM predicts a specific error class via specific clause activations, those activations provide a richer retrieval signal:

- Generic retrieval: "this is an analyze intent needing IO + FS" → retrieve any analyze snippet with IO + FS.
- TM-guided retrieval: "the TM predicts an effect error because `calls_readFile AND NOT declares_FS`" → retrieve exemplars that specifically demonstrate readFile with `! {FS}` declared.

The clause features specify precisely what the exemplar should demonstrate. Different predicted error modes retrieve different exemplars, even for the same intent-kind. This is failure-mode-specific retrieval — the TM tells you not just "this attempt might fail" but "this is what the failure will be" and "this is what the correct version looks like."

The retrieval index changes from (intent-kind, effects, imports) to (intent-kind, effects, imports, TM-clause-activation-vector). The clause activation vector is a binary vector — which clauses fired for this program state — and retrieval finds exemplars whose clause activation vectors are complementary (the exemplar does not trigger the same clauses).

### Measurement Pass — TM Training as Continuous Profiling

**Current state.** The evidence-gates document recommends as a prerequisite:

> Before investing in any lever, quantify which errors dominate on Gemma 4 specifically. Run `scripts/analyze_compose_meta.py` over a recent Gemma batch and categorize failures by: parse vs. type vs. runtime vs. guard; specific error codes within each category; whether the failure is syntactic or semantic.

**TM as measurement.** Training a TM on compose telemetry is this measurement pass in a form that continuously improves:

- **Error distribution**: The clause distribution across error classes IS the error distribution.
- **Error drivers**: The specific literals in high-weight clauses tell you which code features drive each error class. Not just "30% of errors are effect errors" but "effect errors are driven by `calls_println AND NOT declares_IO` (45% of effect errors) and `calls_readFile AND NOT declares_FS` (30% of effect errors)."
- **Per-model profiling**: Train separate TMs on data from different models. The resulting clause sets are symbolic descriptions of each model's weaknesses. Gemma's clauses might be dominated by `uses_def_keyword`, `for_or_while`, `method_call_syntax` (Python/JS prior bleed). Claude's clauses might be dominated by `NOT declares_Env` (effect-row omissions on less common effects).
- **Trend detection**: As the compose system improves (new levers deployed, prompts refined), the TM's clause distribution shifts. Old clauses lose weight, new ones emerge. This is automatic measurement of lever effectiveness — no manual analysis needed.

The document notes: "Gemma's pretraining mix is presumably heavier on Python/JS/Go. Those priors actively mislead." TM clauses would surface this as:

```
Clause: uses_def_keyword => parse_error                     (Python prior)
Clause: for_or_while => parse_error                         (Python prior)
Clause: method_call_syntax => type_error                    (JS/Python prior)
Clause: uses_braces_in_if => parse_error                    (C/JS prior)
Clause: uses_arrow_fn_syntax AND NOT has_match_expr => parse_error  (JS prior)
```

These clauses quantify the prior-bleed problem. The weight/frequency of each clause tells you how much each prior contributes to failures. This is more informative than aggregate error counts.

---

## What the TM Does Not Cover

The evidence-gates document identifies failure modes beyond propositional features:

- **Hindley-Milner inference failures** (ambiguous `foldl` callback typing) — depends on type-level reasoning, not boolean features.
- **Semantic correctness** (does the code solve the task) — orthogonal to code validity.
- **Grammar-constrained decoding** (lever 1) — prevents errors at generation time; TM predicts them post-hoc. Complementary, not substitutes.
- **Fine-tuning / LoRA** (lever 7) — moves the model's priors. TM works around priors. Complementary.
- **Thinking mode** (lever 5) — helps the model reason through constraints. TM does not affect the model's generation process. Orthogonal.

The TM is most valuable in the structural pattern layer: code features predict error classes, hints are generated from clause activations, and retrieval is targeted by failure-mode features. It does not replace the compiler, the type checker, or the model's own reasoning. It accelerates the feedback loop.

---

## Practical Path

### Phase 0: Offline Analysis (Zero Risk, Immediate Value)

Train a TM offline on existing compose telemetry data. No integration with the compose loop.

**Input**: Historical (snippet, error_class) pairs from compose runs. Feature extraction is regex/parsing over source text — same features enumerated in the AST elaboration document.

**Output**: Learned clauses per error class. Compare against hand-written rules in `guard.ail`.

**Value**: 
- Validates whether TM clauses match the hand-written rules (they should, if the rules are correct).
- Discovers patterns the hand-written rules miss (the `"other"` catch-all cases).
- Produces per-model error profiles if data from multiple models is available.
- Quantifies the error distribution — the measurement pass the evidence-gates document requires.

**Effort**: A Python script. Feature extraction + pyTsetlinMachine training + clause extraction. Days, not weeks.

**Decision gate**: Do the learned clauses make sense? Do they discover anything the hand-written rules miss? If yes, proceed to Phase 1. If no, the training data is insufficient or the features are wrong — debug before integrating.

### Phase 1: Replace guard.ail Classifiers

Replace `classify_ailang_error` and `targeted_hint` in `guard.ail` with TM-learned rules.

Two options:

**A. Generate AILANG code from TM clauses.** Translate learned clauses into AILANG functions that match the existing signatures. Deploy as a drop-in replacement for the hand-written versions. Z3-verify the generated functions. No runtime TM needed — the TM's output is static code.

**B. Run the TM at runtime.** Feature-extract from each snippet, evaluate TM clauses, return the predicted class and activated clauses. Requires either a TM runtime in AILANG (possible but slow) or calling out to a Python/Rust TM evaluator (fast but adds a dependency).

Option A is preferred initially: the TM trains offline, emits AILANG code, and the result is a better version of what is already in `guard.ail`. No new runtime dependencies. The generated code can be re-generated periodically as more compose data accumulates.

### Phase 2: Pre-Finalize Screening in the Dispatcher

Add a TM evaluation step before `handle_finalize` in the dispatcher.

After all tool calls have been processed and the program state is accumulated, extract features from the rendered-but-not-yet-compiled source. Run TM clause evaluation. If the TM predicts an error class with confidence above a threshold (clause vote margin > T), return a structured error with the activated clause explanation — skip `ailang check`.

If the TM predicts success or is inconclusive (vote margin below threshold), proceed to `ailang check` as normal.

**Metrics**:
- True positive rate: how often does the TM correctly predict an error that `ailang check` would also catch?
- False positive rate: how often does the TM predict an error on code that `ailang check` would accept?
- Latency saved: average time per compose iteration saved by skipping `ailang check` on TM-predicted errors.
- False negative rate: how often does the TM predict success on code that `ailang check` rejects? (These are the cases where the TM is not helpful — normal path applies.)

**Decision gate**: True positive rate > 80%, false positive rate < 5%. If false positives are too high, the TM is over-predicting and causing unnecessary retries. If true positives are too low, the TM is not catching enough to justify the integration.

### Phase 3: TM-Guided Retrieval

Extend the retrieval index with TM clause activation vectors.

When the TM predicts an error class, use the activated clauses as retrieval keys to find exemplars that demonstrate the correct pattern for the predicted failure mode. Prepend these exemplars to the author prompt.

This is an extension of the existing retrieval proposal from the evidence-gates document. The TM provides a richer signal than intent-kind + effects + imports alone.

**Metrics**:
- First-attempt success rate with TM-guided exemplars vs. generic exemplars.
- Reduction in retry count per compose run.

### Phase 4: Continuous Retraining

Establish a periodic retraining pipeline:
1. Collect new (snippet, error_class) pairs from compose telemetry.
2. Retrain TM on accumulated data.
3. Extract updated clauses.
4. If Phase 1 Option A: regenerate AILANG code in `guard.ail` from new clauses.
5. If Phase 2: update the pre-finalize TM model.
6. Log clause drift (which clauses gained/lost weight) as a signal of changing error patterns.

---

## Interaction With the Structured Authoring Roadmap

The evidence-gates document outlines a five-phase implementation path for structured tool-call authoring:

```
Phase 1 — Schemas and dispatcher skeleton
Phase 2 — Author-loop integration behind capability flag
Phase 3 — Error taxonomy and repair tools
Phase 4 — Measurement
Phase 5 — Expansion
```

The TM work maps onto this timeline:

| Authoring Phase | TM Work | Dependency |
|---|---|---|
| Before Phase 1 | **TM Phase 0**: offline analysis on existing compose data. Produces the measurement pass that authoring Phase 4 needs, but earlier. | None — can start immediately. |
| During Phase 1 | Feature extraction adapts to the dispatcher's program state representation. Features come from the internal AST instead of source text regex. More precise. | Needs the program state schema from authoring Phase 1. |
| Phase 2 | **TM Phase 1**: replace `guard.ail` classifiers with TM-learned rules. | Independent of authoring — operates on source text, not tool calls. |
| Phase 3 | **TM Phase 2**: pre-finalize screening. TM evaluates accumulated program state before `handle_finalize`. | Needs the finalize hook from authoring Phase 1. |
| Phase 4 | TM clause distributions provide the per-error-class measurements. TM profiling replaces or augments `scripts/analyze_compose_meta.py`. | None — TM data feeds authoring Phase 4 directly. |
| Phase 5 | TM clause drift signals which error classes are shrinking (grammar/tool success) and which persist (need finer expression builders). Drives the expansion decision. | None — TM data informs authoring Phase 5 decisions. |

The key observation: TM Phase 0 (offline analysis) is independent of and can run before any authoring work. It produces the measurement baseline the evidence-gates document says is a prerequisite for all levers. Starting the TM work does not delay or depend on the authoring roadmap — it front-loads the measurement.

---

## Implementation Choices

### Where to Train the TM

**Python with pyTsetlinMachine** for Phase 0 and initial training. pyTsetlinMachine is mature, fast, and well-documented. Clause extraction is straightforward. Feature extraction is a Python script that parses AILANG source text with regex.

**AILANG for the deployed classifier** (Phase 1 Option A). The TM's learned clauses are translated to AILANG functions — static code, no runtime TM needed. This keeps the compose system's dependency footprint unchanged.

**AILANG reference TM implementation** (optional, future). If the TM approach proves valuable, a reference TM implementation in AILANG — with Z3-verified feedback logic, TA state transitions, and clause evaluation — becomes a research artifact: the first formally verified Tsetlin Machine. This is not needed for the practical integration but is a natural extension of the Tsetlin_Machines_AILANG_Synthesis work.

### Feature Extraction: Source Text vs. Dispatcher AST

**Phase 0-1**: Features extracted from source text via regex/lightweight parsing. Same features as the AST elaboration document. This works on any AILANG source, including code from the current free-text authoring path.

**Phase 2+**: Features extracted from the dispatcher's internal program state (`ProgramState` in `authoring/state.ail`). This is more precise — the dispatcher already tracks imports, function declarations, effect rows, and body content as structured data. Feature extraction becomes field access on the program state record, not regex over source text.

The transition from source-text features to program-state features is natural as the structured authoring path becomes the primary authoring mode. The TM's clause semantics do not change — only the feature extraction layer.

### NTM vs. Standard TM

For the diagnostic use case (predicting what went wrong), the NTM variant from Paper 2 is preferred:

- Monotonic conjunctions (no negated literals) produce more interpretable clauses: "this code calls println AND imports std/io AND does not declare IO" reads as a direct diagnosis.
- Boosted Type I feedback (P(Reward) = 1.0) converges faster on high-confidence features — important when compose data is limited (hundreds to low thousands of examples).
- Type II feedback still provides cross-class discrimination — clauses that fire for the wrong error class are penalized.

For the retrieval use case (which exemplar to fetch), the standard TM with negated literals may perform better — negated features can distinguish between similar error classes (effect error vs. import error when both involve `readFile`).

Start with NTM. Switch to standard TM if cross-class discrimination is insufficient.

---

## Summary Table

| Evidence-Gates Lever | Current Approach | TM Contribution | TM Phase |
|---|---|---|---|
| Measurement pass | `scripts/analyze_compose_meta.py` (one-off) | TM training as continuous per-model profiling | Phase 0 |
| 4: Error→hint table | Hand-coded in `guard.ail` | Learned propositional rules, predictive, self-improving | Phase 1 |
| 2: Dispatcher validation | Per-tool-call checks in `dispatcher.ail` | Cross-call pattern detection, pre-finalize screening | Phase 2 |
| 3: Retrieval few-shot | Intent-kind + effects + imports | TM clause activations as failure-mode-specific keys | Phase 3 |
| Per-model profiling | Manual analysis of compose batches | Symbolic clause descriptions of each model's weaknesses | Phase 0 (byproduct) |

The investment is incremental: Phase 0 is a Python script that produces the measurement baseline. Each subsequent phase builds on the previous one and has a decision gate. No phase requires infrastructure changes to the compose system — the TM either produces static AILANG code (Phases 0-1) or adds a lightweight evaluation step to the existing dispatcher (Phase 2). The training data already exists in compose telemetry.
