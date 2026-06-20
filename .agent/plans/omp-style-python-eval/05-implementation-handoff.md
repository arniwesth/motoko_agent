# Handoff: implement plan 05 persistent verified AILANG eval

You are implementing [05-persistent-verified-ailang-eval.md](./05-persistent-verified-ailang-eval.md).

## Objective

Add `language:"ail"` support to the existing `eval` tool as a persistent, source-backed AILANG scratchpad. This is **not** a Python-style mutable REPL. AILANG cells persist accepted source declarations/imports in a session module; failed candidates do not mutate state. Every candidate is gated by `ailang check`, with optional `ailang verify` / Z3 verification for contracts.

## Current facts to verify first

- AILANG target is latest stable, **`>=0.25.0`**. The docs catalog showed `0.25.0` as latest on 2026-06-17, but the local workspace binary was `v0.24.2` during planning. Upgrade/select the latest CLI before implementation.
- Verify exact current CLI behavior:
  - `ailang --version`
  - `ailang check <file>` and preferably `ailang check --json <file>`
  - `ailang run --caps <CAPS> --entry main <file>`
  - `ailang verify <file>` and preferably `ailang verify --json <file>`
- Verify whether Z3 is bundled or must be installed separately.
- Verify the AILANG teach prompt path:
  - MCP: `prompt_get(forVersion:"0.25.0", kind:"agent")`
  - CLI fallback: `ailang prompt --kind agent`

Do not implement against stale `v0.19.1` assumptions.

## Key semantic decisions

- Use existing `eval` with `language:"ail"`; do **not** create a separate `ailang_eval` tool or `/exec-ailang-cell` route for MVP.
- Persistence means accumulated source, not mutable variables.
- A cell can use declarations accepted by earlier cells.
- A later cell does **not** update an earlier declaration in place. Duplicate top-level names should fail for MVP unless you explicitly add a safe replacement policy.
- Keep imports, accepted declarations, and ephemeral run wrappers separate. Do not concatenate raw cells blindly; late imports in the middle of a module will break.
- Generated `main` / run wrappers should be ephemeral unless the cell explicitly declares persistent source.
- Unknown eval languages must produce explicit errors. Do not keep the current behavior that coerces unknown languages to Python.
- Proof wording must be exact: only say "verified" when the verifier actually proved the contract. Preserve `skipped`, `unknown`, `timeout`, and `failed`.

## One-time AILANG teaching prompt

The model cannot be expected to write AILANG cold.

Implement a session-scoped teaching prompt marker, preferably keyed by `ctx.state_key` in core/session state and mirrored in the env-server `AilangSession` only for diagnostics.

Expected behavior:

- Before the first `language:"ail"` authoring/repair attempt in a session, surface or inject the AILANG agent teaching prompt once.
- Subsequent `ail` cells in the same session should not duplicate the full prompt.
- After compaction/resume, provide at least a compact reminder and reload the full prompt only if needed.
- The package prompt should contain a short standing instruction, not the full teach prompt on every turn.

If core-side one-time injection is too invasive for the first pass, use the env-server fallback: the first `ail` cell returns a structured notice asking the model to load the teaching prompt before retrying, and records `teachPromptSeen`.

## Main files

Read these before editing:

- `src/tui/src/eval/frames.ts`
- `src/tui/src/eval/registry.ts`
- `src/tui/src/eval/ws-channel.ts`
- `src/tui/src/eval/transcript.ts`
- `src/tui/src/env-server.ts`
- `src/tui/src/ui.ts`
- `src/tui/src/ui.tool-render.test.ts`
- `src/core/env_client.ail`
- `src/core/types.ail`
- `src/core/agent_loop_v2.ail`
- `packages/motoko_eval/types.ail`
- `packages/motoko_eval/eval.ail`
- `packages/motoko_eval/prompts.ail`

Current blockers called out by the plan:

- `EvalLanguage` is currently `"py" | "js"` only.
- `normalizeEvalCells()` currently maps any non-`"js"` language to `"py"`.
- `EvalRegistry` only routes Python and JS kernels.
- `ui.ts` rejects eval result cells unless `language` is `"py"` or `"js"`.
- `agent_loop_v2.ail` special-cases `eval` and calls `exec_cell_ws(...)` directly, so HTTP and WS paths both need coverage.
- `packages/motoko_eval` schema/prompt currently advertises only Python/JS.

## Implementation shape

