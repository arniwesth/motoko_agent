# TM + Fine-Tuning: Dual-Path Prior Correction

## Context

This document connects the Tsetlin Machine research line with the Gemma 4 fine-tuning plan from the Kaggle hackathon session. The two efforts are not independent — they share training data, address the same root cause (Python/JS prior bleed), and produce complementary outputs.

The fine-tuning plan (lever 7) shifts Gemma 4's priors so it generates valid AILANG more often. The TM (augmenting levers 2-4) catches errors that survive the shifted priors. Neither alone is sufficient. Together they close the loop.

---

## Shared Root Cause

Both research lines diagnose the same problem, stated in the evidence-gates document:

> Gemma 4's pre-training priors pull it toward Python/JS. Those priors actively mislead: they pull generation toward `def`, `for`, `while`, `class`, `{...}` blocks with Python-style semantics, `list.map()` method syntax.

The fine-tuning session restates it:

> We need to violently overwrite its Python/JS priors.

The TM surfaces the same problem as learned clauses:

```
Clause: uses_def_keyword => parse_error                     (Python prior)
Clause: for_or_while => parse_error                         (Python prior)
Clause: method_call_syntax => type_error                    (JS/Python prior)
Clause: uses_braces_in_if => parse_error                    (C/JS prior)
```

Fine-tuning attacks the cause (prior distribution). The TM observes the effect (error patterns). Both are needed because fine-tuning reduces error frequency but does not eliminate it — the evidence-gates document explicitly notes that even frontier models with much closer priors (Claude Opus at 84.3%) still fail 15% of the time.

---

## Shared Training Data

The fine-tuning plan generates synthetic data via Claude Opus in three categories:

| Category | Weight | Content |
|---|---|---|
| Core Syntax | 40% | Block vs. expression `let`, multi-arg vs. curried, effect rows |
| Z3 Contracts | 30% | `requires`/`ensures` with integer arithmetic, list theory, string theory |
| Error Recovery | 30% | Simulated mistake → compiler error → thought process → correction |

The TM training data is (AST features, error class) pairs from compose telemetry.

These overlap in a specific and useful way:

### The Error Recovery category IS TM training data

The 30% Error Recovery trajectories in the fine-tuning dataset contain:
1. A deliberately incorrect AILANG snippet (the mistake)
2. A simulated compiler error
3. A thought trace explaining the error
4. The corrected code

Items (1) and (2) are exactly what the TM trains on: code features extracted from the mistake, labeled with the error class. The fine-tuning pipeline generates TM training data as a byproduct.

But the fine-tuning pipeline generates *synthetic* errors (Claude Opus simulating mistakes). The TM should train on *real* errors (from compose telemetry). The question is whether synthetic errors match real errors.

### TM as data quality validator

This is where the TM adds immediate value to the fine-tuning pipeline:

1. Train a TM on real compose telemetry (Phase 0 from the TM integration plan — the offline analysis).
2. Extract the learned clauses. These describe the real error distribution.
3. Compare the TM's clause set against the error patterns in the synthetic fine-tuning data.

If the synthetic data covers the same patterns the TM found in real data, the dataset is well-targeted. If there are high-weight TM clauses with no corresponding synthetic examples, the dataset has gaps — generate more examples for those patterns.

Concretely: if the TM's top clause for parse errors is `mixes_semi_and_in` (mixing `;` and `in` binding styles) but none of the 200 Core Syntax examples demonstrate this mistake, the fine-tuning data will not teach Gemma to avoid it. The TM flags the gap.

### TM-guided dataset composition

The fine-tuning plan uses fixed weights (40/30/30) and hand-written category descriptions. The TM can make these data-driven:

- The category weights should reflect the real error distribution. If 60% of real compose failures are parse errors and 10% are type errors, the dataset should over-index on parse examples, not split evenly.
- Within each category, the specific mistake patterns should match the TM's high-weight clauses. If `match_arm_multi_let_no_braces` is a top parse-error clause, the synthetic dataset needs examples of that specific mistake.
- The evidence-gates document says: "Before investing in any lever, quantify which errors dominate on Gemma 4 specifically." The TM does this quantification. The fine-tuning dataset composition follows from the TM's clause distribution.

