# Plan: `eval` faithful loopback — re-entrant WebSocket to `tool_runtime` (Design B′)

Implements **[ADR-002](../../research/omp-style-python-eval/ADR-002-eval-reentrant-websocket-loopback.md)**.
Design source: [`00-design.md`](../../research/omp-style-python-eval/00-design.md) §4 Design B′.
Feasibility proof: [`smoke/`](../../research/omp-style-python-eval/smoke/) (`smoke_transmit.ail` + `ws_server.ts`).
**Depends on [plan 01 (Design C)](./01-design-c-mvp-local-loopback.md) being shipped and the frame protocol frozen.**
Toolchain: AILANG v0.19.1, Bun 1.3.x.

## Background

Design C (plan 01) serves the in-cell tool loopback locally in the env-server, so a cell's `tool.*` calls hit a **fork** of the real registry — no other extensions' tools, no `on_tool_policy` on in-cell calls. B′ closes that fork: when a kernel emits a `tool-request` frame, the env-server forwards it **back to the brain** over a WebSocket; the brain dispatches it through the **canonical `tool_runtime`** (real policy + all extensions) and `transmit`s the `tool-result` back. This is the structural mirror of oh-my-pi's in-process loopback — a WebSocket stands in for the in-process call *precisely because* registry and kernels live in different processes here.

**The headline blocker is resolved, but read its scope precisely.** ADR-002's `smoke/` test proved the *result send-back*: calling `transmit` inside an `onEvent` handler during a live `runEventLoop` (type-checks + runs). That is necessary but **not sufficient** for Phase 3: dispatching the tool itself can require running `AI`/`Net`/`Process` effects *inside* the handler before the `transmit`, and that finer capability is **not yet verified** (Phase 3 ⚠ gates on a dedicated smoke). So this plan **refines ADR-002's "pure engineering swap, no language dependency" claim**: the transport swap has no language dependency, but the in-handler *effectful dispatch* still needs a one-time proof before Phase 3 commits. `IO`/`Process`-in-handler is already shown (`csp_demo`), so this is "very likely, unverified," not "doubtful."

## Goals

- In-cell `tool.read/write/search`/`agent()` (and any future extension tool) dispatch through the brain's canonical `tool_runtime`, honoring `on_tool_policy` and every loaded extension.
- The eval channel becomes a WebSocket; the env-server forwards `tool-request` frames to the brain and applies the returned `tool-result`.
- **Kernel layer and frozen frame protocol unchanged from C** — this is a transport + loopback-dispatch swap, not a kernel rewrite.

## Non-goals

- No changes to the kernels (`runner.py`, `worker-core.ts`), the session registry, display/image/json capture, timeouts, or idle eviction. All carried verbatim from plan 01.
- No ABI bump: `on_tool_handle`'s effect row already includes `Stream` and `Net`.
- No new in-cell helper surface (still `tool.*` + single-call `agent()` unless plan 01 added more).

---

## What changes vs Design C

| Layer | Design C (plan 01) | Design B′ (this plan) |
|---|---|---|
| Brain→env-server channel | blocking `httpPost` `/exec-cell` | WebSocket (`std/stream connect` + `runEventLoop`) |
| `tool-request` resolved by | env-server local TS handlers | brain `tool_runtime` (canonical) |
| Brain `on_tool_handle` shape | one blocking call, await result | open WS, host `runEventLoop`, dispatch frames until `done` |
| Kernels / frame protocol | — | **identical** |

The `tool-request {reqId, tool, arguments}` / `tool-result {reqId, exit_code, stdout, stderr, metadata}` frames frozen in plan 01 Phase 0 are the seam. Only their **resolution target** moves.

---

## Phase 1 — env-server: WebSocket eval channel

**Files:** `src/tui/src/env-server.ts`, `src/tui/src/eval/ws-channel.ts` (new), `src/tui/src/eval/loopback.ts` (modified).

- Add a WebSocket server route (e.g. `/exec-cell-ws`) alongside the existing `/exec-cell` HTTP route. Keep `/exec-cell` so C remains available as a fallback / for environments without the WS loopback.
  - **Integration reality:** the env-server is **Express** (`app = express()`; `const server = app.listen(port)` at `env-server.ts:1596`), which has **no native WebSocket**. The smoke test's `Bun.serve` WS pattern does **not** transfer to it. Attach a `ws` `WebSocketServer({ server })` (or `express-ws`) to the `http.Server` that `app.listen` returns and handle the upgrade on the `/exec-cell-ws` path. Add `ws` to `src/tui/package.json`.
