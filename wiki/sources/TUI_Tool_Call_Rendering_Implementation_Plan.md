# TUI Tool Call Rendering Implementation Plan

Status: Ready for execution
Spec source: `.agent/specs/TUI_Tool_Call_Rendering_UI_Spec.md`
Primary code owner: `src/tui/src/ui.ts`

## 1. Objectives
- Implement the new hybrid-only tool rendering model from the spec without changing runtime protocol shapes.
- Preserve current behavior where required (`tool_calls`/`tool_results` lifecycle, wait-state semantics), while adding:
  - renderer architecture with fallback,
  - shared status-line formatting,
  - expansion/collapse for tool details,
  - grouped `ReadFile` rendering,
  - edit-tool diff preview rendering,
  - edge-case hardening and tests.

## 2. Constraints
- No protocol shape changes in `src/core/rpc.ail`.
- Legacy `proposed_cmd`/`obs` path remains out of scope.
- Do not regress existing wait-state helper tests and runtime tool-progress ordering tests.

## 3. Target Files
- Core implementation:
  - `src/tui/src/ui.ts`
- Optional new helper modules (preferred to reduce `ui.ts` complexity):
  - `src/tui/src/tool-render/types.ts`
  - `src/tui/src/tool-render/format.ts`
  - `src/tui/src/tool-render/renderers.ts`
  - `src/tui/src/tool-render/grouping.ts`
- Tests:
  - `src/tui/src/ui.wait-state.test.ts` (extend)
  - `src/tui/src/ui.tool-render.test.ts` (new)
  - `src/tui/src/ui.tool-events.test.ts` (new)
  - `src/tui/src/runtime-process.tool-progress.test.ts` (keep baseline)

## 4. Execution Phases

### Phase 0: Baseline Lock (No Behavior Change)
Deliverables:
- Add explicit tool-render internal types (row status, details, renderer contract).
- Extract status/row formatting helpers behind current output strings.
- Add focused tests for current string outputs to guard refactor drift.

Tasks:
1. Introduce `ToolRowStatus`, `ToolRowDetails`, `ToolRenderer`, `ToolRenderCtx` types.
2. Add helper functions for header/row compact formatting used by current code.
3. Keep `handleEvent`, `renderToolCalls`, `applyToolResults`, `applyNativeToolResults` behavior unchanged.

Exit criteria:
- Existing tests pass.
- Output snapshots for current compact rendering are stable.

### Phase 1: Shared Status-Line Contract + Generic Renderer
Deliverables:
- Shared status-line formatter integrated into batch header + row rendering.
- Generic fallback renderer path used for all tools initially.

Tasks:
1. Implement status-line field model (`icon/title/description/badge/meta`).
2. Replace ad hoc string construction in `renderToolCalls` and result application paths with formatter calls.
3. Add deterministic fallback rendering path and wire renderer exception safety.

Exit criteria:
- Header and row outputs follow spec grammar.
- Fallback path verified with injected renderer throw test.

### Phase 2: Expansion/Collapse + Output Preview Policy
Deliverables:
- Global `Ctrl+O` toggle for tool detail expansion.
- Expanded detail rows with stdout/stderr preview and truncation markers.

Tasks:
1. Add `toolOutputExpanded` state and input listener handling for `Ctrl+O`.
2. Add `toolRowDetails` map updated from delegated/native results.
3. Render expanded body blocks under compact row:
   - stdout up to 8 lines,
   - stderr up to 4 lines,
   - hidden-line messaging.
4. Add line-width truncation helper tied to terminal width.

Exit criteria:
- `Ctrl+O` toggles only tool details.
- Think-block controls (`Ctrl+T`) remain unchanged.
- Expanded/collapsed snapshots pass on narrow-width fixtures.

### Phase 3: Streaming Rules + Progress Coalescing
Deliverables:
- Coalesced row refresh for progress-heavy updates.
- Stable row counts under repeated progress updates.

Tasks:
1. Add per-row last render timestamp cache (`lastToolRenderMs`).
2. Apply 50ms coalescing for repeated updates to same `tool_call_id`.
3. Bypass coalescing for terminal transitions (`done`/`failed`) and batch finalization updates so final states always render immediately.
4. Add regression tests for terminal updates that arrive within the coalescing window.
5. Keep raw latest result data in `toolRowDetails`; only visual refresh is throttled.

Exit criteria:
- Dedupe counters remain correct (`applyToolProgressCounters` unchanged semantics).
- No row duplication under repeated progress events.

### Phase 4: Grouped `ReadFile` Policy
Deliverables:
- Group rendering for 2+ `ReadFile` calls in the same `request_id`.

Tasks:
1. Add group-state model and group keying.
2. On `tool_calls`, detect eligible grouped `ReadFile` batches.
3. Render group header + child entries with per-child status.
4. Maintain single-row rendering for one `ReadFile` call.

Exit criteria:
- Grouped and non-grouped `ReadFile` paths both covered by tests.
- Progress + finalization states update group header deterministically.

### Phase 5: Edge-Case Hardening + Finalization Rules
Deliverables:
- Robust handling for missing IDs, out-of-order events, duplicate calls/results.
- Done-phase unseen-row finalization behavior from spec.

