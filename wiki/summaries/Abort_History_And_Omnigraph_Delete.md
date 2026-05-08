---
doc_type: short
full_text: sources/Abort_History_And_Omnigraph_Delete.md
---

# Abort History and Omnigraph Delete Plan

This document plans two coupled fixes: (1) preserving the assistant's in-flight turn after an abort, and (2) empowering the model to safely delete Omnigraph data via the existing `OmnigraphMutate` tool, with explicit guardrails and a documented workflow.

## Patch 1: Preserve In-Flight State on Abort

- **Problem:** `DelegatedAborted` in `rpc.ail` discarded the assistant message, tool results, and extension results, losing history.
- **Fix:** Mirror the success branches: build an observation text from completed results, add a per-tool aborted marker, and append a `[turn aborted by user ...]` note. The state then chains the assistant turn and the abort notification, so the model can reference the failed attempt in later turns.
- **Key implementation details:** no step increment on abort; the abort ends the turn and the next user message increments via `conversation_loop`.
- **Testing:** Unit tests for AILANG state correctness; TS-side stream protocol test to verify the abort message appears in subsequent LLM inputs.

## Patch 2: Omnigraph Deletion Capability

### Fix A: Delete Query Templates (`decisions.gq`, `components.gq`)

- Add GraphQL queries: `delete_decision`, `delete_component`, `delete_dependency`, `delete_governs`.
- Each verified against the Omnigraph query lint tool; fallback if the dialect rejects `and` in edge deletions.

### Fix B: Document the Cleanup Workflow (`AGENT_PROMPT.md`)

- Insert workflow instructions after the `OmnigraphMutate` description: (1) branch, (2) delete edges before nodes, (3) verify, (4) merge.
- The model learns to use `OmnigraphMutate` with named delete queries, avoiding tool-name guessing or shell fallback.

### Fix C: Bulk Deletes + Guardrail

- Add parameter-less `delete_all_*` queries for decisions, components, dependencies, governs.
- Guardrail predicate `denied_mutation_reason` in `guardrail.ail`: 
  - Rule 1: prevent writes directly on `main`.
  - Rule 2: bulk wipe queries require a branch name starting with `wipe/` or `cleanup/`.
- The predicate returns `Option[string]` (deny reason); integrated into `on_tool_policy` via a single `match`.
- Atomic commit with tests for allow/deny scenarios (including bulk wipe on `main` yielding the main-branch deny message).

## Cross-Cutting Concepts

- [[concepts/abort-state-preservation]]: How the runtime threads aborted turns into conversation history.
- [[concepts/omnigraph-deletion-workflow]]: The branch → delete edges → delete nodes → merge pattern for safe graph manipulation.
- [[concepts/guardrail-predicate]]: A single-predicate deny-check pattern with ordered rules for tool policy enforcement.
- [[concepts/tool-result-threading]]: Collecting and formatting tool outputs, including aborted calls, for the language model.

## Testing & Success Criteria

- Replay of the original defect transcript shows the model using `OmnigraphMutate` with the new `delete_*` queries, no shell fallback, and proper sequencing.
- After abort, the agent references its previous `OmnigraphMutate` calls and the abort marker.
- Bulk wipe on non-cleanup branch returns the guardrail deny message, and no destructive query reaches the Omnigraph binary.