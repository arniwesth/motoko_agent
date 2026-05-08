---
doc_type: short
full_text: sources/DST_v1_Motoko_Core.md
---

## Summary of DST_v1_Motoko_Core

This document details the plan for a first-pass [[concepts/deterministic-simulation-testing]] harness for the Motoko agent's AILANG core. The primary goal is **CI regression coverage** – catching behavioral drift and robustness bugs on every commit – rather than full production chaos testing. The approach uses an import-shim architecture, mock LLM and environment modules, and property-based tests run natively in AILANG via `ailang test`.

### Key Concepts and Decisions

- **Purpose:** CI regression harness only; GRPO-style trajectory replay is deferred to v2. ([[concepts/testing-phases]])
- **Architecture:** An **import shim** parameterizes the main loop (`run_loop`) over its AI call and environment execution effects. This avoids patching the AILANG runtime and supports fork-friendliness.
- **Mocking:** Mock LLM is a scripted state machine with seeded adversarial generators (not replayed tapes). Mock environment is Tier-1 canned responses with a hostile default miss policy. ([[concepts/mock-design]])
- **Invariants:** Priority-0 invariants are (a) parser fuzzing (totality and determinism) and (b) full-loop termination in ≤50 steps and no panics under adversarial output. ([[concepts/property-based-testing]])
- **Milestones:** M0 refactors `rpc.ail` for testability; M1 builds parser property tests; M2 creates mock LLM; M3 creates mock env; M4 writes full-loop property tests; M5 wires CI. Estimated total effort 5–8 days. ([[concepts/milestone-planning]])
- **Open questions:** Effect capabilities in property bodies (OQ1), effect-row compatibility between `std/ai::call` and mock (OQ2), SharedMem isolation across property runs (OQ3), and AGENTS.md discovery (OQ4). Each has a known fallback. ([[concepts/open-questions]])
- **CI strategy:** Two separate jobs: a blocking regression job with fixed seed `42` per PR, and a non-blocking nightly fuzz job with rotating seed and 5000 runs. Failing seeds are reproducible locally. ([[concepts/ci-integration]])
- **Non-goals:** No production chaos testing, no trajectory replay for RL, no coverage completeness, and no generalization beyond Motoko's core. ([[concepts/scoping]])

### Beyond v1 Roadmap

Three tiers of expanded testing are outlined: Tier A (chaos monkey with HTTP/network fault injection, 2–4 weeks), Tier B (record + replay for GRPO reproducibility, 1–2 months), and Tier C (true DST akin to Antithesis, deferred indefinitely). The document acknowledges that live LLMs are structurally non-deterministic, meaning full determinism at the LLM layer is impossible – a core architectural constraint. 

See also: [[concepts/ailang-effects]], [[concepts/deterministic-simulation-testing]], [[concepts/mock-design]], [[concepts/property-based-testing]], [[concepts/ci-integration]].