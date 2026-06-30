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
`smoke_ai_in_handler.ail` + `ws_server.ts`, `smoke_ai_toplevel.ail`). Prior substrate proofs
remain in `.agent/research/omp-style-python-eval/smoke/` (`smoke_transmit.ail`,
`smoke_deferred_dispatch.ail`).

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
| `m-csp-session-types` | ❌ planned v1.0.0 | `newChan[Protocol]`, `send`/`recv`/`close`, `spawn`; `protocol P = …` | `Chan` (new) | In-language peers, static session-type protocol checking, dual computed by compiler. Binary sessions only (multiparty deferred). Go-backed cooperative scheduler, replayable. |
| `std/agent` | ❌ planned | `invoke`, `invokeStreaming` | `AI`-ish | **Not CSP.** Synchronous sub-agent governance (budgets, tool allowlists, `resumeSessionId`). |

AILANG compiler tree confirms (2) is real-but-stubbed: `internal/channels/ (todo)`,
`internal/session/ (todo)`. Implementation-status page lists "csp concurrency (deferred)".
AILANG effects are **capability-permission tracking**, not algebraic effect handlers (no
resumable continuations) — so channels can't be built in-language; they need the host-backed
`Chan` effect from (2).

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
| `loop_v2` step pipeline | `selectEvents([llm, tools, control], handler)` — multiplex LLM SSE/NDJSON stream, async tool subprocess output, and control/cancel |
| LLM call (`ai_compat`) | an `ssePost`/`ndjsonPost` `StreamSource` (token events) |
| Tool subprocess (`tool_runtime`, sync `Process`) | `asyncExecProcess` source — streamed/concurrent |
| **`SharedMem` blackboard** (`cache`, `ext/runtime`) | **the philosophical inversion** — replace shared KV with channel messages. *Needs v1.0.0 channels;* shipped `std/stream` does **not** give inter-function channels. |

**Two-phase feasibility:**
- **Phase 1 (today, v0.26.0):** restructure `loop_v2` around `selectEvents`. The substrate exists,
  the in-handler effectful-dispatch question is answered (§5), **and a faithful canonical-dispatch
  re-entrant loop already ships** (`packages/motoko_scratchpad/ws_loopback.ail`, via deferred
  dispatch — §4). Phase 1 generalizes existing, working code rather than inventing a loop.
- **Phase 2 (v1.0.0):** session-typed channels for the internal protocols + `spawn` for real
  in-language peer processes (solvers/sub-agents) + the SharedMem→channel inversion.

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
| CSP/session-types roadmap placement (v1.0.0), "deferred" status | docs MCP roadmap + implementation-status (2026-06-30) |

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

## 11. Open questions / next steps

1. **Real-model in-handler call** — run the `-ai <model>` + keys variant to convert the ⚠ to ✅
   literally (currently covered by composition only). *Lower priority:* production uses deferred
   dispatch (§4), so a real in-handler model call is a nice-to-have, not on the critical path.
2. **`selectEvents` shape of `loop_v2`** — sketch the concrete mapping of `agent_loop_v2` functions
   onto a single prioritized select over {LLM stream, tool outputs, control/cancel}. **Start from
   the shipped template:** generalize `motoko_scratchpad/ws_loopback.ail`'s `loop_until_done`
   (bounded yield → `dispatch_tool_envelope` → `transmit` → re-enter) from one source to many. (This
   is option (c) from the discussion thread.)
3. **Cancellation/abort semantics** across the loop (priority of a control source; teardown of async
   sources — `asyncExecProcess` dies with the loop, so mid-flight tool subprocesses need explicit
   handling).
4. **SharedMem→channel inversion** — design once v1.0.0 `Chan` lands; scope which `cache`/`ext/runtime`
   uses are coordination (→ channels) vs. genuine shared cache (may stay).
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
