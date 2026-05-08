---
doc_type: short
full_text: sources/Motoko_AILANG_Rebase_Forward_Handoff.md
---

# Summary: Motoko AILANG Rebase-Forward Handoff

This document is a **self-contained handoff prompt** for executing **Phase 0 and Phase 0.5** of the Motoko AILANG rebase-forward migration. It directs a fresh Claude Code session to set up the baseline and perform an upstream AI layer interface spike, but not to start any actual migration work (Phase 1). The session must answer six gate questions (Q‑A through Q‑F) by reading the v0.13.0 source code directly, and produce a go/no‑go verdict before proceeding.

## Key Points

- **Scope**: Create the `motoko` branch from tag `v0.13.0`, run vanilla builds/tests, capture diffs and behavioral baselines, and evaluate the v0.13.0 AI layer interface.  
- **Gate Questions** (Phase 0.5) cover streaming additivity (Q‑A), `std/ai_motoko` feasibility (Q‑B), builtin registration (Q‑C), effect sets (Q‑D), budget accounting (Q‑E), and Go dependency drift (Q‑F).  
- **Invariants**: The Motoko-facing branch must stay as close as possible to the upstream release. Custom logic will live in `_motoko`-suffixed files and narrowly fenced edits.  
- **Outputs**: 
  - `ailang/` on branch `motoko` at `v0.13.0`  
  - Baseline reports under `.agent/reports/` (phase0 baseline, dev_agent diff, baseline trace, test‑patch readout)  
  - Skeleton `ailang/FORK.md`  
  - Spike report `phase0_5_ai_interface_spike.md` with all six answers and a go/no‑go verdict  
- **Hard stop** after Phase 0.5; no Phase 1 work, no modifications to `dev_agent` or parent‑repo files. If the spike reveals a need for plan revision, the report must explicitly propose revisions.

## Cross‑document Connections

- The handoff explicitly depends on the migration plan: [[summaries/Motoko_AILANG_Rebase_Forward]] (the source of truth).  
- The six gate questions relate to the design of the Motoko custom AI layer, described in [[summaries/OpenAI_LLM_Streaming_For_Motoko]], [[summaries/OpenRouter_Integration]], and [[summaries/Local_OpenAI_Endpoint_Integration]].  
- The spike’s findings will directly inform the eventual implementation of the [[concepts/ailang-custom-layer]] and the [[concepts/rebase-forward-migration]] strategy.  
- The concept of a [[concepts/phase-0-gate-questions]] set is central, as is the [[concepts/ai-layer-interface-spike]] methodology for empirically validating interface compatibility.

## Significance

This handoff encapsulates the **planning-to-execution transition** for the most critical pre‑migration step. It ensures that the AI layer interface gap between Motoko’s custom fork (v0.9.0‑based) and upstream v0.13.0 is fully understood before any code is moved, thereby de‑risking the rebase‑forward approach.