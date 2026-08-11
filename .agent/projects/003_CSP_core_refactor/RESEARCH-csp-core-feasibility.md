# RESEARCH: Can Motoko's core be rewritten as a CSP architecture?

Date: 2026-06-30
Status: Research — findings + verified capability proofs (no decision yet)
Pinned binary: AILANG **v0.26.0** (commit `3b52a24`)
Toolchain: `ailang.lock` → v0.26.0; Bun 1.3.14
Relates to:
- `.agent/research/omp-style-python-eval/` (the prior spike that probed the same substrate)
- `tools/code-graph/AGENTS.md` (how the architecture facts below were derived)
- AILANG docs MCP (`.mcp.json` → `https://mcp.ailang.sunholo.com/mcp/`)
Smoke evidence (this project): `./smoke/` (`smoke_net_in_handler.ail` + `ws_net_server.ts`,
`smoke_ai_in_handler.ail` + `ws_server.ts`, `smoke_ai_toplevel.ail`, `smoke_cognition_msg.ail`).
Prior substrate proofs remain in `.agent/research/omp-style-python-eval/smoke/`
(`smoke_transmit.ail`, `smoke_deferred_dispatch.ail`).

---

## TL;DR

A CSP rewrite of Motoko's core is **feasible, and the load-bearing language capabilities are
now verified on the current toolchain (v0.26.0)**. "CSP in AILANG" resolves into three distinct
things — only the first is shipped, and it is enough to start:

1. **Shipped today — `std/stream` event-loop CSP** (`Stream` effect, since v0.7.0): async event
   *sources* (subprocess, stdin, WebSocket, SSE/NDJSON) multiplexed by a **deterministic,
   prioritized `selectEvents` "select"** into one cooperative handler that can `transmit` back.
   This is select/event-loop CSP. There is a working demo: `src/examples/csp_demo/main.ail`.
2. **Planned for v1.0.0 — `m-csp-session-types`**: typed channels + `send`/`recv`/`spawn` +
   compile-time **session types** (dual-protocol checking, deadlock/protocol violations caught
   statically), Go-backed **cooperative deterministic** scheduler (replayable). Not shipped.
3. **Orthogonal — `std/agent`** (`m-agent-orchestration`, planned): a *synchronous*
   `invoke(AgentTask) -> Result` governance wrapper for spawning sub-agents. Explicitly **not**
   CSP ("no agent-to-agent communication in AILANG — use a coordinator"). Do **not** conflate it
   with the CSP work.

**A faithful, canonical-dispatch, re-entrant event loop already runs in production** —
`packages/motoko_scratchpad/ws_loopback.ail` (the shipped B′ loopback; see §4). It dispatches
real tool calls through the core `dispatch_tool_envelope` over a WebSocket, using the
**deferred-yield** discipline (capture in handler → exit loop → dispatch effectfully in the
enclosing function → `transmit` → re-enter). Separately, **the historically-unverified
alternative — running a `Net`/`AI`-effect dispatch *inside* the live handler — is now also
CLOSED on v0.26.0** (Capability Ledger, §5). So both shapes work; **production deliberately chose
deferred**, and there is a robustness reason to keep doing so (§6, gotcha 2). Inline dispatch is
an option, not a requirement — and not the one the only shipped precedent took.

---

## 1. What CSP means against AILANG (precise)

| Layer | Shipped? | Primitives | Effect | Notes |
|---|---|---|---|---|
| `std/stream` event loop | ✅ v0.7.0+ | `selectEvents`, `onEvent`/`runEventLoop`, `asyncExecProcess`, `asyncReadStdinLines`, `sourceOfConn`, `connect`/`transmit`/`disconnect`, `ssePost`/`sseConnect`/`ndjsonPost` | `Stream` | Sources are **I/O-backed**, not arbitrary AILANG functions. Deterministic: priority-ordered, same-priority round-robin. Handler `(StreamEvent)->bool` (false = stop). |
| `std/cognition` mailbox fabric | ⚠️ **API shipped v0.21.x, not usable in Motoko's CLI** | `sendMsg`/`recvMsg`, `sendMsgResult`/`recvMsgResult`, `subscribeMsg`/`drain` | `Msg`, `Cog` (new) | Actor/mailbox message passing (named mailboxes, Lamport clocks, blocking `recvMsg`). **But:** native CLI returns `Err(NO_HANDLER)` — transport is **browser/WASM-wired** (`cmd/wasm/effects.go`); only a `StubMsgHandler` exists natively. **And** `Msg`/`Cog` are **outside Motoko's effect ceiling** (`ailang.toml`). Verified §8/smoke. |
| `m-csp-session-types` | ❌ planned v1.0/1.1 | `newChan[Protocol]`, `send`/`recv`/`close`, `spawn`; `protocol P = …` | `Chan` (new) | In-language peers, static session-type protocol checking, dual computed by compiler. Binary sessions only (multiparty deferred). Go-backed cooperative scheduler, replayable. (`std/cognition` reserves `sendMsg`/`recvMsg` names *because* `send`/`recv` are held for this.) |
| `std/agent` | ❌ planned | `invoke`, `invokeStreaming` | `AI`-ish | **Not CSP.** Synchronous sub-agent governance (budgets, tool allowlists, `resumeSessionId`). |

