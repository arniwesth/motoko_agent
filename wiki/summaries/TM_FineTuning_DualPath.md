---
doc_type: short
full_text: sources/TM_FineTuning_DualPath.md
---

# TM + Fine-Tuning: Dual-Path Prior Correction

This document integrates the Tsetlin Machine (TM) research line with the Gemma 4 fine-tuning plan, showing they form a complementary error-correction system. The **shared root cause** is Gemma 4’s pre-training priors that pull generation toward Python/JS patterns, causing parse and type errors in AILANG. The TM learns clauses like `uses_def_keyword => parse_error` ([[concepts/tm_learned_clauses|learned clauses]]), while fine-tuning aims to shift the model’s prior distribution. Both are needed because fine-tuning reduces but doesn’t eliminate errors.

## Complementary Roles

- **Fine-tuning** (lever 7) addresses the cause: it overrides Python/JS priors via a LoRA-trained model on synthetic AILANG examples.
- **TM** (levers 2-4) addresses the effect: it catches errors that remain after fine-tuning, acting as a pre-finalize guard ([[concepts/tm_error_detection|TM error detection]]).

## Shared Training Data

The fine-tuning dataset includes an Error Recovery category (30%) with synthetic mistake→error→correction trajectories. These (mistake, error_class)