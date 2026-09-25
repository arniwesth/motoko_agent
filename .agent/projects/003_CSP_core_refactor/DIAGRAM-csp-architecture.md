# Diagram: a possible CSP architecture for Motoko's core

Companion to [RESEARCH-csp-core-feasibility.md](./RESEARCH-csp-core-feasibility.md). These are
*proposals*, grounded in what ships today (`std/stream` `selectEvents` + the shipped
`motoko_scratchpad/ws_loopback.ail` re-entrant loop) and what's planned (v1.0.0
`m-csp-session-types`). Boxes are **processes** (sequential inside, communicating only by
messages); edges are **channels** labelled with their message/protocol.

**§0 is the current architecture (baseline); §1–§3 are the CSP proposals.**

---

## 0. Current architecture (today, v0.26.0) — baseline for comparison

How the core runs **now**. Same convention: boxes = processes, edges = channels. The defining
trait vs. the CSP proposals: the brain is a **strictly sequential, blocking** loop — one step at a
time, each effect (AI call, tool subprocess, env-server request) **blocks to completion**. There is
no `selectEvents` multiplexer; cross-agent state is a shared `SharedMem` blackboard, not messages.

**Grounding (verified 2026-06-30):** the entry chain, the `loop_v2` invoke set, and the
`AI`-effect attribution are **code-graph** facts (`q callers loop_v2`; `invokes`/`effects`
tables — note the graph was STALE and call/effect edges are source-parsed *approximations*). The
stdlib call sites (`httpPost` routes, `httpGet /health`, `_sharedmem_get`/`get_hint`) are
**source-grounded** (grep), not from the graph. (a) The per-step pipeline **ordering** is *inferred*
(`invokes` is an unordered set). (b) **Correction (source-verified):** the model call **is** per
step — `loop_v2` makes the blocking `dispatch_step(provider, …)` call inside its recursion and
**carries the `AI` effect** (`agent_loop_v2.ail:1125`). Code-graph wrongly attributed `AI` only to
`run_v2`/`conversation_loop_v2` because `dispatch_step` is a `StepProvider`-record call its parser
didn't resolve — a concrete example of the "edges are approximations" caveat.

```mermaid
flowchart TB
  subgraph HOST["TS supervisor (ts_host) - process"]
    SUP["supervisor / rpc<br/>load config, start backend, run"]
  end

  subgraph BRAIN["AILANG brain - process (sequential, blocking)"]
    direction TB
    CONV["run_v2_with_conversation<br/>-> conversation_loop_v2 -> run_v2"]
    STEPLOOP["loop_v2<br/>one synchronous step at a time"]
    CONV --> STEPLOOP
  end

  subgraph ENV["Bun env-server - process"]
    EX["/exec, /exec-ailang, /scratchpad-cell<br/>blocking HTTP routes"]
  end

  subgraph BACK["backend - separate OS process"]
    BE["spawnProcess child (write-only stdin)"]
  end

  SUP -->|"start_or_connect_backend / run_with_config"| BRAIN
  STEPLOOP -->|"AI call: loop_v2 dispatch_step(provider) per step (BLOCKS) [source]"| PROV["LLM provider<br/>AI effect"]
  STEPLOOP -->|"dispatch_calls -> dispatch_one -> run_native_batch: native FS / Process (BLOCKS) [graph]"| TOOLS["tool_runtime<br/>run_native_batch"]
  STEPLOOP -->|"env_client.httpPost (BLOCKING) [source]"| EX
  SUP -->|"httpGet /health [source]"| BE
  EX -->|"delegated exec"| BE

  SM[("SharedMem blackboard<br/>cache core:traj keys - shared KV")]
  BRAIN -.->|"get_hint / store (shared memory) [source]"| SM

  classDef proc fill:#eef,stroke:#557,stroke-width:1px;
  classDef store fill:#fee,stroke:#a55;
  class HOST,BRAIN,ENV,BACK proc;
  class SM store;
```