Tasks:
1. Add synthetic ID generation for missing `request_id`/`tool_call_id`.
2. Support lazy header/placeholder row creation when results arrive before calls.
3. Implement unseen-row finalization marker for delegated `phase=done` mismatches.
4. Ensure active batch clearing and status-bar consistency.

Exit criteria:
- Edge-case tests pass.
- No stranded `[running]` rows at delegated done completion.

### Phase 6: Cleanup + Documentation
Deliverables:
- Remove obsolete formatting branches.
- Add implementation notes in comments where behavior is non-obvious.

Tasks:
1. Prune dead code from pre-renderer paths.
2. Add short maintenance notes near renderer registry and group policy.
3. Run full TUI test suite.

Exit criteria:
- `npm test` under `src/tui` passes.
- No lint/type regressions from refactor.

### Phase 7: File-Edit Diff Rendering
Deliverables:
- Dedicated renderer behavior for `WriteFile` / file-edit tool family diff previews.
- Collapsed hunk summary + expandable bounded diff body.
- Scope note:
  - LLM output diff rendering is already implemented and documented in:
    - `.agent/plans/TUI_Code_Block_Rendering.md`
    - `.agent/summaries/2026-04-08-tui-codeblock-and-diff-rendering.md`
  - This phase is only for tool-call row diff rendering.
  - Reuse requirement: adopt existing LLM diff rendering utilities/components as the default implementation path; introduce new diff formatting code only for tool-event-specific adapters.
  - Concrete reuse targets:
    - Existing code paths implemented from `.agent/plans/TUI_Code_Block_Rendering.md`.
    - Existing behavior summary in `.agent/summaries/2026-04-08-tui-codeblock-and-diff-rendering.md`.
    - Reuse those formatter/render helper modules directly where feasible, and add a thin adapter for tool-result payloads.

Tasks:
1. Add edit-tool renderer entry in registry and wire to generic fallback on payload mismatch.
2. Reuse existing LLM diff rendering helpers/components via adapter layer for tool result payloads.
3. Render collapsed summary with file path, operation, and hunk/change counts when available.
4. Render expanded diff preview with width-aware truncation and omitted-line counters.
5. Add tests for edit diff rendering across:
   - create/update/delete/rename style payloads (when available),
   - malformed or missing diff payloads (fallback path).

Exit criteria:
- Edit-tool rows show deterministic diff previews when structured payload exists.
- Fallback remains safe and readable when structured diff data is absent.
- No regressions in earlier phases' tool rendering behavior.

## 5. PR Slicing Plan
- PR1: Phase 0 + baseline tests.
- PR2: Phase 1 (status-line + fallback renderer).
- PR3: Phase 2 (Ctrl+O + expanded details).
- PR4: Phase 3 (coalescing) + performance-focused tests.
- PR5: Phase 4 (`ReadFile` grouping).
- PR6: Phase 5 + 6 (edge cases, cleanup, full test pass).
- PR7: Phase 7 (file-edit diff renderer).

## 6. Test Matrix

### Unit
- `ui.wait-state.test.ts`
  - existing lock/counter tests retained,
  - add done-phase unseen-row finalization tests.
- `ui.tool-render.test.ts`
  - compact header/row states,
  - expanded output previews,
  - truncation and hidden-line markers,
  - renderer failure fallback.
  - edit-tool diff preview collapsed/expanded + fallback.
  - terminal-state update bypasses coalescing and renders immediately.
- `ui.tool-events.test.ts`
  - out-of-order events,
  - missing IDs,
  - duplicate progress/results,
  - native vs delegated transitions.

### Integration
- `runtime-process.tool-progress.test.ts`
  - keep ordering assertion baseline.
- New integration scenario in TUI event handling tests:
  - `tool_calls` -> `running` -> `progress`(mixed pass/fail) -> `done`.

## 7. Rollback Strategy
- Keep legacy-compatible compact formatting helpers available until PR7.
- Each phase is revertible independently via PR boundaries.
- If performance regression appears after coalescing:
  - disable coalescing by feature flag constant in TUI layer,
  - preserve data model changes.

## 8. Risks and Mitigations
- Risk: `ui.ts` grows too large during transition.
  - Mitigation: move renderer/grouping helpers to `src/tui/src/tool-render/*` by PR2.
- Risk: interaction conflicts (`Ctrl+O` vs editor behavior).
  - Mitigation: consume key only when focus context allows; add key-handling tests.
- Risk: mismatched done/progress counts due to malformed events.
  - Mitigation: centralize counter transitions and test malformed permutations.
- Risk: snapshot fragility from timestamps.
  - Mitigation: snapshot formatter outputs without live timestamps; isolate pure formatting helpers.

## 9. Definition of Done
- All phases completed through PR7.
- New spec behaviors implemented and tested.
- Existing wait-state and runtime progress tests remain green.
- Manual smoke check in terminal:
  - delegated batch with mixed exits,
  - native batch,
  - grouped `ReadFile`,
  - file-edit diff renderer (collapsed/expanded + fallback path),
  - `Ctrl+O` expand/collapse,
  - narrow terminal width.
