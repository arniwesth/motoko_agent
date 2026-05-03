# EditFile Tool Implementation Plan

## Goal
Add an efficient native `EditFile` tool that performs targeted in-file edits without full-file rewrites, while preserving current hybrid tool protocol and UI observability.

## Current State
The runtime supports these tool calls:
- `ReadFile`
- `Search`
- `WriteFile`
- `BashExec`
- `RunTests`

`WriteFile` rewrites full file content. There is no first-class partial-edit tool in the runtime parser/type/runtime pipeline.

## Non-Goals (v1)
- AST-aware edits
- Multi-file transactional edits
- Provider-native function calling migration
- Replacing `WriteFile`

## Design Principles
- Deterministic: same input yields same edit outcome.
- Safe by default: fail on ambiguous match unless explicitly opted into global replacement.
- Atomic writes: no partial writes if any edit in a batch fails.
- Observable: return structured result + unified diff for UI and model feedback loops.
- Backward-compatible: additive only; existing tools and protocol remain valid.

## High-Value Ideas Adopted from oh-my-pi
- Strict-by-default matching: unique match required unless caller explicitly opts into replace-all behavior.
- Staleness protection: optimistic hash guard (`expected_sha256`) to prevent edits against changed files.
- Strong operator feedback: detailed mismatch/ambiguity errors with actionable next step.
- Rich edit observability: include diff and first changed line metadata to improve TUI/model iteration loops.
- Phased edit maturity: ship strict text edits first, then add optional anchored (`LINE#ID`-style) and patch/hunk modes.

## Selective Integration from OpenAI Codex apply_patch
Codex's `apply_patch` engine is robust but significantly more complex than needed for `EditFile` v1.
We will integrate ideas selectively:

Adopt now:
- Clear parser/apply error taxonomy with line-oriented failure messages.
- Deterministic match fallback ladder for future optional relaxed mode:
  - exact
  - trim trailing whitespace
  - trim both sides
  - unicode punctuation normalization
- Explicit dry-run preview support and unified diff output.

Defer to later phases:
- Dedicated patch DSL (`*** Begin Patch` / `*** Update File` / hunks).
- Multi-operation patch application across add/delete/update/move in one payload.

Explicitly avoid:
- Non-transactional multi-op behavior where partial success can persist after later failure.
- Ambiguous path policy drift; keep runtime tool API relative-path-first and enforce workspace boundaries.

## Proposed Tool Contract (v1)
Tool call shape:

```json
{
  "id": "t1",
  "tool": "EditFile",
  "path": "src/core/parse.ail",
  "edits": [
    { "old": "needle", "new": "replacement", "replace_all": false }
  ],
  "dry_run": false,
  "expected_sha256": "optional-current-file-hash"
}
```

Field semantics:
- `id`: required.
- `tool`: must be `EditFile`.
- `path`: required target path.
- `edits`: required non-empty list of edit operations.
- `edits[].old`: required search text.
- `edits[].new`: required replacement text (can be empty string).
- `edits[].replace_all`: optional, default `false`.
- `dry_run`: optional, default `false`; computes result/diff but does not write.
- `expected_sha256`: optional optimistic concurrency guard; if present and file hash differs, fail.

Execution semantics:
- Read file once.
- Validate preconditions (`path`, existence, non-empty `edits`, non-empty `old`).
- Enforce read-before-edit policy in prompts/runtime checks (file should be read in current step history before edit).
- Enforce path safety before any file access:
  - canonicalize against `WORKDIR`,
  - reject path traversal outside workspace (`..` escape),
  - reject absolute paths in v1 tool payloads,
  - evaluate symlink target and reject if resolved target escapes workspace.
- If `expected_sha256` provided and mismatch, fail before any edit.
- Apply edits in order against current working content.
- For `replace_all=false`: require exactly one match.
- For `replace_all=true`: require at least one match and replace all matches.
- If any edit fails, return error and do not write file.
- On success, compute unified diff and write atomically unless `dry_run=true`.

## Result Shape
Add `EditFileResult` variant to `ToolResultItem`:
- `id`
- `path`
- `bytes_written`
- `sha256`
- `diff`
- `first_changed_line`
- `applied_edits`
- `dry_run`
- `match_strategy` (`exact` in v1; reserve enum for future fuzzy/anchor modes)

Failure path:
- Use `ToolErrorResult` with explicit messages:
  - `missing path`
  - `missing edits`
  - `edit #N old must be non-empty`
  - `edit #N matched 0 occurrences`
  - `edit #N matched multiple occurrences; set replace_all=true`
  - `expected_sha256 mismatch`
  - include closest-match hint when practical (line and snippet)

## Implementation Plan

### Phase 1: Type + Parser + Prompt Surface
1. Update `src/core/types.ail`
- Add `EditOp` type.
- Add `ToolCallReq.EditFile` variant.
- Add `ToolResultItem.EditFileResult` variant.

2. Update `src/core/parse.ail`
- Parse `EditFile` JSON payload.
- Parse `edits` array into typed `EditOp` list.
- Keep unsupported-tool warning behavior unchanged.

3. Update `src/core/prompts.ail`
- Extend tool contract examples with `EditFile`.
- Add explicit guidance:
  - prefer `EditFile` for localized modifications,
  - use `WriteFile` for complete rewrites or new-file bootstrap.

