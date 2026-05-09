---
query: "What is the EditFile contract and selection regression?"
---

Let me start by checking the wiki index to find relevant documents on these topics.Found two directly relevant entries. Let me read both the summary and the concept page.Let me also read the related concept and the full source for more detail.## EditFile Contract

The **EditFile runtime contract** is a set of hidden preconditions that the `EditFile` tool must satisfy for execution to succeed, enforced by `src/core/tool_runtime.ail` but **not documented** in the system prompt:

1. **Mandatory ReadFile in the same batch** — `EditFile` is rejected unless the tool batch already includes a successful `ReadFile` for the exact same normalized path. The runtime raises: `read-before-edit policy violation: call ReadFile for this path before EditFile in the same tool batch`. This means the model can never use `EditFile` standalone, even if it already knows the file content.

2. **Strict matching semantics** — `EditFile` fails if the `old` string matches **zero** occurrences, or if `replace_all=false` and there are **multiple** matches. This makes it inherently riskier than `WriteFile` or `BashExec` when file content is ambiguous.

## Selection Regression

The **selection regression** is that the model rarely chooses `EditFile` even for localized edits where it would be the ideal tool. Instead, it prefers `BashExec` or `WriteFile`.

The root causes are:

| Cause | Effect |
|---|---|
| **Hidden ReadFile precondition** | Model cannot succeed with `EditFile` unless it already called `ReadFile` in the same batch — a constraint it doesn't know about from the prompt |
| **Strict matching semantics** | Even if the contract is satisfied, matching ambiguities can still cause failure |
| **Prompt asymmetry** | Prompt says "prefer EditFile for localized edits" but doesn't document the contract; error-recovery text nudges toward `BashExec` heredoc for brittle JSON, further biasing away |

This is **not a model reasoning failure** but a **rational adaptation**: the model minimizes failure risk by choosing tools with fewer hidden constraints. It's an instance of the broader [[concepts/tool-selection-bias]] phenomenon.

## Mitigation

To fix the under-selection, the contract must be surfaced explicitly in the system prompt:

> "For any `EditFile(path=...)`, include `ReadFile(path=...)` earlier in the same `tool_calls` batch."

And matching rules should be clearly documented so the model can accurately assess when `EditFile` is safe to use.
