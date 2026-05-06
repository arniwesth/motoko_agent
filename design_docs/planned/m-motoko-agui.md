# M-MOTOKO-AGUI — Adopt the AG-UI protocol for runtime ↔ UI wire format

**Status**: Planned
**Target**: motoko_agent (future minor release; ~1 sprint of dedicated work)
**Priority**: P3 (architectural; ships when motoko's product strategy benefits from external UI interop)
**Estimated**: 5-7 days (~30-40 hours)
**Dependencies**: M-MOTOKO-RPC-LOOP-FULL-MIGRATION cutover landed (PR #4 merged)
**Surfaced by**: M-MOTOKO-RPC-LOOP-FULL-MIGRATION M10 wire-format fixes (2026-05-06)

## Problem

motoko_agent's runtime ↔ TUI wire format is a bespoke set of JSON event shapes:

```
{ "type": "thinking_stream_start", "step": N, "stream_id": "step-N", "model": "..." }
{ "type": "thinking_delta", "step": N, "stream_id": "step-N", "seq": N, "text_delta": "..." }
{ "type": "thinking_stream_end", "step": N, ..., "status": "completed" }
{ "type": "native_tool_calls", "request_id": "...", "tool_calls": [...] }
{ "type": "native_tool_results", "request_id": "...", "results": [...] }
{ "type": "done", "step": N, "output": "..." }
```

Plus v2-specific trace events (`v2_tool_dispatch_start`, `ext_tool_handled`, `delegated_tool_deferred`, etc.) and TUI commands going the other way (`abort`, `exit`, `model_change`, `user_message`).

This worked fine when the only consumer was motoko's own TS TUI. It produces friction the moment any of the following happens:

1. **Wire-format changes break the TUI** — observed during M10 cutover (PR #4): the v2 loop emitted per-call native_tool_calls events while the TUI expected batched. Required a runtime-side fix to preserve wire compat. Every refactor of the dispatch flow risks similar breakage.
2. **External UIs can't drive motoko** — anyone wanting to embed motoko in their own UI (web dashboard, IDE plugin, mobile app, voice interface) has to learn motoko's bespoke shapes. There's no contract document — the TS TUI implementation IS the contract.
3. **Motoko can't drive other AG-UI agents' UIs** — if AILANG ever supports a motoko-shaped agent in another runtime, that runtime can't reuse the TS TUI as-is.
4. **Trace/replay tooling has to know motoko shapes** — every event consumer (logs, dashboards, replay engines) re-parses the same per-event shapes.

[AG-UI (Agent-User Interaction Protocol)](https://docs.ag-ui.com/) — the agent-↔-UI equivalent of MCP for tools — is the standard most agent ecosystems are converging on. CopilotKit, LangGraph, AutoGen, Mastra all support it.

## Scope

Replace motoko's bespoke wire shapes with AG-UI compliant events. Two layers:

### Layer 1: Runtime event emission (motoko-side AILANG)

`src/core/agent_loop_v2.ail` currently emits via `emit_json(jo([...]))`. Replace with an `emit_agui_*` family that produces AG-UI shapes:

| Current motoko event | AG-UI replacement | Notes |
|---|---|---|
| `thinking_stream_start` | `RUN_STARTED` | Run-level lifecycle |
| `thinking_delta` | `TEXT_MESSAGE_CONTENT` | Per-token incremental |
| `thinking_stream_end` (status=completed) | `TEXT_MESSAGE_END` | |
| `thinking_stream_end` (status=errored) | `RUN_FINISHED` with error | |
| `native_tool_calls` (batch) | one `TOOL_CALL_START` + `TOOL_CALL_ARGS` per call | AG-UI is per-call — natural fit for v2's per-call dispatch |
| `native_tool_results` (batch) | one `TOOL_CALL_END` + `TOOL_CALL_RESULT` per call | |
| `done` | `RUN_FINISHED` | |
| `ext_tool_handled` / `delegated_tool_deferred` | per-call `TOOL_CALL_RESULT` with structured payload | These collapse — they're just specialised result shapes |
| `session_start` | `RUN_STARTED` (top-level run) | |
| `error` (general) | `RUN_FINISHED` with error | |

### Layer 2: TUI event consumption (TS side)

`src/tui/src/ui.ts` currently has a giant switch on `event.type`. Replace with an AG-UI client (CopilotKit's reference implementation, or a hand-rolled state machine reading the standard schema). Key benefit: the renderer becomes per-tool_call_id state-machine driven instead of "wait for batch, render". Already half-done — `toolBatchHeaders` / `toolRows` are keyed by id.

### Bidirectional: Commands (TUI → runtime)

motoko has `user_message`, `abort`, `exit`, `model_change`. AG-UI's spec covers `RUN_INPUT` and `RUN_CANCEL` natively. `model_change` doesn't have an AG-UI equivalent — keep as a motoko-specific extension event.

## Acceptance criteria

- [ ] `agent_loop_v2.ail` emits AG-UI-shaped events for the canonical lifecycle (RUN_STARTED, TEXT_MESSAGE_*, TOOL_CALL_*, RUN_FINISHED)
- [ ] Wire shape conforms to the [AG-UI JSON schema](https://docs.ag-ui.com/concepts/events) (linkable, machine-validatable)
- [ ] TUI renders correctly using a generic AG-UI client library (or a hand-rolled spec-compliant reader)
- [ ] An AG-UI conformance test suite (if upstream provides one) passes against motoko's runtime
- [ ] One non-motoko AG-UI UI (e.g. CopilotKit's dashboard reference impl) can drive motoko end-to-end against a benign prompt
- [ ] All existing motoko sessions still work (TUI tests, M9 matrix variants)

## Implementation strategy

**Stage 1: parallel emission.** Add `emit_agui_*` helpers; emit BOTH the legacy bespoke events AND the AG-UI events. TUI keeps consuming the legacy ones. Verifies the AG-UI emit code is correct without breaking anything.

**Stage 2: TUI flips to AG-UI consumer.** Switch `ui.ts` to read the AG-UI events; legacy events still emitted but ignored. Verifies the TUI renders correctly off the new shape. Keep the legacy emit alive for any external scrapers that haven't migrated yet.

**Stage 3: drop legacy emission.** Delete the bespoke event helpers; AG-UI is the only wire format. Update CHANGELOG with a migration note for any external consumers (probably zero, but the changelog is the right place to document it).

This staged approach means each PR is small, reviewable, and reversible. No big-bang cutover.

## Cross-references

- Parent: `m-motoko-rpc-loop-full-migration.md` (the migration that surfaced the wire-format friction at M10)
- Companion sibling: `m-motoko-workdir-cwd-resolution.md`, `m-motoko-m65-ohmy-pi-delegation.md` (same family of post-cutover follow-ups)
- AG-UI spec: https://docs.ag-ui.com/
- Reference clients: CopilotKit (https://docs.copilotkit.ai/), LangGraph AG-UI driver, Mastra
- AILANG dependency: none — pure motoko-side wire format change

## Open questions for arni

1. **Product strategy**: does motoko aim to be embedable in non-TS UIs (web, mobile, voice)? If yes, AG-UI is high-value. If motoko stays a CLI/TUI-only product, AG-UI is technical-purity-only and lower priority.
2. **Schema versioning**: AG-UI versions its events. We pin a version in the runtime; bumping requires a coordinated runtime + client update. Worth doing now with a v0 schema or wait for AG-UI v1 stable?
3. **Custom extensions**: motoko has v2-specific events (`ext_tool_handled`, `delegated_tool_deferred`) that don't map cleanly to AG-UI. AG-UI supports custom events via a namespace prefix; do we use that or absorb them into TOOL_CALL_RESULT payload metadata?
