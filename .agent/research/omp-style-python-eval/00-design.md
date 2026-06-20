# Design: oh-my-pi-style `eval` (persistent Python + JS w/ tool loopback) for Motoko

**Status**: RFC — for discussion
**Scope**: new `motoko-ext-eval` extension, env-server kernel host, loopback bridge
**Grounded against**: oh-my-pi `v15.12.6-70-gcd0000382` (cloned at `oh-my-pi/`),
AILANG **v0.19.1** — the toolchain this repo pins (`ailang.lock`) and the version
the §4 smoke test ran on. Capability facts below were confirmed against the
*installed* 0.19.1 stdlib (`~/.local/share/ailang/std/`), and cross-checked with the
0.25.0 docs over the `ailang-docs` MCP; the relevant `std/process` and `std/stream`
surfaces are unchanged between the two.
**Related**: [README §Extensions](../../../README.md), `src/core/env_client.ail`,
`src/tui/src/env-server.ts`, oh-my-pi `docs/tools/eval.md`

---

## TL;DR

oh-my-pi's headline `eval` runs **persistent Python and a Bun worker**, and either
kernel can **call back into the agent's own tools** (`read`, `search`, `task`) over a
loopback bridge — load a CSV in Python, chart it in JS, never leave the cell.

We can build the same capability in Motoko, but the architecture is **forced to
differ in one structural way**: oh-my-pi is a single async process where kernels and
the tool registry are co-located, so its loopback is a trivial in-process call.
Motoko is split — the tool registry lives in the **AILANG brain**, the long-lived
runtime lives in the **Bun env-server** — and AILANG **cannot host a persistent
bidirectional REPL** (verified below). So:

- **`eval` is still a Motoko extension** (`motoko-ext-eval`): it owns the schema,
  policy, and `on_tool_handle`. This is unchanged from every other extension.
- **The kernels live in the env-server** (Bun), because only it can hold persistent
  subprocesses with bidirectional stdio. The extension *delegates* execution to it,
  exactly as the core bash/AILANG tools already delegate via `env_client.ail`.
- **The loopback** is the only real fork in the design. Two options: serve it
  locally in the env-server (MVP, ships now) or route it back to the canonical
  `tool_runtime` over a WebSocket (faithful, re-entrant).

Recommendation: **build the MVP (Design C), but freeze the frame protocol up front**
so the loopback can be promoted to the faithful design (B′) as a channel swap, not a
rewrite.

---

## 1. What oh-my-pi actually does

The marketing line ("persistent Python and a Bun worker … loopback bridge") hides a
precise two-channel design. From `oh-my-pi/packages/coding-agent/src/eval/`:

- **It is one async TS/Bun process.** The `eval` tool's `execute()` runs in the
  coding-agent itself; there is no separate exec server.
- **Control channel** (`py/kernel.ts`): NDJSON over the Python subprocess's own
  stdin/stdout. Host sends "run this cell"; kernel emits `display`/`result`/`done`
  frames. JS is a persistent **Worker-backed VM** (`js/worker-core.ts`), not a
  subprocess.
- **Loopback channel** (`py/tool-bridge.ts`): a **separate `Bun.serve` on
  `127.0.0.1`** with a bearer token. Python's `tool.<name>()` proxy makes a
  **blocking `urllib` POST** mid-cell; the host services it on the same event loop
  and dispatches against the **real tool registry** (`callSessionTool`). `agent()`
  reuses the same `runSubprocess(...)` path as the `task` tool.
- **State is per-language, keyed by session id** (`python:${id}`, `js:${id}`), and
  persists across cells *and* across tool calls. Subagents inherit the parent's id,
  so they share the same kernels.
- **Helpers** installed in both runtimes: `display`, `read`/`write`/`append`,
  `tool.<name>(args)`, `completion(...)` (stateless model call), `agent(...)` +
  `parallel()`/`pipeline()` (bounded subagent pools, recursion capped at depth 3).

**Why there is no deadlock:** kernels and the tool registry are in the *same async
process*. The cell's blocking loopback request is serviced by the host's own event
loop while it awaits the `done` frame. This is the exact property Motoko does not
have.

---

## 2. The decisive AILANG capability findings (v0.19.1)

The whole design pivots on what the AILANG brain can and cannot do. Verified against
the installed v0.19.1 stdlib, existing Motoko usage, and the §4 smoke test:

