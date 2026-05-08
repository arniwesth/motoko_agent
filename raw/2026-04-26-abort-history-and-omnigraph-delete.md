# 2026-04-26 — Abort history persistence + Omnigraph delete workflow

## Scope
Implemented `.agent/plans/Abort_History_And_Omnigraph_Delete.md` across runtime and Omnigraph extension surfaces.

## Runtime fix (abort no longer drops in-flight history)

Updated `src/core/rpc.ail` so `DelegatedAborted` in `run_hybrid_step` now preserves the in-flight turn context instead of returning `ab.state` directly.

### Changes
- Added helper:
  - `delegated_aborted_results(calls)` to synthesize per-tool `ToolErrorResult(..., message: "aborted")`.
- Updated `DelegatedAborted` branch to:
  - emit the existing turn-level abort error event,
  - merge native/denied results + aborted delegated results,
  - append observation text to conversation history,
  - include marker: `[turn aborted by user before all tool results returned]`,
  - return state with `msgs` updated and `step` unchanged.
- Added focused inline checks for the new helper in `rpc.ail`.

### Outcome
After abort, next-turn prompting retains prior assistant output and partial tool execution context, so the agent can explain what was attempted.

## Omnigraph deletion capability + guardrails

### A) Delete queries added
Updated mutation catalogs:
- `omnigraph/mutations/decisions.gq`
  - `delete_decision($slug)`
  - `delete_all_decisions()`
- `omnigraph/mutations/components.gq`
  - `delete_component($slug)`
  - `delete_dependency($from_slug)`
  - `delete_dependency_to($to_slug)`
  - `delete_governs($decision_slug)`
  - `delete_governs_to($component_slug)`
  - `delete_all_components()`
  - `delete_all_dependencies()`
  - `delete_all_governs()`

### Dialect-driven adjustment
The plan’s original two-predicate edge delete shape (`where ... and ...`) is not accepted by this Omnigraph CLI dialect. The edge deletes were split into directional queries (`*_from`/`*_to` style names above) so each query is lintable and executable.

Also, parameter-less `delete <Node>` queries are rejected by this parser; bulk queries were made lintable using non-empty-key predicates (for example `where slug != ""`, `where from != ""`).

### B) Prompt guidance added
Inserted a dedicated “Deleting graph data” section in:
- `omnigraph/AGENT_PROMPT.md`

It now explicitly instructs:
1. branch creation,
2. edge cleanup before node deletion,
3. verification reads,
4. merge back to `main`.

### C) Bulk-delete safety rail
Refactored guardrail policy:
- Replaced `is_main_branch_mutation` with `denied_mutation_reason: ToolCallEnvelope -> Option[string]`.
- Rule order:
  1. deny any mutate on `main`,
  2. deny `delete_all_*` unless branch prefix is `wipe/` or `cleanup/`.

Refactor details:
- Added shared arg helper module: `src/core/ext/omnigraph/args.ail`.
- Updated policy call site to `match denied_mutation_reason(...)`.
- Added/updated tests for full allow/deny matrix in `omnigraph_test.ail`.

## Packaged extension sync

Because runtime extension loading resolves Omnigraph through package deps (`pkg/sunholo/motoko_omnigraph`), mirrored the Omnigraph extension changes into:
- `.packages/motoko_omnigraph/src/core/ext/omnigraph/*`

and regenerated lock metadata with:
- `ailang lock`

## Verification performed

- `ailang check src/core/rpc.ail` ✅
- `ailang test src/core/ext/omnigraph/omnigraph_test.ail` ✅ (16/16)
- `npm test -- --runInBand runtime-process.stream-protocol.test.ts` ✅ (suite passed)
- `omnigraph query lint --query mutations/decisions.gq` ✅
- `omnigraph query lint --query mutations/components.gq` ✅
- `omnigraph change ... --name delete_all_decisions --params "{}"` on throwaway branch ✅
- Smoke `omnigraph change` runs for all new delete queries on fresh throwaway branches ✅

Temporary `cleanup/*` test branches created during validation were deleted afterward.

## Files touched (primary)

- `src/core/rpc.ail`
- `src/core/ext/omnigraph/args.ail`
- `src/core/ext/omnigraph/guardrail.ail`
- `src/core/ext/omnigraph/omnigraph.ail`
- `src/core/ext/omnigraph/omnigraph_test.ail`
- `omnigraph/mutations/decisions.gq`
- `omnigraph/mutations/components.gq`
- `omnigraph/AGENT_PROMPT.md`
- `.packages/motoko_omnigraph/src/core/ext/omnigraph/args.ail`
- `.packages/motoko_omnigraph/src/core/ext/omnigraph/guardrail.ail`
- `.packages/motoko_omnigraph/src/core/ext/omnigraph/omnigraph.ail`
- `.packages/motoko_omnigraph/src/core/ext/omnigraph/omnigraph_test.ail`
- `ailang.lock`