- On connection: receive a `run`/`cells` frame, drive the kernels exactly as in C.
- **Redirect the loopback:** when a kernel emits `tool-request`, instead of calling the local resolver (plan 01 Phase 3), **forward the `tool-request` frame down the WebSocket to the brain** and `await` the matching `tool-result` (correlated by `reqId`). The local resolvers become the *fallback* path (used only if no brain peer is attached — keeps single-process tests working).
- Stream `started…done` frames back over the same socket.

**Acceptance:** with a stub brain peer that echoes a canned `tool-result`, a cell's `tool.read()` resolves via the socket round-trip, not the local fs resolver.

---

## Phase 2 — brain: WebSocket client in `on_tool_handle`

**Files:** `motoko_ext_eval/eval.ail` (modified `on_tool_handle`), new helper module `motoko_ext_eval/ws_loopback.ail`.

Replace the blocking `env_client.exec_cell` call (plan 01 Phase 5) with a WebSocket-driven loop:

- `std/stream.connect` to `ws://127.0.0.1:<port>/exec-cell-ws` (the env-server, over loopback).
- Send the `run`/`cells` frame.
- `runEventLoop` with an `onEvent` handler that matches on frame type:
  - `tool-request {reqId, tool, arguments}` → build a `ToolCallEnvelope`, dispatch through the **canonical `tool_runtime`** (Phase 3), and **`transmit` a `tool-result {reqId, …}` back from inside the handler** (the capability proven in `smoke/`).
  - `display`/`result`/`stdout`/`stderr` → accumulate.
  - `done` → close the loop, build `Handled(ToolResultEnvelope)`.

**Capability flags** (from `smoke/` notes, ADR-002):
- `Stream` is its **own** `--caps` capability — ensure the brain runs with `…,Stream`. `on_tool_handle`'s effect row already declares `Stream`, so the type-checker is satisfied; the *runtime* cap grant must include it.
- `ws://` localhost needs `--stream-allow-http --stream-allow-localhost`. Wire these into how the brain process is launched (`scripts/`/Makefile/env-server spawn of the brain).
- `ailang run` flags must precede the positional `.ail` file.

**Acceptance:** `ailang check` clean on `motoko_ext_eval` with the WS handler; the handler type-checks with `transmit` inside `onEvent` (mirrors `smoke_transmit.ail`).

---

## Phase 3 — re-entrant dispatch through `tool_runtime`

**Files:** brain tool-runtime entry point (the canonical dispatcher used by `rpc.ail` / the extension host), `motoko_ext_eval/ws_loopback.ail`.

This is the crux: a `tool-request` arriving mid-cell must be dispatched the **same way a top-level tool call is** — through the registry that applies `on_tool_policy` and every extension's `on_tool_handle`.