AILANG compiler tree confirms (3, `m-csp-session-types`) is real-but-stubbed: `internal/channels/
(todo)`, `internal/session/ (todo)`; implementation-status lists "csp concurrency (deferred)".
**So "channels" splits two ways:** *typed in-language session channels* (`send`/`recv`/`Chan`) are
**not shipped** (v1.0/1.1), while *mailbox message passing* (`std/cognition`, `Msg`) is a **shipped
API but has no native-CLI transport and is out-of-ceiling** for Motoko — usable today only in the
browser/WASM Cognitive-OS runtime or with a stub. AILANG effects are
**capability-permission tracking**, not algebraic effect handlers, so typed channels can't be built
in-language; they need the host-backed `Chan` effect.

---

## 2. Motoko core architecture (from `code-graph`, core profile)

Entry chain (exact-ish via `invokes`):
```
supervisor#main → rpc#{main,run_with_config} → agent_loop_v2#run_v2_with_conversation
  → conversation_loop_v2 → run_v2 → loop_v2          (the sequential step loop)
```
- 24 modules / 378 funcs. Weight-bearing: `tool_runtime` (83, `FS`/`Process`), `agent_loop_v2`
  (69, reaches every effect), `config` (48), `ext/runtime` (43, the extension system).
- `loop_v2` per step: pre-step hook → **compaction** → AI call → response-intercept hook → tool
  dispatch (`dispatch_calls` → `tool_dispatch_adapter` → `tool_runtime`) → solver-candidate hook →
  DP7 gate → cost/usage → event/stream emit.
- Effects localize cleanly to leaves: `Net`→`env_client`/`backend`, `FS`/`Process`→`tool_runtime`,
  `SharedMem`→`cache`, `AI`→`ai_compat`.
- **Concurrency model today:** sequential effectful loop, driven by a TS host (`ts_host` roots:
  `supervisor`, `rpc`, `config`, `env_client`, `parse`, `version`); the backend is a **separate OS
  process** (`backend#start_or_connect_backend` → `std/process.spawnProcess`); cross-agent state is
  a **`SharedMem` blackboard** (`cache.ail` keys like `core:traj:<hash>`).

Caveat (per `code-graph/AGENTS.md`): call/effect edges are **source-parsed approximations**, and
the graph was **STALE** at read time. Re-run `tools/code-graph/extract.sh` before trusting counts.

---

## 3. How a CSP core would map onto the current core

| Current construct | CSP form |
|---|---|
| Tool round-trip `ToolCallEnvelope → ToolResultEnvelope` (`tool_contract`) | session-typed protocol `ToolCall -> !ToolResult -> end`, statically enforced (needs v1.0.0) |
| RPC host↔core (`rpc.ail`) | a typed channel session instead of convention |
| 9 extension hooks (`ext/runtime` dispatch_*) | each hook a typed sub-protocol |
| `loop_v2` step pipeline | `selectEvents([tools, control], handler)` — multiplex async tool output + control/cancel *around* a blocking `std/ai` step (LLM is **not** an in-brain source in Phase 1 — see §5 XOR) |
| LLM call (`ai_compat`) | stays a **blocking `std/ai.stepWithStream`** (provider abstraction preserved). Raw `ssePost`/`ndjsonPost` *would* give a source but loses `std/ai` (§5 XOR); true LLM-source = peer process (§5 option B) |
| Tool subprocess (`tool_runtime`, sync `Process`) | `asyncExecProcess` source — streamed/concurrent |
| **`SharedMem` blackboard** (`cache`, `ext/runtime`) | **the philosophical inversion** — replace shared KV with messages. Two candidate substrates, **both gated today:** (a) `std/cognition` mailboxes (`Msg`) — shipped API but no native-CLI handler + out-of-ceiling (§1, §8); (b) typed `Chan` channels — not shipped (v1.0/1.1). `std/stream` gives WebSocket channels but no inter-*function* channels. |

**Two-phase feasibility:**
- **Phase 1 (today, v0.26.0):** restructure `loop_v2` around `selectEvents`. The substrate exists,
  the in-handler effectful-dispatch question is answered (§5), **and a faithful canonical-dispatch
  re-entrant loop already ships** (`packages/motoko_scratchpad/ws_loopback.ail`, via deferred
  dispatch — §4). Phase 1 generalizes existing, working code rather than inventing a loop — see
  §11 for the concrete mechanism (CSP on socket channels + coordinator discipline, no typed `Chan`).
- **Phase 2 (v1.0/1.1):** session-typed channels for the internal protocols + `spawn` for real
  in-language peer processes (solvers/sub-agents) + the SharedMem→message inversion (via typed
  `Chan`, or via `std/cognition` mailboxes *if* a native Msg handler is wired and the effect ceiling
  is widened — see §1/§8).

---

## 4. Shipped precedent — the faithful re-entrant loop already runs (deferred dispatch)

`packages/motoko_scratchpad/ws_loopback.ail` is the shipped implementation of Design B′ (the
package was `motoko_ext_eval` in the compile cache; renamed to `motoko_scratchpad`, now serving
`py`/`js`/`ail`/`lean` cells). It is **feature-flagged** behind `MOTOKO_SCRATCHPAD_WS_LOOPBACK=1`
and **defaults off** — without the flag, `exec_scratchpad_cell_ws` falls back to plain-HTTP
Design C (`exec_scratchpad_cell`). When on, it is the real thing: in-cell tool calls dispatch
through the **canonical core `dispatch_tool_envelope`** over a WebSocket.

**It uses the DEFERRED pattern, not in-handler dispatch** — even though in-handler is now proven
possible (§5):