A per-turn chain spanning `run_v2` (the blocking model call) and `loop_v2` (everything else) — a
**linear, blocking** flow, contrast with the CSP `selectEvents` multiplexer in §1. **Node
membership is code-graph (`loop_v2` invokes + `run_v2` AI effect); the left-to-right *order* is
inferred — code-graph does not sequence `invokes`.**

```mermaid
flowchart LR
  C["model call<br/>run_v2 (AI effect, blocks)"] --> A["dispatch_pre_step<br/>(ext hook)"]
  A --> B["compact_step_actual<br/>(compaction)"]
  B --> D["dispatch_response_intercept<br/>(ext hook)"]
  D --> E["dispatch_calls -> dispatch_one<br/>-> run_native_batch (blocks per tool)"]
  E --> F["dispatch_solver_candidate<br/>(ext hook)"]
  F --> G["dp7_gate"]
  G --> H["cost / usage<br/>step_cost_millicents"]
  H --> I["emit_event / emit_stream_chunk"]
  I -->|"next turn"| C
```

**Current vs. CSP (what actually changes):**

| Concern | Current (today) | CSP proposal (§1–§3) |
|---|---|---|
| Brain concurrency | sequential, one step at a time | single `selectEvents` over many async sources |
| LLM call | blocking `AI` effect on `run_v2` (`std/ai`; `ai_compat` is a defined-but-unused shim) | `ssePost`/`ndjsonPost` token source, multiplexed |
| Tool exec | native `tool_runtime` Process, blocking | `asyncExecProcess` source / canonical re-entrant dispatch |
| Brain ↔ env-server | blocking `httpPost` (request/response) | bidirectional WebSocket channel |
| Cross-agent state | `SharedMem` blackboard (shared memory) | typed channel messages (Phase 2) |
| Internal seams (tool/RPC/hooks) | convention-only contracts | session-typed protocols (Phase 2) |
| Determinism | sequential ⇒ deterministic | deterministic `selectEvents` / scheduler (preserved) |

> Note: `motoko_scratchpad/ws_loopback.ail` (the shipped re-entrant WS loop, §2) already lives
> *beside* this baseline as a feature-flagged path — the CSP proposal is to make that loop shape
> the core's organizing principle rather than one extension's opt-in.

---

## 1. System view — processes communicating over channels

Each OS process is a CSP "process": sequential internally, isolated, talking only over channels.
Phase 1 channels are `std/stream` WebSockets + async sources (shipped). Phase 2 promotes the
*internal* seams to session-typed `Chan` (v1.0.0).

```mermaid
flowchart TB
  subgraph HOST["TS supervisor (ts_host) - process"]
    SUP["supervisor / rpc<br/>spawn + lifecycle"]
  end

  subgraph BRAIN["AILANG brain - process (sequential)"]
    direction TB
    LOOP["loop_v2 : selectEvents<br/>deterministic prioritized select"]
    HANDLER["onEvent handler<br/>capture frame, return bool"]
    DISPATCH["dispatch_tool_envelope<br/>canonical tool_runtime + policy + extensions"]
    LOOP --> HANDLER
    HANDLER -.->|"deferred: exit loop, then dispatch"| DISPATCH
    DISPATCH -->|"transmit result, re-enter"| LOOP
  end

  subgraph ENV["Bun env-server - process"]
    WS["exec-cell-ws : WebSocket route"]
    KERN["persistent kernels<br/>py / js / ail / lean"]
    WS --- KERN
  end

  subgraph BACK["backend - separate OS process"]
    BE["spawnProcess child<br/>write-only stdin today"]
  end

  SUP -->|"start_or_connect / RPC"| BRAIN
  LOOP ==>|"LLM stream source: ssePost / ndjsonPost (SSE/NDJSON tokens)"| PROV["LLM provider<br/>Net / AI effect"]
  LOOP ==>|"tool-output source: asyncExecProcess (stdout chunks)"| BE
  BRAIN <-->|"WS channel: run / tool-request / tool-result / done"| WS
  KERN -.->|"loopback: tool.read/write/search/agent"| WS
  DISPATCH -->|"real tool calls: FS / Process / Net / AI"| BE

  SM[("SharedMem blackboard<br/>cache core:traj keys - Phase 1 today")]
  BRAIN -.->|"shared KV (to invert in Phase 2)"| SM

  classDef proc fill:#eef,stroke:#557,stroke-width:1px;
  classDef store fill:#fee,stroke:#a55;
  class HOST,BRAIN,ENV,BACK proc;
  class SM store;
```

