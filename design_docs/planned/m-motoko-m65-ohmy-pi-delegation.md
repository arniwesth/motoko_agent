# M-MOTOKO-M6.5-OHMY-PI-DELEGATION — Wire env-server inbox-based delegation

**Status**: Planned
**Target**: motoko_agent (post-Pi-deployment, exact version TBD)
**Priority**: P2 (only triggered when motoko deploys against a Pi/env-server)
**Estimated**: 1-2 days (~8-12 hours)
**Dependencies**: M-MOTOKO-RPC-LOOP-FULL-MIGRATION cutover landed (PR #4 merged)
**Surfaced by**: M-MOTOKO-RPC-LOOP-FULL-MIGRATION M6 lean implementation (2026-05-06)

## Problem

The M-MOTOKO-RPC-LOOP-FULL-MIGRATION M6 milestone shipped a **lean** `ohmy_pi` backend split: when the model emits a `BashExec` with shell tokens / streaming / hard-cancel flags, the dispatcher returns a `delegated_deferred_message` envelope (`error: true, delegated_backend_not_wired: true`) instead of attempting to run it. This was the explicitly authorized fallback (Gate 3 option (b)) so the cutover could ship without doing the full env-server inbox-wait migration.

In v2 standalone mode this is fine — there's no env-server, so there's nothing to delegate TO. But when motoko runs against a Pi/env-server (the production deployment shape), the env-server WOULD be ready to run those commands via shell — the legacy code path handled this via:

1. Emit `tool_calls` event with `request_id` to stdout
2. The TS env-server reads it, runs the command in its own subprocess with full shell support + streaming
3. Posts back a `tool_results` event on the agent's stdin
4. AILANG's `wait_for_tool_results` polls the inbox + drains stdin until it sees the matching request_id
5. Decodes the results, builds tool-role Messages, returns them

We deleted that whole pipeline at M10b (~600 LOC of `wait_for_tool_results`, `pull_tool_results`, `decode_delegated_results`, `delegated_aborted_results`, `delegated_wait_attempts`, etc.) because it was unreachable post-cutover.

## Scope

Restore the inbox-based delegation pipeline against the new v2 architecture:

1. **Thread an `inbox: [string]` through `loop_v2`** alongside `[Message]`. Each iteration may receive new lines on stdin that aren't tool results yet (e.g. `model_change`, `abort`) — those need to queue back into the inbox so `conversation_loop_v2` can consume them once the current task completes.

2. **Re-implement `wait_for_tool_results`** scoped to v2:
   ```ailang
   func wait_for_tool_results_v2(
     inbox: [string],
     request_id: string,
     attempts: int
   ) -> Result[{ raw: string, inbox: [string] }, AIError] ! {IO, SharedMem}
   ```
   Returns the matched raw line plus the residual inbox (without the consumed line). On timeout returns `Err{TimeoutError}` instead of the `delegated_aborted_results` shape.

3. **Wire it into `dispatch_calls`**'s `Delegate → Delegated` branch. Replace the current `delegated_deferred_message` with:
   - Emit batched `tool_calls` event with `request_id`
   - Call `wait_for_tool_results_v2(inbox, request_id, attempts)`
   - On `Ok(raw)`: `decode_delegated_results(raw, delegated_calls)` → tool-role Messages
   - On `Err`: produce a structured timeout/abort tool-role envelope (similar shape to current `delegated_deferred_message` but with `timed_out` instead of `not_wired`)

4. **Re-port `decode_delegated_results`, `delegated_results_from_entries`, `delegated_result_for_call`, `find_exec_result`** — the result-shape extraction layer. These were ~80 LOC in legacy rpc.ail; trimmer in v2 because we don't need to bridge ToolResultItem ADT (we go straight to JSON Message content).

5. **Coordinate with the TS env-server** to make sure the request_id / tool_calls / tool_results contract still matches what `runtime-process.ts` emits and consumes. This was unchanged by M10's wire-format fix so should be a no-op verification.

## Acceptance criteria

- [ ] Running motoko against a Pi env-server with `ohmy_pi=true` and a BashExec with `cmd:"echo hi | grep hi"` succeeds via the env-server delegation path
- [ ] `streaming: true` BashExec produces incremental output through the same path
- [ ] `needs_hard_cancel: true` BashExec can be cancelled mid-execution via the env-server
- [ ] Delegation timeout produces a tool-role timeout error (`timed_out: true`) without crashing the loop
- [ ] Mixed batches (some Native, some Delegated) round-trip correctly
- [ ] M9 matrix still 25/25 (with `ohmy_pi=false` — no regression for standalone mode)
- [ ] New smoke: `scripts/smoke_v2_delegation_roundtrip.ail` against a mock env-server stub

## Why this isn't M6.0

The M6 lean shipped because Gate 3 was answered with explicit authorization for option (b) "defer ohmy_pi if blocking — return ToolErrorResult for delegated calls". The lean implementation:
- Preserves the `ohmy_pi: bool` flag plumbing through `run_v2_with_conversation`
- Calls `backend_for(envelope, ohmy_pi)` per-call
- Returns the structured `delegated_backend_not_wired` envelope on Delegated routes
- Forces Native when `ohmy_pi=false` (so standalone mode is fully usable)

This means M6.5 is **purely additive** — no architectural change, just filling in the deferred path. The trigger is "motoko gets deployed to a Pi", not "M6 was incomplete".

## Implementation notes

- The legacy code that did this is preserved in git history (commit `6350b7a` deleted it; revert/cherry-pick the relevant `wait_for_tool_results` + `decode_delegated_results` blocks for reference).
- Look at PR #4 commit `0117803f` (the streaming PR's foundation) for the inbox plumbing pattern motoko already uses for non-tool-call commands (`abort`, `model_change`, `user_message` in `conversation_loop_v2`).
- The TS-side env-server's contract is in `src/tui/src/env-server.ts` — search for `tool_calls` / `tool_results` event handlers; should be unchanged from before the migration.

## Cross-references

- Parent sprint: `m-motoko-rpc-loop-full-migration.md` (Gate 3 = option (b))
- Companion: `m-motoko-workdir-cwd-resolution.md` (sibling small fix, ships earlier)
- AILANG dependency: none new — uses existing `std/io.readLine`, `std/shared_mem`, etc.
