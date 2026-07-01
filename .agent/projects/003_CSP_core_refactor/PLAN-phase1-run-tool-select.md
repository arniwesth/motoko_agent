# Phase-1 implementation plan: `run_tool_select`

Date: 2026-07-01
Status: Draft (implements the **Proposed** `ADR-001-csp-core-phase1.md`)
Pinned toolchain: **AILANG v0.26.0** (commit `3b52a24`); `ailang.lock` → `ailang_version: "v0.26.0"`.
Verified this session: local `ailang --version` = `v0.26.0` / commit `3b52a24`; `ailang.lock`
`ailang_version: "v0.26.0"`. All `file:line` anchors below were re-read against source on this
toolchain (see "Anchor re-verification log" at the end).

Relates to:
- `ADR-001-csp-core-phase1.md` — the spec this plan sequences (cited as **ADR §X** / **contract #N**).
- `RESEARCH-csp-core-feasibility.md` — the evidence base (cited as **RESEARCH §N**).
- `../001_DST/ADR-001-...md` — leave DST-teeable seams; do not build DST here (ADR "Observability").
- `packages/motoko_scratchpad/ws_loopback.ail` — the shipped deferred template being generalized.

---

## Goal

Turn the ADR's settled decision — replace `loop_v2`'s tool phase (`dispatch_calls`,
`agent_loop_v2.ail:731`) with **`run_tool_select`**, a `std/stream.selectEvents` multiplexer over
per-tool sources plus a control/cancel source, generalizing the shipped `ws_loopback.ail`
`loop_until_done` (`packages/motoko_scratchpad/ws_loopback.ail:194`) — into an **incrementally
shippable, flag-gated, source-grounded** implementation that lands at **both** `dispatch_calls` call
sites (`agent_loop_v2.ail:1341` hybrid arm, `:1454` tool-calls arm) while holding all **8 behavioral
contracts** of ADR "Behavioral contracts Phase 1 must preserve". The decision is settled (ADR
Decision); this plan is the *how* and *in-what-order* only. No AILANG language dependency: everything
here is buildable on v0.26.0 (ADR §"Phase 1 — IN").

## Non-goals (Phase-2 OUT — do not build here)

Per ADR §"Phase 2 — OUT" (gated on the unshipped `Chan` effect + session types, v1.0/1.1):
typed `Chan` / `send`/`recv` / compile-time session types; `spawn`-backed in-language peers;
`SharedMem`→message inversion; **in-brain LLM-as-source** (forbidden on v0.26.0 by the §5 XOR — the
model call stays a blocking `std/ai` step). Also out: **building DST itself** (`001_DST` track — the
recorder *spike* is a nice-to-have, not on this critical path); **making the model call a source**;
**making the `Pending` approval a select source** (deferred to Phase 2 per contract #2).

## The settled decisions this plan does not re-open

Per ADR Decision + Open Questions, treat as **decided**, not design space:
- Model call = blocking `dispatch_step` / `std/ai` (§5 XOR). No LLM-as-source.
- Dispatch mode = **deferred** (effects run in the enclosing sequential context; handler-side effect
  errors exit 0 silently — RESEARCH §6 gotcha 2, ADR Constraints).
- Protocol = **runtime-checked frame ADTs** (`run` / `tool-request` / `tool-result` / `done`).
- Q2 tool-result ordering → contract #4 (id-correlation is the hard rule; call-order is soft).
- Q3 concurrency opt-in → contract #8 (`parallel_safe` flag; default sequential).
- Only **Open Q #1** (control-source priority value + `disconnect`/`selectEvents`-exit interleave)
  stays open, pinned by the cancellation smoke (WI-6 implements; G6(g) validates).

If implementation surfaces a *genuinely new* gap (not a re-litigation), record it under
"Plan notes / ADR feedback" below and flag it for the ADR's `## Review Comments` — do not silently
diverge.

---

## Work breakdown

The spine is 9 work items (WI-0…WI-8), each **independently shippable behind the flag with the old
`dispatch_calls` path as the default fallback** until parity is green (ADR "Rollout & parity
validation"; mirrors `ws_loopback`'s `MOTOKO_SCRATCHPAD_WS_LOOPBACK` default-off at
`ws_loopback.ail:211`). Each item lists **Files touched**, **Contract(s) satisfied**, **Test**, and
**Revert**. Dependencies are called out; the ordering respects them (preflight before concurrency;
matrix before select; assembly before live-output; cancellation before flag flip).

### WI-0 — Scaffold + feature flag (default = old path)

Introduce `run_tool_select` as a **pass-through that still calls the sequential `dispatch_calls`
fold**, wired at **both** call sites, doing nothing new. This makes every later step shippable and
reversible from the first commit, exactly as `ws_loopback` shipped.

- **Files touched:** `src/core/agent_loop_v2.ail` (two call sites `:1341`, `:1454` — swap
  `dispatch_calls(...)` for `run_tool_select(...)`); a new module (suggest
  `src/core/run_tool_select.ail`) exporting `run_tool_select(rt, ctx, calls, workdir, step_idx,
  stream_id, ohmy_pi, session_id, control) -> [Message] ! {…}` whose v0 body is
  `dispatch_calls(rt, ctx, calls, …)` verbatim when the flag is off.
- **Flag:** `MOTOKO_RUN_TOOL_SELECT` (env, default `"0"`), read via `getEnvOr(...)` the same way
  `ws_loopback.ail:211` reads its flag. Off ⇒ delegate to `dispatch_calls`; on ⇒ the new path (built
  up across WI-1…WI-6). The single `control` argument is threaded from `loop_v2` (a new coordinator
  value; ADR §12 sketch `state{… control …}`) — inert until WI-6.
- **Effect row:** copy `dispatch_calls`' declared row verbatim —
  `{FS, Process, IO, Clock, AI, Env, Net, SharedMem, Stream, Trace}` (`agent_loop_v2.ail:740`).
  **Do not trust the code-graph here:** the fresh core extract under-approximates this row to
  `{Clock,FS,IO,Process,Trace}` (ADR provenance note (b); confirmed by both reviewers). Source
  `:740` is the ceiling — `Stream` is already present, so **no new effect-ceiling grant** is needed
  (ADR M3; `ailang.toml:47` `max` already lists `Stream`).
- **Both call sites, explicitly (B1):** `:1454` passes `result.tool_calls`; `:1341` passes the
  single synthesized `[synth_call]` hybrid batch. For the 1-element hybrid batch, concurrency is
  moot but the cancellation / live-output / event-ordering contracts still apply — so it routes
  through the *same* `run_tool_select`, not a parallel code path (ADR "Scope of the edit", B1
  disposition). **Decision inherited from ADR:** do **not** leave the hybrid arm on the old
  sequential dispatch.
- **Contracts satisfied:** none yet (scaffolding); establishes the revert boundary for #1–#8.
- **Test:** with flag off, the full existing test suite passes unchanged (pass-through is a no-op).
  With flag on, WI-0's pass-through still delegates to `dispatch_calls`, so behavior is identical —
  a "flag-on is a no-op at WI-0" assertion.
- **Revert:** flip the two call sites back to `dispatch_calls`; delete the module. Zero behavioral
  delta because the flag defaults off.

### WI-1 — Policy preflight (contract #2) — **must precede concurrency**

Resolve `dispatch_tool_policy` for the whole batch **before** any source starts, so the blocking
`readLine()` approval never runs while other sources are live (which would deadlock the select — the
control source can't be observed while stdin blocks).

- **Files touched:** `src/core/run_tool_select.ail` (new `policy_preflight(calls) -> (allowed,
  denied, pending_resolved)`), reusing `dispatch_tool_policy` (`ext/runtime`, invoked today from
  inside `dispatch_calls`), `policy_denied_message` (`agent_loop_v2.ail`, the `Deny` arm's builder),
  and the existing `Pending` `readLine()` machinery.
- **Anchor:** the `Pending` arm today emits `tool_pending` then blocks on `readLine()`
  (`agent_loop_v2.ail:758` `Pending(reason, default)` → `let raw = readLine();` ~`:769`; EOF/unparsed
  input applies the extension `PolicyDefault`). Preflight runs this loop **sequentially, up front**,
  for every call; `Deny`/`Pending` are settled before the select; only `Allow`/`NoOpinion` calls
  enter the partition.
- **Contracts satisfied:** **#2** (policy preflight — no stdin deadlock). Making approval its own
  select source is explicitly Phase-2 (contract #2, non-goals) — and is *grounded*: the substrate
  primitive already exists (`asyncReadStdinLines(name, priority) -> StreamSource`,
  `std/stream.ail:151`), so Phase 2's "approval as a select source" is a real, not speculative, path.
  Phase 1 keeps the simpler preflight.
- **Test:** G6(c) — a `Deny` and a `Pending` (approve, deny, and EOF→default) each resolve before any
  source starts; assert the control source is observable throughout (no stdin block during select).
- **Revert:** flag off.
- **Dependency:** none; **blocks WI-3** (select must not start with an unresolved `Pending`).

### WI-2 — Partition + dispatch matrix (contracts #1, #3, #8)

Replace the single-`source_for` framing with the honest **`partition(calls)`** (ADR "Two arms …
`source_for` is a partition", G12). Split the Allow-ed batch by tool kind and keep the scratchpad
special-case ahead of the deferred arm.

- **Files touched:** `src/core/run_tool_select.ail` (partition + per-kind routing);
  `src/core/tool_runtime.ail` (add the `parallel_safe` flag next to the existing per-tool flags at
  `:118-120`); read-only from `tool_dispatch_adapter.ail` (`dispatch_one:174`,
  `tool_result_item_to_json:66`).
- **Partition (contract #1 matrix, ADR table):**

  | Tool kind | Phase-1 execution | Result shape (must match today) |
  |---|---|---|
  | Local synchronous (ReadFile/WriteFile/EditFile/Search) | **unchanged**, synchronous, *not* a source | identical to `dispatch_one` → `tool_result_item_to_json` (`tool_dispatch_adapter.ail:66,174`) |
  | Live-process (bash w/ `streaming`/`needs_stderr_live`) | `asyncExecProcess` source arm (WI-3/WI-5) | must still carry stderr + exit code + truncation meta (`tool_runtime.ail` `mk_meta:183`) |
  | Extension-handled (`on_tool_handle → Handled`) | deferred arm, `dispatch_tool_handle` | unchanged envelope |
  | Delegated / `ohmy_pi` backend | deferred arm, `delegated_deferred_message` (`agent_loop_v2.ail:675`) | unchanged deferred-error shape |
  | Scratchpad (contract #3) | **special-cased ahead of deferred arm** → `exec_scratchpad_cell_ws` | unchanged WS-cell result |
  | Cancelled | synthetic tool-role message (WI-4) | new; defined in WI-4 |

- **Scratchpad (contract #3, G3) — do not regress.** Keep the pre-normal special-case
  `is_scratchpad_tool_name(envelope.tool) && scratchpad_extension_active(rt)` →
  `exec_scratchpad_cell_ws(...)` (`agent_loop_v2.ail:868`, import `:63`). **Do not** route scratchpad
  through the deferred dispatcher the sketch names: `dispatch_tool_envelope` **hard-errors** on
  scratchpad ("recursive scratchpad loopback is disabled", `tool_envelope_dispatch.ail:37-38`). The
  scratchpad hook hosts its *own* `runEventLoop` (`ws_loopback`), so deferred dispatch keeps it from
  nesting inside the core handler (ADR §10, no nested loops).
- **`parallel_safe` (contract #8).** Add `parallel_safe: arg_bool(args, "parallel_safe", false)`
  alongside `streaming`/`needs_stderr_live`/`needs_hard_cancel` at `tool_runtime.ail:118-120`; it
  joins the per-tool capability set the way `needs_delegation_for_process` (`:15-18`) consumes the
  others. Default **off** ⇒ default sequential. Concurrency (WI-3) is only ever offered to the
  native-subprocess arm, and only when **every** call in the batch is a read-only query
  (ReadFile/Search) **or** annotated `parallel_safe` (ADR contract #8). Anything mutating or
  unannotated bash stays sequential.
- **Routing note (verify at edit time):** the Native/Delegated split is
  `if ohmy_pi then backend_for_v2(envelope, true) else Native` (`agent_loop_v2.ail:831`, mirrored
  `:932`); today's native runtime *returns a delegated-backend error* for
  `streaming`/`needs_stderr_live`/`needs_hard_cancel` (`tool_runtime.ail:885-886`). Phase 1's
  live-process arm is where those features finally execute in-brain via `asyncExecProcess` — the
  matrix row above is the contract for what their result must still carry.
- **Contracts satisfied:** **#1** (dispatch matrix), **#3** (scratchpad), **#8** (`parallel_safe`
  flag — the flag lands here; the *policy widening* is a rollout step, WI-8).
- **Test:** G6(b) mixed BashExec + ReadFile (local-sync stays synchronous, its `Message.content`
  byte-identical to `dispatch_one`); G6(d) extension `Handled`; G6(e) scratchpad cell (routes to
  `exec_scratchpad_cell_ws`, **not** `dispatch_tool_envelope`); G6(f) delegated/`ohmy_pi`.
- **Revert:** flag off.
- **Dependency:** WI-1 (only Allow-ed calls partition).

### WI-3 — The select loop + frame ADTs (contract #7)

Generalize the shipped loop into the core. `ws_loopback` uses **single-connection** `runEventLoop`
(`std/stream.ail:120`, one WS `conn`); `run_tool_select` needs the **multi-source** multiplexer
`selectEvents(sources: [StreamSource], handler: (StreamEvent) -> bool)` (`std/stream.ail:160`). This is
the first WI that makes the core call `std/stream` — today **zero** `std/stream` primitives exist in
`src/core/**` (ADR M3; grep-confirmed). All primitives named here are **verified present in the
installed `std/stream.ail` on v0.26.0** (see the Substrate-primitive log at the end): `selectEvents:160`,
`asyncExecProcess:173`, `sourceOfConn:143`, `disconnect:126`, `transmit:99`, `StreamEvent` type `:53`.

- **Files touched:** `src/core/run_tool_select.ail` (the `selectEvents` handler + the frame ADTs);
  new frame types (suggest `src/core/tool_select_frames.ail`).
- **Frame ADTs (contract #7, runtime-checked) — scoped to the *deferred loopback* protocol.** The
  `run` / `tool-request` / `tool-result` / `done` frames are the **deferred-arm** WS loopback protocol
  (the ws_loopback shape), **not** the native arm — native process sources deliver `StreamEvent`
  (`SourceBytes`/`SourceText`, `std/stream.ail:53`) directly, no frame layer. Define the frame sum
  types + **transitions for malformed / duplicate / out-of-order / unknown frames**, reusing the
  existing `error_result` machinery (`tool_envelope_dispatch.ail:13`, `error_result(call, message)`) so
  out-of-protocol frames are **rejected**, not silently accepted. Any unavoidable handler-side error
  surfaces via a `done{status:error}` frame / result sentinel — **process exit cannot be relied on**
  (RESEARCH §6 gotcha 2; ADR Constraints).
- **Chunk→tool routing is by source *name*, not index (corrects the ADR §12 sketch).** The real event
  is `SourceBytes(name, bytes)` / `SourceText(name, string)` (`std/stream.ail:53`), and
  `asyncExecProcess(cmd, args, name, priority, chunkSize)` (`:173`) matches chunks by the `name` string
  — **not** by the `tool_i` index the sketch shows. **Decision:** set each native source's `name =
  tool_call_id` (or a bijective key), so `SourceBytes(name, …)` routes to the right call. This also
  supplies the per-`tool_call_id` separation contract #6 needs (WI-5).
- **Native arm = concurrent process sources under ONE `selectEvents`.** `asyncExecProcess` sources
  (`:173`, read-only stdout in `chunkSize`-byte events) stream concurrently; same-priority sources
  round-robin (`:158`). The handler returns **`false`** to stop (`selectEvents` "stops when handler
  returns false, idle timeout, or max duration", `:159`).
- **Deferred arm = sequential blocking, in the enclosing context — NOT interleaved into the concurrent
  select (new finding, `std/stream.ail:166`).** The `ws_loopback` deferred-yield discipline (capture →
  exit loop → dispatch effectfully in the enclosing function → `transmit` → re-enter;
  `collect_one:154`, `dispatch_deferred_request:183`, `loop_until_done:194`) **exits the loop to
  dispatch** — but exiting `selectEvents` **kills every live process source** ("the subprocess is
  killed when the source is closed or `selectEvents` exits", `std/stream.ail:166`). Therefore a mixed
  batch **cannot** deferred-yield while native sources stream, or it reaps them mid-stream.
  **Decision:** run the two arms as **separate stages**, never one interleaved select — the concurrent
  native-process stage under `selectEvents` to completion/cancellation, and the deferred arm as
  one-blocking-dispatch-at-a-time in the enclosing sequential context (its own single-conn
  `runEventLoop`/`transmit` per `ws_loopback`, or a direct blocking `dispatch_tool_envelope`). Two
  deferred tools never run concurrently (ADR B3); a deferred dispatch never nests inside the native
  select.
- **`selectEvents` self-stop conditions affect completeness (contract #4).** Because `selectEvents`
  can also stop on **idle timeout / max duration** (`:159`), not only handler-`false`, WI-4 assembly
  must synthesize a result for **every** call still unfinished when the select returns for *any*
  reason — a hung/slow tool must not orphan a `tool_call_id`.
- **Iteration bound.** Seed `ws_loopback`'s `remaining` cap (32, `loop_until_done` at
  `ws_loopback.ail:194-195`) to bound the deferred re-entry loop.
- **Contracts satisfied:** **#7** (frame failure modes). Lays the substrate for #4/#5/#6.
- **Test:** G6(a) two independent `BashExec` calls produce **correct, id-correlated results** through
  `run_tool_select` (the parity floor). *Concurrency* of the two is asserted only once (i) the
  live-process arm is validated (Plan-notes 4 substrate smoke) **and** (ii) they are `parallel_safe`
  (bash is not read-only, so contract #8 keeps them sequential by default — WI-8 widening). Also: a
  frame-protocol unit test drives malformed/duplicate/out-of-order/unknown frames and asserts
  rejection via `error_result`.
- **Revert:** flag off.
- **Dependency:** WI-1 (no live `Pending`), WI-2 (partition feeds the two arms).

### WI-4 — Result assembly (contracts #4, #5): collect-by-id, emit-in-call-order

Assemble the `[Message]` return so the next model step gets a provider-valid transcript.

- **Files touched:** `src/core/run_tool_select.ail` (collect-by-`tool_call_id`, assemble-in-call-order);
  reuse `tool_result_message` (`agent_loop_v2.ail` ~`:479`) and `delegated_deferred_message`
  (`:675`) for message shapes.
- **Hard invariant (Q2, provider correctness).** Every `tool_call` gets **exactly one** tool-role
  message carrying its **non-empty** `tool_call_id`, all present before the next model step.
  Providers correlate `tool_use → tool_result` **by id, not position** (`tool_result_message` comment
  ~`:477-479`: "Anthropic / OpenAI / Gemini all correlate tool_use → tool_result by this id"), and an
  empty `tool_call_id` is rejected **422** (`msgs_to_messages` comment ~`:363-365`). ⇒ **concurrency
  is provider-safe as long as ids are preserved**; out-of-order completion is not a correctness
  hazard (ADR contract #4).
- **Soft invariant (DST/readability).** Emit in original call order (collect-by-id, then
  assemble-in-call-order) — free, and keeps the DST "tool-call IDs preserved" invariant + trace
  stability.
- **Contracts satisfied:** **#4** (transcript completeness + id-correlation), **#5** (call-order
  assembly — the readable half).
- **Test:** G6(i) provider replay with ordered `tool_call_id`s: N calls, out-of-order completion,
  assert N tool-role messages, each with its non-empty id, in call order.
- **Revert:** flag off.
- **Dependency:** WI-3 (results arrive from both arms).

### WI-5 — Live output + TUI events (contracts #5, #6)

Wire live tool stdout to the **UI only**, and preserve the batched TUI event bracketing.

- **Files touched:** `src/core/run_tool_select.ail` (per-tool `stream_id` allocation, chunk
  rendering); the batched-event emit sites around the call (`agent_loop_v2.ail:1447-1455`);
  `tool_runtime.ail` `mk_meta` truncation contract (read-only, `:183/851/869/908/917`).
- **Model-vs-UI boundary (contract #6, G7).** Partial stdout chunks are **never** appended to the
  model transcript — the model still receives **one final tool-role message per call** (contract #1);
  live chunks render to the TUI exclusively.
- **Two `tool_call_id`-keyed namespaces (contract #6, S2).** There are **two** distinct ids to derive
  from `tool_call_id`, not one: (a) the `selectEvents` **source `name`** passed to `asyncExecProcess`
  (`std/stream.ail:173`), which routes `SourceBytes(name, …)` chunks to the right tool (WI-3); and
  (b) the TUI **`stream_id`** on the emitted chunk event. Both must be per-`tool_call_id`, and the TUI
  `stream_id` must **not** be the model's `stream_id` (which keys `thinking_delta`/`text_delta` at
  `agent_loop_v2.ail:1196-1201` via `emit_stream_chunk`) — otherwise tool output and model tokens
  collide in the TUI per-`stream_id` buffer.
- **Backpressure / truncation (contract #6, G8).** The live event granularity is `asyncExecProcess`'s
  `chunkSize` bytes-per-event (`std/stream.ail:173`); set it deliberately (the stdlib suggests 4096–65536).
  Carry per-tool and per-batch **byte limits + truncation** from `mk_meta` (`tool_runtime.ail:183`).
  Chunks beyond the live-stream limit are omitted from the UI stream, but the **final message still
  reports the truncation metadata**.
- **Event ordering & TUI pairing (contract #5, S1/G10).** Keep the batched `native_tool_calls` (pre,
  `:1448`) / `native_tool_results` (post, `:1455`) pair **bracketing** `run_tool_select`, keyed by
  `request_id = "step-${step_idx}"` (`:1447`) — the TUI's `request_id` pairing is preserved. The
  *per-call* event sub-order (`native_tool_denied` / `ext_tool_handled` / `delegated_tool_deferred`)
  becomes **select-priority order**, not call-list order. Claim = "hook & event **APIs** unchanged;
  scheduling/ordering contract defined here" (G10) — not "events unchanged".
- **Contracts satisfied:** **#5** (event ordering + `request_id` pairing), **#6** (live-output
  boundary, `stream_id`, backpressure).
- **Test:** G6(h) TUI `native_tool_calls`/`native_tool_results` `request_id` pairing survives; a
  live-output unit test asserts (i) no partial chunk enters the transcript, (ii) tool `stream_id` ≠
  model `stream_id`, (iii) truncation metadata present on the final message when the limit is hit.
- **Revert:** flag off.
- **Dependency:** WI-4 (final messages exist to bracket).

### WI-6 — Cancellation (contract #4; pins Open Q #1)

Make the control source real and implement the reap sequence. Cancellation is **two-stage** because
the two arms are separate stages (WI-3): during the **native concurrent stage** the control source
lives inside `selectEvents`; during the **deferred sequential stage** the control is checked *between*
dispatches (an in-flight deferred dispatch cannot be preempted).

- **Files touched:** `src/core/run_tool_select.ail` (control-source priority, teardown, synthetic
  cancelled messages); reuse the `delegated_deferred_message` envelope shape (`:675`) for the
  cancelled sentinel.
- **Control source = a real `StreamSource` at max priority.** `selectEvents` priority is an `int`,
  **"higher = checked first"** (`std/stream.ail:171`), so the control source gets a priority strictly
  greater than any tool source's — `Cancel` is then seen at the next select boundary. This is the
  concrete form of Open Q #1's "exact priority value."
- **Reap sequence (ADR contract #4).** (i) control source at max priority (above); (ii) stop admitting
  new deferred dispatches; (iii) **`disconnect` the underlying `StreamConn`** of each WS source —
  `disconnect` takes a `StreamConn` (`std/stream.ail:126`), and WS sources are built from a conn via
  `sourceOfConn(conn, name, priority)` (`:143`), so you disconnect the conn, not the source handle;
  (iv) **have the handler return `false` so `selectEvents` exits**, which reaps **all**
  `asyncExecProcess` process sources together ("the subprocess is killed when the source is closed or
  `selectEvents` exits", `std/stream.ail:166`) — note this is `selectEvents` exiting, **not**
  `runEventLoop`; (v) synthesize a cancelled tool-role message for **every** call without a result.
  Bound the deferred re-entry with the `remaining=32` cap (`ws_loopback.ail:194`).
- **Substrate-forced limits (not choices).** **No per-`StreamSource` `kill`** — verified against the
  `std/stream.ail` export surface: the only teardown primitives are `disconnect(conn: StreamConn)`
  (`:126`, WS-only) and `selectEvents` exit (`:166`); there is no `close(source)` for a process source
  (RESEARCH §7 confirmed at the stdlib). ⇒ loop-exit is all-or-nothing: reaping one subprocess ends
  its siblings, which take the synthetic-cancelled path.
  An in-flight **deferred** dispatch **cannot** be preempted — only pending (not-yet-dispatched)
  deferred tools are cancellable; a deferred call already mid-blocking runs to completion (kept if it
  returns before teardown, else marked cancelled). These are honest limits, surfaced in the ADR
  Negatives — do not design around them.
- **Cancelled message shape (contract #4).** Completed results preserved; not-yet-started and
  in-flight-cancelled calls each get a synthetic tool-role message carrying an `error`/cancelled
  sentinel (same envelope shape as `delegated_deferred_message`), each with its non-empty
  `tool_call_id` so WI-4's hard invariant still holds.
- **Open Q #1 (the one residual, now narrowed).** The mechanism is grounded (control = max-priority
  `int` source, `:171`; reap = `selectEvents` exit, `:166`; WS teardown = `disconnect(conn)`, `:126`).
  What stays empirical: the **exact priority value** (how far above the tool sources) and whether
  `disconnect(conn)` must strictly precede the `selectEvents` exit or may interleave — pinned by the
  cancellation smoke (G6(g)).
- **Contracts satisfied:** **#4** (cancellation transcript + reap policy). Resolves Open Q #1 via
  the smoke.
- **Test:** G6(g) cancellation **before start** (all synthetic-cancelled) **and during live process
  output** (running native tool reaped, siblings synthetic-cancelled, deferred-in-flight kept if it
  returns first). Assert the resulting `[Message]` is provider-valid (WI-4 invariant).
- **Revert:** flag off.
- **Dependency:** WI-3 (sources exist to tear down), WI-4 (synthetic messages join the assembled
  list).

### WI-7 — Startup assertions for the `Stream`/`AI` cap gotchas

Bake in the two operational gotchas (RESEARCH §6; ADR Constraints) as fail-fast startup checks.

- **Files touched:** the brain's startup path (where caps/handler are known — locate the launch
  assertion site; likely the supervisor/main entry that already parses caps). Add two assertions:
  1. **`AI` needs TWO grants:** `--caps …,AI` **and** a bound handler (`-ai <model>` or `-ai-stub`).
     `ailang run --help`'s example cap list **omits `AI`** — a documented trap (RESEARCH §6). Assert
     both present; fail loudly (the failure mode is silent exit 0, RESEARCH §6).
  2. **`Stream` needs the cap + allow-flags:** `--caps …,Stream` with `--stream-allow-*` (see the
     smoke invocations in `smoke/README.md`: `--caps IO,Net,Stream --stream-allow-http
     --stream-allow-localhost`). Assert before the first `selectEvents`.
- **Contracts satisfied:** none of #1–#8 directly; this is the ADR Constraints "Add startup
  assertions" work item — a hard prerequisite for the flag being safely flippable.
- **Test:** a startup-assertion smoke — launch with `--caps` missing `AI`, assert a **loud** failure
  (not silent exit 0); same for missing `Stream`/allow-flags. Scripted, no live network.
- **Revert:** the assertions are guard-only; harmless with the flag off, but gate them behind the
  flag if a launch-config edge case appears.
- **Dependency:** independent; can land any time, **must** land before WI-8 flip.

### WI-8 — Parity suite (G6 a–i) + flag flip

Author the parity suite as scripted/provider-stub tests, then flip the default once green.

- **Files touched:** a **to-be-created** test target (no such Make/CI target exists yet — R12
  discipline; the ADR "Rollout & parity validation" marks G6 to-be-created, and the Version-pin
  section states "no new CI/Make target is assumed … any such target is to-be-created"). Suggest a
  scripted harness under the project's test tree that runs each case with the flag **on** and asserts
  parity against the flag-**off** (`dispatch_calls`) baseline.
- **Parity list (all scripted / provider-stub — no live network, no Ollama/OpenRouter):**
  (a) two independent `BashExec` (correct id-correlated results; concurrent only when `parallel_safe`
  + live-process arm validated) · (b) mixed `BashExec` + `ReadFile` ·
  (c) policy `Deny` and `Pending` (preflight) · (d) extension `Handled` · (e) scratchpad cell ·
  (f) delegated / `ohmy_pi` routing · (g) cancellation before start **and** during live output ·
  (h) TUI `native_tool_calls`/`native_tool_results` `request_id` pairing · (i) provider replay with
  ordered `tool_call_id`s.
- **Flag-flip criterion:** flip `MOTOKO_RUN_TOOL_SELECT` default `"0"→"1"` **only when (a)–(i) all
  pass** and the startup-assertion smokes (WI-7) pass. Keep the old `dispatch_calls` path in-tree as
  the fallback for at least one release after the flip (so revert is a flag flip, not a code
  restore).
- **Concurrency-policy widening (contract #8 rollout).** Widen in order: **read-only-only first**
  (parity a/b) → then `parallel_safe`-annotated exec. Do not enable `parallel_safe`-exec concurrency
  until (a)/(b) are green.
- **Contracts satisfied:** validates **all** of #1–#8 via the parity matrix.
- **Test:** the suite is itself the test; CI target to-be-created.
- **Revert:** flip the default back to `"0"`.
- **Dependency:** WI-1…WI-7 all landed.

---

## Contract → work-item traceability

Every one of the 8 behavioral contracts maps to ≥1 concrete, testable work item.

| Contract | Work item(s) | Test(s) |
|---|---|---|
| **#1** Dispatch matrix by tool kind | WI-2 | G6(b),(d),(e),(f) |
| **#2** Policy `Pending` preflight (no deadlock) | WI-1 | G6(c) |
| **#3** Scratchpad special-case carried forward | WI-2 | G6(e) |
| **#4** Cancellation → provider-valid transcript (Q2 id-correlation + reap) | WI-4 (assembly), WI-6 (cancel/reap) | G6(g),(i) |
| **#5** Event ordering + `request_id` TUI pairing | WI-5 (bracketing), WI-4 (call-order) | G6(h),(i) |
| **#6** Live-output model-vs-UI boundary, `stream_id`, backpressure | WI-5 | live-output unit test; G6(a) |
| **#7** Frame-protocol failure modes (malformed/dup/OOO/unknown) | WI-3 | frame-protocol unit test |
| **#8** Concurrency opt-in (`parallel_safe`) | WI-2 (flag), WI-8 (widening) | G6(a),(b) |

Both `dispatch_calls` call sites are addressed in **WI-0** (`:1341` hybrid, `:1454` tool-calls) and
every later WI operates through the single `run_tool_select` both sites now call.

---

## Parity & smoke test plan

All tests are **scripted / provider-stub**; **no** Phase-1 gate may depend on live network, Ollama,
OpenRouter, or an unbuilt CI target (R12). The model call in any parity case uses the `Scripted`
`StepProvider` path (`dispatch_step` on `Scripted`, `stub_step.ail:110`, imported
`agent_loop_v2.ail:62`) — no real provider.

- **Parity suite G6(a)–(i):** as listed in WI-8. To-be-created target; flag-flip gated on green.
- **Startup-assertion smokes (WI-7):** missing-`AI`-cap and missing-`Stream`-cap launches fail loudly
  (guards the RESEARCH §6 silent-exit-0 trap). Model on the `smoke/README.md` cap invocations.
- **Cancellation smoke (Open Q #1):** G6(g) doubles as the empirical pin for the exact control-source
  priority value and the `disconnect`/loop-exit interleave — the one residual open question.
- **Frame-protocol unit test (contract #7):** malformed/duplicate/out-of-order/unknown → `error_result`
  rejection, never silent accept.

Re-use, don't reinvent: the `./smoke/` proofs already validate the load-bearing capability
(`Net`/`AI` in-handler, the §5 XOR); this plan's smokes are *behavioral parity*, layered on top.

---

## Rollout & flag-flip criteria

1. Land WI-0…WI-7 incrementally, **flag default off** the whole time; each WI independently
   revertible (flag flip). Old `dispatch_calls` path stays the default fallback.
2. Author G6(a)–(i) + startup + frame smokes (WI-8, WI-7, WI-3).
3. **Flip `MOTOKO_RUN_TOOL_SELECT` default `"0"→"1"` only when:** G6(a)–(i) green **and**
   startup-assertion smokes green **and** cancellation smoke has pinned Open Q #1.
4. Widen `parallel_safe` concurrency **after** flip, in order: read-only-only → `parallel_safe`-exec.
5. Keep `dispatch_calls` in-tree ≥1 release post-flip (revert = flag flip, not code restore).

Blast radius to watch (ADR "Rollout"): the dispatch path reaches `loop_v2` / `run_v2` /
`run_v2_from_messages` / `conversation_loop_v2` / RPC entry / `supervisor#main` — the flag confines
the risk to `run_tool_select` + the 8 contracts, not the coordinator scaffold.

---

## Risks / open

- **Open Q #1 (control-source priority + teardown interleave).** The reap *sequence* is decided
  (contract #4); the exact priority value and whether `disconnect` strictly precedes loop-exit is
  pinned by the cancellation smoke (G6(g)). Only residual open question — do **not** re-open Q2/Q3.
- **`parallel_safe` policy widening.** The flag lands in WI-2; the *policy* widening (which batches
  actually parallelize) is a staged rollout (WI-8). Risk is over-parallelizing a batch with hidden FS
  ordering deps — mitigated by default-sequential + read-only-first order.
- **Live-process arm is new in-brain territory.** Today `streaming`/`needs_stderr_live`/
  `needs_hard_cancel` return a delegated-backend error (`tool_runtime.ail:885-886`); WI-3/WI-5 are the
  first time those execute in-brain via `asyncExecProcess`. Verify the result still carries stderr +
  exit code + truncation meta (matrix row, contract #1) — this is the highest-novelty seam. **Open
  substrate question:** `asyncExecProcess` documents only **stdout as `SourceBytes`**
  (`std/stream.ail:15,164`); how a process source surfaces **stderr and exit code** is *undocumented*
  (a `Closed(int, string)` event exists, `:57`, but the docs describe it in the WS-close sense, not as
  a process exit-code carrier). WI-3 must **empirically determine** how the live-process arm obtains
  stderr + exit code (source event vs. a separate completion call); if the substrate cannot supply
  them live, live-process tools may need to stay on the delegated backend for Phase 1. Pin this with a
  small `asyncExecProcess` smoke before committing the live-process arm.
- **Two-arm phasing is forced, not stylistic (`std/stream.ail:166`).** A mixed batch cannot interleave
  concurrent native streaming with deferred-yield dispatch in one `selectEvents` (exiting the select
  to dispatch kills the live process sources). WI-3 runs the arms as separate stages. Risk: the staging
  changes wall-clock interleaving of a mixed batch vs today's strict call-order fold — acceptable under
  contract #5 (per-call event sub-order is explicitly no longer call-order), but call it out in review.
- **`selectEvents` self-stop (idle timeout / max duration, `:159`) can end the select before all tools
  finish.** WI-4 assembly must synthesize a result for every unfinished `tool_call_id` on *any* select
  return, not only on cancel — otherwise a slow/hung tool orphans an id and the next model step 422s
  (contract #4). Confirm the idle-timeout/max-duration knobs (if configurable) are set sanely for
  long-running bash.
- **Code-graph is STALE-prone and under-approximates effect rows.** Trust source signatures for the
  effect ceiling (`:740`, `:1125`), not the graph (ADR provenance (b)). Re-run
  `tools/code-graph/extract.sh` before leaning on any `invokes`/`effect_edges` claim.
- **Re-validation trigger.** If the local `ailang` is ever not v0.26.0 (commit `3b52a24`), re-run
  `./smoke/` and re-confirm the §5 XOR + the `selectEvents` surface before trusting this plan (ADR
  "Version pin"). Verified in-session as v0.26.0/`3b52a24` (see log below).

## Effort / sequencing notes

- **Critical path:** WI-0 → WI-1 → WI-2 → WI-3 → WI-4 → WI-5/WI-6 → WI-8. WI-7 is independent (land
  early). WI-5 and WI-6 both depend on WI-4 but are otherwise parallelizable.
- **Preflight before concurrency** is a hard ordering (WI-1 before WI-3): a `Pending` `readLine()`
  inside a live select deadlocks the control source.
- **Assembly before live-output/cancellation** (WI-4 before WI-5/WI-6): both need the final
  per-call message shape and the id-correlation invariant in place.
- **Smallest shippable increment:** WI-0 alone (pass-through, flag off) — zero behavioral delta,
  establishes the revert boundary.
- **Highest-risk increment:** WI-3 (first `std/stream` in core) + the live-process arm — budget the
  most validation here.

## Plan notes / ADR feedback

No settled decision is re-opened here. Four items for the ADR authors' attention (candidates for the
ADR's `## Review Comments`, **not** silent divergence) — items 3 and 4 are *new substrate findings*
surfaced by reading the installed `std/stream.ail` this session, which the ADR's illustrative §12
sketch does not account for:

1. **`run_tool_select` argument list.** `dispatch_calls` takes
   `(rt, ctx, calls, workdir, step_idx, stream_id, ohmy_pi, session_id)` (`agent_loop_v2.ail:731`).
   The ADR §12 sketch shows `run_tool_select(rt, ctx, calls, control)`. The plan threads the full
   `dispatch_calls` signature **plus** `control` (WI-0), since `workdir`/`step_idx`/`stream_id`/
   `ohmy_pi`/`session_id` are all load-bearing (session id for events, step id for `request_id`,
   stream id for the model-vs-tool `stream_id` boundary in contract #6). Flagged only because the
   sketch's short signature could mislead an implementer — not a decision change.
2. **`dispatch_one` effect row is narrower than `dispatch_calls`'.** `dispatch_one` is
   `! {FS, Process}` (`tool_dispatch_adapter.ail:174`), whereas `dispatch_calls` declares the full
   `{FS,Process,IO,Clock,AI,Env,Net,SharedMem,Stream,Trace}` (`:740`) because the wider effects come
   from the deferred/delegated/handle leaves and the events. `run_tool_select` must declare the full
   `dispatch_calls` row (it does the same leaf work); the local-sync arm's narrow row is a subset.
   Noted so WI-0 copies `:740`, not `:174`.
3. **The §12 sketch's single-`selectEvents`-with-`ToolRequest`-arm is not implementable as drawn.**
   The sketch shows one `selectEvents` whose handler both streams `SourceBytes` *and* does a deferred
   `dispatch_tool_envelope` on a `ToolRequest` frame. But deferred dispatch requires **exiting** the
   select (the ws_loopback discipline), and exiting `selectEvents` **kills every live process source**
   (`std/stream.ail:166`). So a mixed batch cannot do both in one select — the native concurrent arm
   and the deferred arm must be **separate stages** (WI-3 decision). This does not change the ADR
   decision (deferred dispatch, two arms), but the sketch's shape misleads; recommend the ADR note
   the arms are sequential *stages*, not one interleaved select.
4. **`asyncExecProcess` stderr / exit-code delivery is undocumented — a live-process-arm viability
   risk.** The stdlib documents only stdout→`SourceBytes` for process sources (`std/stream.ail:15,164`);
   the matrix (contract #1) requires the live-process result to still carry stderr + exit code +
   truncation meta. Whether the substrate can supply those *live* (vs. only via the delegated backend)
   is unverified. If it cannot, live-process tools stay delegated in Phase 1 and the "concurrent live
   output" Positive shrinks to read-only-query concurrency. Recommend the ADR flag this as a
   validation gate (a small `asyncExecProcess` smoke), not an assumed capability.

---

## Anchor re-verification log (v0.26.0, commit `3b52a24`, 2026-07-01)

Every anchor below was re-read against source this session (source is ground truth over the
code-graph, per `tools/code-graph/AGENTS.md`):

| Claim | Anchor | ✓ |
|---|---|---|
| Two `dispatch_calls` call sites | `agent_loop_v2.ail:1341` (hybrid `[synth_call]`), `:1454` (`result.tool_calls`) | ✓ |
| Hybrid arm synthesizes 1 call | `extract_bash` import `:51`; `synthesize_hybrid_bash_call:661`; `synth_call` built `:1315`, dispatched `:1341`; `hybrid_tools` param `:1111` | ✓ |
| Extension-handled dispatch | `dispatch_tool_handle` import `:60`, called `:811`/`:894`; `Handled(result_env)` `:813` | ✓ |
| `dispatch_calls` def + effect row | `:731`; row `{FS,Process,IO,Clock,AI,Env,Net,SharedMem,Stream,Trace}` `:740` | ✓ |
| Sequential fold recursion | `call :: rest` `:743`(≈); recurses on `rest` `:756` (+ `:807,828,841,857,892,915,942,962`) | ✓ |
| `Pending` blocks on `readLine()` | `Pending(reason, default)` `:758` → `readLine()` `:769` (exact) | ✓ |
| Scratchpad special-case | `is_scratchpad_tool_name && scratchpad_extension_active` → `exec_scratchpad_cell_ws` `:868`; import `:63` | ✓ |
| Native/Delegated routing | `backend_for_v2(envelope, true) else Native` `:831` (mirror `:932`) | ✓ |
| Provider id-correlation (Q2 hard rule) | empty `tool_call_id`→422 comment `:365`, `msgs_to_messages` def `:366`; `tool_result_message` id-correlation comment `:479`, def `:480` | ✓ |
| `delegated_deferred_message` | `agent_loop_v2.ail:675` | ✓ |
| Batched TUI events + `request_id` | `request_id="step-${step_idx}"` `:1447`; `native_tool_calls` `:1448`; `native_tool_results` `:1455` | ✓ |
| Model `stream_id`/`on_chunk`/`dispatch_step` | `emit_stream_chunk(...stream_id...)` `:1196-1201`; `dispatch_step(...)` `:1202` | ✓ |
| `loop_v2` effect row incl. `Stream` | `:1125` (`{AI,FS,Process,IO,Env,Net,SharedMem,Clock,Stream,Trace}`) | ✓ |
| `dispatch_step` def / import | `src/core/test/stub_step.ail:110`; import `agent_loop_v2.ail:62` (core profile excludes `src/core/test/**`) | ✓ |
| Deferred dispatcher (sketch names) | `dispatch_tool_envelope` `tool_envelope_dispatch.ail:36`; **scratchpad hard-error** `:37-38`; `error_result` `:13` | ✓ |
| `ws_loopback` template + flag | `collect_one:154`, `dispatch_deferred_request:183`, `loop_until_done:194` (`remaining` cap), `exec_scratchpad_cell_ws:210`, flag `MOTOKO_SCRATCHPAD_WS_LOOPBACK` default off `:211` | ✓ |
| Tool capability flags + routing | `streaming/needs_stderr_live/needs_hard_cancel` `tool_runtime.ail:118-120`; `needs_delegation_for_process:15-18`; delegated-backend error `:885-886`; `mk_meta` `:183/851/869/908/917` | ✓ |
| `dispatch_one` / `tool_result_item_to_json` | `tool_dispatch_adapter.ail:174` (`! {FS,Process}`) / `:66` | ✓ |
| Effect ceiling (no `Msg`/`Cog`) | `ailang.toml:47` `max=[IO,Env,AI,Net,FS,Process,SharedMem,Clock,Stream,SharedIndex,Rand,Trace]` | ✓ |
| Zero `std/stream` in `src/core/**` today | grep confirms no `selectEvents`/`runEventLoop`/`asyncExecProcess` in `src/core/**` | ✓ |
| Toolchain pin | `ailang --version` = v0.26.0 / `3b52a24`; `ailang.lock` `ailang_version:"v0.26.0"` | ✓ |

All Make/CI parity targets are **to-be-created** (none exist today). Line numbers in
`agent_loop_v2.ail` are exact as of this read but re-grep before editing (the file is edited often).

### Substrate-primitive log (`std/stream.ail`, installed v0.26.0)

Read this session at `/home/motoko/.local/share/ailang/std/stream.ail` — every `run_tool_select`
primitive named in this plan is verified present (closing the ADR's S3 "named a non-existent API"
class of risk):

| Primitive | Signature (abridged) | Line | Used by (WI) |
|---|---|---|---|
| `selectEvents` | `(sources: [StreamSource], handler: (StreamEvent) -> bool) -> unit ! {Stream}` | `:160` | WI-3 (multi-source multiplexer) |
| stop conditions | "stops when handler returns false, idle timeout, or max duration" | `:159` | WI-3/WI-4/WI-6 |
| same-priority order | "same-priority sources use round-robin to prevent starvation" | `:158` | WI-5 (event sub-order) |
| `asyncExecProcess` | `(cmd, args, name, priority, chunkSize) -> StreamSource ! {Stream}`; stdout→`SourceBytes` | `:173` | WI-3/WI-5 (native arm) |
| process kill semantics | "killed when the source is closed or `selectEvents` exits" | `:166` | WI-6 (reap); phasing note |
| priority semantics | "priority: dispatch priority (higher = checked first)" | `:171` | WI-6 / Open Q #1 |
| `StreamEvent` | `... | Closed(int,string) | SourceText(string,string) | SourceBytes(string,bytes)` | `:53` | WI-3 (frame handling); name-routing |
| `sourceOfConn` | `(conn: StreamConn, name, priority) -> StreamSource ! {Stream}` | `:143` | WI-6 (WS source from conn) |
| `disconnect` | `(conn: StreamConn) -> unit ! {Stream}` — **`StreamConn`-only, no per-`StreamSource` close** | `:126` | WI-6 (WS teardown) |
| `runEventLoop` | `(conn: StreamConn) -> unit ! {Stream}` — single-conn (ws_loopback's) | `:120` | contrast to `selectEvents` |
| `transmit` | `(conn: StreamConn, msg) -> Result[unit,_] ! {Stream}` | `:99` | WI-3 (deferred-yield transmit-back) |
| `asyncReadStdinLines` | `(name, priority) -> StreamSource ! {Stream}` — the Phase-2 approval-source | `:151` | (Phase-2, not built) |

*Two undocumented gaps* (Plan-notes 3/4): chunk→tool correlation is by **source name string**, not
the `tool_i` index the ADR sketch shows (`:53,173`); and `asyncExecProcess` **stderr/exit-code**
delivery is undocumented (`:15,164`) — both require a smoke before WI-3 commits the live-process arm.
