---
doc_type: short
full_text: sources/TUI_Streamed_Tool_Plan_UX.md
---

# TUI Streamed Tool-Plan UX Plan – Summary

This plan redesigns how the terminal UI (TUI) presents model tool calls during streaming. Instead of dumping raw JSON and then separate runtime execution events (causing duplicate renderings), it introduces a unified timeline view with live planning updates and execution status tracking.

## Core Idea

A **two‑layer rendering** approach:
1. **Live “Planned Tools” block** (expanded by default in TTY) derived from incremental parsing of the streaming `thinking_delta` content.  
2. **Execution updates** from runtime events map onto the same rows via a [[concepts/Canonical Tool Identity]] key, transitioning statuses (planned → running → done/error).

Each tool call is shown only once, eliminating conflicting representations. In non‑TTY (plain) mode, verbose JSON dumps are replaced by concise summaries (a debug env var allows raw output if needed).

## Key Design Decisions

### Incremental Tool‑Call Extraction
A new `tool-plan-parser` performs tolerant, bounded extraction from streamed text (see [[concepts/Incremental Tool-Plan Parsing]]). It accumulates up to 128 KiB per assistant step, uses a 64 KiB rolling window for candidate detection, and only parses when a syntactically complete JSON structure (with a `tool_calls` array) is recognised. Partial fragments are ignored; no parser errors reach the user. When the buffer overflows, a `stream_truncated_for_parse` flag is set for diagnostics.

### Canonical Identity System
Instead of deduplicating by `tool_call_id` alone, the system uses a composite key: `step + request_id + tool_call_id` (with a fallback to `tool + normalized_args_hash + first_seen_index` when IDs are missing). This enables stable mapping between stream‑planned and runtime‑emitted calls, even when provider IDs are incomplete.

### Reconciliation States
All calls are tracked with a `toolStatus` map that supports six states:  
- `planned`, `running`, `done`, `error` (normal lifecycle)  
- `planned_unexecuted` – streamed plan that never appears at runtime  
- `runtime_only` – runtime call with no prior streamed match  
- `filtered` – call blocked before execution  

These states are described in [[concepts/Tool Call Reconciliation States]] and guarantee every call is classified without gaps.

### Rendering Policy
- **TTY**: “Planned Tools (streaming)” section expanded by default; raw stream text still available but de‑emphasised (collapsed toggle is optional).  
- **Non‑TTY**: no raw token‑by‑token JSON; compact phase lines and final tool summaries only.

## Implementation Scope (Phases)
1. **UI state and skeleton** – add `PlannedTool` and `toolStatus` maps, render the planned‑tools section in `ui.ts`.
2. **Stream extraction pipeline** – feed `thinking_delta` to the incremental parser; emit internal UI updates; deduplicate using the canonical key.
3. **Plain‑mode logger cleanup** – replace raw JSON logging with concise summaries; add `MOTOKO_PLAIN_VERBOSE_STREAM` override.
4. **Tests** – coverage includes TTY expansion, transition timings, reconciliation cases (`planned_unexecuted`, `runtime_only`, `filtered`), and buffer‑limit handling.

## Acceptance Criteria
- Planned tools appear live during streaming in TTY (expanded by default).
- No duplicate renderings of the same call.
- Execution results update planned entries by identity.
- Plain output stays compact; debug override works.
- Parser tests included in the same rollout.
- All reconciliation states implemented and validated.

## Risks Mitigated
- **Incremental parse false positives** → strict structural checks (`tool_calls` array shape).  
- **Churn from partial fragments** → only parse when a complete candidate is detected.  
- **Memory growth** → per‑step caps and rolling tail eviction.  
- **UX confusion** → explicit status badges and phase labels.

## Wider Connections
This design interacts with several cross‑document concepts:  
- [[concepts/Tool Call Reconciliation States]] (all possible call statuses)  
- [[concepts/Incremental Tool-Plan Parsing]] (bounded extraction from a stream)  
- [[concepts/Canonical Tool Identity]] (composite keys for deduplication)  
- [[concepts/TTY vs Plain Output Policies]] (rendering differences)  
- [[concepts/UI State per Assistant Step]] (internal state model)

Future work (out of scope) includes a native `tool_plan_delta` protocol event and cross‑provider extraction guarantees.