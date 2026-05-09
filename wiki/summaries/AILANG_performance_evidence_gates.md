---
doc_type: short
full_text: sources/AILANG_performance_evidence_gates.md
---

# Summary: AILANG performance evidence gates

This document outlines a future plan to improve the quality of Compose AILANG analysis tasks by introducing **evidence gates** that enforce grounded output, and by addressing the fundamental distribution-shift problem faced by the target model, Gemma 4 26B‑A4B‑it.

## Core evidence‑gate proposals
Three immediate patches are suggested for the analysis pipeline:
- **Minimum file evidence:** require a minimum number of successful `readFile` calls and non‑trivial file sizes before accepting an analysis result.
- **Grounded‑findings retry gate:** verify that the output contains concrete file paths and factual statements extracted from those files; if missing, retry with a corrective hint.
- **Prefer structured validators:** replace free‑text `expected_output` with structured kinds like `"contains_all"` or a new `"analyze_findings"` JSON schema to improve confidence checks.

These gates are intended to prevent shallow analysis and to integrate cleanly with the model’s native strengths (tool calling, structured output) and large context window.

## Target model implications — Gemma 4
Because the agent runs on `google/gemma-4-26B-A4B-it`, the plan must account for its capabilities:
- **Native tool calling and structured output** should be the preferred paths, making the evidence gates easier to enforce.
- **256 K context window** relaxes compaction requirements but demands care with thinking‑transcript replay.
- **Thinking mode** (`<|think|>`) must be sanitised from history when replayed; an opt‑in toggle is recommended.
- **Recommended sampling** (`temperature=1.0`, `top_p=0.95`, `top_k=64`) should be adopted when targeting Gemma.

## The AILANG validity problem — distribution shift
Gemma 4 struggles to generate valid AILANG because the language is outside its pre‑training distribution. The root cause is **closeness of prior languages**: frontier models succeed because they are trained on languages similar to AILANG (OCaml, Haskell), while Gemma’s Python/JS priors actively mislead. This leads to recurrent parse failures and type errors despite existing retry logic.

## Candidate levers (ordered by leverage)
Seven levers are proposed to close the validity gap:
1. **Grammar‑constrained decoding** — eliminate invalid syntax at sampling time (requires self‑hosted vLLM).
2. **Structured tool‑call authoring** — replace free‑text code generation with a tool‑call API that builds AILANG programmatically.
3. **Retrieval‑conditioned few‑shot exemplars** — inject known‑good, intent‑matched code snippets as in‑context examples.
4. **Deterministic error→hint table** — map specific `ailang check` errors to targeted corrective hints on first failure.
5. **Thinking mode for hard intents only** — enable reasoning for complex tasks, disabled for trivial ones.
6. **Skeleton‑first, then hole‑fill** — generate structural scaffolding deterministically, let the model fill only the body.
7. **Fine‑tuning / LoRA** — adapt the model on a corpus of valid AILANG; highest ceiling, highest cost.

## Deep‑dive on the two most actionable levers

### [[concepts/grammar-constrained decoding]]
Deferred because it requires endpoint‑level control unavailable on hosted Gemma providers. The analysis covers library choices (xgrammar, llguidance), grammar strategies (JSON‑schema wrapping, skeleton CFG, full AILANG CFG), and the limitations (type errors persist). When self‑hosting becomes possible, a staged rollout is prescribed, starting with JSON‑schema wrapping and advancing to a skeleton CFG.

### [[concepts/structured tool-call authoring]]
The primary near‑term candidate: the model never types source code directly but instead calls structured tools (`add_import`, `define_func`, `build_block`, etc.) that a dispatcher assembles into valid AILANG. This plays to Gemma’s native tool‑calling strength, removes syntax errors, and provides rich, typed error feedback for retries. A phased implementation is proposed, from schemas and dispatcher skeleton to author‑loop integration and measurement.

## Related concepts
- [[concepts/evidence gates]] — the analysis‑quality preconditions described above.
- [[concepts/gemma-4-ailang-distribution-shift]] — why Gemma fails on AILANG and what that implies for mitigation.
- [[concepts/retrieval-conditioned few-shot]] — using similar snippets to anchor generation.
- [[concepts/error-to-hint table]] — deterministic repair hints from compiler errors.
- [[concepts/structured tool-call authoring]] — the dispatcher‑based code‑building approach.
- [[concepts/grammar-constrained decoding]] — token‑level enforcement of syntax.
- [[concepts/ailang-validity-levers]] — the full set of interventions and their trade‑offs.

## Key decisions and open items
- The plan must be formalised with exact thresholds, telemetry, and ramp strategy.
- Baseline measurement of failure distribution on Gemma 4 is needed before applying any lever.
- Structured authoring tool‑call API design questions remain: AST handle representation, composite/template tools, budget accounting.
- The error→hint table should be a data file (JSON/YAML) to allow extension without code changes.
- Grammar‑constrained decoding is fully deferred pending endpoint control; its analysis serves as an activation checklist.

This document provides a cohesive strategy for raising AILANG analysis quality, with immediate steps (evidence gates) and a prioritised research roadmap for the deeper validity challenge.