- `collect_one` (l.154): the `onEvent` handler is **`! {Stream, FS}`** — it only `decode`s the
  frame, `writeFile`s a `tool-request` to a path, and returns **`false` to exit `runEventLoop`**.
  No effects beyond FS happen inside the handler.
- `dispatch_deferred_request` (l.183): **`! {IO, Clock, FS, Process, AI, Env, Net, SharedMem,
  Stream}`** — calls `dispatch_tool_envelope(rt, ctx, …)` **outside** the handler.
- `loop_until_done` (l.194): the bounded (`remaining`, seeded **32**) yield → dispatch → `transmit`
  → re-enter cycle. This is the deterministic, canonical-dispatch, re-entrant event-loop template a
  CSP `loop_v2` would generalize.

**Why deferred (the production verdict).** Two reasons, both independently confirmed this session:
(1) when this shipped (v0.19.1/v0.24.2) in-handler `AI`/`Net` dispatch was unverified; (2) deferred
dispatch runs effects in the enclosing sequential context, so **errors surface** — handler-side
effect errors exit 0 silently (§6, gotcha 2). So inline dispatch being *possible* does not make it
*preferable*: the only shipped precedent chose deferred, and the robustness argument stands.

**Takeaway for 003:** the strongest feasibility evidence is not the in-handler smoke — it is that a
**faithful, canonical-dispatch, deterministic, re-entrant `runEventLoop` already runs in
production**. Phase 1 of a CSP core is "generalize `loop_until_done`," not "invent a loop."

---

## 5. Capability ledger — verified THIS session, all on v0.26.0

Question settled: **can an effectful call run *inside* a live `runEventLoop`/`selectEvents`
handler and transmit its result back on the same socket?**

| Capability, inside a live handler | Status | Evidence |
|---|---|---|
| `transmit` (Stream) | ✅ | `smoke_transmit.ail` (prior, v0.19.1; design assumed unchanged) |
| `IO` / `Process` | ✅ | `src/examples/csp_demo/main.ail` |
| **`Net`** (`httpGet`, real network round-trip) | ✅ **new** | `smoke_net_in_handler.ail` + `ws_net_server.ts` |
| **`AI`** (`std/ai.call`, stub handler) | ✅ **new** | `smoke_ai_in_handler.ail` (+ `smoke_ai_toplevel.ail` control) |
| Real networked model call (`-ai <model>` + keys) | ⚠️ unrun (no creds) | = proven AI handler ∘ proven Net transport |

The B′ Phase-3 gate is **closed by composition**: the only unrun piece is a literal provider call,
which is just the (proven) AI-handler dispatch over the (proven) Net transport. With keys, the
`-ai claude-haiku-4-5` path would work.

### Reproduce
```bash
cd .agent/projects/003_CSP_core_refactor/smoke

# Net inside handler (real network round-trip)
RESULT_FILE=/tmp/ws_net_result.txt PORT=8790 bun run ws_net_server.ts        # terminal 1
ailang run --caps IO,Net,Stream --net-allow-http --net-allow-localhost \
  --stream-allow-http --stream-allow-localhost smoke_net_in_handler.ail      # terminal 2
# expect: SERVER_RECEIVED: net-in-handler-OK-7f3a

# AI effect inside handler (stub handler; no creds)
RESULT_FILE=/tmp/ws_ai_result.txt PORT=8791 bun run ws_server.ts             # terminal 1
ailang run --caps IO,Stream,AI -ai-stub \
  --stream-allow-http --stream-allow-localhost smoke_ai_in_handler.ail       # terminal 2
# expect: SERVER_RECEIVED: AI_REPLY::{"kind":"Wait"}
```
Gotcha: do **not** `pkill -f ws_server.ts` / `pkill -f PORT=8791` — the pattern self-matches the
killing shell (exit 144). Kill by PID.

### LLM-as-`selectEvents`-source: a verified XOR (keeps `std/ai` **XOR** multiplexes)

Investigated this session (installed stdlib + `ai_compat.callStreamResult`). **On 0.26.0 the LLM
call cannot be a `selectEvents` source *and* keep `std/ai`'s provider abstraction — they are
mutually exclusive paths:**
- `std/ai.stepWithStream(model, msgs, tools, cache, on_chunk: (StreamChunk)->() ! {IO}) ->
  Result[StepResult, AIError] ! {AI}` is a **self-contained blocking call** that owns its internal
  streaming loop and yields **no `StreamSource`**. Its `on_chunk` is `! {IO}` only (can't `transmit`,
  dispatch, or poll other sources) and returns `()` (no mid-stream cancel).
- The only path that yields a source — `ssePost(url,body,headers)` + `sourceOfConn` — is **raw
  SSE**, losing `std/ai`: model routing (`model_for_provider`/OpenRouter), auth, per-provider
  shapes, tool-call deltas, `StepResult` usage/cost, prompt caching, thinking deltas.

