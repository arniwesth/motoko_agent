---
doc_type: short
full_text: sources/2026-04-21-editfile-selection-regression.md
---

# EditFile Under-Selection Root Cause Summary

## Symptom
The model rarely chooses `EditFile` even for localized edits.

## Root Causes
1. **Hidden runtime precondition**: `EditFile` requires a prior successful `ReadFile` for the same path in the same tool batch. Without this, the runtime rejects the call with a "read-before-edit policy violation". This precondition is enforced in `src/core/tool_runtime.ail`.
2. **Strict matching semantics**: `EditFile` fails if `old` matches 0 occurrences or if `replace_all=false` and multiple matches exist. This makes the tool less reliable in ambiguous files, reducing model confidence.
3. **Prompting asymmetry**: The prompt mentions preferring `EditFile` for localized edits, but does not document the `ReadFile -> EditFile` contract. Additionally, parse-error recovery text suggests `BashExec` heredoc for brittle JSON, further biasing away from `EditFile`.

These factors create a rational bias toward `BashExec` or `WriteFile` to minimize tool-call failure risk. The observed under-selection is thus not a model deficiency but a reaction to the [[concepts/editfile-contract]] and [[concepts/tool-selection-bias]].

## Impact
The model preferentially uses `BashExec` or `WriteFile` over `EditFile`, appearing as a failure to use the appropriate localized editing tool.

## Follow-up
If higher `EditFile` adoption is desired, the exact precondition must be explicitly documented in the system prompt and tool contract: "For any `EditFile(path=...)`, include `ReadFile(path=...)` earlier in the same `tool_calls` batch." A clearer [[concepts/tool-documentation]] approach could align model behavior with expectations.