---

## The Dual-Path Architecture

```
                  ┌─────────────────────────────┐
                  │   Compose Telemetry          │
                  │   (snippet, error_class)     │
                  └──────────┬──────────────────┘
                             │
                    ┌────────┴────────┐
                    ▼                 ▼
            ┌──────────────┐  ┌──────────────────┐
            │  TM Training │  │  Dataset Design   │
            │  (offline)   │  │  for Fine-Tuning  │
            └──────┬───────┘  └────────┬──────────┘
                   │                   │
                   ▼                   ▼
            ┌──────────────┐  ┌──────────────────┐
            │  Learned     │  │  Claude Opus      │
            │  Clauses     │  │  Synthetic Data   │
            └──────┬───────┘  └────────┬──────────┘
                   │                   │
          ┌────────┴────┐              │
          ▼             ▼              ▼
   ┌────────────┐ ┌──────────┐ ┌──────────────────┐
   │ Validate   │ │ guard.ail│ │ Gemma 4 LoRA     │
   │ Synthetic  │ │ Replace  │ │ Fine-Tuning      │
   │ Dataset    │ │ Hints    │ │                   │
   └────────────┘ └──────────┘ └────────┬──────────┘
                                        │
                                        ▼
                               ┌─────────────────┐
                               │ Fine-Tuned       │
                               │ Gemma 4          │
                               └────────┬─────────┘
                                        │
                                        ▼
                               ┌─────────────────┐
                               │ Compose Loop     │
                               │ (reduced errors) │
                               └────────┬─────────┘
                                        │
                                        ▼
                               ┌─────────────────┐
                               │ TM catches       │
                               │ remaining errors │
                               │ (pre-finalize)   │
                               └──────────────────┘
```

The TM feeds three outputs into the fine-tuning pipeline:
1. **Dataset validation**: Are the synthetic mistakes representative of real mistakes?
2. **Dataset composition guidance**: Which error patterns need more training examples?
3. **Gap analysis**: Which real error patterns have no synthetic coverage?

The fine-tuning produces a model that makes fewer errors. The TM catches what remains.

---

## Concrete Workflow

### Step 1: TM Phase 0 (before any fine-tuning)

Train a TM on existing compose telemetry. Extract clauses. This takes an afternoon and costs nothing beyond compute time for a Python script.

Output: a clause set describing Gemma 4's real error patterns, with weights indicating frequency.

### Step 2: Dataset Design (informed by TM)

Use the TM clause set to design the fine-tuning dataset:

- For each high-weight TM clause, generate synthetic examples that demonstrate the mistake and its correction.
- Weight categories proportionally to the TM's error class distribution.
- For the Error Recovery category specifically, the "mistakes" in the synthetic data should match the TM's clause patterns, not generic AILANG docs "Common Mistakes."

Example: if the TM finds that 25% of Gemma 4's parse errors involve `uses_in_keyword AND in_block_context` (using `let x = 1 in` inside `{ }` blocks), then 25% of the parse-error recovery examples should demonstrate this specific mistake.

### Step 3: Validate Synthetic Data Against TM

After generating the 500-sample micro-pilot dataset (or the full 15k dataset), extract AST features from the "mistake" portions of Error Recovery examples. Run them through the TM. Check:

- Do the synthetic mistakes trigger the same TM clauses as real compose failures?
- Are there high-weight TM clauses that no synthetic example triggers? (These are coverage gaps.)
- Are there synthetic mistake patterns that trigger no TM clauses? (These are either novel or unrealistic.)

This is a mechanical check — a Python script that runs feature extraction on the synthetic data and evaluates TM clauses. No human judgment needed.

### Step 4: Fine-Tune with Validated Data

Proceed with the micro-pilot (Phase 0 of the fine-tuning plan). Use the TM-validated dataset.

### Step 5: Evaluate and Retrain TM

After fine-tuning, run the fine-tuned Gemma 4 on compose tasks. Collect new telemetry. Retrain the TM on the new data.

The TM's clause distribution should shift: clauses corresponding to patterns the fine-tuning addressed should lose weight. Clauses corresponding to patterns the fine-tuning missed should gain relative weight.

