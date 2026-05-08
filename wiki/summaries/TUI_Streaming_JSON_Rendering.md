---
doc_type: short
full_text: sources/TUI_Streaming_JSON_Rendering.md
---

This document outlines a plan to add live color rendering for streamed JSON blocks in a terminal UI (TTY), preserving existing planned-tools UX. Key design:

- **JSON Highlighting**: A new `json-highlight.ts` module implements a tolerant, incremental-safe JSON tokenizer that never throws on incomplete input, enabling stable highlighting of both fenced and bare JSON segments during streaming.
- **Segment Classification**: In `stream-markdown.ts`, JSON language tags (`json`, `jsonc`, `application/json`) are normalized, and bare/unfenced JSON regions are detected via top-level balanced object heuristics. Fenced classification takes precedence inside code fences.
- **Tool-Envelope Visibility Policy**: A dedicated classifier assesses confidence that a JSON segment is a tool envelope (requires `tool_calls` structure). Two confidence levels exist: `confident_strict` (parse succeeds) and `confident_heuristic` (partial match). When detected, the JSON block is hidden by default and a placeholder `[tool json hidden; see Planned Tools]` is shown. This decision is deterministic and independent of the planned-tools panel’s mount timing; no mode switches occur if confidence later changes. An env var `MOTOKO_SHOW_TOOL_JSON_STREAM=1` can force display for debugging.
- **Integration Phases**: The work is split into phases: 
  1. Build tolerant JSON highlighter with tests.
  2. Update stream-markdown to annotate segments.
  3. Route JSON segments through the highlighter in `ui.ts`, applying visibility policy.
  4. Wire env override.
  5. Test coverage for complete, partial, bare JSON, tool envelope hiding, placeholder stability, and env override.
- **Risks**: Misclassification of non-tool JSON is mitigated by strict shape detection; performance churn is controlled by existing throttling.

Related concepts: [[concepts/tolerant-json-parsing]], [[concepts/streaming-json-rendering]], [[concepts/tool-envelope-detection]], [[concepts/terminal-ui-json-highlighting]]