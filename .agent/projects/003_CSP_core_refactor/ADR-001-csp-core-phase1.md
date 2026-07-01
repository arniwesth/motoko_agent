# ADR-001: CSP-style event-loop core for Motoko (Phase 1)

Date: 2026-06-30
Status: Proposed
Pinned toolchain: AILANG **v0.26.0** (commit `3b52a24`); `ailang.lock` → `ailang_version: "v0.26.0"`.

Relates to:
- `RESEARCH-csp-core-feasibility.md` (this project — the evidence base; cited throughout as §N)
- `DIAGRAM-csp-architecture.md` (this project — §0 baseline vs §1–§3 proposals)
- `./smoke/` (this project — the verified capability proofs; see `smoke/README.md`)
- `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` (DST; esp. R7/R8 and its
  R1–R15 review — this ADR is written to not repeat those mistakes)

---

## Context

Motoko's core today runs a **strictly sequential, blocking** agent loop. `loop_v2`
(`src/core/agent_loop_v2.ail:1107`) processes one step at a time: each effect — the model call, each
tool subprocess, each env-server request — blocks to completion before the next begins. Tool batches
execute as a sequential fold (`dispatch_calls`, `agent_loop_v2.ail:731`; the `call :: rest` arm at
`agent_loop_v2.ail:743` recurses on `rest` at `:756`), there is **no mid-batch cancellation** (a
batch runs to completion once started), and there is **no live tool output** (a tool's stdout is
only observed after it exits). Cross-agent state is a shared `SharedMem` blackboard
(`cache.ail`, `core:traj:<hash>` keys), not messages. This is the baseline drawn in
`DIAGRAM-csp-architecture.md` §0.

AILANG has shipped, since v0.7.0, a `std/stream` event-loop substrate — async I/O-backed *sources*
(subprocess, stdin, WebSocket, SSE/NDJSON) multiplexed by a deterministic, prioritized
`selectEvents` into one cooperative handler that can `transmit` back (RESEARCH §1). This is
select/event-loop CSP. It is **not** the typed-channel / `send`/`recv` / session-types CSP planned
for AILANG v1.0/1.1 (`m-csp-session-types`, RESEARCH §1) — that remains unshipped.

A faithful, canonical-dispatch, re-entrant event loop built on exactly this substrate **already runs
in production**: `packages/motoko_scratchpad/ws_loopback.ail`
(`collect_one:154` / `dispatch_deferred_request:183` / `loop_until_done:194` /
`exec_scratchpad_cell_ws:210`), feature-flagged behind `MOTOKO_SCRATCHPAD_WS_LOOPBACK=1` and
defaulting off (RESEARCH §4). It dispatches real tool calls through the canonical core
`dispatch_tool_envelope` over a WebSocket using the **deferred-yield** discipline (capture frame in
handler → exit loop → dispatch effectfully in the enclosing function → `transmit` → re-enter).

