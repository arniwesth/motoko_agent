# TUI Tool Call Rendering UI Spec Drafting Plan

## Goal
Produce a concrete, implementation-ready UI specification for tool call rendering in the Motoko TUI (`src/tui/src/ui.ts`), informed by current Motoko behavior and proven patterns from Pi, Gemini CLI, and Codex.

## Why This Plan
The current renderer shows accurate tool state transitions but remains text-flat and low-density for complex tool batches. Before implementation, we need a written spec that locks behavior, layout, and state semantics to avoid ad hoc UI drift.

## Scope
- In scope:
  - Hybrid tool-event rendering only: `tool_calls`, `tool_results`, `native_tool_calls`, `native_tool_results`.
  - Delegated and native tool call rendering in the history pane.
  - Tool batch header behavior (`queued`, `running`, `progress`, `done`).
  - Per-tool row format, status semantics, output preview/truncation rules.
  - Expansion/collapse behavior for verbose tool outputs.
  - Status bar coupling for active tool-batch progress.
  - Accessibility/readability constraints for narrow terminal widths.
- Out of scope:
  - Legacy command/observation rendering (`proposed_cmd`, `obs`) and non-hybrid execution-path behavior.
  - Runtime protocol shape changes in `src/core/rpc.ail`.
  - Non-tool message rendering (thinking markdown, slash-command UX, overlays).
  - Theme-system redesign.

## Inputs
- Current Motoko implementation:
  - `src/tui/src/ui.ts`
  - `src/tui/src/runtime-process.ts`
- Comparative references:
  - Pi coding agent tool and bash execution components.
  - Gemini CLI tool message/group/dense views.
  - Codex TUI history cell + exec output compaction behavior.

## Comparative Assessment: oh-my-pi (Reference Quality)
- Overall assessment:
  - High-quality reference implementation for tool rendering architecture and streaming UX discipline.
- Strengths worth carrying into spec drafting:
  - Clear renderer architecture:
    - Tool-specific renderer registry with graceful generic fallback.
    - Separation of event plumbing from presentation components.
  - Strong progressive disclosure model:
    - Compact-first rendering with explicit expand hints.
    - Consistent preview/truncation behavior with omitted-lines indicators.
  - Good terminal performance safeguards:
    - Streaming throttling, line caps, and width-aware truncation.
  - Shared visual primitives:
    - Standardized status-line/icon semantics used across renderers.
  - Useful grouping semantics:
    - Grouped read-like rendering for repeated homogeneous calls.
- Weaknesses / caveats to account for:
  - Renderer diversity increases maintenance and test surface area.
  - Some lifecycle semantics are encoded in controller logic and should be made explicit in spec tables.
  - Certain details are framework-specific and may require adaptation in Motoko's current UI architecture.
- Drafting implication:
  - Use oh-my-pi as a pattern source for architecture and UX mechanics, not as a line-for-line template; Motoko spec should prioritize deterministic event/state invariants and minimal incremental implementation slices.

## Deliverable
A spec document under `.agent/specs/` containing:
1. UX goals and non-goals.
2. Canonical rendering model (batch + row states).
3. Visual grammar (glyphs, prefixes, spacing, compact vs expanded forms).
4. Output handling policy (preview, truncation, omitted-lines markers, full output references).
5. Interaction model (expand/collapse and keyboard behavior).
6. Data/state model mapped to current `UI` class fields.
7. Event-to-render transition table for `tool_calls`, `tool_results`, `native_tool_calls`, `native_tool_results`.
8. Error and edge-case handling (missing IDs, partial batches, duplicate progress events).
9. Acceptance criteria and test plan.

## Drafting Phases

### Phase 1: Baseline Inventory
- Capture current render behavior precisely from `ui.ts`.
- Enumerate existing state structures:
  - `toolRows`, `toolRowMeta`, `toolBatchHeaders`, `toolBatchState`, `activeToolRequestId`.
- Document constraints from existing event model and run-state transitions.

### Phase 2: Comparative Pattern Extraction
- Extract reusable patterns from Pi/Gemini/Codex into a normalized list:
  - Status glyph system.
  - Compact + dense dual rendering.
  - Head/tail output compaction with omitted-line counters.
  - Progressive disclosure for long outputs.
  - Grouping semantics for multi-tool batches.

### Phase 3: Spec Design
- Define Motoko-specific rendering contract:
  - Default compact row shape.
  - Optional detail row semantics.
  - Header progress language.
  - Failure/truncation markers.
- Define deterministic formatting rules (tool descriptors, argument snippets, exit metadata).
- Add `Renderer Architecture` section:
  - Renderer registry model and selection rules.
  - Generic fallback behavior and parity requirements.
  - `mergeCallAndResult` and `inline` mode semantics.
- Add `Shared Status-Line Contract` section:
  - Exact fields: icon, title, description, badges, metadata.
  - Canonical icon/color mapping and status tokens.
- Add `Streaming Rules` section:
  - Throttling behavior and update cadence.
  - Preview limits and width-sensitive truncation.
  - Hidden-line messaging and expand hint language.
- Add `Async/Background Tool Lifecycle` section:
  - Transition table covering queued/running/background/final.
  - Re-entry/finalization semantics for async tools.
- Add `Grouped Tool Policy` section:
  - `read` grouping as first-class baseline behavior.
  - Extensibility contract for future grouped tool families.

### Phase 4: Validation and Feasibility
- Cross-check spec against current code paths for implementation feasibility.
- Identify required refactors (if any) and classify as:
  - required now,
  - optional follow-up,
  - deferred.

### Phase 5: Acceptance and Implementation Handoff
- Finalize acceptance criteria.
- Define implementation sequencing (small PR-friendly slices).
- Define minimal regression test matrix for `src/tui/src/ui.wait-state.test.ts` and new tool-render tests.

## Spec Decisions To Resolve Explicitly
1. Status symbols and color semantics:
   - Whether to replace `[queued]/[running]/[done]/[failed]` tags or keep both.
2. Row density strategy:
   - Always compact-first vs adaptive by tool type.
3. Output preview policy:
   - Fixed line cap vs dynamic cap based on terminal height.
4. Expansion interaction:
   - Global toggle, per-row toggle, or both.
5. Native tool parity:
   - Whether native and delegated tools share identical rendering grammar.
6. Header verbosity:
   - Keep request IDs visible by default vs only in verbose/debug mode.

## Risks and Mitigations
- Risk: overfitting to one external CLI pattern.
  - Mitigation: define Motoko-native constraints first, use external patterns only as tested primitives.
- Risk: spec too broad to implement incrementally.
  - Mitigation: include phased rollout profile (MVP + enhancements).
- Risk: mismatch between spec and event timing realities.
  - Mitigation: tie every UI transition to concrete incoming event types.
- Risk: regression in readability on small terminals.
  - Mitigation: include width-sensitive examples and truncation rules.

## Acceptance Criteria
- Spec maps every tool-related incoming event to deterministic UI transitions.
- Spec defines one canonical compact format and one expanded format with examples.
- Spec defines truncation/omission rules for stdout/stderr and tool metadata.
- Spec includes edge-case handling for malformed/missing tool fields.
- Spec defines renderer failure fallback behavior (tool renderer error -> deterministic safe fallback rendering).
- Spec includes test strategy with at least:
  - status transition correctness,
  - dedupe behavior for progress updates,
  - rendering stability on narrow widths.
- Spec is detailed enough that implementation can proceed without additional design clarification.

## Proposed Output File
- Draft target: `.agent/specs/TUI_Tool_Call_Rendering_UI_Spec.md`
- This plan is the precursor and execution checklist for producing that spec.
