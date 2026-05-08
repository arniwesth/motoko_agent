---
doc_type: short
full_text: sources/TUI_Tool_Call_Rendering_UI_Spec_Drafting.md
---

# TUI Tool Call Rendering UI Specification Drafting Plan

A concrete, implementation-ready UI specification for tool call rendering in Motoko's TUI (`src/tui/src/ui.ts`). This plan outlines the scope, phases, comparative analysis, and decisions needed before implementation, with the final deliverable a `.agent/specs/TUI_Tool_Call_Rendering_UI_Spec.md` document.

## Goal & Scope
- Focused exclusively on hybrid tool events (`tool_calls`, `tool_results`, `native_tool_calls`, `native_tool_results`) within the history pane.
- Covers batch headers, per-tool row format, status semantics, output preview/truncation, expand/collapse, status bar integration, and narrow-terminal accessibility.
- Out of scope: legacy commands, non-tool messages, runtime protocol changes, theme redesign.

## Inputs & Comparative Analysis
- Current Motoko implementation (`ui.ts`, `runtime-process.ts`).
- Three external CLIs: **oh-my-pi** (primary reference for renderer architecture and streaming UX), **Gemini CLI**, and **Codex**.
- **oh-my-pi strengths**: tool-specific renderer registry with fallback, progressive disclosure (compact-first, omitted-lines indicators), streaming throttling, shared status-line primitives, grouped read-like rendering.
- **oh-my-pi caveats**: increased maintenance surface, lifecycle semantics hidden in controller logic, framework-specific details needing adaptation.
- Implication: use oh-my-pi as a pattern source, not a template; Motoko spec will prioritize deterministic event/state invariants.

## Drafting Phases
1. **Baseline Inventory**: capture current render behavior and state structures (`toolRows`, `toolBatchHeaders`, etc.).
2. **Pattern Extraction**: normalized list from references (status glyphs, dual rendering, output compaction, grouping).
3. **Spec Design**: define Motoko-specific compact/detail layouts, deterministic formatting, renderer registry, status-line contract, streaming rules, async tool lifecycle, and grouped tool policies.
4. **Validation**: cross-check feasibility, classify refactors as required/optional/deferred.
5. **Acceptance & Handoff**: final acceptance criteria, implementation slices, regression test matrix.

## Key Decisions to Resolve
- Status symbols and color semantics (keep or replace `[queued]`/`[done]` tags).
- Row density (always compact-first vs. adaptive).
- Output preview limits (fixed line cap vs. dynamic by terminal height).
- Expansion interaction (global toggle, per-row, or both).
- Native and delegated tool rendering parity.
- Header verbosity (request IDs visible by default or only in debug mode).

## Deliverable & Acceptance
- Full spec document with UX goals, visual grammar, interaction model, data/state mapping, event-to-render transition table, error handling, and a comprehensive test plan.
- Acceptance includes deterministic UI transitions for every tool event, canonical compact/expanded formats, truncation rules, edge-case handling, and implementation-readiness.

## Related Concepts
- [[concepts/tool-call-rendering]]
- [[concepts/motoko-tui]]
- [[concepts/ui-specification]]
- [[concepts/renderer-architecture]]
- [[concepts/streaming-rules]]
- [[concepts/progressive-disclosure]]