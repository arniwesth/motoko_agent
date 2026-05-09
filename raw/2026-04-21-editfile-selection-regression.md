# EditFile Under-Selection: Root Cause (2026-04-21)

## Symptom
The model rarely chooses `EditFile` even when localized edits would be appropriate.

## Root Causes
1. Hidden runtime precondition in tool execution:
- `EditFile` is rejected unless the same tool batch already includes a successful `ReadFile` for that exact normalized path.
- Enforcement: `src/core/tool_runtime.ail` (`run_edit_file`) with error:
  `read-before-edit policy violation: call ReadFile for this path before EditFile in the same tool batch`.

2. Strict matching semantics:
- `EditFile` fails when `old` matches 0 occurrences.
- `EditFile` also fails if `replace_all=false` and multiple matches exist.
- This makes `EditFile` lower-confidence than `WriteFile`/`BashExec` in ambiguous files.

3. Prompting asymmetry:
- Prompt text mentions preferring `EditFile` for localized edits, but does not document the runtime `ReadFile -> EditFile` contract.
- Parse-error recovery text nudges toward `BashExec` heredoc for brittle JSON cases, further biasing away from `EditFile`.

## Impact
- The model rationally favors `BashExec` or `WriteFile` to reduce tool-call failure risk.
- Appears as "model not using EditFile," but mostly reflects runtime contract + prompt mismatch.

## Follow-up
- If we want higher `EditFile` adoption, document the exact precondition in system prompt/tool contract:
  "For any `EditFile(path=...)`, include `ReadFile(path=...)` earlier in the same `tool_calls` batch."
