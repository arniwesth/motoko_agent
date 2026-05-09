---
doc_type: short
full_text: sources/TM_Clauses_Over_AILANG_AST_Elaboration.md
---

# TM Clauses Over AILANG AST Features — Elaboration

## Summary

The AILANG compose system uses hand-written propositional classifiers (`classify_ailang_error`, `targeted_hint`) that match error strings after compilation. This document proposes replacing them with a **Tsetlin Machine (TM)** that learns directly from **AST-derived boolean features** of AILANG code, enabling error prediction *before* compilation. The learned clauses are interpretable, auditable, and automatically translatable back into AILANG code, forming a self-improving loop that refines with every compose run.

## Key Concepts

### 1. From Hand-Written Rules to Learned Clauses
- Existing classifiers operate on error-message text, coupling them to compiler wording and making them reactive.
- A TM learns clause-based rules from data: conjunctions of literals that directly encode the presence or absence of specific code features, such as `calls_println AND NOT declares_IO`.

### 2. [[concepts/ast_feature_extraction]]
- **~80 boolean features** are extracted from source text before compilation:
  - Structural (module declaration, match expressions, lambda usage)
  - Import patterns (std/io, std/fs, quoted imports)
  - Effects declared (IO, FS, etc.)
  - Function calls (println, readFile, httpGet)
  - Anti-patterns (Python‑isms, method‑call syntax, missing `show`)
- Features are cheap to compute via simple parsing, faster than full type‑checking.

### 3. Classification Targets and Training Data
- Targets: `correct`, `effect`, `parse`, `type`, `import_or_symbol`, `other`.
- Training sources:
  - **Compose telemetry** (real LLM-generated code and its check results)
  - **Test suite** (positive and deliberately broken examples)
  - **Synthetic data** via LLM-guided semantic bootstrapping, including sub-intent discovery and three-stage generation.

### 4. Learned Clauses: Interpretable Error Signatures
- The TM game dynamics produce clauses like:
  - `calls_println AND NOT declares_IO AND imports_std_io` → effect error
  - `uses_braces_in_if` → parse error
  - `calls_map AND NOT imports_std_list` → import/symbol error
- Type II feedback refines clauses for cross‑class discrimination, e.g., adding `imports_std_io` to distinguish missing‑import from missing‑effect.

### 5. Translation to AILANG
- Learned clauses are mechanically converted to pure boolean functions on a `CodeFeatures` record.
- The full multi‑class classifier becomes a Z3‑verifiable AILANG function that uses majority voting across clause pools.

### 6. [[concepts/self-improving_loop]]
- Pre‑compile prediction: TM flags likely errors → skip `ailang check`, save latency and API cost.
- On misclassification (predict “correct” but check fails), the example is fed back to retrain the TM.
- Activated clauses automatically generate targeted hints, replacing the hand‑written `targeted_hint` function.

### 7. Impact on the Compose System
- Replaces brittle string‑based classifiers with robust, feature‑based ones.
- Reduces compose iterations by preempting errors.
- Enhances telemetry: clause activation patterns become fine‑grained signals of LLM error tendencies.
- Improves the compose guard against fabricated analysis by learning discriminative structural patterns.

## Feasibility
- **Scale**: ~160 literals, well within TM capacity (similar to MNIST with 784 features).
- **Data**: A few hundred compose runs yield >1000 labeled snippets; synthetic bootstrapping fills initial gaps.
- **Speed**: Feature extraction is regex‑based and faster than type‑checking.

This approach replaces hand‑crafted heuristics with learned, auditable propositional logic that improves automatically – a direct fit for AILANG’s symbolic and self‑correcting agentic loop.