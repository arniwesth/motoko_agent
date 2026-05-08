---
doc_type: short
full_text: sources/TUI_Tool_Call_Rendering_UI_Spec.md
---

# TUI Tool Call Rendering UI Spec Summary

This document defines a deterministic, hybrid-only tool rendering model for the Motoko TUI's history and status bar. It outlines a visual grammar, renderer architecture, output handling, streaming rules, and interaction model for both delegated and native tool calls, ensuring readability at scale and robustness under partial/malformed data.

## Core Concepts
- **Hybrid-only rendering**: Applies to `tool_calls`, `tool_results`, `native_tool_calls`, and `native_tool_results`; legacy command/observation rendering is out of scope.
- **Renderer registry**: A dictionary of `ToolRenderer` objects keyed by canonical tool name, with a fallback renderer for unknown tools. Each renderer provides `renderCall` and `renderResult` hooks, optional merge/inline flags, and must be pure.
- **Status‑line contract**: All batch headers and tool rows share a common field model (icon, title, description, badge, meta) with a canonical icon/color mapping ([[concepts/status-line-contract]]).
- **Compact vs. expanded rows**: A global `Ctrl+O` toggle switches between collapsed (summary line only) and expanded (argument/output preview with truncation) views.
- **Output handling policy**: Defines per‑channel preview limits, truncation rules, and omitted‑line markers; ensures readability on narrow terminals ([[concepts/output-handling-policy]]).
- **Grouped tool rendering**: When a tool family (e.g., `ReadFile`) has multiple calls in the same batch, they are rendered as a single grouped block with a header and child rows, using a configurable group key and status aggregation ([[concepts/grouped-tool-rendering]]).
- **Streaming throttling**: Progress updates are coalesced (min 50ms) and row states are mutated in‑place; terminal width changes trigger re‑truncation without recomputing raw outputs.
- **Deterministic event‑to‑render mapping**: A table specifies how each incoming event updates headers, rows, and status bar coupling, with rules for out‑of‑order events, missing IDs, and duplicate progress ([[concepts/deterministic-tool-rendering]]).

## Architecture Highlights
- Retains existing TUI structures (`toolBatchHeaders`, `toolRows`, `toolBatchState`, `activeToolRequestId`) and extends rendering policy without changing the protocol.
- Introduces new fields: `toolOutputExpanded` toggle, `toolRowDetails` (stdout/stderr cache), `toolGroups` for grouped rendering, and a throttle map.
- Fallback renderer ensures no tool events are dropped; exceptions produce generic rows plus a debug activity log line.

## Interaction Model
- `Ctrl+O` globally toggles expansion; does not affect non‑tool rows or the existing think‑block cycle (`Ctrl+T`).
- Default state is collapsed; expanded view adds argument and output preview lines with omitted‑line markers.
- The active delegated batch is coupled to the status bar for live progress counters.

## Grouped Tool Policy (Initial: ReadFile)
- When a batch contains ≥2 `ReadFile` calls, render a grouped block with a header line (`[group] ReadFile (<N>)`) and indented child rows showing path and line range.
- A single `ReadFile` call falls back to the normal row format.
- Extensible contract: future grouped tools must define group key, child identity, and status aggregation rules.

## Edge Cases and Reliability
- Missing `request_id` or `tool_call_id` are handled with synthetic identifiers and warning markers.
- Out‑of‑order results create placeholder headers and rows lazily.
- Duplicate `tool_calls` keep the first row and refresh metadata.
- Unseen rows at batch finalization are marked as failed with a `[missing-result]` tag.
- Renderer exceptions never crash the UI loop; they fall back to generic row grammar.

## Implementation Slices
1. Shared formatting helpers and row detail state (no behavior change).  
2. Expanded/collapsed rendering and `Ctrl+O` toggle.  
3. Output preview/truncation policy.  
4. Grouped `ReadFile` rendering.  
5. Renderer registry and fallback wrapper.  
6. Edge‑case fixes and tests.  
7. (Deferred) Edit‑tool diff renderer (`WriteFile`/file‑edit family) reusing LLM diff utilities.

## Related Concepts
- [[concepts/tool-renderer-registry]] – the registry model and `ToolRenderer` contract.  
- [[concepts/status-line-contract]] – icon, title, badge, and meta field standards.  
- [[concepts/grouped-tool-rendering]] – the grouping policy and extensibility contract.  
- [[concepts/output-handling-policy]] – preview limits, truncation, and omitted‑line messaging.  
- [[concepts/deterministic-tool-rendering]] – event‑to‑render transition rules and deduplication.
