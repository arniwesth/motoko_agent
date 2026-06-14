# ADR-001: `eval` MVP serves the tool loopback locally in the env-server (Design C)

**Status**: Accepted
**Date**: 2026-06-14
**Related**: [00-design.md](./00-design.md) (§3, §4 Design C, §5), [01-session-summary-and-handover.md](./01-session-summary-and-handover.md), [ADR-002-eval-reentrant-websocket-loopback.md](./ADR-002-eval-reentrant-websocket-loopback.md), `src/core/env_client.ail`, `src/tui/src/env-server.ts`

## Context

We are porting oh-my-pi's `eval` tool — persistent Python + JS cells that can call back into the agent's own tools (`tool.read/write/search`, `agent(...)`) mid-cell over a loopback bridge — into Motoko.

Two facts force the architecture (verified against AILANG v0.19.1; see [00-design.md §2](./00-design.md)):

1. **AILANG cannot host a persistent bidirectional REPL in the brain.** `std/process.spawnProcess` gives a writable stdin but discards stdout/stderr; `std/stream.asyncExecProcess` reads stdout but is read-only and dies when the event loop exits. So the persistent Python/Bun kernels **must live in the Bun env-server**, which already holds long-lived bidirectional subprocesses. oh-my-pi's `kernel.ts` / `worker-core.ts` port almost directly.

2. **The tool registry lives in the AILANG brain; the kernels live in the env-server** — two processes separated by a synchronous HTTP boundary. oh-my-pi avoids loopback deadlock by co-locating kernels and registry in one async process; Motoko cannot. So *where a cell's `tool.*` call resolves* is the one real design fork.

This ADR records the decision for the **first shippable version**. The faithful, re-entrant variant is recorded separately in [ADR-002](./ADR-002-eval-reentrant-websocket-loopback.md).

## Alternatives considered

1. **Kernels in the AILANG brain.** Rejected — not a preference but a capability wall (§2 above). No single AILANG mechanism is *both* persistent-bidirectional *and* survives the event loop: `spawnProcess` writes stdin but can't read stdout; `asyncExecProcess` reads stdout but is read-only and dies with the loop.
2. **Re-entrant WebSocket loopback to the canonical `tool_runtime` (Design B′).** Faithful — in-cell `tool.*` runs the real registry, real `on_tool_policy`, and all other extensions. Deferred, not rejected: it is the planned successor ([ADR-002](./ADR-002-eval-reentrant-websocket-loopback.md)). It shares the entire kernel layer with this design, so C is a strict subset of B′, not throwaway work. Building B′ first would couple the genuinely new kernel-hosting work (persistence, `display()`/image/JSON capture, cancellation, timeouts, idle cleanup) to the more involved transport/re-entrancy work with no MVP in between.
3. **No loopback at all (plain `eval` with no `tool.*`).** Rejected — the tool-callback bridge is the headline capability we are porting; cells that can read/search/spawn subagents are the 90% use case.

## Decision

Ship **Design C**:

- `eval` is a **Motoko extension** (`motoko_ext_eval`) — it owns `provided_tools: ["eval"]`, the `cells` schema (`on_describe_tools`), gating (`on_tool_policy`), and `on_tool_handle`. It **delegates execution** to the env-server, the same front/backend split that `exa_search` and the core bash/AILANG tools already use via `env_client.ail`.
- The brain → env-server channel is **blocking `httpPost`** to a new `/exec-cell` route (reuses the `env_client.ail` pattern).
- The env-server gains a **session→kernel registry** (`python:${id}`, `js:${id}`) hosting persistent Python + Bun kernels, with display/image/JSON capture, cancellation, timeouts, and idle cleanup. Near-direct port of oh-my-pi's `py/kernel.ts`, `py/runner.py`, `py/prelude.py`, `js/worker-core.ts`.
- The **loopback is served locally inside the env-server in TS**: `read`/`write` = fs, `search` = ripgrep, `agent` = `callSubagentModel` (**already exists** in `env-server.ts`). There is **no deadlock** — the env-server holds the kernels and answers their tool calls itself; the brain just waits for the final result.
- **Freeze the NDJSON frame protocol up front**, independent of transport: `run` / `display` / `result` / `tool-request` / `tool-result` / `done`. This is the contract that lets C be promoted to B′ as a channel swap, not a rewrite.

## Consequences

- **The in-cell `tool.*` surface is a fork of the real registry.** It does *not* run other Motoko extensions' tools, and it does *not* honor `on_tool_policy` for in-cell calls. Accepted because the cell's 90% case (read/write/search/agent) is exactly what the env-server can already do natively. True parity is deferred to [ADR-002](./ADR-002-eval-reentrant-websocket-loopback.md).
- **In-cell `agent()` is the single-call form only.** `callSubagentModel` gives one bounded subagent call with little new code; oh-my-pi's `parallel()` / `pipeline()`, the depth-3 recursion cap, and spawn-policy enforcement are *not* in the MVP and are additional work if wanted (design §6). Scope the cell prelude's `agent()` accordingly so it doesn't imply capabilities we don't ship.
- **Don't reimplement brain policy in TS.** Gate the env-server loopback to a fixed, workdir-confined tool list rather than porting `on_tool_policy` logic — keep policy canonical and let B′ deliver real parity later.
- **Effect-system escape hatch.** Native Python/Bun kernels run *outside* AILANG's capability model — a cell can do arbitrary FS/network I/O the effect row would normally gate. This is a deliberate hole in a "self-verifying software" project and must be fenced: workdir confinement, a network policy, and `on_tool_policy` gating of the `eval` tool itself. Call this out explicitly in the extension's README.
- **C is a strict subset of B′.** The kernel layer is identical; only the channel (`httpPost` vs WebSocket) and where the loopback resolves (env-server TS vs brain `tool_runtime`) differ. Effort is low.
- **Open questions still to settle during implementation** (from [00-design.md §7](./00-design.md)): JS runtime (Bun `Worker` vs `vm` context); Python availability probing + install-script guarantee of `python3`; what the eval session id keys off and whether `compose`/subagents inherit it to share kernels; output limits (adopt oh-my-pi's 50KB window / 30s default timeout / artifact spill, or set our own).
