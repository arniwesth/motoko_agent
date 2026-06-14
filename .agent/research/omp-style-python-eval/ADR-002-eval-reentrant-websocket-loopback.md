# ADR-002: `eval` loopback resolves in the canonical `tool_runtime` over a WebSocket (Design B′)

**Status**: Proposed (planned successor to [ADR-001](./ADR-001-eval-mvp-local-loopback.md); feasibility verified, deferred to a later iteration)
**Date**: 2026-06-14
**Related**: [00-design.md](./00-design.md) (§2, §4 Design B′, §5), [01-session-summary-and-handover.md](./01-session-summary-and-handover.md), [ADR-001-eval-mvp-local-loopback.md](./ADR-001-eval-mvp-local-loopback.md), `smoke/smoke_transmit.ail`, `smoke/ws_server.ts`

## Context

[ADR-001](./ADR-001-eval-mvp-local-loopback.md) ships `eval` with the tool loopback served *locally in the env-server in TS*. That MVP has one accepted cost: a cell's in-cell `tool.*` calls hit a **fork** of the real tool registry — no other Motoko extensions' tools, and no `on_tool_policy` enforcement on in-cell calls.

oh-my-pi gets parity for free because kernels and the tool registry live in one async process: a cell's blocking loopback request is serviced by the host's own event loop. Motoko's registry (brain) and kernels (env-server) are split across a process boundary, so faithful parity requires the loopback request to travel **back to the brain** and be dispatched through the canonical `tool_runtime` — re-entrantly, while the brain is already waiting on the cell.

The open feasibility question was whether AILANG could do this at all: can the brain answer a loopback request *mid-stream* — i.e. call `transmit` **inside an `onEvent` handler** during a live `runEventLoop`?

## Alternatives considered

1. **Stay on Design C's local TS loopback permanently.** Rejected as the end state — it permanently forks the in-cell tool surface from the real registry and silently bypasses `on_tool_policy` and every other extension inside cells. Fine as an MVP (ADR-001), not as the target.
2. **Poll the brain from the env-server over HTTP for each loopback call** (no persistent socket). Rejected — re-entrancy over a request/response HTTP boundary while the brain is blocked awaiting the cell result is exactly the deadlock shape we are avoiding; it would need the brain to run a concurrent server loop anyway. A single bidirectional WebSocket within one event loop is the cleaner structural mirror of oh-my-pi's in-process loopback.
3. **Request an AILANG language feature** to support effectful re-entrancy. Found unnecessary — the smoke test (below) shows v0.19.1 already supports it. No upstream dependency.

## Decision

Adopt **Design B′** as the planned faithful successor to ADR-001, promoting C→B′ as a **transport swap** once the MVP has proven the kernel layer:

- The eval channel becomes a **WebSocket** (`std/stream connect` + `runEventLoop`) instead of blocking `httpPost`.
- The env-server runs the cell; when a kernel emits a `tool-request` frame it forwards it down the socket. The brain's `onEvent` handler dispatches it through the **canonical `tool_runtime`** (real `on_tool_policy` + all extensions) and `transmit`s the `tool-result` back. The loop exits on the `done` frame.
- **The kernel layer and the NDJSON frame protocol are unchanged from ADR-001.** Only the channel and where the loopback resolves differ — `tool-request` frames are redirected from the env-server's local TS handlers to the brain. This is why ADR-001 mandates freezing the frame protocol up front.

### Feasibility: the B′ blocker is RESOLVED ✅ (verified on AILANG v0.19.1)

`transmit` **can** be called inside an `onEvent` handler during a live `runEventLoop`. A handler closure carrying the `Stream` effect both type-checks (`ailang check` clean) and works at runtime: an end-to-end WS round-trip had the handler send `"reply-from-handler"` back to a Bun WS server, which received it. See `smoke/smoke_transmit.ail` + `smoke/ws_server.ts`. Run recipe:

```bash
cd .agent/research/omp-style-python-eval/smoke
RESULT_FILE=/tmp/ws_smoke_result.txt PORT=8787 bun run ws_server.ts   # terminal 1
ailang run --caps IO,Net,Stream --stream-allow-http --stream-allow-localhost smoke_transmit.ail   # terminal 2
# expect: server prints "SERVER_RECEIVED: reply-from-handler"
```

Implementation notes carried by the smoke test:
- `Stream` is its **own** `--caps` capability — not folded into `Net`.
- `ws://` to localhost needs `--stream-allow-http --stream-allow-localhost` (default is `wss://` only); the brain connects to the env-server over loopback, so both apply.
- `ailang run` flags must precede the positional `.ail` file (Go flag parsing stops at the first non-flag arg).
- Cleanup gotcha: **do NOT** `pkill -f ws_server.ts` — the pattern self-matches the killing shell's own command line (exit 144). Kill by PID.

## Consequences

- **True parity.** In-cell `tool.*` runs the real registry, honors `on_tool_policy`, and reaches every other extension — the fork from ADR-001 is closed.
- **No deadlock and no remaining language dependency.** The brain's event loop services the re-entrant loopback request; the `transmit`-from-handler capability is proven (above). C→B′ is a pure engineering swap with no upstream AILANG feature request.
- **The effect-system escape hatch from ADR-001 still stands** — native kernels run outside AILANG's capability model regardless of how the loopback resolves; workdir confinement + network policy + `eval`-tool gating remain required.
- **Sequencing.** Build ADR-001 (Design C) first; it exercises every genuinely new piece shared with B′. Promote to B′ once the kernel layer is proven, swapping `httpPost` for the WebSocket and redirecting `tool-request` frames to the brain — no kernel changes.
