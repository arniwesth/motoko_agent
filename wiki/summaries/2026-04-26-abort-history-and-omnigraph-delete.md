---
doc_type: short
full_text: sources/2026-04-26-abort-history-and-omnigraph-delete.md
---

## Summary

This work introduces two major runtime improvements:

1. **Abort history preservation**: The `run_hybrid_step` function in `rpc.ail` now retains in-flight turn context on user abort instead of dropping it. A new helper `delegated_aborted_results` synthesizes per-tool abort results, appends an observation marker to conversation history, and preserves the assistant’s previous output. This allows the agent to explain what was attempted when the next turn starts.
2. **Omnigraph deletion capability & safety guardrails**: A full set of GraphQL delete mutations were added to the Omnigraph mutation catalogs, with dialect-specific adjustments for the CLI parser. A new guardrail policy (`denied_mutation_reason`) replaces the flat `is_main_branch_mutation` check and enforces a strict workflow: all mutations on the `main` branch are denied, and `delete_all_*` bulk operations are only allowed if the branch name starts with `wipe/` or `cleanup/`. The AGENT_PROMPT was updated to describe a safe deletion procedure: create a branch, clean up edges before node deletion, verify, then merge back.

Changes were mirrored into the packaged extension (`.packages/motoko_omnigraph`) to keep the lockfile in sync, and all tests and lint checks passed.

### Key concepts
- [[concepts/abort-handling]]: preserving conversation state after user abort
- [[concepts/omnigraph]]: the graph-based decision system with mutation catalogs
- [[concepts/guardrail-policy]]: branch‑aware mutation denial rules (deny on `main`, require `wipe/` or `cleanup/` prefix for `delete_all_*`)
- [[concepts/branch-based-deletion-workflow]]: edge‑first deletion, verification reads, and safe merging

## Related Concepts
- [[concepts/package-sync-mechanism]]
- [[concepts/constraint-graph]]
- [[concepts/structured-agent-memory]]
- [[concepts/decision-provenance]]
- [[concepts/motoko-extension-architecture]]
