---
doc_type: short
full_text: sources/TM_Evidence_Gates_Integration.md
---

# TM Integration With Evidence Gates – Summary

The document positions Tsetlin Machines (TM) not as a new lever alongside the seven evidence-gates levers, but as a **learning substrate** that enhances existing levers by replacing hand‑coded heuristics with data‑driven propositional rules. It maps TM contributions across the lever hierarchy and defines a phased integration path with immediate, low‑risk value.

## TM and the Evidence‑Gates Levers

- **[[concepts/evidence-gates|Lever 4 (Error→Hint Table)]]** – The TM learns to classify AILANG errors from code features instead of brittle, post‑hoc regex on compiler messages. Learned clauses out‑perform hand‑written `guard.ail` classifiers, are predictive, and self‑improve with more compose data.
- **[[concepts/structured-tool-call-authoring|Lever 2 (Structured Tool‑Call Authoring)]]** – The TM augments the dispatcher: (a) generates empirical validation rules, (b) detects **cross‑call patterns** the per‑call checks miss, and (c) screens the accumulated program state before finalization to skip slow `ailang check` calls.
- **[[concepts/retrieval-few-shot|Lever 3 (Retrieval Few‑Shot)]]** – TM clause activations become failure‑mode‑specific retrieval keys. When the TM predicts a specific error class, the retrieval index can fetch exemplars that demonstrate the **correct pattern** for that failure, making exemplars far more targeted.
- **Measurement Pass** – Training a TM on compose telemetry continuously profiles error distributions, identifies which code features drive failures, and yields per‑model symbolic descriptions of weaknesses (e.g., Python/JS prior bleed). This replaces the one‑off `analyze_compose_meta.py` script recommended in the evidence gates document.

## Phased Integration

1. **Phase 0 – Offline Analysis** (zero risk, days) – Train TM on existing compose data; compare learned clauses against hand‑written rules; produce the measurement baseline and per‑model error profiles.
2. **Phase 1 – Replace `guard.ail` Classifiers** – Translate learned clauses into static AILANG code (drop‑in replacement) or, less preferred, run the TM at runtime.
3. **Phase 2 – Pre‑Finalize Screening** – Add TM evaluation before `handle_finalize` in the dispatcher; skip compilation on high‑confidence error predictions.
4. **Phase 3 – TM‑Guided Retrieval** – Extend retrieval index with TM clause activation vectors; use failure‑mode‑specific exemplars.
5. **Phase 4 – Continuous Retraining** – Periodic retraining on new telemetry, re‑generating classifiers and updating the screening model, with drift logging.

The TM phases map onto the structured authoring roadmap: Phase 0 can start immediately, providing the measurement baseline eagerly; later phases align with authoring phases without delaying them.

## What TM Does **Not** Cover

The TM operates on structural boolean features; it does **not** address Hindley‑Milner inference failures, semantic correctness, grammar‑constrained decoding (Lever 1), fine‑tuning (Lever 7), or thinking‑mode reasoning. It **complements** those levers by accelerating the feedback loop for the errors it can capture.

## Key Concepts
- [[concepts/tm-clauses|TM Clauses]] – Propositional rules learned from (code‑feature, error‑class) pairs; interpretable, predictive, and self‑improving.
- [[concepts/continuous-profiling|Continuous Profiling]] – TM training as an ongoing measurement pass that reveals error drivers and per‑model priors.
- [[concepts/tm-guided-retrieval|TM‑Guided Retrieval]] – Using clause activations to retrieve exemplars tailored to the predicted failure mode.
- [[concepts/pre-finalize-screening|Pre‑Finalize Screening]] – TM‑based gating before the expensive compiler step, shortening the compose loop.