This tells you:
- Did the fine-tuning work? (Clause weights dropped for targeted patterns.)
- What to target next? (New high-weight clauses indicate the remaining failure modes.)
- Is the fine-tuning overfitting to the synthetic distribution? (If real compose failures diverge from the patterns in the training data, the TM will surface the divergence.)

---

## The Micro-Pilot as TM Training Ground

The fine-tuning plan's Phase 0 micro-pilot generates data the TM can use:

- **Base Gemma 4 on 20 AILANG prompts**: The failures produce (snippet, error_class) pairs. These are TM training examples from the pre-fine-tuning distribution.
- **Micro-Pilot Gemma on the same 20 prompts**: The remaining failures produce TM training examples from the post-fine-tuning distribution. The TM's clause comparison between the two sets measures exactly what the fine-tuning changed.
- **The 500 synthetic examples**: The Error Recovery subset provides additional labeled data for TM training — synthetic but validated against real patterns.

The micro-pilot costs ~$25 total. It produces:
1. A fine-tuned model checkpoint (the primary output).
2. A TM trained on real Gemma 4 error patterns (byproduct).
3. A TM-validated assessment of synthetic data quality (byproduct).
4. A before/after clause comparison measuring fine-tuning effectiveness (byproduct).

---

## Connection to the Fine-Tuning Script

The existing `generate_phase0_data.py` script has a specific structure that matters for TM integration:

```python
CATEGORIES = [
    {"name": "Core Syntax", "weight": 0.4, ...},
    {"name": "Z3 Contracts", "weight": 0.3, ...},
    {"name": "Error Recovery", "weight": 0.3, ...}
]
```

**Current issue with the script (from memory summary)**: `NUM_SAMPLES < 10` with fractional weights rounds to zero tasks — `int(N * w)` produces 0 when N is small. Use `max(1, int(N * w))` or `random.choices()`. Also: `max_tokens=2000` is too low for the XML-tagged output format — the memory summary recommends 8192 to prevent truncation that causes regex parse failures.

**TM-informed modifications**:

1. Replace fixed weights with TM-derived weights. If the TM finds the error distribution is 50% parse / 30% effect / 15% type / 5% import, the category weights and sub-category distributions should reflect this.

2. Add sub-categories within Error Recovery that correspond to specific TM clauses:

```python
ERROR_SUBCATEGORIES = [
    {"clause": "mixes_semi_and_in", "weight": 0.25,
     "instruction": "Simulate mixing semicolons and `in` bindings inside a {} block..."},
    {"clause": "calls_println_without_IO", "weight": 0.20,
     "instruction": "Simulate calling println without declaring IO effect..."},
    {"clause": "curried_call_on_multiarg", "weight": 0.15,
     "instruction": "Simulate using f(a)(b) on a multi-arg function..."},
    # ... derived from TM clause weights
]
```

3. After generation, run a validation pass that extracts features from each Error Recovery sample and checks TM clause coverage.

---

## Summary: What Each Path Needs From the Other

| Fine-Tuning Needs From TM | TM Needs From Fine-Tuning |
|---|---|
| Error distribution to set dataset weights | Compose telemetry from fine-tuned model to measure effectiveness |
| Specific mistake patterns for Error Recovery examples | Before/after comparison to validate TM clause sensitivity |
| Synthetic data validation (do generated mistakes match real ones?) | Nothing — TM Phase 0 is independent |
| Coverage gap analysis (which real patterns have no synthetic coverage?) | Nothing — TM Phase 0 is independent |

The TM work is strictly upstream of the fine-tuning work for dataset design, and strictly downstream of the fine-tuning work for effectiveness measurement. There is no circular dependency. The execution order is:

```
1. TM Phase 0: offline analysis on existing compose data         (independent, start now)
2. Fine-tuning dataset design: informed by TM clause distribution (depends on 1)
3. Fine-tuning micro-pilot: train and evaluate                    (depends on 2)
4. TM retrain: on post-fine-tuning compose data                   (depends on 3)
5. Fine-tuning scale-up: informed by TM's before/after comparison (depends on 4)
```

Step 1 costs nothing and produces actionable output regardless of whether fine-tuning proceeds. It is the natural first move.