1. Phase 0 spike:
   - Upgrade/select AILANG `>=0.25.0`.
   - Create a tiny temporary `.ail` module and verify check/run/verify commands and JSON output formats.
   - Record command decisions in the plan or a small smoke note.

2. Types and normalization:
   - Extend `EvalLanguage` to include `"ail"`.
   - Extend `EvalCell` with optional AILANG fields: `verify`, `run`, `entry`, `caps`.
   - Add optional `metadata?: { ailang?: AilangCellMetadata }` to `EvalCellResult`.
   - Preserve `metadata.ailang` through env-server response, `ToolResultEnvelope.metadata.cells`, `eval_result.cells_json`, and `parseEvalCellsJson`.

3. AILANG source session:
   - Add `kernel-ailang.ts` / `ailang-session.ts`.
   - Store `imports`, `acceptedDecls`, `lastGoodSource`, `teachPromptSeen`, timestamps.
   - Render candidate module deterministically:
     1. generated module declaration,
     2. deduped imports,
     3. accepted declarations,
     4. candidate declarations,
     5. optional ephemeral run wrapper.
   - Commit only after the configured check/verify gates pass.

4. Check/verify/run pipeline:
   - Always run `ailang check`.
   - Run verifier for `verify:"auto"` only when annotations are present; require pass for `verify:true` / `"required"`.
   - Map statuses to:
     - check: `passed | failed | skipped`
     - verify: `verified | failed | unknown | timeout | skipped`
   - Add human-readable status lines to the transcript or `status` display bundles.

5. Routing:
   - Extend `/exec-cell`; do not add a separate route.
   - Make WS eval path use the same normalization and runner behavior as HTTP.
   - Ensure v2 direct `exec_cell_ws` behavior matches extension fallback behavior.

6. Extension schema/prompt/policy:
   - Update `packages/motoko_eval/types.ail` schema to include `language:"ail"` and optional AILANG fields.
   - Update prompt guidance with:
     - Python/JS vs AILANG selection advice,
     - one-time teaching prompt instruction,
     - proof caveat.
   - Policy must intersect requested caps with allowed caps; env-server should enforce a ceiling too.

7. TUI:
   - Accept `language:"ail"` in `normalizeEvalCellResult`.
   - Preserve `metadata.ailang`.
   - Render check/verify status in eval card headers/details.
   - Use existing `highlightCodeLines(code, "ail")` / `"ailang"` path.

## Tests required

- TS unit:
  - source accumulation,
  - reset,
  - invalid cell does not mutate prior accepted declarations,
  - late import placement,
  - duplicate declaration failure or explicit replacement policy,
  - check failure mapping,
  - verify success/failure/unknown/timeout mapping,
  - timeout handling.
- Normalization regression:
  - unknown language errors explicitly,
  - `language:"ail"` survives HTTP `/exec-cell`,
  - `language:"ail"` survives WS `/exec-cell-ws`,
  - `language:"ail"` survives `eval_result.cells_json`,
  - TUI parser accepts it.
- Wire metadata:
  - `cell.metadata.ailang` survives env-server response → `ToolResultEnvelope.metadata.cells` → `eval_result.cells_json` → `parseEvalCellsJson`.
- Teach prompt:
  - fresh session surfaces the AILANG teaching prompt before first `ail` authoring attempt,
  - same session does not repeat full prompt,
  - compacted/resumed session gets at least compact reload reminder.
- Policy:
  - restricted profile denies run/effectful caps,
  - check-only/verify-only is allowed only if explicitly configured.
- Regression:
  - existing Python/JS eval tests remain green,
  - existing `/exec-ailang` stateless route remains available unless deliberately deprecated.

Manual E2E target:

```text
use eval in AILANG to define a pure abs_diff function with an ensures clause proving the result is non-negative, verify it, then run main to print abs_diff(10, 3)
```

Expected:

- first AILANG teach prompt appears once before authoring,
- first cell check passes, verify is `verified`, committed,
- second cell check passes, run prints `7`,
- no Python/JS kernel involvement,
- eval card shows check/verify status clearly.

## Be careful

- Do not claim all calculations are verified. Only stated contracts that the verifier proves are verified.
- Do not hide `unknown` or timeout as success.
- Do not make every prompt include the full AILANG teaching guide.
- Do not rely only on package `on_tool_handle`; v2 has a direct eval WebSocket path.
- Do not let unknown languages silently become Python.
- Do not mutate prior source state after failed check/verify.
