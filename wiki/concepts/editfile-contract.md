---
sources: [summaries/2026-04-21-editfile-selection-regression.md]
brief: Hidden precondition requiring ReadFile before EditFile in the same tool batch, enforced by the runtime.
---

# EditFile Runtime Contract

## Definition
The **EditFile runtime contract** is the set of preconditions that the `EditFile` tool must satisfy for execution to succeed. These preconditions are enforced by the tool runtime but are not consistently documented in the system prompt, creating an apparent mismatch between intended tool usage and actual model behavior.

## Key Preconditions

### 1. Mandatory ReadFile in the Same Batch
`EditFile` is “runtime-rejected unless the same tool batch already includes a successful `ReadFile` for that exact normalized path.”

- **Enforcement**: `src/core/tool_runtime.ail` (`run_edit_file`) raises the error: `read-before-edit policy violation: call ReadFile for this path before EditFile in the same tool batch`.
- **Implication**: The model cannot use `EditFile` standalone; it must always pair it with a preceding `ReadFile` call — even if the file content is already known from context or memory.

### 2. Strict Matching Semantics
In addition to the batch requirement, the `EditFile` operation fails if:
- The `old` string matches **zero occurrences** in the file.
- The `replace_all` flag is `false` and there are **multiple matches**.

This makes `EditFile` inherently less reliable than `WriteFile` or `BashExec` when the exact file content is ambiguous, further discouraging its selection.

## Relationship to Model Behavior
These hidden preconditions create a [[concepts/tool-selection-bias]] toward safer alternatives (`BashExec`, `WriteFile`). The model rationally avoids `EditFile` not because it is inappropriate, but because the probability of satisfying the contract without explicit documentation is low.

The documented source of this issue is [[summaries/2026-04-21-editfile-selection-regression]], which attributes the under-selection largely to this runtime contract mismatch.

## Mitigation
To increase `EditFile` adoption, the contract must be surfaced in the system prompt and tool description:
- “For any `EditFile(path=...)`, include `ReadFile(path=...)` earlier in the same `tool_calls` batch.”
- Clear documentation of the matching rules to set appropriate expectations.

This aligns with broader [[concepts/tool-documentation]] practices for transparent AI–tool interfaces.

---

*Related: [[summaries/2026-04-21-editfile-selection-regression]] | [[concepts/tool-selection-bias]] | [[concepts/tool-documentation]]*