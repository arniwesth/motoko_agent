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
mechanism.** Concretely: replace `loop_v2`'s tool phase (`dispatch_calls`) with a `run_tool_select`
function that multiplexes per-tool sources **plus a control/cancel source** via
`std/stream.selectEvents`, generalizing the shipped `ws_loopback.ail` `loop_until_done` template
(RESEARCH §4, §12), with no AILANG language dependency.

**Scope of the edit, stated honestly (revised per review B1/B3/G1).** The *edit point* is localized —
the coordinator, state threading, model call, hooks, compaction, and cost/usage are untouched (see
"refactor, not rewrite" below) — but "one function changes" undersells the **behavioral** blast
radius, and this ADR no longer claims it:

- **`dispatch_calls` has two call sites in `loop_v2`, not one:** the tool-calls arm
  (`agent_loop_v2.ail:1454`, the one the §12 sketch shows) **and** the `hybrid_tools` arm
  (`agent_loop_v2.ail:1341`), which dispatches a single synthesized `BashExec` call through the *same*
  pipeline (`hybrid_tools` is a `loop_v2` parameter, `agent_loop_v2.ail:1111`; a shipped, default-capable
  path). **Decision:** `run_tool_select` replaces `dispatch_calls` at **both** sites; for the
  single-element hybrid batch, concurrency is moot but the cancellation / live-output / event-ordering
  contracts below still apply. (`invokes` records `loop_v2 → dispatch_calls` once and, being an
  unordered set, cannot show the multiplicity — source `:1341` and `:1454` establish the two sites.)
- **`run_tool_select` is not a rename of `dispatch_calls`.** Today `dispatch_calls` routes tools
  through `dispatch_one` (native, via `tool_dispatch_adapter`), `dispatch_tool_handle` (extension),
  and `delegated_deferred_message` (delegated) — it does **not** call `dispatch_tool_envelope` (that
  function lives in `tool_envelope_dispatch.ail:36` and is called only by `ws_loopback.ail:188`). The
  §12 sketch's deferred arm substitutes `dispatch_tool_envelope`, so the change also swaps the
  deferred dispatcher. Both the tool-kind routing and the scratchpad special-case must be carried
  forward deliberately — see **"Behavioral contracts Phase 1 must preserve"** below.

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
  self-contradiction). CSP is *positioned to* **dissolve R8** (recorder = a process teeing the
  channel, not a seam in `dispatch_step`) and **sidestep R7** (substitute the channel *peer*, not the
  effect handler) (RESEARCH §9) — *composition-only argument; the recorder spike is pending, RESEARCH
  §9 / §13 #6.* See "Observability mechanism" below.
- **Extension-sandboxing trajectory.** The tool path already runs through `ext/runtime`'s hooks, and
  the hook boundary is already CSP-shaped (returns are already messages: `Handled | Delegate`,
  `Allow | Deny | NoOpinion | Pending`) (RESEARCH §10). Phase 1 needs **zero** extension changes
  (RESEARCH §10, "Phase 1 per-package change: none"); Phase 2 is where capability-scoped, observable
  hook channels pay off.

Feasibility note (not itself a driver — revised per review M5): Phase 1 has **no AILANG language
dependency** — it generalizes shipped, working code (`selectEvents` + `ws_loopback.ail`) and the
capability ledger (RESEARCH §5) de-risks every seam on the current toolchain. This is what makes the
drivers above *achievable now*; Phase 2's wins are gated on the unshipped `Chan` effect (v1.0/1.1).

## Scope

### Phase 1 — IN (no AILANG language dependency, buildable on v0.26.0)

- Generalize `loop_v2`'s `dispatch_calls` into `run_tool_select`, multiplexing per-tool sources + a
  control/cancel source via `selectEvents` (RESEARCH §12). **This is the central thing adopted.**
- The dispatch mode (**deferred**), model-call treatment (**blocking `std/ai`**), and protocol
  encoding (**frame ADTs**) decided above.