| Capability | Reality | Source |
|---|---|---|
| `std/process.spawnProcess` | Long-lived child, **writable stdin only — stdout/stderr discarded** | `std/process` module |
| `std/process.exec` | One-shot; captures output; blocks to completion | `std/process`; used by `/exec-ailang` today |
| `std/stream.asyncExecProcess` | Streams subprocess **stdout, read-only**; subprocess **killed when the event loop exits** | `std/stream` module |
| `std/stream` WebSocket (`connect`/`transmit`/`onEvent`/`runEventLoop`) | **Fully bidirectional**, persistent within a loop | `std/stream` module |
| Event-loop handlers carry effects | **Yes** — `selectEvents` handler calls `println` (IO); enclosing fn is `! {Stream, Process, IO}` | `src/examples/csp_demo/main.ail` |
| `transmit` inside an `onEvent` handler (bidirectional send-from-handler) | **Yes** — type-checks and verified at runtime via WS round-trip | `smoke/smoke_transmit.ail` (this RFC); unblocks Design B′ |
| Brain already spawns a long-lived child | **Yes** (write-only) | `src/core/backend.ail:58` |
| LLM streaming today is synchronous | `callStream` blocks until done; the per-token `onEvent` path was a shim *design choice*, not a capability gap (§4 shows effectful `onEvent` works in 0.19.1) | `src/core/ai_compat.ail:163-179` |

**Hard conclusion:** AILANG cannot host a persistent, bidirectional REPL in the
brain. `spawnProcess` can write but not read; `asyncExecProcess` reads stdout but is
read-only and dies with its event loop. Therefore **kernels must live in the
env-server** (Bun), which holds bidirectional persistent subprocesses trivially —
and oh-my-pi's `kernel.ts` / `worker-core.ts` port almost directly.

**Unlock:** AILANG event-loop handlers *can* carry effects (csp_demo proves IO; the
type system is effect-polymorphic), and WebSocket is bidirectional. That is exactly
what a *re-entrant* loopback would need — see Design B′.

---

## 3. Layering — `eval` is an extension; the env-server is its backend

This was the point of confusion worth nailing down explicitly. "Kernels in the
env-server" does **not** mean eval stops being an extension. Front and backend are
different layers, and Motoko already splits them this way everywhere:

- `exa_search` is an extension whose `on_tool_handle` calls the Exa HTTP API.
- Core bash/AILANG tools delegate to the env-server over HTTP (`env_client.ail` →
  `/exec`, `/exec-ailang`).

`eval` is the same shape:

```
LLM sees "eval" tool
   │
   ▼
motoko-ext-eval   (AILANG extension — schema, on_tool_policy, on_tool_handle)   ← the front
   │  httpPost  (Design C)   /   WebSocket  (Design B′)
   ▼
env-server        (Bun — /exec-cell route, persistent kernels)                  ← the backend (new)
   │  NDJSON over stdin/stdout          ┌──── loopback ────┐
   ▼                                    ▼                  │
python -i  /  Bun Worker  ◄── tool.read() / agent() ───────┘
```

The extension owns:
- `provided_tools: ["eval"]`
- `on_describe_tools` → the `cells` schema (mirror oh-my-pi: `cells: EvalCellInput[]`,
  each `{ language: "py"|"js", code, title?, timeout?, reset? }`)
- `on_tool_policy` → gating (e.g. confine to workdir, deny in restricted modes)
- `on_tool_handle` → opens the eval channel to the env-server and streams results

The env-server gains (new): a `/exec-cell` route + a session→kernel registry
(`python:${id}`, `js:${id}`), display/image/JSON capture, cancellation, idle
cleanup. This is a near-direct port of oh-my-pi `py/kernel.ts`, `py/runner.py`,
`py/prelude.py`, and `js/worker-core.ts`.

---

## 4. The one real fork: where the loopback resolves

`tool.read()` / `agent()` inside a cell has to reach *some* tool implementation.
The boundary between brain (registry) and env-server (kernels) is synchronous HTTP
today, which is where the design splits.

### Design C — MVP, no re-entrancy (recommended first)

- Brain → env-server `/exec-cell` over blocking `httpPost` (reuses the
  `env_client.ail` pattern).
- The loopback (`tool.read/write/search/agent`) is served **locally inside the
  env-server in TS**: `read`=fs, `write`=fs, `search`=ripgrep, `agent`=
  `callSubagentModel` (**already exists** in `env-server.ts`).
- **No deadlock** — the env-server holds the kernels and serves their tool calls
  itself; the brain just waits for the final result.
- **Cost:** the in-cell `tool.*` surface is a **fork** of the real registry. It does
  *not* run other Motoko extensions' tools or their `on_tool_policy`. Acceptable
  because the cell's 90% case (read/write/search/agent) is exactly what the
  env-server can already do natively.

### Design B′ — faithful, re-entrant (later)

- The eval channel is a **WebSocket** (`std/stream connect` + `runEventLoop`).
- env-server runs the cell; when a kernel emits a `tool-request` frame it forwards
  it down the socket. The brain's `onEvent` handler dispatches it through the
  **canonical `tool_runtime`** (real policy + all extensions) and `transmit`s the
  result back. Loop exits on the `done` frame.
- This is the structural mirror of oh-my-pi: a WebSocket replaces oh-my-pi's
  in-process loopback *precisely because* registry and kernels are in different
  processes here.