- Expose / reuse a callable `dispatch_tool(ctx, ToolCallEnvelope) -> ToolResultEnvelope` that the `onEvent` handler can invoke. Confirm the existing dispatcher can be called re-entrantly (the brain is inside `eval`'s own `on_tool_handle` when the loopback fires). The event-loop services the request on the same logical flow — **no deadlock**, since the brain is *in* `runEventLoop`, not blocked on a synchronous call (ADR-002 alternatives §2).
- **⚠️ Proven vs assumed — the load-bearing gap.** The `smoke/` test proved only that **`transmit` (the `Stream` effect)** works inside an `onEvent` handler; `csp_demo` additionally shows `IO`/`Process` in handlers. What B′ Phase 3 actually needs is stronger: dispatching a **full tool — potentially an `AI`-effect LLM subagent call (`agent()`), plus `Net`/`Process`** — from *inside* the handler mid-`runEventLoop`. That is an **extrapolation, not yet verified.** **Prerequisite before committing Phase 3:** extend `smoke/` to prove an *effectful dispatch* in-handler — e.g. the handler performs an `httpPost`/`callStream`-shaped call (the real `AI`/`Net` effects) and `transmit`s the result — and confirm it both type-checks and runs. If AILANG cannot run an `AI`-effect call inside a live event-loop handler, the in-cell `agent()` must instead be marshaled as a *deferred* request resolved after the loop yields, or routed differently. Resolve this before building Phase 3, not during.
- **Guard against unbounded re-entrancy:** an `eval` cell could call a tool that itself triggers `eval`. Add a depth counter on `ExtCtx`/the loopback (cap, e.g. 3, matching oh-my-pi's recursion cap) and deny beyond it via `Deny(...)`.
- **Policy is now canonical:** in-cell `tool.*` goes through `on_tool_policy`. Decide whether the eval-cell context should carry a stricter policy profile than top-level (e.g. still workdir-confined). Keep the workdir-confinement fence from plan 01 as defense-in-depth even though policy now applies.

**Acceptance:** an in-cell `tool.read()` is denied when `on_tool_policy` denies it (prove canonical policy is enforced); an in-cell call to another loaded extension's tool succeeds (prove the fork is closed); a cell that recursively triggers `eval` is capped at the configured depth.

---

## Phase 4 — abort, timeout, and teardown across the socket

**Files:** `src/tui/src/eval/ws-channel.ts`, `motoko_ext_eval/ws_loopback.ail`, kernel host.

- **Abort:** `/abort` mid-cell must propagate: brain closes the WS / sends a cancel frame → env-server SIGINTs the kernel (plan 01 cancellation) → in-flight `tool-request` awaiting a `tool-result` resolves to a cancellation error rather than hanging. (oh-my-pi's `tool-bridge.ts` resolves bridge calls the instant the signal aborts — port that resolve-on-abort behavior to the WS path.)
- **Timeout:** per-cell timeout still enforced in the env-server; on timeout, send `done {status:"error", cancelled:true}` and tear the kernel down per policy.
- **Connection loss:** if the WS drops, the env-server falls back to local resolvers only if explicitly allowed (otherwise fail the cell loudly — no silent fork).

**Acceptance:** aborting a long-running cell that is mid-`agent()` unwinds within the escalation window without orphaning the kernel; the brain's `runEventLoop` exits cleanly.

---

## Phase 5 — tests & verification

- **Promote the smoke test into a real fixture:** extend `smoke/` into an integration test where the env-server forwards a `tool-request` and the brain answers it through `tool_runtime` (not a canned echo).
- **AILANG:** `ailang check` on `motoko_ext_eval`; `make check_core`.
- **TS unit:** WS channel frame correlation by `reqId`; abort propagation; fallback-disabled-by-default.
- **E2E parity test:** the same cell that worked under C now (a) reaches a second extension's tool in-cell, and (b) is blocked by `on_tool_policy` when it should be — neither is possible under C.
- **Regression:** `make test`, plus confirm `/exec-cell` (HTTP, Design C) still works as the fallback.

**Reproduce the proven capability (baseline before building):**
```bash
cd .agent/research/omp-style-python-eval/smoke
RESULT_FILE=/tmp/ws_smoke_result.txt PORT=8787 bun run ws_server.ts          # terminal 1
ailang run --caps IO,Net,Stream --stream-allow-http --stream-allow-localhost smoke_transmit.ail   # terminal 2
# expect: server prints "SERVER_RECEIVED: reply-from-handler"
```
**Gotcha:** do **not** `pkill -f ws_server.ts` — the pattern self-matches the killing shell (exit 144). Kill by PID.

---

## Sequencing & risks

0. **Gate (do before Phase 3):** the effectful-dispatch-in-handler smoke (Phase 3 ⚠). If it fails, B′'s in-cell `agent()` design changes — surface this before building.
1. Phase 1 (WS channel + redirect) → 2 (brain WS client) → 3 (re-entrant dispatch) → 4 (abort/teardown) → 5 (tests). Phase 3 is the highest-risk, highest-value step.
2. **Risks:**
   - *Effectful dispatch inside the handler (the big one)* — `transmit`-in-handler is proven; an `AI`/`Net`/`Process` tool call inside the handler mid-`runEventLoop` is **not** (Phase 3 ⚠). Gate Phase 3 on the prerequisite smoke; have the deferred-`agent()` fallback ready.
   - *Re-entrancy correctness* — dispatching a tool while inside `eval`'s own `on_tool_handle`. Mitigated by the depth cap (Phase 3) and the fact that `runEventLoop` services it on the same flow (no concurrent mutation of brain state). Validate carefully under DST/trace.
   - *Abort across two processes + a socket* — the trickiest teardown path; port oh-my-pi's resolve-on-abort semantics (Phase 4).
   - *"Swap" underestimation* — ADR-002 consequence: this is a transport **and** dispatch change on both ends, not a one-line substitution. Budget accordingly.
   - *Capability flag drift* — the brain must actually be launched with `Stream` + `--stream-allow-http --stream-allow-localhost`; a missing flag fails only at runtime. Add a startup assertion.
3. **Keep `/exec-cell` (HTTP, C) as the documented fallback** so environments without the WS loopback degrade to the local-fork behavior instead of losing `eval`.