**Reading it:** the brain is one sequential process whose *concurrency* is a single
`selectEvents` multiplexing many async sources (LLM token stream, tool output, control). Effectful
tool dispatch goes through the canonical `dispatch_tool_envelope` — and (per the shipped precedent)
happens **after** the handler yields, not inside it. Kernels and the backend live in their own
processes; the only cross-process coupling is channels.

---

## 2. The re-entrant dispatch cycle (deferred — as shipped)

This is `motoko_scratchpad/ws_loopback.ail`'s `loop_until_done`, generalised: capture in the
handler, **exit** the loop, run the effect in the enclosing sequential context (so errors surface),
`transmit`, re-enter. Bounded by a depth/iteration cap.

```mermaid
sequenceDiagram
  participant K as Kernel (env-server)
  participant L as Brain loop_v2 (selectEvents)
  participant H as onEvent handler (Stream,FS)
  participant D as dispatch_tool_envelope (IO,FS,Process,AI,Net)

  L->>H: event - tool-request frame
  H->>H: writeFile(req), return false
  H-->>L: runEventLoop returns (loop yields)
  Note over L,D: effectful dispatch OUTSIDE the handler
  L->>D: dispatch_tool_envelope(call)
  D-->>L: tool-result (real registry + policy)
  L->>K: transmit(tool-result)
  L->>L: re-enter runEventLoop (remaining - 1)
  K-->>L: done frame
  L->>L: exit, build ToolResultEnvelope
```

> Inline alternative (handler does the dispatch itself) is **verified possible** on v0.26.0
> (smokes, §5) but **not** what production chose — deferred surfaces effect errors that a handler
> would swallow (process still exits 0). See RESEARCH §4, §6.

---

## 3. Phase 2 — session-typed channels (v1.0.0 `m-csp-session-types`)

Promote the convention-only internal seams to **typed channels** with compile-time protocol
checking, and replace the SharedMem blackboard with message passing. `spawn` turns sub-agents /
solvers into real in-language peer processes instead of I/O sources.

```mermaid
flowchart LR
  SUPV["coordinator process"]
  STEP["step process<br/>(agent turn)"]
  TOOLP["tool process"]
  SOLV["spawned solver / sub-agent peers"]

  SUPV -->|"protocol Step = send Msg, recv StepResult, end"| STEP
  STEP -->|"protocol Tool = send ToolCall, recv ToolResult, end"| TOOLP
  SUPV -->|"spawn + Chan"| SOLV
  SOLV -->|"recv Candidate, end"| SUPV

  NOTE["Chan effect; dual computed by compiler;<br/>cooperative deterministic scheduler (replayable);<br/>binary sessions only in v1"]

  classDef p fill:#efe,stroke:#5a5;
  classDef n fill:#ffd,stroke:#aa3;
  class SUPV,STEP,TOOLP,SOLV p;
  class NOTE n;
```

---

## Legend / grounding

- **Solid `==>`** = `std/stream` async source (shipped). **`<-->`** = bidirectional WebSocket
  channel (shipped). **Dotted** = deferred / to-be-changed.
- **Phase 1 (today, v0.26.0):** §1 + §2 are buildable now — they generalise shipped code
  (`selectEvents`, `ws_loopback.ail`). No language dependency.
- **Phase 2 (v1.0.0):** §3 needs the unshipped `Chan` effect + session types.
- Hard constraints still apply (RESEARCH §7): no persistent bidirectional subprocess in-brain
  (peers are external until `spawn`), cooperative not parallel, binary sessions only.