- **B′ blocker — RESOLVED ✅ (verified on AILANG v0.19.1).** `transmit` *can* be
  called inside an `onEvent` handler during a live `runEventLoop`. A handler closure
  carrying the `Stream` effect both **type-checks** (`ailang check` clean) and
  **works at runtime**: an end-to-end WS round-trip had the handler send
  `"reply-from-handler"` back to a Bun WS server, which received it. See
  `smoke/` (`smoke_transmit.ail` + `ws_server.ts`). Run recipe:
  ```
  ailang run --caps IO,Net,Stream --stream-allow-http --stream-allow-localhost smoke_transmit.ail
  ```
  Notes for B′ implementation:
  - `Stream` is its **own capability** (`--caps ...,Stream`) — not folded into `Net`.
  - `ws://` to localhost needs `--stream-allow-http --stream-allow-localhost`
    (default is `wss://` only); the brain will connect to the env-server over
    loopback, so both flags apply.
  - `run` flags must precede the positional `.ail` file (Go flag parsing stops at the
    first non-flag arg).
  - This removes the only AILANG-capability dependency that stood between Design C
    and Design B′. No upstream feature request needed.

### Comparison

| | C (MVP) | B′ (faithful) |
|---|---|---|
| Channel | `httpPost` (blocking) | WebSocket (bidirectional) |
| Loopback resolves in | env-server (TS) | brain `tool_runtime` (canonical) |
| Re-entrancy / deadlock risk | none | none (event-loop services it) |
| In-cell tools = real registry | no (fork) | yes |
| Honors `on_tool_policy` + other extensions in-cell | no | yes |
| Blocked on AILANG capability | no | none — `transmit`-in-handler verified ✅ (§4) |
| Effort | low | medium (no upstream dependency) |

**The kernel layer is identical in both.** Only the channel and loopback resolution
differ. So C is a strict subset of B′, not a throwaway.

---

## 5. Recommendation & sequencing

1. **Build Design C.** It exercises every genuinely new piece — persistent kernel
   hosting, state across cells, `display()`/image/JSON capture, cancellation,
   timeouts, idle cleanup — all of which are shared with B′.
2. **Freeze the frame protocol now.** Define the cell-run and loopback frames
   (`run` / `display` / `result` / `tool-request` / `tool-result` / `done`) as the
   contract, independent of transport. Promoting C→B′ then swaps `httpPost` for a
   WebSocket and redirects `tool-request` frames to the brain — no kernel changes.
3. ~~**Resolve the B′ blocker in parallel.**~~ **Done** — the
   `connect`+`onEvent`+`transmit`-from-handler smoke test passes (`smoke/`,
   AILANG v0.19.1). B′ is fully unblocked; C→B′ is now purely an engineering swap
   with no language dependency.

---

## 6. Cross-cutting concerns

- **Effect-system hole / Phoenix ethos.** Native Python/Bun kernels run *outside*
  AILANG's capability model — a cell can do arbitrary FS/network I/O the effect row
  would normally gate. For a "self-verifying software" project this is a deliberate
  escape hatch and must be fenced: workdir confinement, a network policy, and
  `on_tool_policy` gating of the `eval` tool itself. Worth an explicit note in the
  extension's README.
- **Reuse already present in env-server.** `callSubagentModel` / `/compose` give us
  a *basic* in-cell `agent()` with little new code — but only the single-call form;
  oh-my-pi's `parallel()` / `pipeline()`, recursion depth cap (3), and spawn-policy
  enforcement are additional work if we want them. `/snapshot` + `/restore` give a
  cancellation/rollback story.
- **Don't reimplement policy in TS.** Even in Design C, gate the env-server loopback
  to a fixed, workdir-confined tool list rather than porting `on_tool_policy` logic —
  keep policy canonical and let B′ deliver true parity.
- **Scaffolding.** Per the README, `ailang init motoko-extension --name
  <org>/motoko_ext_eval --tools "eval" --effects "Net,Stream,Process,FS,Env"` gives
  the package skeleton with all 8 hooks no-op'd.

---

## 7. Open questions

1. ~~**B′ blocker:** is `transmit` callable inside an `onEvent` handler
   mid-`runEventLoop`?~~ **Resolved — yes** (see §4 and `smoke/`).
2. **JS runtime:** Bun `Worker` (oh-my-pi's choice) vs a `vm` context — which fits
   the env-server process model and our cancellation story best?
3. **Python availability:** gate the `py` cell on an availability probe (oh-my-pi
   does `<python> -c ...`); how does the install script guarantee a usable `python3`?
4. **Session id source:** what does the eval session id key off in Motoko, and do
   `compose`/subagents need to inherit it to share kernels (as oh-my-pi does)?
5. **Output limits:** adopt oh-my-pi's caps (50KB truncation window, 30s default
   per-cell timeout, artifact spill) or set our own?