The feasibility research for adopting this shape in the core is **done** (`RESEARCH-csp-core-feasibility.md`).
The two pre-ADR gaps it set out to close are closed: the LLM-as-source question (§5) and the
`loop_v2` `selectEvents` sketch (§12, RESEARCH §13 #2 RESOLVED). This ADR is the decision record.
It does not re-derive the research; it cites it.

## Decision

**Adopt the Phase-1 `selectEvents` / `run_tool_select` model for the core's tool-execution
mechanism.** Concretely: generalize `loop_v2`'s tool phase (`dispatch_calls`) into a
`run_tool_select` function that multiplexes per-tool sources **plus a control/cancel source** via
`std/stream.selectEvents`, generalizing the shipped `ws_loopback.ail` `loop_until_done` template
(RESEARCH §4, §12). This is a **localized refactor of one function**, with no AILANG language
dependency.

Within that decision, the three sub-decisions the research left open resolve as:

1. **Model-call treatment — blocking `std/ai` step.** The model call stays a blocking
   `dispatch_step(provider, …)` behind the existing `StepProvider` seam. `selectEvents` wraps only
   the **tool** phase around it. This is forced by the XOR in §5 (below) and is the status quo for
   the model call.
2. **Dispatch mode — deferred.** Effectful tool dispatch happens **outside** the `selectEvents`
   handler, in the enclosing sequential context — the discipline production already chose in
   `ws_loopback.ail` (RESEARCH §4), for the robustness reason in §6 (handler-side effect errors exit
   0 silently).
3. **Protocol encoding — runtime-checked frame ADTs.** Encode the loop protocol as typed frame sum
   types validated at runtime (`run` / `tool-request` / `tool-result` / `done`), the "poor-man's
   session types" of RESEARCH §11, upgradeable to compiler-checked session types in Phase 2.

Everything else about the core loop — the tail-recursive coordinator, the state threading
(`msgs / step_idx / step_budget / totals / provider`), the model call, **all four hook points**
(`dispatch_pre_step`, `dispatch_response_intercept`, `dispatch_solver_candidate`, and
`dispatch_tool_policy/handle` inside dispatch), compaction, and cost/usage accounting — stays
**unchanged** (RESEARCH §12). This is the "refactor, not rewrite" claim, made precise below.

### The load-bearing constraint: the LLM XOR (§5)

On v0.26.0 you **cannot** have the LLM call be a `selectEvents` source *and* keep `std/ai`'s
provider abstraction — they are mutually exclusive (RESEARCH §5):

- `std/ai.stepWithStream(...)` is a self-contained **blocking** call that owns its internal
  streaming loop and yields **no `StreamSource`**; its `on_chunk` callback is `! {IO}` only (it
  cannot `transmit`, dispatch, or poll other sources) (RESEARCH §5).
- The only path that yields a source — `ssePost(...)` + `sourceOfConn` — is **raw SSE**, which
  loses `std/ai`'s model routing, auth, per-provider shapes, tool-call deltas, `StepResult`
  usage/cost, and prompt caching (RESEARCH §5).

**Therefore this ADR does not claim in-brain LLM-as-source for Phase 1.** A true LLM source is a
Phase-2+ option requiring a peer process (the `std/ai` call moved to an env-server/LLM process,
streaming tokens to the brain over WS; RESEARCH §5 option B). Phase 1 keeps the model call blocking.

## Decision Drivers

Motivation — leading with *why*, not bare feasibility:

- **Concurrent tool execution + mid-batch cancellation + live tool output.** Today's loop is
  sequential, un-cancellable mid-batch, and shows tool output only post-exit (`dispatch_calls`
  sequential fold, `agent_loop_v2.ail:731,743,756`). `run_tool_select` buys all three (RESEARCH §12,
  "What Phase 1 buys").
- **Deterministic Simulation Testing (DST).** This refactor turns implicit effect boundaries into
  explicit, tee-able message frames, which directly attacks the two problems the DST ADR could not
  cleanly resolve — `001_DST/ADR-001` R7 (satisfy `{Env,FS,Net}` deterministically without effect
  mocking) and R8 (the recorder "must not change prod behavior" vs "seams must be added"
  self-contradiction). CSP **dissolves R8** (recorder = a process teeing the channel, not a seam in
  `dispatch_step`) and **sidesteps R7** (substitute the channel *peer*, not the effect handler)
  (RESEARCH §9). See "Observability mechanism" below.
- **Extension-sandboxing trajectory.** The tool path already runs through `ext/runtime`'s hooks, and
  the hook boundary is already CSP-shaped (returns are already messages: `Handled | Delegate`,
  `Allow | Deny | NoOpinion | Pending`) (RESEARCH §10). Phase 1 needs **zero** extension changes
  (RESEARCH §10, "Phase 1 per-package change: none"); Phase 2 is where capability-scoped, observable
  hook channels pay off.
- **No language dependency.** Phase 1 generalizes shipped, working code (`selectEvents` +
  `ws_loopback.ail`); the capability ledger (RESEARCH §5) de-risks every seam on the current
  toolchain. Phase 2's wins are gated on the unshipped `Chan` effect (v1.0/1.1).

## Scope

### Phase 1 — IN (no AILANG language dependency, buildable on v0.26.0)

- Generalize `loop_v2`'s `dispatch_calls` into `run_tool_select`, multiplexing per-tool sources + a
  control/cancel source via `selectEvents` (RESEARCH §12). **This is the central thing adopted.**
- The dispatch mode (**deferred**), model-call treatment (**blocking `std/ai`**), and protocol
  encoding (**frame ADTs**) decided above.
- Carry the `Stream` effect at extension hook call sites; rely on deferred dispatch so a hook that
  hosts its own `runEventLoop` (`scratchpad`'s flagged `ws_loopback`) is never entered inside the
  core's handler (no nested loops) (RESEARCH §10). **No per-package extension code change**
  (`context-mode`, `scratchpad`; `autoresearch` has no `.ail` hooks) (RESEARCH §10).

### Phase 2 — OUT (defer to a separate Phase-2 ADR, gated on AILANG v1.0/1.1)

The gating reason is concrete: each of these needs the **unshipped `Chan` effect + session types**
(`m-csp-session-types`, planned v1.0/1.1; AILANG compiler tree confirms `internal/channels/(todo)`,
`internal/session/(todo)`, "csp concurrency (deferred)" — RESEARCH §1).

- Typed `Chan` / `send`/`recv` / compile-time session types for the internal seams.
- `spawn`-backed in-language peer processes (solvers / sub-agents).
- The `SharedMem` → message inversion (replace the `cache` blackboard with messages).
- In-brain LLM-as-source (the §5 option B peer-process provider).

## Constraints

Hard constraints from RESEARCH §7 — the design does **not** try to engineer around these:

- **No persistent bidirectional subprocess/REPL in the AILANG brain.** `spawnProcess` is write-only
  stdin (stdout/stderr discarded); `asyncExecProcess` is read-only stdout and **dies when the event
  loop exits**. Only the WebSocket is fully bidirectional + persistent. ⇒ CSP "peers" are external
  (env-server over WS) until v1.0.0 `spawn` (RESEARCH §7).
- **Cooperative, single-loop concurrency — not CPU parallelism.** Fine: Motoko's work is I/O-bound,
  and real parallelism already comes from the separate backend OS process (RESEARCH §7).
- **Cancellation is coarse/cooperative, not preemptive.** A mid-flight blocking
  `dispatch_tool_envelope` cannot be preempted by the select; cancel takes effect at select
  boundaries (RESEARCH §12, Open Question #1 below).
- **Shipped `std/stream` has no inter-*function* channels** — sources must be I/O-backed. The
  SharedMem→channel inversion waits for Phase 2 (RESEARCH §7).

Two operational gotchas that the implementation **must** bake in (RESEARCH §6):

1. **The `AI` effect needs TWO runtime grants.** `-ai <model>` / `-ai-stub` binds the *handler*;
   `--caps AI` separately grants the *capability* — and `ailang run --help`'s example cap list
   omits `AI` (a trap). The brain must launch with **both** `--caps …,AI` and a model/stub.
   Likewise the loop needs `--caps …,Stream` with `--stream-allow-*`. **Add startup assertions** for
   both (RESEARCH §6, `smoke/README.md`).
2. **Effect failures inside a stream handler do NOT crash the process** — the handler aborts
   mid-way, `runEventLoop` returns, and `main` exits **0 with nothing on stderr** (observed directly:
   the AI smoke without `--caps AI` printed the pre-call line, skipped the rest, exited 0 — RESEARCH
   §6). This is the decisive reason Phase 1 uses **deferred** dispatch: effects run in the enclosing
   sequential context, so errors surface (RESEARCH §6). Any unavoidable handler-side error must be
   surfaced explicitly via a `done{status:error}` frame / result sentinel — process exit cannot be
   relied upon.

## The Phase-1 change: `dispatch_calls` → `run_tool_select`

**What is already CSP-shaped (verified, source-grounded).** `loop_v2` is a **tail-recursive
coordinator** threading all state as explicit values (`msgs, step_idx, step_budget, totals,
provider`) with **no shared mutable loop state** (RESEARCH §12) — it already satisfies the
coordinator discipline of RESEARCH §11. It has exactly two channels:

- **model channel:** the step dispatcher `dispatch_step(provider, model, msgs, rt, on_chunk)` — a
  real function at `src/core/test/stub_step.ail:110`, imported at `agent_loop_v2.ail:62` and called at
  `agent_loop_v2.ail:1202`. It dispatches on the `StepProvider` ADT (`LiveAI => stepWithStream(...)`
  is the blocking `std/ai` step; `Scripted` is the test path), so it *is* the `StepProvider` seam.
  `loop_v2` **does** carry the `AI` effect — verified at `src/core/agent_loop_v2.ail:1125` (the effect
  row of the `loop_v2` body includes `AI`). *Provenance note (re-grounded against a fresh
  `tools/code-graph` extract, 2026-06-30, v0.26.0 commit `3b52a24`; the graph was STALE and was re-run
  per `tools/code-graph/AGENTS.md`): the fresh extract's `effect_edges` table **now does carry**
  `loop_v2 → AI`, so graph and source agree on the **effect** — the research's "code-graph missed that
  edge" (RESEARCH §12, DIAGRAM §0) was a stale-graph artifact corrected by re-extraction. The `invokes`
  graph still shows no edge to `dispatch_step`, but the **verified reason is the profile boundary, not
  a record-field indirection**: `dispatch_step` is defined in `src/core/test/stub_step.ail`, and the
  default **core profile excludes `src/core/test/**`** (`tools/code-graph/extract.sh`: "Core excludes …
  src/core/test"), so the callee is filtered out of the core graph's func set. (This corrects the
  research/DIAGRAM framing of it as a "`StepProvider`-record call the parser didn't resolve.") Source
  is ground truth; trust `agent_loop_v2.ail:62,1202`.*
- **tool channel:** `dispatch_calls(rt, ctx, calls, …) -> [Message]` (`agent_loop_v2.ail:731`;
  graph-confirmed `loop_v2 → dispatch_calls` in `invokes`) — today a **sequential fold**: the
  `call :: rest` arm (`agent_loop_v2.ail:743`) recurses on `rest` (`agent_loop_v2.ail:756`), one tool
  at a time.

**The localized change.** Keep the entire recursion, the model call, all four hook points,
compaction, cost/usage, and events **unchanged**. The hook topology is graph-confirmed against the
fresh extract: `loop_v2` invokes `dispatch_pre_step`, `dispatch_response_intercept`, and
`dispatch_solver_candidate` (all `src/core/ext/runtime`) plus `dispatch_calls` directly; the fourth
hook pair `dispatch_tool_policy` / `dispatch_tool_handle` is invoked **inside** `dispatch_calls`
(graph-confirmed `dispatch_calls → {dispatch_tool_policy, dispatch_tool_handle, dispatch_one,
tool_call_to_envelope}`). The CSP increment replaces **one function**:
`dispatch_calls → run_tool_select`, multiplexing tools + a control source via `selectEvents`. The
§12 sketch (grounded in `run_v2:1494`, `loop_v2:1107`, `dispatch_calls:731`):

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

*The sketch is illustrative pseudocode, not literal source.* Its anchor functions are real and
verified — `dispatch_pre_step` (`ext/runtime.ail:164`), `compact_step_with_limit`
(`compaction.ail:134`), `dispatch_step` (`stub_step.ail:110`, called `agent_loop_v2.ail:1202`),
`dispatch_response_intercept` (`ext/runtime.ail:252`), the `finish_reason != "tool_calls"` branch
(`agent_loop_v2.ail:1302`), `dispatch_solver_candidate` (`ext/runtime.ail:303`), and `dispatch_calls`
(`agent_loop_v2.ail:731`) — but binding names like `assistant_of` / `accumulate`, elided arguments
(the real `compact_step_with_limit` takes a `context_limit`; `dispatch_pre_step` wraps
`messages_to_msgs(msgs)`), and the `run_tool_select` body are schematic, standing in for the
implementation this ADR authorizes, not naming existing symbols.

**Two arms under one control source (be explicit about this — RESEARCH §12).** `run_tool_select` is
not "every tool becomes a process source." `asyncExecProcess` only sources a subprocess's stdout
(read-only, dies with the loop). FS / env-delegated / AI-subagent tools go through the **deferred
envelope** path (`dispatch_tool_envelope`, the `ws_loopback` shape), **not** a process source. So the
function is two arms — process sources vs. deferred dispatch — multiplexed under one control source.

**Observability mechanism (named, per the R8 lesson).** The frames `run_tool_select` exchanges
(`run` / `tool-request` / `tool-result` / `done`) **are** the DST trace events: a recorder is a
process that **tees the frame stream**, and `selectEvents`' deterministic priority + same-priority
round-robin ordering makes the message order reproducible by construction (RESEARCH §9). This is the
"tee the channel" mechanism of RESEARCH §9, and it is what dissolves the R8 self-contradiction —
there is no observation seam inside `dispatch_step`; the frames already exist on the wire. *Caveat
(verified-vs-inferred): the cheap DST partial win — point the provider path at a scripted local
server and tee the frames as a normalized trace — is asserted by composition from shipped pieces
(RESEARCH §9, §13 #6), not yet demonstrated end-to-end. It is a Phase-1 spike, listed as such, not a
completed result.*

**Why deferred, restated as the call.** In-handler effectful dispatch is **verified possible** on
v0.26.0 (the `Net`-in-handler and `AI`-in-handler smokes, RESEARCH §5 / `smoke/README.md`) — but the
only shipped precedent (`ws_loopback.ail`) deliberately uses **deferred** because handler-side effect
errors exit 0 silently (RESEARCH §6, gotcha 2). This ADR follows production: deferred is the robust
default. In-handler dispatch is an available option, not a requirement, and not the one chosen.

## Consequences

### Positive

- **Concurrent tool execution with live streamed output** and **mid-batch cancellation** via the
  control source — neither exists today (RESEARCH §12).
- **Refactor, not rewrite:** the coordinator, state threading, model call, and every hook are
  untouched; one function changes (RESEARCH §12). Risk is contained to `run_tool_select`.
- **DST leverage now:** the loop's frames become a tee-able trace, attacking `001_DST` R7/R8 without
  waiting for v1.0.0 (RESEARCH §9). A genuine partial win is available on current `std/stream`.
- **Zero extension churn in Phase 1**, and a clean Phase-2 trajectory toward capability-scoped,
  observable hook channels (RESEARCH §10).
- **Deterministic by construction:** `selectEvents` priority + round-robin ordering is replayable,
  composing with the DST/trace tooling direction (RESEARCH §9, §12).

### Negative

- **Tool-result ordering becomes a real obligation.** Concurrent tools must still emit tool-results
  in `tool_call_id` order to preserve the DST invariant "tool-call IDs preserved" — collect by id,
  emit in call order (RESEARCH §12; Open Question #2).
- **Two-arm complexity.** `run_tool_select` multiplexes process sources and deferred dispatch under
  one control source — more moving parts than the sequential fold it replaces (RESEARCH §12).
- **Cancellation is cooperative/coarse** — a mid-flight blocking dispatch cannot be preempted; cancel
  lands at select boundaries (RESEARCH §7, §12; Open Question #1). This is weaker than a user might
  expect from "cancel."
- **Concurrency must be opt-in.** Some tool batches have ordering/safety dependencies; the default
  must stay sequential unless a batch is known-independent (RESEARCH §12; Open Question #3).
- **The XOR is permanent for Phase 1:** no streamed multiplexing *of the model call itself*; token
  rendering stays via the blocking step's `on_chunk` (RESEARCH §5). A true LLM source is Phase 2.

## Rejected Alternatives

- **In-handler effectful dispatch** (do the tool dispatch inside the `selectEvents` handler).
  *Verified possible* on v0.26.0 (RESEARCH §5 smokes) but rejected for Phase 1: handler-side effect
  errors exit 0 silently with nothing on stderr (RESEARCH §6, gotcha 2), and the only shipped
  precedent (`ws_loopback.ail`) chose deferred for exactly this reason (RESEARCH §4). Available as an
  opt-in later if a streaming use case demands it; not the default.
- **Raw `ssePost` for the model call** (to make the LLM a `selectEvents` source). Rejected: it loses
  `std/ai`'s provider abstraction — model routing, auth, per-provider shapes, tool-call deltas,
  `StepResult` usage/cost, prompt caching (RESEARCH §5 XOR). The cost is not worth a streamed model
  source in Phase 1.
- **Full rewrite of the core loop into a CSP architecture.** Rejected: unnecessary. `loop_v2` is
  already a state-threading coordinator with no shared mutable loop state (RESEARCH §12); the change
  is one function. A rewrite would discard verified, working hook/compaction/cost machinery for no
  Phase-1 gain.
- **`std/cognition` mailboxes (`Msg`/`Cog`) for core messaging.** Rejected: shipped API but returns
  `Err(NO_HANDLER)` in the native CLI (transport is browser/WASM-wired, `cmd/wasm/effects.go`), and
  `Msg`/`Cog` are **outside Motoko's effect ceiling** (`ailang.toml:47` `max = [...]` excludes them).
  Verified by `smoke/smoke_cognition_msg.ail` (RESEARCH §1, §8). Not a Phase-1 option.
- **Wait for AILANG v1.0/1.1 typed channels** before doing anything. Rejected: Phase 1 delivers
  concurrency, cancellation, live output, and DST leverage with **zero** language dependency
  (RESEARCH §5 ledger). Waiting forgoes all of it for Phase-2 polish (compile-time session types)
  that Phase 1's frame ADTs upgrade *into* — a tightening, not a rewrite (RESEARCH §11).

## Open Questions

Only the genuinely open items are carried here. RESEARCH §13 #1 (LLM-as-source) and #2 (the
`loop_v2` `selectEvents` sketch) are **resolved** — see §5 and §12; do not re-open them.

1. **Cancellation teardown semantics.** A control `Cancel` must tear down in-flight sources, but
   `asyncExecProcess` sources die with the loop and a mid-flight blocking `dispatch_tool_envelope`
   cannot be preempted (RESEARCH §7, §12, §13 #3). What is the precise teardown contract — which
   tool-results are emitted as "cancelled," what the control source's priority is relative to tool
   sources, and how a partially-run subprocess tool is reaped?
2. **Tool-result ordering under concurrency.** Concurrent completion must still serialize to
   `tool_call_id` order (RESEARCH §12). Confirm the collect-by-id / emit-in-call-order discipline
   holds against the DST invariant and against the provider's expectations for tool-result message
   sequencing.
3. **Concurrency opt-in policy.** What decides a batch is safe to run concurrently vs. must stay
   sequential (default)? Per-tool annotation, a known-independent allowlist, or always-sequential
   until proven? (RESEARCH §12.)

*(Lower priority, off the critical path: a literal real-model in-handler call (RESEARCH §13 #1) is
covered only by composition today. Because Phase 1 uses deferred dispatch, this is a nice-to-have,
not a blocker.)*

## Version pin & re-validation trigger

This ADR's capability claims are pinned to **AILANG v0.26.0** (commit `3b52a24`; `ailang.lock`
`ailang_version: "v0.26.0"`). The research already caught drift at this boundary — the MCP
`effects_catalog` was stale (missed `Msg`, `Cog`, `SharedIndex`, `Rand`, `Trace`; installed stdlib
is ground truth) and `std/ai` signatures churned across recent minors (RESEARCH §8).

**Re-validation trigger:** on **any minor AILANG bump** (v0.27+, or v1.0), before relying on this
ADR, re-run the `./smoke/` capability proofs and re-confirm the §5 XOR (the shape of
`stepWithStream` / `ssePost` is the load-bearing fact) and the `selectEvents` source/handler
surface. A patch bump (v0.26.x) does not trigger re-validation. The smoke suite (`smoke/README.md`)
is the validation harness; no new CI/Make target is assumed by this ADR — any such target is
**to-be-created** as part of Phase-1 implementation, not a precondition of the decision.

## Verified vs. inferred (provenance summary)

- **Verified this session (v0.26.0), source/smoke-grounded:** `Net`-in-handler and `AI`-in-handler
  (`smoke/`, RESEARCH §5); the §5 XOR (installed stdlib + `ai_compat.callStreamResult`);
  `loop_v2` carries `AI` (`agent_loop_v2.ail:1125`); `dispatch_calls` is a sequential fold
  (`agent_loop_v2.ail:731`; `call :: rest` arm `:743`, recursion `:756`); the `ws_loopback.ail`
  deferred template
  (`collect_one:154`/`dispatch_deferred_request:183`/`loop_until_done:194`); effect ceiling excludes
  `Msg`/`Cog` (`ailang.toml:47`); `std/cognition` `NO_HANDLER` in CLI
  (`smoke/smoke_cognition_msg.ail`).
- **Graph-confirmed (re-grounded 2026-06-30 against a fresh `tools/code-graph` extract).** The graph
  was STALE at read time; `tools/code-graph/extract.sh` was re-run (core profile, v0.26.0 commit
  `3b52a24`; 388 funcs / 486 invokes / 472 effect edges; `coverage: 24/24 ok`, `incomplete: false`).
  The fresh graph confirms, in `invokes`: the entry edges `run_v2 → loop_v2`,
  `run_v2_from_messages → loop_v2`, `run_v2_with_conversation → conversation_loop_v2`; the tool
  channel `loop_v2 → dispatch_calls`; the three direct hooks `loop_v2 → {dispatch_pre_step,
  dispatch_response_intercept, dispatch_solver_candidate}`; and the in-dispatch hook pair
  `dispatch_calls → {dispatch_tool_policy, dispatch_tool_handle}`. In `effect_edges` it confirms
  `loop_v2 → AI` (agreeing with source `agent_loop_v2.ail:1125`).
- **Inferred / approximate (flagged; AGENTS.md: "must not treat call/effect rows as compiler-derived
  facts").** Two concrete, *persistent* graph approximations survive the re-extract and are the
  reason source signatures stay ground truth: (a) the **model step is invisible to the `invokes`
  graph** — its dispatcher `dispatch_step` is defined in `src/core/test/stub_step.ail:110`, which the
  **core profile excludes** (`extract.sh`: "Core excludes … src/core/test"), so it is filtered from
  the core func set and no `loop_v2 → dispatch_step` edge appears even though `loop_v2`'s `AI` effect
  does (verified reason = profile boundary, *not* a record-field call — correcting RESEARCH §12 /
  DIAGRAM §0); (b) the **graph under-approximates `dispatch_calls`' effect row** — `effect_edges`
  lists only `{Clock,FS,IO,Process,Trace}`, whereas the source signature declares
  `{FS,Process,IO,Clock,AI,Env,Net,SharedMem,Stream,Trace}` (`agent_loop_v2.ail:740`), missing
  `AI/Env/Net/SharedMem/Stream` (those effects are attributed to the deferred/delegated leaves
  reached via `dispatch_one`/`dispatch_tool_handle`). The per-step pipeline *ordering* in DIAGRAM §0
  remains inferred (`invokes` is an unordered set). The real-model in-handler call (RESEARCH §13 #1)
  and the DST channel-recorder partial win (RESEARCH §9, §13 #6) are asserted by composition, not yet
  demonstrated end-to-end.

## Review Comments

_(Reserved for reviewer. Please ground findings against current source — `src/core/agent_loop_v2.ail`,
`packages/motoko_scratchpad/ws_loopback.ail`, `ailang.toml`, `ailang.lock` — and the `./smoke/`
proofs, and cite real `file:line` / commits rather than invented PR numbers, per the lessons from
`001_DST/ADR-001` R1–R15.)_
