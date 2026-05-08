---
sources: [summaries/Exa_Websearch_Extension.md, summaries/AILANG_Agent.md, summaries/2026-04-21-editfile-selection-regression.md]
brief: Tool selection bias is the LLM's systematic preference for certain tools due to hidden risks; mitigations include explicit routing cards like Exa's AGENT.md.
---

# Tool Selection Bias

Tool selection bias is the systematic preference of a language model for certain tools over others, not because those tools are the best fit for the task, but because the model perceives a lower probability of tool-call failure or receives biased guidance. This bias arises from hidden runtime constraints, ambiguous semantics, asymmetric prompting, and the absence of authoritative routing.

## Key Drivers

### Hidden Runtime Preconditions
Some tools have strict preconditions that are not exposed in the prompt. For instance, `EditFile` requires a successful `ReadFile` for the exact path in the same tool batch; without it, the call is rejected. The model learns to avoid such tools unless the preconditions are clearly satisfied, making alternatives like `WriteFile` or `BashExec` appear safer.

### Ambiguous Matching Semantics
When a tool’s behavior depends on precise matching (e.g., `EditFile`’s `old` string matching zero or multiple occurrences), the model faces uncertainty about whether the current state of the file will meet those expectations. This uncertainty increases the perceived risk of failure, nudging the model toward more deterministic operations.

### Prompt-Contract Asymmetry
If the system prompt advocates for a tool but fails to document its full contract, the model may encounter contradictions between its training and actual runtime feedback. Additionally, error-recovery hints (e.g., falling back to heredoc-based approaches) can further reinforce avoidance of the riskier tool.

### Missing Authoritative Routing
Without explicit instruction, models often default to familiar general‑purpose tools (e.g., `BashExec` with `curl`) instead of specialized ones. The Exa Websearch Extension counteracts this by injecting an **AGENT.md routing card** that declares its tools authoritative and advises the LLM to prefer them over manual `curl` or `wget` for web retrieval (see [[summaries/Exa_Websearch_Extension]]). The absence of such routing can bias selection toward less suitable alternatives.

## Observed Manifestations
- **Avoidance of `EditFile`**: The model rarely selects `EditFile` for localized edits, instead favoring `BashExec` or `WriteFile`. This is a rational adaptation to the hidden `ReadFile -> EditFile` contract and strict match semantics (documented in [[summaries/2026-04-21-editfile-selection-regression]]).
- **Over‑reliance on generic tools**: Without explicit guidance, an agent may use `BashExec` to perform web searches rather than a dedicated search tool like `ExaSearch`, simply because the latter’s contract is less familiar or its availability is not emphasized. The Exa extension’s AGENT.md provides that emphasis, shifting the balance toward the specialized tool.

## Mitigation
To reduce tool selection bias, developers should:
- **Expose critical preconditions** directly in the tool contract presented to the model.
- **Balance prompt guidance** with explicit documentation of failure modes and required context.
- **Use authoritative routing cards** (e.g., an AGENT.md injected via `on_build_system_prompt`) that assert the primacy of certain tools and override any default bias toward generic shell commands. This aligns with the approach taken by the Exa Websearch Extension.
- **Declare tool availability explicitly** and instruct the LLM to use provided tools even if they are omitted from a generic “Available Tools” table, reducing ambiguity that leads to avoidance.

## Related Concepts
- [[concepts/editfile-contract]] – The exact set of runtime requirements that must be met for `EditFile` to succeed.
- [[concepts/tool-documentation]] – Best practices for aligning tool descriptions with runtime behavior to reduce selection bias.
- [[concepts/prompt-engineering-for-tool-use]] – How to design prompts that accurately convey tool reliability and preconditions, including the use of dedicated routing cards.
- [[summaries/AILANG_Agent]] – Background on the agent’s tool‑use architecture.
- [[summaries/Exa_Websearch_Extension]] – Example of injecting an authoritative routing card to steer tool selection.