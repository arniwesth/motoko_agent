---
doc_type: short
full_text: sources/TUI_Tool_Call_Rendering_Implementation_Plan.md
---

# TUI Tool Call Rendering Implementation Plan

This document outlines a multi‑phase implementation plan for a new hybrid‑only tool rendering model in the TUI, introducing a [[concepts/tool-renderer-architecture|renderer architecture]], shared status‑line formatting, expansion/collapse controls, [[concepts/readfile-grouping|grouped `ReadFile` rendering]], and dedicated file‑edit diff previews.

## Core Objectives

- Implement the spec without changing runtime protocol shapes (`src/core/rpc.ail`).
- Preserve current tool‑call/tool‑result lifecycle and wait‑state semantics while adding:
  - Renderer registry with fallback.
  - Unified status‑line grammar.
  - `Ctrl+O` toggle to expand tool details.
  - Stream‑aware coalescing for progress updates.
  - Edge‑case handling (missing IDs, out‑of‑order events).
  - Diff previews for file‑edit tools using existing LLM diff utilities (see [[summaries/2026-04-08-tui-codeblock-and-diff-rendering]]).

## Execution Phases

1. **Phase 0 – Baseline Lock**  
   Introduce internal types (`ToolRenderer`, `ToolRenderCtx`, etc.) and extract formatting helpers while keeping all current output identical.

2. **Phase 1 – Shared Status‑Line & Fallback Renderer**  
   Unify header/row string construction through the new formatter; wire a generic fallback renderer with exception safety.

3. **Phase 2 – Expansion/Collapse & Output Previews**  
   Add `Ctrl+O` toggle, store per‑row details, and render truncated stdout/stderr when expanded.

4. **Phase 3 – Streaming Coalescing**  
   Use a 50 ms throttle for repeated progress updates to the same tool, with immediate rendering for terminal transitions (`done`/`failed`).

5. **Phase 4 – Grouped `ReadFile` Rendering**  
   When two or more `ReadFile` calls share a `request_id`, display them under a common group header while preserving single‑call rows.

6. **Phase 5 – Edge‑Case Hardening**  
   Handle missing identifiers, result‑before‑call ordering, unseen‑row finalization markers, and active batch clearing.

7. **Phase 6 – Cleanup & Documentation**  
   Remove dead code, add maintenance notes, and verify full test suite.

8. **Phase 7 – File‑Edit Diff Rendering**  
   Reuse existing LLM diff rendering helpers to show collapsed/expanded diffs for `WriteFile` and related tools, with safe fallback for malformed payloads.

## Key Design Points

- **Renderer contract** separates status‑line generation from detail rendering, enabling easy extension and safe fallback.  
- **Status‑line model** uses `icon/title/description/badge/meta` fields, replacing ad‑hoc string building.  
- **Coalescing** balances real‑time feel with performance; terminal states always bypass the throttle.  
- **Grouping** reduces visual noise for concurrent `ReadFile` operations without changing the underlying data flow.  
- **Reuse of existing diff utilities** avoids duplication and ensures consistency between LLM output diffs and tool‑call row diffs.

## Test & Rollback Strategy

- Phases are independent PRs, each revertible.  
- Baseline snapshots guard against drift; new unit tests cover rendering, events, and diffs.  
- Integration tests keep runtime‑process ordering assertions intact.  
- A feature flag constant can disable coalescing if performance regresses.

## Wiki Connections

- The spec derives from `.agent/specs/TUI_Tool_Call_Rendering_UI_Spec.md`.  
- File‑edit diff rendering builds on [[summaries/2026-04-08-tui-codeblock-and-diff-rendering]].  
- The proposed renderer architecture is a candidate for the concept page [[concepts/tool-renderer-architecture]].  
- Grouping policies and coalescing strategies could be expanded in [[concepts/readfile-grouping]] and [[concepts/tool-event-coalescing]].