**Consequence for the ADR (refines Phase 1, doesn't break it):** do **not** claim in-brain
LLM-as-source for Phase 1. The model call stays a **blocking `std/ai` step** (with `on_chunk`
rendering, as today), and `selectEvents` multiplexes **tools + control + cancel** *around* it — which
matches the real control flow: the model call is the blocking `dispatch_step(provider, …)` inside
`loop_v2`'s per-step recursion (§12), with `selectEvents` wrapping the *tool* phase around it.
(Correction: `loop_v2` **does** carry `AI` via the `StepProvider` seam — `agent_loop_v2.ail:1125`;
code-graph missed that edge because `dispatch_step` is a provider-record call.) Three ways to get a
true LLM source later:

| Option | Keeps `std/ai`? | Cost |
|---|---|---|
| **A.** blocking step + multiplex tools/control (Phase 1) | ✅ | none — status quo for the model call |
| **B.** move the `std/ai` call to a **peer process** (env-server/LLM proc); stream tokens to the brain over WS; brain consumes via `sourceOfConn` | ✅ (runs in peer) | extra process + socket hop — the *genuinely CSP* answer (provider = peer behind a channel) |
| **C.** upstream: a `std/ai` → `StreamSource` adapter | ✅ | AILANG-gated (feature request) |

---

## 6. Two operational gotchas (load-bearing for a CSP core)

1. **The `AI` effect needs TWO runtime grants.** `-ai <model>` / `-ai-stub` binds the *handler*;
   `--caps AI` separately grants the *capability* — and `ailang run --help`'s example cap list
   (`IO,FS,Net,Env,Process`) **omits `AI`**, which is a trap. A CSP core's brain process must launch
   with **both** `--caps …,AI` and a model/stub. Add a startup assertion (mirrors the existing
   `Stream` + `--stream-allow-*` note in the B′ plan).
2. **Effect failures inside a stream handler do NOT crash the process.** A missing capability (or any
   effect error) inside the handler aborts the handler mid-way, `runEventLoop` returns, and `main`
   exits **0 with nothing on stderr**. (Observed directly: the AI smoke without `--caps AI` printed
   the pre-call line, skipped the post-call lines, and exited 0.) **Implication:** handler-side
   errors must be surfaced explicitly (a `done{status:error}` frame / result sentinel) — you cannot
   rely on process exit. The **deferred-dispatch** pattern (effects in the enclosing sequential
   context) *does* surface errors (the top-level AI control returned exit 1 with a clear message).
   This is exactly why the shipped `motoko_scratchpad/ws_loopback.ail` (§4) dispatches deferred:
   inline dispatch is possible, but deferred is the more robust default and the one production chose.

---

## 7. Hard constraints (do not design around these)

- **No persistent bidirectional subprocess/REPL in the AILANG brain** (verified prior, surfaces
  unchanged): `spawnProcess` = write-only stdin (stdout/stderr discarded); `asyncExecProcess` =
  read-only stdout + **dies when the event loop exits**. Only the **WebSocket** is fully
  bidirectional + persistent. ⇒ CSP "peers" cannot be in-brain subprocesses today; they are external
  (env-server over WS) until v1.0.0 `spawn`/channels.
- **Shipped `std/stream` has no inter-function channels** — sources must be I/O-backed. The
  SharedMem→channel inversion waits for v1.0.0.
- **Cooperative, single-loop** — concurrency/multiplexing, not CPU parallelism (fine; Motoko's work
  is I/O-bound, and real parallelism already comes from the separate backend OS process).
- **Binary sessions only** in v1 of `m-csp-session-types` — multi-agent fan-out needs composition or
  waits for multiparty.

---

## 8. Version provenance (drift to watch)

| Fact | Verified against |
|---|---|
| `selectEvents`/`asyncExecProcess`/WebSocket surfaces; `transmit`-in-handler | v0.19.1 (omp spike), surfaces asserted unchanged through 0.25 |
| **`Net`-in-handler, `AI`-in-handler, `ailang check` effect-poly handler** | **v0.26.0 (this doc)** |
| Shipped B′ deferred-dispatch loopback (canonical `dispatch_tool_envelope`) | `packages/motoko_scratchpad/ws_loopback.ail` (read 2026-06-30) |
| `std/process`/`std/stream`/`std/net`/`std/ai` module surfaces | latest docs MCP (queried 2026-06-30) |
| CSP/session-types roadmap placement (v1.0/1.1), "deferred" status | docs MCP roadmap + implementation-status (2026-06-30) |
| **`std/cognition` mailbox (`Msg`/`Cog`) shipped but `NO_HANDLER` in native CLI; transport is browser/WASM (`cmd/wasm/effects.go`)** | **v0.26.0 installed stdlib + `smoke/smoke_cognition_msg.ail` (2026-06-30)** |
| **Motoko effect ceiling = `IO,Env,AI,Net,FS,Process,SharedMem,Clock,Stream,SharedIndex,Rand,Trace`** (excludes `Msg`/`Cog`) | **`ailang.toml:47`** |
| **Correction:** MCP `effects_catalog` was stale — missed `Msg`, `Cog`, `SharedIndex`, `Rand`, `Trace`; installed stdlib is ground truth | installed `~/.local/share/ailang/std` (2026-06-30) |

---

## 9. CSP × DST — would CSP improve Deterministic Simulation Testing?

Cross-ref: [`../001_DST/ADR-001-deterministic-simulation-testing-architecture.md`](../001_DST/ADR-001-deterministic-simulation-testing-architecture.md).
**Yes — and specifically on the two problems that ADR flags as unresolved (R7 effect
satisfaction, R8 the recorder self-contradiction).** DST's premise is "failures occur across
boundaries → record boundary traces → assert invariants." CSP's premise is "all communication is
explicit messages over channels." Same seam, opposite sides: DST wants every boundary observable
and controllable; CSP makes every boundary a channel.

**Mechanism.** Today boundaries are *implicit* effects (`std/ai.step`, tool exec, env read), so
observing/controlling them needs either a scripted stub (a *fork* of the real path, e.g.
`run_v2_with_stub`) or effect-handler mocking AILANG lacks (R7). As channels, the same boundaries
give DST three things structurally:
- **record = tee the channel** (production processes byte-identical with/without the recorder);
- **fake = swap the peer** (run the *real* `loop_v2`, connect its provider channel to a scripted
  provider process);
- **replay = the scheduler** (planned `Chan` scheduler is cooperative/deterministic/replayable;
  shipped `selectEvents` is deterministic — message order reproducible by construction).

| ADR-001 item | How CSP helps |
|---|---|
| **R8** — recorder "must not change prod behavior" vs "seams must be added" (self-contradiction) | **Dissolved** — recorder is a process on the channel, not a seam in `dispatch_step`. |
| **R7** — satisfy `{Env,FS,Net}` deterministically without effect mocking (the hardest part) | **Sidestepped** — substitute the channel *peer*, not the effect handler. |
| Decision #2 — "drive real production transition code where feasible" | Maximized — drive the **real** `run_v2`/`loop_v2`, swap only peers (vs. the `run_v2_with_stub` fork that can drift). |
| Canonical trace events (`provider_call_prepared`, `provider_result`, `tool_policy_decision`, …) | These **are** the channel messages; the normalized trace = serialized channel log; recorder = a logging process. |
| Open question — virtual time for `std/clock` | A deterministic scheduler *is* the clock; `Clock` becomes a channel to a time process you advance. |

**Three-way complementarity** (extends the ADR's Z3-vs-DST framing). Session types (Phase 2) add a
third axis — protocol/shape properties checked at compile time:
- `on_pre_step never receives system messages` → a **type guarantee** if that channel's message
  type excludes `SystemMsg`; step/turn ordering → encoded in the session protocol. **Static.** ✅
- Value invariants stay runtime/Z3: `tool-call IDs survive elision`, `payload contains pinned
  system prefix`, `last_input_tokens carries forward`, the 60/75/85 tier arithmetic. ❌
- So: **Z3 = pure value props · DST-runtime = trace value props · session types = protocol/shape
  props.** A slice of today's DST scenarios become free static checks; the rest stay runtime but
  cheaper to observe.

**Honest limits.**
- **DST Layer 2 (harness boundary)** — child env prep, sandbox paths, spawn args, env forwarding —
  is TS-host + OS-process, *before* AILANG starts. CSP in the core does nothing for it.
- **Biggest wins are Phase 2 (v1.0.0)** — in-language channel interposition + session-typed
  invariants. *But* a real partial win exists **today**: the shipped `ws_loopback.ail` frames
  (`run`/`tool-request`/`tool-result`/`done`) and the env-server `httpPost` boundary are already
  message boundaries a recorder can tee, and the LLM channel can be pointed at a scripted local
  server on current `std/stream`.
- **DST Layer 0** (pure helpers) is unaffected — no boundaries.
- You would not rewrite to CSP *for* DST, but DST is a strong *additional* argument: it attacks
  exactly R7 and R8, which the DST ADR could not cleanly resolve.

## 10. CSP × the extension system

Cross-ref: §4 (the `motoko_scratchpad` precedent), §9 (DST). The whole tool path runs through
`src/core/ext/runtime.ail`'s hooks, so CSP must coexist with extensions. The boundary that matters
is **already CSP-shaped**, so Phase 1 needs no ABI change and Phase 2 formalizes what extensions
already drift toward.

**What an extension is today.** A package registers an `ExtensionHooks` record — ordered,
synchronous closures the loop folds over: `{ id, provided_tools, on_describe_tools,
on_build_system_prompt, on_budget_plan, on_pre_step, on_tool_policy, on_tool_handle,
on_response_intercept, on_solver_candidate }`. Three load-bearing facts:
- **Returns are already messages:** `on_tool_handle -> Handled(ToolResultEnvelope) | Delegate`,
  `on_tool_policy -> Allow | Deny | NoOpinion | Pending`, `on_pre_step -> PassThrough | Compacted`.
- **Dispatch is an ordered fold + short-circuit:** `dispatch_tool_handle` walks `registry.hooks`
  in `parse_core_ext_order`; `Delegate` → next, `Handled` → stop.
- **Effectful hooks carry the ENTIRE effect row** `{IO,Process,FS,AI,Env,Net,SharedMem,Clock,
  Stream}` — a third-party hook runs in the core process with ambient access to everything (the
  README's "extensions outside the capability model" concern).

**Phase 1 (today, no ABI break).** The `selectEvents` loop calls `dispatch_tool_handle`
synchronously at the dispatch point — exactly as shipped `ws_loopback.ail` does
(`dispatch_tool_envelope → dispatch_tool_handle`). Extensions are unchanged. And because the hook
effect row already includes `Stream`, an extension can opt into CSP *internally*:
`motoko_scratchpad`'s `on_tool_handle` already opens a WebSocket and runs its own `runEventLoop` to
its env-server kernels (§4). So today is already a hybrid — **light hook in-AILANG, heavy execution
in a peer process over a channel.**

**Phase 1 per-package change: none.** The repo's extension packages with AILANG hooks are
`motoko-ext-context-mode` and `motoko_scratchpad` (`motoko-ext-autoresearch` has no `.ail` hooks;
ABI types live in `pkg/sunholo/motoko_ext_abi`). None need code changes in Phase 1 because: (a) the
hook signatures **already declare `Stream`** (e.g. `context-mode/register.ail:71,74`), so a loop
carrying the `Stream` effect invokes them unchanged; (b) dispatch is the same `parse_core_ext_order`
fold; (c) both packages' hooks **block** (`context-mode` `on_tool_handle` = `exec`; `scratchpad`
`on_tool_handle` = `exec_scratchpad_cell` httpPost) and blocking is safe under deferred dispatch (the
loop has already yielded). The Phase-1 work is **core-side**: carry `Stream` at hook call sites, and
use **deferred dispatch** so a hook that hosts its own `runEventLoop` (`scratchpad`'s flagged
`ws_loopback`) is never entered inside the core's handler (no nested loops).

| Package | Real hook work | Phase-1 required | Optional opt-in |
|---|---|---|---|
| `motoko-ext-context-mode` | prompt/budget/policy + `on_tool_handle` = blocking `exec` | **none** | cancellation for its `exec` |
| `motoko_scratchpad` | `on_tool_handle` = blocking `exec_scratchpad_cell`; `ws_loopback` = flagged WS re-entrant | **none** | streaming cell output (additive ABI); dedup its loop vs the core's |
| `motoko-ext-autoresearch` | — (no `.ail` hooks) | n/a | — |

The optional items are **additive, not migration**: a streaming-result hook variant (one change in
`motoko_ext_abi`, consumed only by `scratchpad`) and cooperative cancellation. Neither is required to
keep existing extensions working.

**Phase 2 (v1.0.0 `Chan` + session types).** Hooks become typed channel protocols; each extension
a peer process.

| Today (closure) | CSP (channel protocol) |
|---|---|
| `on_tool_policy : (Ctx,Call) -> Decision` | `protocol Policy = send (Ctx,Call) -> recv Decision -> end` |
| `on_tool_handle : … -> Handled \| Delegate` | `protocol Tool = send (Ctx,Call) -> recv (Handled \| Delegate) -> end` |
| ordered fold + short-circuit | a **coordinator** querying extension processes in registry order, stopping on `Handled`/`Deny` |
| `registry_generated` static load | load **+ `spawn`** the extension process, establish its channel |

Wins specific to extensions: **capability containment** (an extension runs scoped and talks only
over its channel — the broad effect row becomes the protocol, real sandboxing of third-party
packages); **session-typed hook contracts** (e.g. `on_pre_step never receives SystemMsg` becomes a
type — ties to §9 DST static invariants); **independent failure** (a crashing/looping extension is
contained); **observable hook boundaries** (the seam ADR-001 flags as a failure class).

**Honest constraints.**
- **Serialization:** envelope hooks are easy (`call_to_json`/`result_to_model_json` exist);
  `[Msg]`-based hooks (`on_pre_step`, `ExtCtx.history_slice`) are heavier to send across a channel.
- **Binary sessions only (v1):** N extensions = N binary sessions a coordinator multiplexes —
  matches the ordered registry, a fit not a fight.
- **Loader change:** `parse_core_ext_order` must also spawn + handshake
  (`provided_tools`/`on_describe_tools` = the handshake); gated on v1.0.0 `spawn`.
- **Latency:** a round-trip per hook per step; cheap hooks (`on_tool_policy`: `IO,Clock`) aren't
  worth processifying.

**Realistic shape — a gradient, not a flip.** Keep cheap/pure hooks in-process; processify the
heavy, stateful, untrusted ones (the full-effect-row hooks). That is exactly the split
`motoko_scratchpad` already embodies. CSP doesn't replace the extension system — it formalizes the
in-process-hook / peer-process-execution split extensions already drift toward, and (Phase 2) makes
the hook boundary typed, capability-scoped, and observable.

## 11. Implementing CSP on 0.26.0 without typed channels

The reframe: Motoko is **not** without channels — it lacks *typed in-language* channels
(`Chan`/`send`/`recv`/session types, v1.0/1.1). It already has transport-backed channels. "CSP
without channels" = use the channels you have + supply the rest as discipline. Three layers.

**1. The OS-process boundaries already ARE channels.** A channel is two endpoints exchanging typed
messages with no shared state — which Motoko's process boundaries already are:

| CSP channel | Shipped mechanism (0.26.0) |
|---|---|
| brain ↔ env-server | **WebSocket** (`connect`/`transmit`/`onEvent`/`runEventLoop`) — the `ws_loopback.ail` precedent (§4) |
| brain ↔ LLM provider | **blocking `std/ai` step** in Phase 1 (keeps provider abstraction). Raw `ssePost`/`ndjsonPost` is a source but loses `std/ai` (§5 XOR); LLM-as-source = peer process (§5 B) |
| brain ↔ tools | `asyncExecProcess` source / dispatch envelopes |
| brain ↔ backend | `spawnProcess` + `httpGet`/`httpPost` |

Processes (brain, env-server, backend, kernels) are already OS-isolated; `selectEvents` is the
`select`. So **between OS processes you have full CSP today** — sockets are the channels.

**2. In-*language* "processes": CSP as discipline, not concurrency.** Two AILANG functions can't
`send`/`recv` in-process without a socket or shared memory. Substitute the **coordinator pattern**
(`loop_v2` already half-is one):
- one owner of mutable state (the coordinator); sub-processes are sequential pure-ish functions;
- communication = explicit message *values* threaded through the coordinator, never shared
  mutation — extension hooks already do this (`Handled | Delegate`, `PassThrough | Compacted`);
- **no `SharedMem` for coordination** (the very thing CSP drops) — keep it for genuine cache only.

This buys CSP's *reasoning* (isolation, communicate-don't-share, compositional) without its
*concurrency* (cooperative/sequential, loop-scheduled). Fine for I/O-bound work; real parallelism
still comes from the separate OS processes.

**3. Protocols as runtime-checked frames (poor-man's session types).** Static sessions aren't
shipped; encode the protocol as **typed frame ADTs + a runtime validator** (`ws_loopback`'s
`run`/`tool-request`/`tool-result`/`done` already does this):
- message sum types (`type Frame = Run(..) | ToolRequest(..) | ToolResult(..) | Done(..)`);
- validate transitions at runtime (handler `match`es frame type, rejects out-of-protocol);
- optionally **Z3-contract the pure transition function** — the §9 three-way split (Z3 = value
  props · runtime = trace props · session types = shape props) covers what static sessions would,
  minus compile-time totality.

**What you give up (state it in the ADR):** no static deadlock/protocol checking (runtime/Z3 only);
no cheap `spawn` of arbitrary functions as peers (in-language peers are sequential-cooperative; true
peers are OS processes or wait for v1.0/1.1); no compiler-computed protocol dual (you hand-write and
keep both ends in sync).

**One-line strategy.** Implement **CSP-the-architecture** (isolated sequential processes, socket
channels, deterministic `selectEvents`, no shared mutable state, runtime-checked frame protocols)
**without CSP-the-language-feature.** Concretely: generalize `ws_loopback.ail`'s `loop_until_done`
into the core loop (§4); treat the env-server/LLM/tool sockets as channels; impose the
coordinator-threads-state discipline in-process; encode protocols as frame ADTs (+ Z3 where pure).
**Phase 2 upgrades these hand-rolled frame protocols to compiler-checked session-typed channels —
a tightening, not a rewrite.** This answers the ADR's "refactor or rewrite?" → refactor: the
channels and the loop template already exist.

## 12. Phase-1 sketch: `loop_v2` on `selectEvents` (the "refactor not rewrite" evidence)

Grounded in the real source (`agent_loop_v2.ail`: `run_v2:1494`, `loop_v2:1107`, `dispatch_calls:731`).

**What's already CSP-shaped (the good news).** `loop_v2` is a **tail-recursive coordinator** that
threads all state as explicit values — `msgs, step_idx, step_budget, totals, provider` — and
recurses; **no shared mutable loop state**. That already satisfies §11's coordinator discipline. It
has exactly two channels:
- **model channel:** `dispatch_step(provider, model, msgs, rt, on_chunk) -> {result, next_provider}`
  — blocking `std/ai` step behind the `StepProvider` seam (also the DST recorder seam). `on_chunk`
  (`! {IO}`) renders tokens. Stays blocking (§5 XOR).
- **tool channel:** `dispatch_calls(rt, ctx, calls, …) -> [Message]` — today a **sequential fold**
  (`call :: rest`), one tool at a time.

`run_v2` is just setup (build provider/msgs/`zero_totals()`, trace span, call `loop_v2`).

**The localized change.** Keep the entire recursion, the model call, all four hook points
(`dispatch_pre_step`, `dispatch_response_intercept`, `dispatch_solver_candidate`, plus
`dispatch_tool_policy/handle` inside dispatch), compaction, cost/usage, events — **unchanged**. The
CSP increment replaces **one function**: `dispatch_calls` → `run_tool_select`, multiplexing tools +
a control source via `selectEvents`.

```text
loop_v2(state{rt, msgs, step_idx, step_budget, totals, provider, control, …}):
  guards(step_budget, cost_cap)                         -- unchanged
  m1 = dispatch_pre_step(rt, ctx, msgs)                 -- unchanged (ext compaction)
  m2 = compact_step_with_limit(m1, model)               -- unchanged
  {result, provider'} = dispatch_step(provider, m2, on_chunk)   -- BLOCKING model step (§5 XOR)
  m3 = m2 ++ [assistant_of(result)] ; totals' = accumulate(totals, result)
  match dispatch_response_intercept(rt, ctx, result.content):   -- unchanged
    InterceptHandled(env) -> recurse with env appended
    NoIntercept:
      if result.finish_reason != "tool_calls":
        dispatch_solver_candidate(…) -> Accept(done) | Continue(recurse) | NoDecision(done)  -- unchanged
      else:
        tool_msgs = run_tool_select(rt, ctx, result.tool_calls, control)   -- <== THE ONLY CHANGE
        recurse loop_v2(state{ msgs: m3 ++ tool_msgs, step_idx+1, step_budget-1, totals', provider' })

run_tool_select(rt, ctx, calls, control):                  -- generalizes dispatch_calls + ws_loopback
  sources = [ source_for(call) | call <- calls ] ++ [ control ]
            -- native subprocess tool -> asyncExecProcess source (live stdout)
            -- delegated/FS/AI tool    -> deferred dispatch_tool_envelope (ws_loopback shape, §4)
  selectEvents(sources, \event. match event {
    SourceBytes/Text(tool_i, chunk) -> render + accumulate; stop when all tools done
    Control(Cancel)                 -> tear down sources; emit cancellation tool-results; stop
    ToolRequest(frame)              -> deferred dispatch_tool_envelope(rt, ctx, frame); transmit back
  })
  -> [Message]   -- one tool-role msg per call (ordered by tool_call_id), or cancellation msgs
```

**What Phase 1 buys** (vs. today's sequential `dispatch_calls` fold): concurrent tool execution with
live streamed output; **mid-batch cancellation** via the control source (today there is none — a
batch runs to completion); the re-entrant tool loopback generalized from `ws_loopback` (§4);
deterministic ordering (`selectEvents` priority + round-robin) → DST-replayable (§9).

**Honest caveats / sub-questions (feed the ADR's risks):**
- **Result ordering:** concurrent tools must still emit tool-results in `tool_call_id` order
  (DST invariant "tool-call IDs preserved") — collect by id, emit in call order.
- **Not all tools are subprocesses:** `asyncExecProcess` only sources a subprocess's stdout
  (read-only, dies with the loop). FS/env-delegated/AI-subagent tools go through the **deferred
  envelope** path, not a process source — `run_tool_select` is really two arms (process sources vs.
  deferred dispatch) multiplexed under one control source.
- **Cancellation is cooperative/coarse:** a mid-flight blocking `dispatch_tool_envelope` can't be
  preempted by the select — cancel takes effect at select boundaries (open #3).
- **Concurrency must be opt-in:** some tool batches have ordering/safety dependencies; default to
  sequential unless the batch is known-independent.

**Conclusion:** the migration is a **localized refactor** (`dispatch_calls → run_tool_select`), not a
rewrite — the coordinator, state threading, model call, and every hook are untouched. This closes
pre-ADR research item #2.

## 13. Open questions / next steps

1. **Real-model in-handler call** — run the `-ai <model>` + keys variant to convert the ⚠ to ✅
   literally (currently covered by composition only). *Lower priority:* production uses deferred
   dispatch (§4), so a real in-handler model call is a nice-to-have, not on the critical path.
2. ~~**`selectEvents` shape of `loop_v2`**~~ **RESOLVED — see §12.** The migration is a localized
   refactor (`dispatch_calls → run_tool_select`); `loop_v2` is already a state-threading coordinator,
   the model call stays a blocking `dispatch_step` (§5 XOR), and `selectEvents` wraps only the tool
   phase + a control source. Both pre-ADR research gaps (#1 LLM-as-source §5, #2 loop sketch §12) are
   now closed — the Phase-1 ADR can be drafted.
3. **Cancellation/abort semantics** across the loop (priority of a control source; teardown of async
   sources — `asyncExecProcess` dies with the loop, so mid-flight tool subprocesses need explicit
   handling).
4. **SharedMem→message inversion** — scope which `cache`/`ext/runtime` uses are coordination
   (→ messages) vs. genuine shared cache (may stay). Two substrates, both gated: typed `Chan`
   (v1.0/1.1), or `std/cognition` mailboxes **iff** someone wires a native Msg handler (today
   `NO_HANDLER` in CLI) and widens the effect ceiling. **Pre-ADR probe:** is a native `StubMsgHandler`
   reachable from `ailang run`, or is the fabric browser-only? (§1, §8.)
5. **Determinism/replay** — both shipped `selectEvents` and planned channels are deterministic; confirm
   this composes with DST/trace tooling (`001_DST`).
6. **DST channel-recorder spike (today, no v1.0.0 needed)** — per §9, prove the cheap partial win:
   point `loop_v2`'s provider path at a scripted local server and tee the `ws_loopback.ail` frames as
   a normalized DST trace. Directly attacks ADR-001 R7/R8. (See §9.)
7a. **Extension Phase-1 — confirm zero per-package changes** (per §10). Verify the two core
   guarantees (carry `Stream` at hook call sites; deferred dispatch so hook-owned `runEventLoop`s
   don't nest). Existing packages (`context-mode`, `scratchpad`) keep working unchanged; the
   streaming-result hook variant + cooperative cancellation are additive opt-ins, not migration.
7b. **Extension Phase-2 channel ABI** (per §10) — which hooks processify first, and how
   `ExtCtx`/`[Msg]` serialize across a channel (envelopes are JSON-ready via
   `call_to_json`/`result_to_model_json`; `history_slice` is not). Decide the in-process-vs-peer
   gradient before any extension is processified.

---

## References
- **Shipped B′ precedent: `packages/motoko_scratchpad/ws_loopback.ail`** (the deferred-dispatch,
  canonical re-entrant loop; `collect_one` / `dispatch_deferred_request` / `loop_until_done` /
  `exec_scratchpad_cell_ws`). README: `packages/motoko_scratchpad/README.md`.
- Shipped substrate: `std/stream` (docs MCP), `src/examples/csp_demo/main.ail`
- Prior spike (designs/ADRs that `motoko_scratchpad` implements):
  `.agent/research/omp-style-python-eval/{00-design.md,ADR-001,ADR-002}`,
  `.agent/plans/omp-style-python-eval/02-design-b-prime-reentrant-websocket.md`
- Planned CSP: AILANG `design_docs/planned/v1_0_0/m-csp-session-types.md`,
  `m-agent-orchestration.md`
- DST (§9 cross-ref): `.agent/projects/001_DST/ADR-001-deterministic-simulation-testing-architecture.md`
  (esp. R7 effect satisfaction, R8 recorder seam, the canonical trace-event list)
- Architecture facts: `tools/code-graph/` (core profile), `tools/code-graph/AGENTS.md`