- **The core begins calling `selectEvents`/`runEventLoop`** (today only extension hooks like
  `ws_loopback` do — `std_calls` shows *zero* `std/stream` primitives in `src/core/**`). This needs
  **no new effect-ceiling grant** (revised per review M3): `loop_v2`'s effect row already includes
  `Stream` (`agent_loop_v2.ail:1125`) and `dispatch_calls` already declares it (`:740`), so the hook
  call sites already carry `Stream`. Rely on deferred dispatch so a hook that hosts its own
  `runEventLoop` (`scratchpad`'s flagged `ws_loopback`) is never entered inside the core's handler
  (no nested loops) (RESEARCH §10). **No per-package extension code change** (`context-mode`,
  `scratchpad`; `autoresearch` has no `.ail` hooks) (RESEARCH §10).

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

**The localized change.** Keep the entire recursion, the model call, all four hook **APIs**,
compaction, cost/usage, and the event *envelope* **unchanged**. The hook topology is graph-confirmed
against the fresh extract: `loop_v2` invokes `dispatch_pre_step`, `dispatch_response_intercept`, and
`dispatch_solver_candidate` (all `src/core/ext/runtime`) plus `dispatch_calls` directly; the fourth
hook pair `dispatch_tool_policy` / `dispatch_tool_handle` is invoked **inside** `dispatch_calls`
(graph-confirmed `dispatch_calls → {dispatch_tool_policy, dispatch_tool_handle, dispatch_one,
tool_call_to_envelope}`). The CSP increment introduces **`run_tool_select`** in place of
`dispatch_calls` at its **two call sites** (`agent_loop_v2.ail:1341,1454`; see "Scope of the edit"
above), multiplexing tools + a control source via `selectEvents` — a localized *edit point*, but one
that carries the seven behavioral contracts below (it is not a pure rename; per review B3 it also
swaps the deferred dispatcher and must preserve tool-kind routing, the scratchpad special-case, policy
`Pending`, cancellation-transcript, and event-ordering behavior). The §12 sketch (grounded in
`run_v2:1494`, `loop_v2:1107`, `dispatch_calls:731`):

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

**Two arms under one control source, and `source_for` is really a partition (revised per review
B3/G12).** `run_tool_select` is not "every tool becomes a process source," and it is not one generic
`source_for(call)`. The honest shape is **`policy_preflight(calls)` → `partition(calls)` →
`select + assemble_in_call_order`**, where `partition` splits the batch by tool kind (below). Only the
**native-subprocess arm** (`asyncExecProcess`, read-only stdout, dies with the loop) runs
**concurrently** with live streamed output. The **deferred arm** (FS / env-delegated / AI-subagent /
scratchpad, the `ws_loopback` shape) is **one blocking dispatch at a time** in the enclosing context —
so two deferred tools do **not** run concurrently with each other in Phase 1; only native-subprocess
tools stream concurrently. The proportion of each depends on the tool mix and `ohmy_pi`/`backend_for_v2`
routing (`agent_loop_v2.ail`), so the ADR does not claim universal concurrency.

**Observability mechanism (named, per the R8 lesson).** The frames `run_tool_select` exchanges
(`run` / `tool-request` / `tool-result` / `done`) **are** the DST trace events: a recorder is a
process that **tees the frame stream**, and `selectEvents`' deterministic priority + same-priority
round-robin ordering makes the *ordering of already-arrived events* reproducible by construction
(RESEARCH §9). *Two scoping caveats (revised per review S1/G11):* (1) **determinism is scoped to the
AILANG scheduler, not wall-clock I/O** — external process-output timing, WebSocket peer timing, and
approval-input timing stay outside the scheduler unless captured and replayed as trace input; so DST
replay of deferred-dispatch tools requires **controlling the peer** (the env-server), not just the
select. (2) The per-call event *sequence* changes from today's call-list order (the `call :: rest`
recursion at `:743,756`) to **select-priority/round-robin order** — the ADR does *not* claim this
sub-order is unchanged (see the event-ordering contract below). The cheap DST partial win — point the
provider path at a scripted local server and tee the frames — is asserted by composition from shipped
pieces (RESEARCH §9, §13 #6), **not yet demonstrated end-to-end**; it is a Phase-1 spike, not a
completed result.

**Why deferred, restated as the call.** In-handler effectful dispatch is **verified possible** on
v0.26.0 (the `Net`-in-handler and `AI`-in-handler smokes, RESEARCH §5 / `smoke/README.md`) — but the
only shipped precedent (`ws_loopback.ail`) deliberately uses **deferred** because handler-side effect
errors exit 0 silently (RESEARCH §6, gotcha 2). This ADR follows production: deferred is the robust
default. In-handler dispatch is an available option, not a requirement, and not the one chosen.

## Behavioral contracts Phase 1 must preserve

Added in response to review (GPT-5.5 G1–G4, G7–G9; GLM 5.2 B2, S1–S3). `run_tool_select` changes
*how* tools execute; it must not change the contracts today's `dispatch_calls` satisfies with the
provider, the extension system, and the TUI. These are **binding sub-decisions**, not implementation
afterthoughts. Each is grounded in current source.

1. **Dispatch matrix by tool kind (G1).** "Native subprocess tool" is not today's whole native path.
   `dispatch_calls → dispatch_one → run_native_batch` routes a *mixed* ADT — file read/write/edit,
   search, bash, tests, path validation, truncation metadata, stdout/stderr hashes, exit codes,
   tool-specific JSON — and `tool_runtime` classifies `streaming` / `needs_stderr_live` /
   `needs_hard_cancel` as **delegated-backend** features today, returning "requires delegated backend"
   for them (`tool_runtime.ail:118-120,885-886`). Phase 1 must define, per kind, the final
   `Message.content` shape and whether it matches today's `dispatch_one` output
   (`tool_result_item_to_json`):

   | Tool kind | Phase-1 execution | Result shape |
   |---|---|---|
   | Local synchronous (ReadFile/WriteFile/EditFile/Search) | **unchanged**, synchronous, not a source | identical to today's `dispatch_one` |
   | Live-process (bash w/ `streaming`/`needs_stderr_live`) | `asyncExecProcess` source arm (concurrent, live stdout) | must still carry stderr + exit code + truncation meta |
   | Extension-handled (`on_tool_handle → Handled`) | deferred arm, `dispatch_tool_handle` | unchanged envelope |
   | Delegated / `ohmy_pi` backend | deferred arm | unchanged `delegated_deferred_message` shape |
   | Cancelled | synthetic tool-role message (contract #4) | new, defined below |

   The default for anything not proven independent stays the **unchanged synchronous** path (see the
   concurrency opt-in policy, contract #8).

2. **Policy `Pending` must not deadlock the select (G2).** `dispatch_calls`'s `Pending` arm emits
   `tool_pending` then **blocks on `readLine()`** for operator approval (`agent_loop_v2.ail:758-769`).
   If `run_tool_select` starts other tool sources and then hits `Pending`, the whole event loop is
   blocked in stdin approval and the control/cancel source cannot be observed. **Decision:** run a
   **policy preflight** — resolve `dispatch_tool_policy` for every call in the batch (including any
   `Pending` approval) **before** starting any source. Deny/Pending are settled up front; only
   Allow-ed calls enter the select. (Making approval its own select source is deferred to Phase 2.)

3. **Scratchpad special-case must be carried forward (G3).** `dispatch_calls` special-cases scratchpad
   *before* normal handling — `is_scratchpad_tool_name(...) && scratchpad_extension_active(rt)` →
   `exec_scratchpad_cell_ws(...)` (`agent_loop_v2.ail:868-869`, import `:63`). The deferred dispatcher
   the sketch names, `dispatch_tool_envelope`, **hard-errors** on scratchpad ("recursive scratchpad
   loopback is disabled", `tool_envelope_dispatch.ail:37-38`). **Decision:** `run_tool_select` keeps
   the scratchpad special-case (routing to `exec_scratchpad_cell_ws`) ahead of the deferred arm; Phase
   1 does **not** disable the scratchpad WS cell path.

4. **Cancellation produces a provider-valid transcript (G4, B2, S3; resolves Q #2 ordering and the
   cancellation *policy* — only the control-priority residual stays open as Q #1).** On cancel, the
   assistant message still contains N `tool_calls`; the next model step must receive tool-role
   messages the provider accepts.
   - **Ordering — split into a hard and a soft invariant (Q2).** The **hard, provider-correctness**
     rule is *completeness + id-correlation, not position*: every `tool_call` gets exactly one
     tool-role message carrying its non-empty `tool_call_id`, all present before the next model step.
     This is grounded in source — providers correlate `tool_use → tool_result` **by id, not order**,
     and an empty `tool_call_id` is rejected 422 (`agent_loop_v2.ail:363-365` and the
     `envelope_to_tool_message` comment at `~479`). The **soft, DST/readability** rule is emit in
     original call order (collect-by-id, assemble-in-call-order) — free, and keeps the DST invariant
     "tool-call IDs preserved" and trace stability. Consequence: **concurrency is provider-safe as
     long as ids are preserved**; out-of-order completion is not a correctness hazard.
   - **What each call becomes.** Completed results are preserved; not-yet-started and
     in-flight-cancelled calls each get a **synthetic tool-role message** carrying an
     `error`/cancelled sentinel (same envelope shape as `delegated_deferred_message`).
   - **Cancellation is arm-specific (B2).** A native-subprocess tool *can* be cancelled mid-flight
     (the control source fires during `selectEvents`); an in-flight **deferred** dispatch **cannot**
     be preempted — only pending (not-yet-dispatched) deferred tools are cancellable.
   - **Recommended reap sequence (Q1 — closes the policy; one residual left open).** (i) Put the
     **control source at highest `selectEvents` priority** so `Cancel` is seen at the next boundary
     (priority-ordered select, RESEARCH §1); (ii) stop admitting new deferred dispatches; (iii)
     `disconnect` each WebSocket source; (iv) exit `runEventLoop`, which reaps **all**
     `asyncExecProcess` process sources together (they die with the loop, RESEARCH §7); (v) synthesize
     cancelled messages for every call without a result. Bound the teardown with `ws_loopback`'s
     existing `remaining` iteration cap (seeded 32, RESEARCH §4). Two limits are **substrate-forced,
     not choices**: there is **no per-source `kill`** (RESEARCH §7), so loop-exit is all-or-nothing
     (reaping one subprocess ends its siblings → they take the synthetic-cancelled path); and a
     deferred dispatch already mid-blocking-call runs to completion (kept if it returns before
     teardown, else marked cancelled). The **one genuine residual** — the exact control-source
     priority value and whether `disconnect` must strictly precede loop-exit or may interleave — stays
     Open Question #1, to be pinned by the cancellation smoke.

5. **Event ordering & TUI pairing (S1, G10).** Today `loop_v2` brackets dispatch with a batched
   `native_tool_calls` (pre, `agent_loop_v2.ail:1448`) / `native_tool_results` (post, `:1455`) pair
   keyed by `request_id` (`:1447`), and per-call events (`native_tool_denied`, `ext_tool_handled`,
   `delegated_tool_deferred`) fire in call-list order from inside `dispatch_calls`. **Decision:** the
   batched `native_tool_calls`/`native_tool_results` pair still **brackets** `run_tool_select` (the
   TUI's `request_id` pairing is preserved), but the *per-call* event sub-order becomes
   select-priority order, not call-list order. The claim is **"hook and event APIs unchanged;
   scheduling/ordering contract defined here"** (G10) — not "events unchanged."

6. **Live output: model-vs-UI boundary, `stream_id`, backpressure (G7, S2, G8).** Live tool stdout is
   a **UI stream only**. **Decision:** partial stdout chunks are **never** appended to the model
   transcript — the model still receives one final tool-role message per call (contract #1); live
   chunks render to the TUI exclusively. Tool stdout gets a **distinct `stream_id` per `tool_call_id`**
   (not the model's `stream_id`, which keys `thinking_delta`/`text_delta` at `agent_loop_v2.ail:1196-1201`)
   to avoid conflating tool output with model tokens in the per-stream buffer. Per-tool and per-batch
   **byte limits + truncation** carry over from `tool_runtime`'s `mk_meta` truncation contract; chunks
   beyond the live-stream limit are omitted from the UI stream but the final message still reports the
   truncation metadata.

7. **Frame-protocol failure modes (G9).** The runtime-checked frame ADTs must define transitions for
   **malformed**, **duplicate**, **out-of-order**, and **unknown** frames (reusing the existing
   `error_result` machinery in `tool_envelope_dispatch`), rejecting out-of-protocol frames rather than
   silently accepting them.

8. **Concurrency opt-in policy (resolves Open Q #3).** The deferred arm is sequential by construction
   (contract #1 / "two arms"), so concurrency is only ever available to the **native-subprocess arm** —
   which already shrinks the question to "which subprocess batches parallelize." **Decision:** default
   **sequential**; a batch runs concurrently only when **every** call in it is a **read-only query**
   (e.g. `ReadFile` / `Search`) OR is a native-subprocess tool explicitly annotated **`parallel_safe`**.
   Anything that mutates FS/state or runs unannotated bash stays sequential. Implement `parallel_safe`
   as a **new per-tool capability flag alongside the existing pattern** — `streaming` /
   `needs_stderr_live` / `needs_hard_cancel` are already parsed per-tool at `tool_runtime.ail:118-120`
   and drive routing via `needs_delegation_for_process` (`tool_runtime.ail:15-18`); `parallel_safe`
   joins them, making concurrency a first-class capability, not a heuristic. Rollout widens the policy
   in order: read-only-only first (parity tests G6 a/b), then `parallel_safe`-annotated exec.

## Rollout & parity validation

Added in response to review (GPT-5.5 G5/G6). A core-loop change has a core-entry-wide blast radius
(the current dispatch path reaches `loop_v2` / `run_v2` / `conversation_loop_v2` / RPC entry /
`supervisor#main`).

- **Feature-flag gating (G5).** Ship `run_tool_select` behind a flag/config switch with the existing
  **sequential `dispatch_calls` as the fallback**, defaulting to the old path until parity tests pass
  — mirroring how `ws_loopback` itself ships (`MOTOKO_SCRATCHPAD_WS_LOOPBACK=1`, default off,
  `ws_loopback.ail:211`).
- **Parity test list (G6), scripted/provider-stub (no live network).** Acceptance requires passing:
  (a) two independent `BashExec` calls; (b) mixed `BashExec` + `ReadFile`; (c) policy `Deny` and
  `Pending` (preflight); (d) extension `Handled`; (e) scratchpad cell; (f) delegated / `ohmy_pi`
  routing; (g) cancellation before start **and** during live process output; (h) TUI
  `native_tool_calls`/`native_tool_results` `request_id` pairing; (i) provider replay with ordered
  `tool_call_id`s. These are **to-be-created** (no such Make/CI target exists yet — R12 discipline).

## Consequences

### Positive

- **Concurrent execution + live streamed output for native-subprocess tools** (revised per review
  B3): the `asyncExecProcess` arm streams stdout concurrently; deferred-dispatch tools remain
  sequential in Phase 1. Neither concurrency nor live output exists today (RESEARCH §12).
- **Mid-batch cancellation, arm-scoped** (revised per review B2): cancel in-flight *process-source*
  tools and *pending (not-yet-dispatched)* deferred tools via the control source — none exists today.
  In-flight deferred dispatches are not preemptible (see Negatives / contract #4).
- **Localized *edit*, honest about behavioral blast radius:** the coordinator, state threading, model
  call, and every hook API are untouched (RESEARCH §12) — but the change touches **two** `dispatch_calls`
  call sites and swaps the deferred dispatcher, and must honor the seven behavioral contracts above.
  Risk is contained to `run_tool_select` + those contracts, not to the loop scaffold.
- **DST leverage now:** the loop's frames become a tee-able trace, positioned to attack `001_DST`
  R7/R8 without waiting for v1.0.0 (RESEARCH §9) — *composition-only; recorder spike pending.*
- **Zero extension churn in Phase 1**, and a clean Phase-2 trajectory toward capability-scoped,
  observable hook channels (RESEARCH §10).
- **Deterministic at the scheduler layer:** `selectEvents` priority + round-robin ordering is
  replayable for already-arrived events (RESEARCH §9, §12); external peer/process/approval timing is
  *not* scheduler-governed and needs trace capture for full DST replay (see contract #5).

### Negative

- **Tool-result ordering becomes a real obligation.** Concurrent tools must still emit tool-results
  in `tool_call_id` order to preserve the DST invariant "tool-call IDs preserved" — collect by id,
  emit in call order (RESEARCH §12; contracts #4/#5; Open Question #2).
- **New behavioral surface to hold.** `run_tool_select` multiplexes process sources and deferred
  dispatch under one control source, and must honor the seven contracts above (dispatch matrix,
  policy preflight, scratchpad, cancellation transcript, event ordering, live-output boundary, frame
  failure modes) — materially more than the sequential fold it replaces (RESEARCH §12).
- **Cancellation is cooperative/coarse and arm-specific** — an in-flight *deferred* dispatch cannot
  be preempted (only pending deferred tools are cancellable); a *process-source* tool is reaped by
  exiting the loop, which forces siblings onto the synthetic-cancelled path (RESEARCH §7, §12;
  contract #4; Open Question #1). This is weaker than a user might expect from "cancel."
- **Concurrency must be opt-in.** Some tool batches have ordering/safety dependencies; the default
  must stay sequential unless a batch is known-independent (RESEARCH §12; Open Question #3).
- **The XOR holds while `std/ai`'s current surface holds** (revised per review M2 — it is an
  AILANG-API fact, not a Motoko choice): no streamed multiplexing *of the model call itself*; token
  rendering stays via the blocking step's `on_chunk` (RESEARCH §5). It dissolves the moment AILANG
  ships a `std/ai`→`StreamSource` adapter (RESEARCH §5 option C), independent of Phase 2's
  peer-process work — re-checked per the re-validation trigger below.

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
  already a state-threading coordinator with no shared mutable loop state (RESEARCH §12); the edit is
  localized to the tool phase (two call sites + the behavioral contracts above). A rewrite would
  discard verified, working hook/compaction/cost machinery for no
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
`loop_v2` `selectEvents` sketch) are **resolved** — see §5 and §12; do not re-open them. The review
round settled the *policy* of the dispatch-matrix, `Pending`, scratchpad, event-ordering, live-output,
and frame-failure contracts (behavioral contracts #1–#7). The three previously-open design questions
are now **decided** (with named validation), leaving a single residual:

- **Q2 tool-result ordering — RESOLVED into contract #4.** The hard rule is completeness +
  `tool_call_id` correlation (provider correlates by id, not position — `agent_loop_v2.ail:363-365`),
  so out-of-order completion is not a correctness hazard; call-order emission is a free DST/readability
  invariant. Closed by parity test G6(i).
- **Q3 concurrency opt-in — RESOLVED into contract #8.** Default sequential; promote a batch only when
  all calls are read-only queries or explicitly `parallel_safe` (a new per-tool capability flag
  alongside `tool_runtime.ail:118-120`). Closed by parity tests G6(a)/(b).

1. **Control-source priority + teardown interleave on cancellation** (the one residual of contract #4,
   §13 #3). The reap *sequence* is recommended (control source at highest priority; stop-admit →
   `disconnect` sockets → exit `runEventLoop` to reap process sources → synthesize cancelled; bound by
   `ws_loopback`'s `remaining=32`), and the "no per-source `kill` / no deferred preempt" limits are
   substrate-forced (RESEARCH §7). What stays open is the **exact control-source priority value** and
   whether `disconnect` must strictly precede loop-exit or may interleave — to be pinned by the
   cancellation smoke (parity test G6(g)).

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
surface. A **patch bump (v0.26.x) re-validates only if the `std/ai` or `std/stream` module hash
changed** (revised per review M4 — RESEARCH §8 documents `std/ai` signature churn and a stale MCP
`effects_catalog`, so a blanket patch exemption is too optimistic; gate on the stdlib module hash
rather than the version field). The smoke suite (`smoke/README.md`) is the validation harness; no new
CI/Make target is assumed by this ADR — any such target is **to-be-created** as part of Phase-1
implementation, not a precondition of the decision.

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

_**Reviewer: GLM 5.2 (`openrouter/z-ai/glm-5.2`) — 2026-07-01.**
Grounded against current source (`src/core/agent_loop_v2.ail`, `packages/motoko_scratchpad/ws_loopback.ail`,
`src/core/test/stub_step.ail`, `ailang.toml`), the `./smoke/` proofs, and RESEARCH §1–§13. Every
`file:line` below was re-read this session; no PR numbers invented._

Overall: the decision is sound and the provenance discipline is the best I have reviewed — the
verified-vs-inferred split, the stale-graph re-extraction, and the §5 XOR are exactly the kind of
load-bearing honesty `001_DST/ADR-001` R1–R15 demanded. I am not asking for a rewrite. But the
"refactor, not rewrite / one function changes" framing understates the blast radius, and two of the
headline Positive consequences overstate what the deferred-dispatch model actually delivers. These
should be tightened before the ADR leaves `Proposed`.

### Blocking (must address before `Accepted`)

**B1. "One function changes" is false as stated — `dispatch_calls` has TWO call sites in `loop_v2`,
and the sketch shows only one.** The §12/§"Phase-1 change" pseudocode substitutes
`run_tool_select` only in the `finish_reason == "tool_calls"` arm. But `loop_v2` calls
`dispatch_calls` at **two** sites: `agent_loop_v2.ail:1454` (the tool_calls arm, the one sketched)
**and** `agent_loop_v2.ail:1341` (the `hybrid_tools` arm — `extract_bash` synthesizes a single
`BashExec` `ToolCall` from a fenced shell block and dispatches it through the *same* `dispatch_calls`
pipeline). The hybrid path is a real, shipped, default-capable branch (`hybrid_tools` is a `loop_v2`
parameter, `agent_loop_v2.ail:1111`), not a dead path. The ADR must either (a) state explicitly that
`run_tool_select` replaces `dispatch_calls` at **both** sites and what that means for a single-element
synthesized batch (concurrency is moot; cancellation/live-output semantics still differ from the old
sequential call), or (b) justify keeping the hybrid path on the old sequential dispatch while only the
tool_calls arm becomes concurrent — which is a real design decision the ADR currently silently omits.
The ADR flags the sketch as "illustrative pseudocode, not literal source" (line 237), and the decision
text says "generalize `dispatch_calls`" (line 50) which implies all call sites — but neither makes the
second site explicit. As written, an implementer following the sketch would leave the hybrid arm on
`dispatch_calls` and either keep two parallel code paths or break hybrid mode. *Severity: blocks the
`run_tool_select`" claim at line 277.* **Code-graph grounding:** the fresh core extract (`stale=false`,
`coverage 24/24 ok`, `incomplete=false`, `approximate=true`, built 2026-06-30) confirms the
`loop_v2 → dispatch_calls` edge in `invokes` (one row), and also shows `loop_v2 → synthesize_hybrid_bash_call`
and `loop_v2 → extract_bash` (the hybrid arm's helpers) as real outgoing invokes — so the graph *sees*
the hybrid code path. But per `tools/code-graph/AGENTS.md`, `invokes` is an **unordered set** of
source-parsed approximations ("must not treat call/effect rows as compiler-derived facts"), so it
records the relationship once and **cannot establish multiplicity** — it cannot tell me `dispatch_calls`
is invoked twice. Source (`:1341` and `:1454`) is the only way to establish the two call sites; this is
the documented graph limitation, not a graph failure.

**B2. The "mid-batch cancellation" Positive consequence (line 274) overstates without the Negative's
arm-specific qualification (lines 292–294).** The cancellation picture splits by arm:
- **Process-source tools** (`asyncExecProcess`): the control source fires **during** `selectEvents`;
  the handler can return `false` to stop the loop, reaping the subprocess (which "dies when the event
  loop exits," RESEARCH §7). Mid-batch cancellation **IS real** for this arm.
- **Deferred-dispatch tools**: an in-flight `dispatch_tool_envelope` runs as a **blocking call in the
  enclosing sequential context** (RESEARCH §4; `ws_loopback.ail:183,203` — `dispatch_deferred_request`
  blocks, `loop_until_done` does one deferred dispatch per iteration). The control source can only be
  observed **between** deferred dispatches, never during one — an in-flight deferred tool **cannot** be
  cancelled. Only not-yet-dispatched tools in the batch can be cancelled.
The Positive bullet ("mid-batch cancellation via the control source") reads as applying to all tools;
the Negative ("a mid-flight blocking dispatch cannot be preempted") qualifies only the deferred-dispatch
case. These are not strictly contradictory — the Positive is general, the Negative is a qualifier — but
the Positive's unqualified scope misleads. Reword to split by arm: "cancel in-flight process-source
tools and pending (not-yet-dispatched) deferred-dispatch tools." (The teardown-primitive concern for the
`Control(Cancel) -> tear down sources` sketch arm is tracked separately as S3 below.)

**B3. "Concurrent tool execution" is true only for the `asyncExecProcess` (native-subprocess) arm;
the deferred-dispatch arm is sequential.** The "two arms" section (lines 247–251) correctly
distinguishes process-source tools from deferred-dispatch tools, but does not state the consequence:
deferred dispatch is one blocking call at a time in the enclosing context, so two env-delegated /
AI-subagent / FS tools cannot run concurrently with each other — only the native-subprocess tools
concurrently stream stdout. The proportion of process-source vs. deferred-dispatch tools in a typical
batch depends on the tool mix and the `ohmy_pi`/`backend_for_v2` routing
(`agent_loop_v2.ail:831`), so the ADR should not imply concurrency is universal. The Positive bullet
(line 274) should be split: "concurrent execution + live streamed output **for native-subprocess
tools**; deferred-dispatch tools remain sequential in Phase 1." Additionally, the sketch uses
`dispatch_tool_envelope` (line 232) for the deferred-dispatch arm, but the current `dispatch_calls`
does **not** call `dispatch_tool_envelope` — it uses `dispatch_one` (native, `agent_loop_v2.ail:850`),
`dispatch_tool_handle` (extension-handled, `:811`), and `delegated_deferred_message` (delegated,
`:840`). `dispatch_tool_envelope` is defined in `src/core/tool_envelope_dispatch.ail:36` and is called
only by `ws_loopback.ail:188`. So the sketch does not merely rename `dispatch_calls` →
`run_tool_select`; it also substitutes a different dispatch function for the deferred arm — further
undermining "one function changes." The ADR's "illustrative pseudocode" disclaimer (line 237) covers
this, but the scope gap should be named explicitly.

### Should-address

**S1. The "deterministic by construction" claim (lines 256, 282) covers select ordering, but the
per-call event *sequence* changes and the ADR should specify the new contract.** Today `loop_v2` emits
a batched `native_tool_calls` event (`agent_loop_v2.ail:1448`, pre-dispatch, carrying `request_id`)
and a paired `native_tool_results` event (`:1455`, post-dispatch, same `request_id`), with per-call
events (`native_tool_denied`, `ext_tool_handled`, `delegated_tool_deferred`) fired **from inside**
`dispatch_calls` in call-list order. The TUI's `renderToolCalls`/`applyNativeToolResults` consumers
pair on `request_id` (per the comment block at `:1440–1446`). Under deferred dispatch, per-call
events still fire **outside** the `selectEvents` handler (during `dispatch_tool_envelope` between
select iterations), so the `emit_event` `Trace`-effect side channel is NOT interleaved with select
events. The real, narrower concern is that the per-call event *sequence* changes from today's
call-list order (the `call :: rest` recursion at `:743,756`) to select-priority/round-robin order
(whichever
tool-request frame the select processes first). For deferred-dispatch tools backed by external
WebSocket sources, frame *arrival* order depends on the env-server's response timing — external to
`selectEvents`'s determinism, which governs only the ordering of already-arrived events. So
"deterministic by construction" is true for the select layer but does not extend to external
peer-timing. The ADR says events are "unchanged" (line 200) but should specify: (a) the per-call
event sequence under `run_tool_select` (select-priority order, not call-list order); (b) that DST
replay requires controlling the peer (env-server) for deferred-dispatch tools, not just the select;
(c) that the batched `native_tool_calls`/`native_tool_results` pair still brackets
`run_tool_select` (preserving the TUI's `request_id` pairing). **Code-graph grounding:** `q callers
emit_event` confirms `emit_event` is called at distance 1 from **both** `loop_v2` (the batched pair)
**and** `dispatch_calls` (the per-call events) — the graph sees both emitters but, `invokes` being an
unordered set, cannot express their temporal ordering. Source + the TUI consumer contract
(`:1440–1446`) are the only evidence for the ordering concern.

**S2. `stream_id` namespace collision risk between model `text_delta` and live tool stdout.** The
model's `on_chunk` (`agent_loop_v2.ail:1201`, `! {IO}`) renders `thinking_delta`/`text_delta` events
keyed by `session_id`/`stream_id` into a per-`stream_id` TUI buffer (`:1196–1197`). "Live tool
output" introduces a *second* stream of chunks on the same `session_id`. The ADR does not specify
`stream_id` allocation for tool stdout (a distinct id per tool_call_id? a shared "tool" stream?).
Without it, tool stdout and model tokens can be conflated in the TUI's per-stream buffer. Minor for
the decision, but it gates the "live streamed output" benefit and should be a named sub-decision, not
an implementation afterthought.

**S3. "Tear down sources" (sketch, line 231) names an operation no cited API provides.** RESEARCH §7
lists `asyncExecProcess` (read-only, dies with the loop) and WebSocket `connect`/`disconnect`
(disconnect is named in RESEARCH §1's substrate table). There is no per-source `cancel`/`close`/`kill`
primitive cited for a process source — only `disconnect` for a socket. The sketch should either name
the primitive (`disconnect` for sockets; "exit `runEventLoop` to reap the subprocess" for process
sources, with the consequence that sibling in-flight tools' results are lost) or move the arm to
Open Question #1's scope. As written the arm reads as resolved.

### Minor / framing

**M1. Decision Drivers (lines 100–106) states the DST R7/R8 wins as motivation without the body's
"asserted by composition, not yet demonstrated" caveat** (lines 261–262, 391–393). A reader of
Decision Drivers alone over-weights a still-unproven claim. Add a one-line "(composition-only; spike
pending, RESEARCH §9/§13 #6)" qualifier to the R7/R8 bullet.

**M2. "The XOR is permanent for Phase 1" (line 297) conflates an AILANG-API fact with a Phase-1
scoping decision.** The XOR is a property of `std/ai`'s current surface, not a choice Motoko makes;
it dissolves the moment AILANG ships a `std/ai`→`StreamSource` adapter (RESEARCH §5 option C),
independent of Phase 2's peer-process work. The version-pin re-validation section (lines 353–357)
correctly treats it as a re-checkable fact; the Negative bullet should match that framing ("gated on
`std/ai`'s current surface, re-confirmed per the trigger below") rather than "permanent."

**M3. "Carry the `Stream` effect at extension hook call sites" (lines 124–127) is already satisfied,
not a new obligation.** `loop_v2`'s effect row already includes `Stream` (`agent_loop_v2.ail:1125`)
and `dispatch_calls`' already declares `Stream` (`:740`, sourced from `on_tool_handle`'s declared
effects per the comment at `:729–730`). The genuinely new obligation is that the **core itself**
calls `selectEvents`/`runEventLoop` (today only extension hooks like `ws_loopback` do). Reword to
"the core begins calling `selectEvents`/`runEventLoop` (already permitted by the existing `Stream`
in `loop_v2`'s row)" so the reader doesn't infer a new effect-ceiling grant is needed. **Code-graph
grounding:** `std_calls` for the core profile returns **zero** rows for `selectEvents`/`runEventLoop`/
`asyncExecProcess`/`transmit`/`sourceOfConn` — `src/core/**` calls no `std/stream` primitives today.
The only shipped usage is `ws_loopback.ail`, which is outside the core profile (0 rows in `funcs` for
`ws_loopback`/`loop_until_done`/`collect_one`). So the graph corroborates that Phase 1 *introduces*
`std/stream` into the core; the ADR's shipped-precedent evidence is source-only, not graph-verifiable
in the default profile.

**M4. Re-validation trigger exempts patch bumps (lines 356–357) despite documented `std/ai` churn.**
RESEARCH §8 notes `std/ai` signatures "churned across recent minors" and that the MCP
`effects_catalog` was stale. A patch bump *can* ship a stdlib change. The patch exemption is
reasonable but optimistic; consider "patch bumps re-validate only if the `std/ai` or `std/stream`
module hash changed" rather than blanket exemption.

**M5. The "no AILANG language dependency" driver (lines 112–114) is slightly circular as a
*motivation*.** It is a true *constraint* (Phase 1 is buildable on v0.26.0) but as motivation it
reads as "we chose Phase 1 because Phase 1 needs no new language." The substantive motivation is the
concurrency/cancellation/DST leverage above it; the no-language-dependency line is better framed as a
risk/feasibility note than a driver.

### Code-graph grounding (per `tools/code-graph/AGENTS.md`)

All queries against the fresh core extract (meta: `stale=false`, `source_stale=false`,
`coverage 24/24 ok`, `incomplete=false`, `approximate=true`, `profile=core`, `include_tests=false`,
built 2026-06-30, AILANG v0.26.0 commit `3b52a24`). `row_counts`: `funcs 388`, `invokes 486`,
`effect_edges 516`, `std_calls 558`. Per AGENTS.md, call/effect rows are **source-parsed
approximations**; `incomplete=false` means "fully extracted", not "compiler-true"; `invokes` is an
**unordered set** (records a relationship, never a count or ordering).

- **`loop_v2 → dispatch_calls`** confirmed in `invokes` (one row). The graph also shows `loop_v2 →
  synthesize_hybrid_bash_call` and `loop_v2 → extract_bash` (from `src/core/parse`) — the hybrid arm's
  helpers — so the graph sees the hybrid code path. It **cannot** establish that `dispatch_calls` is
  invoked *twice* (unordered set); source `:1341` and `:1454` does. → grounds B1.
- **`dispatch_calls` effect under-approximation CONFIRMED.** `effect_edges` for `dispatch_calls` =
  `{Clock, FS, IO, Process, Trace}` (duplicated per reachability path), **missing** `AI, Env, Net,
  SharedMem, Stream` vs the source signature at `:740` (`{FS,Process,IO,Clock,AI,Env,Net,SharedMem,
  Stream,Trace}`). This exactly matches the ADR's provenance note (b). *Implication:* the graph would
  mislead an implementer about `run_tool_select`'s required effect row — source is mandatory for the
  effect ceiling.
- **`loop_v2 → AI` CONFIRMED** in `effect_edges` (via `LIKE '%loop_v2%'`); `loop_v2`'s graph effects =
  `{AI, Clock, Env, FS, IO, Process, Trace}`, **missing** `Net, SharedMem, Stream` vs source `:1125`.
  The ADR's specific claim ("`loop_v2 → AI` now carried") holds; the ADR's phrasing "graph and source
  agree on the **effect**" (line 185) is scoped to `AI` specifically, not full-row agreement, so the
  missing `{Net,SharedMem,Stream}` for `loop_v2` is the same under-approximation pattern as
  `dispatch_calls` — consistent with the graph's source-parsed nature, not an ADR oversight. Noted for
  completeness. *Query caveat:* an exact `WHERE func_slug = '...#loop_v2'` returned **empty** in the
  chDB CSV scan while `LIKE` returned the rows — a `#`-slug equality-filter quirk, not a data absence.
  Anyone re-validating must use `LIKE` or the `q` subcommands, not raw `=` on `#`-slugs.
- **`dispatch_step` invisible to the core graph CONFIRMED.** 0 rows in `funcs` (LIKE `%dispatch_step%`)
  and 0 `loop_v2 → dispatch_step` invokes edges — because the core profile excludes `src/core/test/**`
  (`extract.sh`; AGENTS.md). The model channel is invisible to `invokes` by construction; the ADR's
  profile-boundary explanation (lines 188–193) is correct, and the earlier "record-field indirection"
  framing in RESEARCH §12 / DIAGRAM §0 was indeed the wrong diagnosis.
- **`emit_event` called from both `loop_v2` (d=1) and `dispatch_calls` (d=1)** — `q callers emit_event`.
  The graph sees both emitters but cannot express their temporal ordering (unordered set). → grounds S1.
- **Zero `std/stream` usage in `src/core/**`** — `std_calls` returns no `selectEvents`/`runEventLoop`/
  `asyncExecProcess`/`transmit`/`sourceOfConn`. The shipped precedent (`ws_loopback.ail`) is **outside
  the core profile** (0 rows in `funcs`). → grounds M3; also: the ADR's single strongest evidence point
  (the shipped loopback) is **not graph-verifiable** in the default profile — only source can vouch for it.
- **Hook topology CONFIRMED.** `loop_v2 → {dispatch_pre_step, dispatch_response_intercept,
  dispatch_solver_candidate}` (all `src/core/ext/runtime`); `dispatch_calls → {dispatch_tool_policy,
  dispatch_tool_handle, dispatch_one, tool_call_to_envelope}` — matches the ADR's "four hook points"
  claim (lines 200–205) exactly.

### Verified this review (ground truth re-read)

- `dispatch_calls` sequential fold, `call :: rest` recursion: `agent_loop_v2.ail:731,743,756`. ✓
- `dispatch_calls` full effect row incl. `Stream`: `agent_loop_v2.ail:740`. ✓
- `loop_v2` effect row incl. `AI`: `agent_loop_v2.ail:1125`. ✓
- `dispatch_step` call + import: `agent_loop_v2.ail:1202`, import `:62`; def `src/core/test/stub_step.ail:110`
  (confirms the ADR's "core profile excludes `src/core/test/**`" explanation for the missing
  `invokes` edge). ✓
- **Second `dispatch_calls` call site (hybrid_tools arm, NOT in the ADR's sketch):**
  `agent_loop_v2.ail:1341` (synthesized `[synth_call]` batch). ✓ — basis for B1.
- `dispatch_tool_envelope` NOT called by `dispatch_calls`: grep confirmed 0 matches in
  `agent_loop_v2.ail`; def at `src/core/tool_envelope_dispatch.ail:36`, called only by
  `ws_loopback.ail:188`. The sketch's deferred arm uses it; current `dispatch_calls` uses
  `dispatch_one` (`:850`), `dispatch_tool_handle` (`:811`), `delegated_deferred_message` (`:840`).
  ✓ — basis for B3.
- `finish_reason != "tool_calls"` branch + `dispatch_solver_candidate`: `agent_loop_v2.ail:1302,1352`. ✓
- Batched event pair around dispatch: `native_tool_calls` `:1448`, `native_tool_results` `:1455`
  (both keyed by `request_id` `:1447`). ✓ — basis for S1.
- Deferred-dispatch template: `ws_loopback.ail:154,183,194,210`; flag
  `MOTOKO_SCRATCHPAD_WS_LOOPBACK=1` default off at `:211`. ✓ — basis for B2/B3.
- Effect ceiling excludes `Msg`/`Cog`: `ailang.toml:47`. ✓
- Code-graph (fresh, core profile): `loop_v2 → dispatch_calls` ✓; `dispatch_calls` effects
  under-approximated to `{Clock,FS,IO,Process,Trace}` (missing `AI,Env,Net,SharedMem,Stream`) ✓;
  `loop_v2 → AI` ✓ (but `loop_v2` effects also miss `Net,SharedMem,Stream`); `dispatch_step` absent
  from `funcs`/`invokes` (profile excludes `src/core/test/**`) ✓; `emit_event` called from both
  `loop_v2` and `dispatch_calls` (d=1) ✓; zero `std/stream` calls in `src/core/**` ✓; `ws_loopback`
  outside core profile (0 rows) ✓. Query caveat: `=` on `#`-slugs returns empty in chDB CSV scan —
  use `LIKE` or `q` subcommands. ✓ — full table above.

**Revise and re-circulate (stay in `Proposed`).** Address B1–B3 (two call sites + `dispatch_tool_envelope`
conflation; cancellation scope by arm; concurrency-only-for-subprocess-arm), then S1–S3 (event-sequence
contract + peer-timing caveat; `stream_id` allocation; teardown primitive). The M-items are editorial.
None of B1–B3 changes the *decision* (adopt `run_tool_select`); they correct the *scope/risk*
representation so the implementer and the
DST ADR's readers aren't misled about what Phase 1 delivers. The provenance, version-pin, and
rejected-alternatives sections need no change — those are the ADR's strongest parts.

— GLM 5.2

---

_**Reviewer: GPT-5.5 - 2026-07-01. Review status: done by GPT-5.5.**
Additional critique, intentionally not repeating the GLM 5.2 findings except where the consequence is
different. Grounded first through `tools/code-graph` per `tools/code-graph/AGENTS.md`, then through
source-index lines where the graph cannot prove ordering, multiplicity, or package-local details._

**Code-graph grounding used by GPT-5.5.** Queries were run with
`python3 tools/code-graph/query/cgq.py` against the default `core` graph. Metadata: `stale=false`,
`source_stale=false`, `incomplete=false`, `coverage 24/24 ok`, `profile=core`,
`include_tests=false`, built `2026-06-30T19:43:41Z`, AILANG v0.26.0 commit `3b52a24`, row counts
`funcs=388`, `invokes=486`, `effect_edges=516`, `std_calls=558`, `source_chunks=388`,
`source_lines=28253`. Per `tools/code-graph/AGENTS.md`, call/effect rows are source-parsed
approximations, not compiler facts; `invokes` is unordered and cannot prove call-site multiplicity or
temporal ordering. Those facts are grounded with source-index hits instead.

Graph/source-index facts this review relies on:

- `dispatch_calls` invokes `dispatch_tool_policy`, `dispatch_tool_handle`, `dispatch_one`,
  `tool_call_to_envelope`, `backend_for_v2`, `delegated_deferred_message`, scratchpad helpers,
  `emit_event`, `emit_scratchpad_result_if_present`, and message builders (`invokes` query on
  `src/core/agent_loop_v2#dispatch_calls`).
- `dispatch_one` invokes `run_native_batch` and `tool_result_item_to_json`; `dispatch_tool_envelope`
  also invokes `run_native_batch`, `tool_result_item_to_json`, `dispatch_tool_policy`, and
  `dispatch_tool_handle` (`invokes` query on both functions).
- Source-index hits find `dispatch_calls` at `agent_loop_v2.ail:731`, recursive arms at
  `:756/:807/:828/:841/:857/:892/:915/:942/:962`, and external call sites at `:1341` and `:1454`.
- Source-index hits find `Pending` handling in `dispatch_calls` (`agent_loop_v2.ail:758-760`) and
  `Pending` merge/return behavior in `ext/runtime.ail:182-196,449-471`; graph `callers
  dispatch_tool_policy` shows `dispatch_calls` and `dispatch_tool_envelope` as direct callers.
- Source-index hits find scratchpad fast-path import/call in `agent_loop_v2.ail:63,869` and
  `dispatch_tool_envelope`'s recursive-loopback error in `tool_envelope_dispatch.ail:38`.
- Source-index hits find provider/tool-result correlation warnings and TUI result-shape comments in
  `agent_loop_v2.ail:362-365,477-499,610-615,637-640,660,692-705`.
- Source-index hits find `tool_result_item_to_json` at `tool_dispatch_adapter.ail:66,178` and
  `tool_envelope_dispatch.ail:5,48`; they find `mk_meta` and stdout/stderr truncation metadata at
  `tool_runtime.ail:183,851,869,908,917`.
- Source-index hits find process capability flags `streaming`, `needs_stderr_live`, and
  `needs_hard_cancel` in `tool_runtime.ail:118-120,881-886`; today's native runtime returns a
  delegated-backend error for those features rather than implementing them in-process.
- `effect_edges` under-approximate some declared rows, as GLM already noted; for example graph rows
  for `dispatch_calls` show only `Clock/FS/IO/Process/Trace` despite the source signature declaring
  more effects. This review uses graph reachability to identify contracts and source signatures for
  exact effect ceilings.

Overall: I agree with the Phase-1 direction, but the ADR still reads more like a feasible architecture
than an implementation contract. The risky missing piece is not "can Motoko call `selectEvents`?" It
is preserving the existing tool-result, policy, extension, TUI, and provider contracts while changing
tool execution from a recursive call-list fold into an event loop.

### Blocking (must address before `Accepted`)

**G1. The ADR treats "native subprocess tool" as if it were equivalent to today's native tool
dispatcher, but it is not.** Current native execution is not just `bash` stdout. Graph grounding:
`invokes` shows `dispatch_calls -> dispatch_one`, `dispatch_one -> run_native_batch`, and
`dispatch_one -> tool_result_item_to_json`; source-index hits show `tool_result_item_to_json` and
`mk_meta`/stdout/stderr metadata. That means the current path routes a mixed ADT of tools through
`tool_runtime.ail`: file reads/writes/edits, search, bash, tests, path validation, truncation
metadata, `stdout`/`stderr` hashes, exit codes, and tool-specific JSON shapes. The ADR's
`asyncExecProcess` source only explains live stdout for subprocess-like tools; it does not explain
how `ReadFile`/`WriteFile`/`EditFile`/`Search` remain synchronous, how stderr and exit code are
captured for live process tools, or how this relates to today's `streaming`/`needs_stderr_live`/
`needs_hard_cancel` flags, which `tool_runtime` currently classifies as delegated-supervisor features
rather than native in-process features. It also does not state how the final model-facing JSON remains
compatible with `tool_result_item_to_json`. Required fix: define the Phase-1 dispatch matrix per tool kind:
unchanged synchronous local tools, live-process tools, extension-handled tools, delegated tools, and
cancelled tools; for each, state the final `Message.content` shape and whether it is expected to
match today's `dispatch_one` output.

**G2. The current `Pending` approval mechanism is incompatible with the advertised concurrent select
phase unless approvals are resolved before source startup or moved onto a nonblocking source.** Graph grounding: `callers dispatch_tool_policy` shows
`dispatch_calls` and `dispatch_tool_envelope` as direct callers; source-index hits show the
`Pending` arm in `dispatch_calls` and the `Pending` merge contract in `ext/runtime`. `dispatch_calls`
handles `Pending` by emitting `tool_pending` and then blocking on `readLine()`
(`agent_loop_v2.ail:762-794`; blocking is source/stdlib-grounded, not graph-proven). If
`run_tool_select` starts other tool sources first and then hits a pending approval path, the whole
event loop is blocked in stdin approval and the control/cancel source cannot be observed. Required
fix: specify a policy preflight stage, make approval input a proper select source, or explicitly
state that `Pending` pauses all in-flight concurrency and why that is acceptable.

**G3. The scratchpad fast path will regress if `run_tool_select` uses `dispatch_tool_envelope`
naively.** Graph grounding: `invokes` for `dispatch_calls` includes `is_scratchpad_tool_name`,
`scratchpad_extension_active`, `scratchpad_cells_arg`, and `emit_scratchpad_result_if_present`.
Source-index hits also find the `exec_scratchpad_cell_ws` import/call and
`dispatch_tool_envelope`'s recursive-loopback error. `dispatch_calls` special-cases scratchpad before
normal `dispatch_tool_handle` (`agent_loop_v2.ail:864-893`) and calls `exec_scratchpad_cell_ws`;
`dispatch_tool_envelope` explicitly returns an error for `scratchpad`/`Scratchpad`
(`tool_envelope_dispatch.ail:36-39`). The ADR's sketch uses `dispatch_tool_envelope` for the
deferred arm, so the most literal implementation changes scratchpad behavior from "handled through
the existing WS cell path" to "recursive scratchpad loopback is disabled." Required fix: keep the
scratchpad special case in `run_tool_select` or state that Phase 1 intentionally disables/replaces it.

**G4. Cancellation needs a provider-valid transcript contract, not just "emit cancellation
tool-results."** Graph/source-index grounding: source-index search for `tool_call_id` finds the
provider-correlation comments and message builders in `agent_loop_v2.ail`; `invokes` shows
`dispatch_calls -> tool_result_message`, `policy_denied_message`, and `delegated_deferred_message`.
Because `invokes` is unordered, final message ordering must be specified from source/design, not
inferred from the graph. On cancellation, the loop still has an assistant message containing N
`tool_calls`; the next model step must receive exactly the tool-role messages that provider expects.
The ADR should define whether completed results are preserved, whether cancelled-but-not-started and
cancelled-in-flight calls each get synthetic tool-role messages, what `exit_code/stdout/stderr/error`
shape those messages use, and whether the final list is serialized in original call order.

### Should-address

**G5. The rollout plan is too abrupt for a core-loop change.** Graph grounding: `callers
dispatch_one` shows the current dispatch path reaches `loop_v2`, `run_v2`, `run_v2_from_messages`,
`run_v2_with_stub`, `conversation_loop_v2`, RPC entrypoints, and `supervisor#main`, so the blast
radius is core-entry-wide even if the direct edit is local. Phase 1 should require a feature flag or
config switch with sequential `dispatch_calls` as the fallback until parity tests pass.

**G6. The ADR needs an explicit parity test list.** Graph grounding: the test cases come from
`dispatch_calls` outgoing edges (`dispatch_tool_policy`, `dispatch_tool_handle`, `backend_for_v2`,
`dispatch_one`, `delegated_deferred_message`, scratchpad helpers) plus source-index hits for batched
TUI events and `tool_call_id` correlation. Acceptance should include scripted/provider-stub tests
for: two independent BashExec calls; mixed BashExec plus ReadFile; policy Deny and Pending; extension
Handled; scratchpad; delegated/ohmy_pi behavior; cancellation before start and during live process
output; TUI `native_tool_calls`/`native_tool_results` request pairing; and provider replay with
ordered `tool_call_id`s.

**G7. "Live tool output" needs a model-vs-UI boundary.** Source-index grounding: hits show
`tool_result_message` and `envelope_to_tool_message` preserve model-facing `tool_call_id`, while TUI
comments describe separately rendered event payloads. Graph edges do not encode payload data flow.
The ADR should explicitly forbid feeding partial stdout chunks into the model transcript unless a
separate provider protocol is defined.

**G8. Backpressure and output limits are not optional implementation details.** Graph/source-index
grounding: source-index search finds `mk_meta` in `tool_runtime.ail` and its use in Bash/Test/process
result construction; `invokes` shows `dispatch_one` and `dispatch_tool_envelope` both route through
`run_native_batch` and `tool_result_item_to_json`. A streamed process source can emit unbounded
chunks before completion. The ADR should name per-tool and per-batch byte limits, truncation
representation, and whether chunks beyond the UI limit are dropped, summarized, or only omitted from
the live stream.

### Minor / framing

**G9. "Protocol encoding - runtime-checked frame ADTs" needs a failure mode.** Graph/source-index
grounding: source-index hits show existing `error_result` machinery in `tool_envelope_dispatch` and
existing denial/delegated synthetic tool messages in `agent_loop_v2`; the new frame protocol has no
corresponding `run_tool_select` function in the graph today. Add malformed, duplicate, out-of-order,
and unknown-frame transitions to the protocol.

**G10. The ADR should distinguish "unchanged hook APIs" from "unchanged hook scheduling."** Graph
grounding: `dispatch_calls` outgoing edges include both hook calls and `emit_event`; `effect_edges`
for `dispatch_calls` include observable effects (`IO`, `Trace`, `FS`, `Process`, `Clock`) and
under-approximate the source signature. The graph confirms observability but cannot prove order.
Reword the claim to "APIs unchanged; scheduling contract defined below."

**G11. `selectEvents` determinism should be scoped to the AILANG scheduler, not to wall-clock I/O.**
Graph grounding: `std_calls` in the core graph has no current `selectEvents`/`runEventLoop`/
`asyncExecProcess` usage in `src/core/**`, so the determinism claim is about proposed new core calls
plus cited research, not established current core behavior. External process output timing,
WebSocket peer timing, and approval input timing remain outside the scheduler unless captured and
replayed as trace input.

**G12. The implementation sketch should stop implying a single generic `source_for(call)`.** Graph
grounding: the `dispatch_calls` outgoing edge set fans out to policy, extension, backend choice,
scratchpad special cases, native dispatch, delegated synthetic results, event emission, and message
conversion. A more honest sketch would show `policy_preflight(calls)`, `partition(process_live,
local_sync, extension_or_deferred, denied)`, and `assemble_tool_messages_in_call_order(...)`.

**Revise and re-circulate (stay in `Proposed`).** The decision can remain "adopt Phase-1
`run_tool_select`," but the ADR should not advance to `Accepted` until it specifies dispatcher
parity, policy sequencing, scratchpad behavior, cancellation transcript shape, rollout gating, and
behavioral tests.

- GPT-5.5

---

### Author response — disposition (2026-07-01)

Every comment was verified against source before acting (the reviewers were correct on all
load-bearing claims — two `dispatch_calls` call sites at `:1341`/`:1454`; `dispatch_calls` uses
`dispatch_one`/`dispatch_tool_handle`/`delegated_deferred_message`, not `dispatch_tool_envelope`;
`dispatch_tool_envelope` hard-errors on scratchpad at `tool_envelope_dispatch.ail:37-38`; `Pending`
blocks on `readLine()` at `:769`; scratchpad special-case at `:868-869`). The **decision is
unchanged** (adopt `run_tool_select`); the scope/risk representation and the implementation contract
were tightened. Status stays **Proposed**. The `Stream`-already-in-row (M3), two-call-sites (B1),
and `dispatch_step` profile-boundary facts were re-confirmed against the fresh core extract.

| # | Where addressed |
|---|---|
| **B1** two call sites / blast radius | Decision → "Scope of the edit, stated honestly"; both `:1341`+`:1454` named, hybrid arm decided |
| **B2** cancellation scope by arm | Positive bullet 2 (arm-scoped); contract #4; Negative "arm-specific" bullet |
| **B3** concurrency only for subprocess arm; not a rename | Decision bullet 2; "Two arms … `source_for` is a partition"; Positive bullet 1 |
| **S1** event-sequence contract + peer-timing | Observability caveats (1)(2); contract #5 |
| **S2** `stream_id` allocation | Contract #6 (distinct `stream_id` per `tool_call_id`) |
| **S3** teardown primitive | Contract #4 (`disconnect` / loop-exit; no per-source `kill`); Open Question #1 |
| **M1** DST driver caveat | Decision Drivers DST bullet ("composition-only; spike pending") |
| **M2** XOR "permanent" → API-gated | Negative "XOR holds while `std/ai`'s surface holds" |
| **M3** `Stream` already granted | Scope IN bullet ("core begins calling `selectEvents` … no new grant") |
| **M4** patch-bump re-validation | Re-validation trigger (gate on `std/ai`/`std/stream` module hash) |
| **M5** no-language-dependency framing | Moved to a "Feasibility note (not a driver)" |
| **G1** dispatch matrix per tool kind | Contract #1 (matrix table) |
| **G2** `Pending` deadlock | Contract #2 (policy preflight) |
| **G3** scratchpad regression | Contract #3 (keep `exec_scratchpad_cell_ws` special-case) |
| **G4** provider-valid cancellation transcript | Contract #4 |
| **G5** rollout gating | "Rollout & parity validation" (feature flag, sequential fallback) |
| **G6** parity test list | "Rollout & parity validation" (a)–(i), to-be-created |
| **G7** live-output model-vs-UI boundary | Contract #6 (never append partial stdout to transcript) |
| **G8** backpressure / output limits | Contract #6 (byte limits + truncation via `mk_meta`) |
| **G9** frame failure modes | Contract #7 (malformed/duplicate/out-of-order/unknown) |
| **G10** APIs vs scheduling | Contract #5 ("APIs unchanged; scheduling contract defined") |
| **G11** determinism scoped to scheduler | Observability caveat (1); Positive "at the scheduler layer" |
| **G12** partition, not one `source_for` | "Two arms … `source_for` is a partition" |
