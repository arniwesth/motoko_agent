---
doc_type: short
full_text: sources/Semi_Formal_Reasoning_Integration.md
---

# Semi-Formal Reasoning Integration Plan (Revised)

**Document type:** Implementation plan  
**Date:** 2026-04-06  
**Authors:** gpt-5.3-codex, sonnet-4.6, gemini-3.1-pro-preview  
**Status:** Proposed  

## Overview
This plan outlines a phased approach to embed semi-formal reasoning into the Motoko/AILANG runtime. Its dependency on the extension architecture is described in [[summaries/Core_Extension_System_for_Semi_Formal]]. The goal is to make reasoning measurable, safe, and structurally enforceable beyond prompt-only formatting. The design avoids reliance on prompt compliance alone, separates structural from semantic validity, and keeps budget controls explicit.

## Design Principles
- No reliance on prompt compliance alone.
- Stable protocol unless a measurable benefit requires changes.
- Verifier constraints enforced via runtime policy, not just prompt text.
- Structural vs. semantic validity separation.
- Configurable, explicit budget controls.

## Phased Implementation

### Phase A: Prompt + Deterministic Routing
Modifies `prompts.ail` and `rpc.ail` to add deterministic task routing for semi-formal templates (patch equivalence, fault localization, code QA). Template injection point is after `with_cache_hint` in `rpc.ail::main()`, ensuring it survives `SYSTEM_MD` overrides. Controlled by `SEMI_FORMAL_ENABLED` and `SEMI_FORMAL_TASKS` flags. Backward-compatible when disabled.

### Phase B: Step Budget Controls
Replaces hardcoded step depths with env-configurable `AI_MAX_STEPS`, `AI_MAX_STEPS_SOLVER`, and `AI_MAX_STEPS_VERIFIER`. Implements precedence and rounding logic for budget splitting. Both `main()` and `conversation_loop` call sites are updated. See [[concepts/step-budget]].

### Phase C: Read-Only Verifier Tool Policy
Introduces a `ToolPolicy` type (`FullAccess` | `ReadOnly`) and threads it through the tool call chain. In `ReadOnly` mode, mutations are denied, and only a strict readonly allowlist of bash commands is permitted. Policy violations return structured errors. This ensures verifier safety; see [[concepts/tool-policy]].

### Phase D: Verifier Pass Orchestration
Adds an optional second-pass verifier flow (starting with patch equivalence). The solver runs with `FullAccess`, then a verifier runs with `ReadOnly`, evaluating the solver's output. Verifier verdicts (`equivalent`, `not_equivalent`, `inconclusive`) determine whether to finalize or inject findings back into the solver. Verifier events carry `"pass": "verifier"`. This phase relies on the [[concepts/verifier-pass]] design and the tool policy from Phase C.

### Phase E: Certificate Schema + Semantic Validators
Defines an initial JSON certificate schema with fields: verdict, confidence, premises, evidence, gaps, etc. Semantic validators ensure evidence quality, non-empty gaps for inconclusive, and citation coverage for high confidence. Malformed certificates trigger corrective messages. See [[concepts/certificate-schema]].

### Phase F: Typed Certificates (ADT-Backed)
Replaces ad-hoc JSON checks with ADT-backed certificate types and a typed decode/validation pipeline in `certificate.ail`. Maintains backward-compatible error messages.

## Rollout Strategy
- Ship flags with safe defaults (all zero) for no behavioral change.
- Enable Phase A in canary environments.
- Roll out Phase C policy before Phase D verifier (so verifier always runs ReadOnly).
- Start with patch-equivalence tasks; expand to fault localization after validation.
- Evaluation gates: accuracy improvement, step/cost overhead, false-positive rate, no regressions.

## Example End-to-End Tests
Two grounded examples are provided: a patch-equivalence verification session using fixtures and verifier, and a fault-localization session without verifier. Both illustrate expected tool usage, certificate shape, and operator checklists.

## Cross-Document Concepts
- [[concepts/semi-formal-reasoning]]: the overall integration philosophy.
- [[concepts/tool-policy]]: enforcement of readonly constraints for verifier safety.
- [[concepts/step-budget]]: dynamic step limits for solver/verifier splits.
- [[concepts/verifier-pass]]: orchestrated two-pass reasoning.
- [[concepts/certificate-schema]]: structured output for verifier conclusions.
- [[concepts/extension-system]]: the optional substrate described in the dependency plan.
