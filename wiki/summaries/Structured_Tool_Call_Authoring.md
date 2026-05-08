---
doc_type: short
full_text: sources/Structured_Tool_Call_Authoring.md
---

# Structured Tool-Call Authoring for AILANG – Summary

This plan introduces a **structured tool-call authoring surface** (Option 2: skeleton + free‑text bodies) for the Compose author loop. Its goal is to **eliminate parse errors** when generating [[AILANG]] code with [[Gemma 4]] by shifting syntax responsibility from the model to a deterministic dispatcher.

## Core idea
Instead of asking the model to emit raw AILANG (where its Python/JS priors cause frequent syntax failures), the model uses **fenced `tool_call` JSON blocks** (the same protocol already proven for read‑side tools) to build a program step‑by‑step. The dispatcher accumulates an in‑memory program and renders valid AILANG at `finalize()`. The model chooses *content*, the dispatcher owns *shape*.

## Key components
- **Authoring tool surface** (Phase 1): tools like `set_module`, `add_import`, `define_func`, `build_block`, `build_match` and `finalize`. Function bodies remain free‑text AILANG that is parsed immediately; parse errors are returned as structured tool‑call feedback.
- **Dispatcher** (a write‑side extension to the existing [[fenced-tool-call-protocol|fenced tool_call dispatcher]]) validates schema, checks references, hints at effects, and renders canonical AILANG. `ailang check` at `finalize()` remains the authoritative type/effect checker.
- **Phased rollout**: Phase 0 establishes baselines and schemas; Phase 1 builds the dispatcher and renderer; Phase 2 integrates behind a feature flag; Phase 3 adds repair tools; Phase 4 measures impact and decides on default activation; Phases 5–6 are conditional enhancements (finer expression builders, native tool‑call transport).

## Motivation and fit for Gemma 4
Gemma 4 is **out‑of‑distribution for AILANG syntax**, leading to high parse‑error rates. Structured authoring:
- exercises Gemma’s strong JSON‑emission ability,
- uses Python/JS‑friendly calls like `add_import(...)`,
- returns localized, actionable errors per tool call,
- collapses retry loops into structured repair interactions.

## Relation to broader research
This is **lever 2** from [[AILANG-performance-evidence-gates|the performance evidence gates research note]] – the highest‑leverage fully deployable option without endpoint‑side control. It also complements existing work on the [[compose-author-loop|compose author loop]], [[compose-author-premise-tools|read‑side author tools]], and prepares ground for future [[native-tool-calling|provider‑native tool calling]].

## Risks and monitoring
Main risks: malformed JSON under load (mitigated by the existing fence dispatcher), schema cognitive load (addressed by a minimal initial surface), body parse errors (caught at the tool level). Telemetry focuses on parse‑error rate (target < 2 %), first‑attempt success, and tool‑call budgets. Fallback policies allow graceful degradation back to free‑text authoring if structured mode fails.

## Open decisions
- AST handle representation: string IDs vs. inline nesting.
- Precise split of semantic validation between dispatcher and the real `ailang check`.
- Composite template tool inventory beyond `scaffold_main`.
- JSON‑emission reliability of Gemma 4 under high schema complexity (calibrated by a Phase 0.3 smoke test).

## Future options
Runtime observations (`author_no_action`, `author_turn_limit`) already suggest fallback improvements, stronger prompt contracts, and auto‑repair heuristics – listed as deferred options to be revisited after initial roll‑out.