### Phase 2: Native Runtime Execution
1. Update `src/core/tool_runtime.ail`
- Route `EditFile` to native backend.
- Implement edit engine:
  - ordered application,
  - single/all replacement modes,
  - optimistic hash guard,
  - dry-run branch,
  - atomic write on success.
- Reuse existing unified diff builder for result `diff`.
- Compute and return `first_changed_line`.
- Implement atomic write as:
  - write full new content to temp file in same directory,
  - fsync temp file where runtime supports it,
  - rename temp file over target,
  - preserve no-partial-write guarantee on failure paths (target file remains unchanged if final rename does not happen).
- Implement path guard helper shared by `ReadFile`, `WriteFile`, and `EditFile` to maintain consistent policy.

2. Update `src/core/rpc.ail`
- Add `EditFile` to:
  - `tool_call_id`
  - `tool_name`
  - `one_tool_call_to_json`
  - `tool_result_item_to_display` (map diff into `stdout` with `exit_code=0` like `WriteFile`).

### Phase 3: TUI Metadata + Rendering Consistency
1. Update `src/tui/src/runtime-process.ts`
- Extend `DelegatedCall` shape to include `edits`, `dry_run`, `expected_sha256` for event typing.

2. Update `src/tui/src/ui.ts` and `src/tui/src/index.ts`
- Add `EditFile` call metadata formatting (`path`, edit count).
- Reuse existing diff-preview rendering already enabled for `EditFile` family.

### Phase 4: Tests
1. `src/core/parse_test.ail`
- Valid `EditFile` parse.
- Missing `path`/`edits`.
- Multi-edit order preservation.
- Absolute path payload rejected in validation layer tests.

2. `src/core/tool_runtime.ail` tests (new or inline)
- Single replacement success.
- `replace_all=false` with multiple matches fails.
- `replace_all=true` success.
- Zero matches fails.
- `expected_sha256` mismatch fails.
- Transactional guarantee: no partial write on failed second edit.
- `dry_run=true` produces diff but no write.
- Error quality checks: ambiguous/no-match errors include actionable guidance.
- `first_changed_line` is correct for single and multi-edit operations.
- Path safety:
  - traversal path rejected,
  - absolute path rejected,
  - symlink escape rejected.
- Read-before-edit policy:
  - edit without prior read fails with explicit error,
  - edit after prior read succeeds.
- Atomicity:
  - injected write/rename failure leaves original file unchanged.

3. TUI tests
- `src/tui/src/ui.tool-render.test.ts`:
  - `EditFile` row metadata formatting.
  - Collapsed/expanded diff behavior for `EditFile` tool results.

4. Protocol tests (`rpc` + TS runtime process)
- Ensure `EditFile` call serialization/deserialization is stable in:
  - `tool_calls` events,
  - `native_tool_calls` events,
  - `native_tool_results` display payload.
- Ensure `EditFileResult` fields used by UI (`diff`, `first_changed_line`) survive end-to-end event flow.

## File Change Map
- `src/core/types.ail`
- `src/core/parse.ail`
- `src/core/parse_test.ail`
- `src/core/prompts.ail`
- `src/core/tool_runtime.ail`
- `src/core/rpc.ail`
- `src/tui/src/runtime-process.ts`
- `src/tui/src/ui.ts`
- `src/tui/src/index.ts`
- `src/tui/src/ui.tool-render.test.ts`

## Backward Compatibility
- Existing tool calls continue to work unchanged.
- `WriteFile` remains available.
- Hybrid native/delegated split remains unchanged (`EditFile` is native).

## Risks and Mitigations
- Ambiguous text edits can misapply.
  - Mitigation: default strict single-match requirement.
- Concurrent external file modifications can invalidate assumptions.
  - Mitigation: `expected_sha256` guard.
- Large file diff output can increase context size.
  - Mitigation: existing UI diff collapse + existing truncation behavior in tool display paths.
- Future matcher leniency can apply unintended edits.
  - Mitigation: keep strict mode default; any relaxed matching must be explicit and fully test-covered.

## Rollout
1. Land Phase 1 + 2 behind additive schema changes.
2. Run core checks/tests and TUI tests.
3. Land Phase 3 UI polish and test updates.
4. Monitor traces for `Tool parse error` and `EditFile` failure-class distribution.
5. Optional Phase 5 follow-up: `ApplyPatch` tool for hunk-based edits with anchor/context constraints.
6. Optional Phase 6 follow-up: anchor-validated edit mode (`LINE#ID`) to catch stale line references before mutation.
7. Optional Phase 7 follow-up: codex-style patch parser + matcher ladder, but retain transactional-per-file guarantees.

## Acceptance Criteria
- Model can emit valid `EditFile` tool JSON and runtime executes it.
- `EditFile` succeeds for unambiguous edits and fails clearly for ambiguity/missing matches.
- No partial writes on failed multi-edit requests.
- Tool result includes diff and is visible in TUI like existing edit tools.
- Existing tool workflows and tests remain green.
- `EditFile` rejects unsafe paths (absolute, traversal, workspace-escaping symlink target).
- `EditFile` read-before-edit enforcement behaves deterministically and is test-covered.
- `EditFile` protocol payloads are round-trip safe across runtime and TUI.
