---
doc_type: short
full_text: sources/AILANG_Composition_Subagent.md
---

# AILANG Composition — Subagent Delegation Mode

## Overview
This design evolves the existing inline AILANG composition into a **subagent delegation pattern**. The main agent emits a structured `Compose` tool call with a natural-language intent; a dedicated composition subagent handles the full authoring lifecycle (snippet writing, type-check retries, execution, and summarization). The main agent only sees the final outcome, preserving its context and reducing token waste.

## Motivation
Three pain points drive the change:
- **Retry churn** occupying the main agent’s context with failing snippets and error messages.
- **Conflicting skill demands** bloating the system prompt with both SWE guidance and a large AILANG reference card.
- **Model-tier mismatch** – AILANG authoring is cheap and can run on a smaller model, freeing the expensive main model for judgment tasks.

## Key Design Elements
- **Mode toggle** via `AILANG_COMPOSITION_MODE` env var: `subagent` (default) or `inline` (fallback preserving the existing implementation).
- **Structured `Compose` tool call** with fields: `intent`, `expected_output`, `hints` (read/write paths, avoid capabilities). Replaces raw AILANG fences in the main agent’s output.
- **Subagent loop** in the env-server: LLM authoring → `ailang check` → retry up to `AILANG_SUBAGENT_MAX_ATTEMPTS` → execution → summarization. All retries are invisible to the main agent.
- **TUI visibility** is maintained: `compose_*` events stream to the developer via a nested collapsible card, showing snippets, check results, retries, and summary – without entering the main agent’s `msgs`.
- **Security tightenings**: `hints.avoid` strips capabilities; future path-scoped sandboxing possible.
- **Phased delivery** (Phases 1–5) with incremental rollout, existing inline path untouched.

## Architectural Highlights
- New `/compose` endpoint in env-server emits chunked JSONL events; the runtime forwards them to TUI and synthesizes a `ComposeResult` for the main agent’s history.
- Subagent prompt is strict: one AILANG fence, no prose, full reference card, few-shot examples, and provider-side prompt caching.
- Intent → snippet cache (Phase 4, opt-in) can skip authoring for repeated compositions.

## Related Concepts
- [[concepts/subagent-delegation]] – Offloading AILANG authoring to a specialist subagent.
- [[concepts/compose-tool-call]] – Structured JSON payload replacing inline AILANG fences.
- [[concepts/ailang-composition-mode-toggle]] – Env-var selection between subagent and inline modes.
- [[concepts/retry-loop-visibility]] – Hiding retries from the main agent while showing them in TUI.
- [[concepts/tui-nested-card-rendering]] – Collapsible card UI for subagent activity.
- [[concepts/intent-cache]] – Intent-keyed snippet cache for composition reuse.
- [[concepts/summarization-pass]] – Post-execution LLM call that distills results for the main agent.
- [[concepts/security-per-call-caps]] – Capability narrowing via `hints.avoid` and sandboxing.