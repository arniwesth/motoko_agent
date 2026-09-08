# Handoff: implement Phase-1 `run_tool_select`

Date: 2026-07-01
For: the agent implementing the plan (writing production AILANG)
Deliverable: a working, flag-gated `run_tool_select` landed across WI-0…WI-8, with the parity suite
green and the flag default flipped — shipped as a sequence of independently-revertible commits.
Pinned toolchain: **AILANG v0.26.0** (commit `3b52a24`); `ailang.lock` pins v0.26.0.

## Your task

Implement the **accepted plan** in `PLAN-phase1-run-tool-select.md`: replace `loop_v2`'s tool phase
(`dispatch_calls`, `agent_loop_v2.ail:731`) with `run_tool_select` — a `std/stream.selectEvents`
multiplexer over per-tool sources + a control source — at **both** call sites
(`agent_loop_v2.ail:1341`, `:1454`), holding all **8 behavioral contracts**. The **plan is the spec
and the ADR decision is settled** — do not re-open the architecture (blocking `std/ai`, deferred
dispatch, frame ADTs, the two-arms partition, `parallel_safe`). Your job is to write the code in the
plan's order, prove each step, and gate the flag flip on parity.

This is a **refactor behind a feature flag**, not a rewrite. The coordinator, model call, all four
hooks, compaction, and cost/usage stay untouched (plan "Blast radius" Ring 1). Every work item ships
with the **old `dispatch_calls` path as the default fallback** until parity passes.

## Read first (in order)

1. **`PLAN-phase1-run-tool-select.md`** — your spec. Load-bearing parts, in priority order:
   - **TL;DR** + **Architecture (the new tool phase)** — the mermaid diagram *is* the target
     dataflow; build to it. Note the two **separate stages** (native concurrent / deferred sequential).
   - **Work breakdown WI-0…WI-8** — each item is `Files touched · Contract(s) · Test · Revert · Dependency`.
     This is your commit sequence. Respect the stated dependencies (preflight before concurrency;
     assembly before live-output/cancellation).
   - **Contract → work-item traceability** — the definition of done per contract.
   - **Substrate-primitive log** (end of plan) — every `std/stream` primitive you will call, with its
     verified `std/stream.ail:line` and signature. Do not re-derive these; do re-open the file.
   - **Plan notes / ADR feedback #3 and #4** — the two **substrate risks you must retire first**
     (name-not-index routing; undocumented `asyncExecProcess` stderr/exit-code). See "Do this before
     WI-3" below.
   - **Anchor re-verification log** — the `agent_loop_v2.ail` / `tool_runtime.ail` / etc. anchors.
     Re-grep before editing (the file moves).
2. **`ADR-001-csp-core-phase1.md`** — the 8 **behavioral contracts** (#1–#8) in full, the §5 XOR, the
   gotchas, and Open Q #1. The plan compresses these; the ADR is the authority on *why*. Do not
   re-litigate settled decisions (Q2/Q3 are contracts #4/#8).
3. **`packages/motoko_scratchpad/ws_loopback.ail`** — the shipped deferred template you are
   generalizing (`collect_one:154`, `dispatch_deferred_request:183`, `loop_until_done:194`,
   `exec_scratchpad_cell_ws:210`, flag `:211`). `run_tool_select`'s deferred arm and its flag
   discipline mirror this file.
4. **`/home/motoko/.local/share/ailang/std/stream.ail`** — the installed substrate. Re-read
   `selectEvents:160`, `asyncExecProcess:173`, `sourceOfConn:143`, `disconnect:126`,
   `StreamEvent:53`, priority/kill semantics `:159,166,171`.
5. **`src/core/agent_loop_v2.ail`** — the real loop. The two call sites (`:1341`, `:1454`),
   `dispatch_calls:731` (the fold you're replacing, to preserve its per-kind routing), the effect row
   `:740`, the batched events `:1447-1455`, model stream `:1196-1201`.
6. **`.agent/projects/003_CSP_core_refactor/smoke/`** — the existing capability proofs and
   `smoke/README.md` cap invocations; your new smokes layer on top.

## Do this before WI-3 (retire the two substrate risks first)

The plan's biggest unknown is whether the **native live-process arm** is even viable on v0.26.0.
Front-load two tiny smokes under `smoke/` **before** committing STAGEA — they can change the plan:

1. **`asyncExecProcess` stderr + exit-code smoke (Plan-notes #4).** The stdlib documents only
   stdout→`SourceBytes` (`std/stream.ail:15,164`). Contract #1 requires the live-process result to
   still carry **stderr + exit code + truncation meta**. Write a smoke that runs a command which
   writes to stderr and exits non-zero under `selectEvents`, and determine empirically how (or
   whether) stderr/exit-code surface (a `Closed(int, string)` event? a separate completion call?
   not at all?). **If they cannot be obtained live, live-process tools stay on the delegated backend
   for Phase 1** — update the plan's contract-#1 matrix row and note it for the ADR before proceeding.
2. **Source-name routing smoke (Plan-notes #3).** Confirm `asyncExecProcess(cmd, args, name, …)`
   delivers `SourceBytes(name, bytes)` keyed by the `name` string, so setting `name = tool_call_id`
   routes chunks to the right call. (The ADR §12 sketch's `tool_i` index is wrong on mechanism.)

Only after these pass (or the matrix is adjusted) should you build STAGEA. Everything else (WI-0,
WI-1, WI-2 sync/deferred arms, WI-7) is independent of this gate and can proceed in parallel.

## Scope — build this, defer that

**IN (Phase 1):** WI-0…WI-8 exactly as the plan sequences them — scaffold+flag, policy preflight,
partition+matrix+`parallel_safe`, the select loop + frame ADTs, result assembly, live output+events,
cancellation+reap, startup assertions, parity suite + flag flip. Deliver all 8 contracts as tested
code. The parity suite (G6 a–i) is **to-be-created** (no such Make/CI target exists) and is the
flag-flip gate.

**OUT (defer — do not build):** anything in the ADR's **Phase 2 — OUT** list (typed `Chan`, session
types, `spawn` peers, SharedMem→message, in-brain LLM-as-source); **DST itself** (the recorder spike
is optional, off the critical path); making the model call a source (§5 XOR forbids it on v0.26.0);
making approval a select source (`asyncReadStdinLines:151` exists but is Phase-2; use preflight).

## The spine (your commit sequence)

Follow the plan's Work breakdown verbatim. Summary of the ordering and its hard dependencies:

0. **WI-0 scaffold + flag** — `run_tool_select` as a pass-through to `dispatch_calls` at both sites,
   behind `MOTOKO_RUN_TOOL_SELECT` (default `"0"`). Copy the effect row from **source `:740`**, not
   the graph. Zero behavioral delta. This is your revert boundary.
1. **WI-1 policy preflight (#2)** — resolve the whole batch's policy (incl. blocking `readLine():769`
   approval) **before** any source starts. **Must land before WI-3** or the select deadlocks on stdin.
2. **WI-2 partition + matrix + `parallel_safe` (#1/#3/#8)** — the six-way partition; keep local-sync
   synchronous; keep the scratchpad special-case (`exec_scratchpad_cell_ws:868`, **not**
   `dispatch_tool_envelope`, which hard-errors on scratchpad `:37-38`); add `parallel_safe` beside the
   flags at `tool_runtime.ail:118-120`.
3. **WI-3 select loop + frame ADTs (#7)** — generalize single-conn `runEventLoop` → multi-source
   `selectEvents:160`; native arm concurrent, deferred arm sequential, **separate stages** (exiting
   the select kills process sources, `:166`); frame ADTs scoped to the deferred loopback protocol.
4. **WI-4 assembly (#4/#5)** — collect by `tool_call_id`, emit in call order; synthesize a result for
   **every** unfinished call on *any* select return (self-stop `:159`), so no id is orphaned (→422).
5. **WI-5 live output + events (#5/#6)** — UI-only stdout, distinct `stream_id` per `tool_call_id`
   (≠ model's `:1196-1201`); keep the batched `native_tool_calls`/`native_tool_results` `request_id`
   bracket (`:1447-1455`); truncation via `mk_meta`.
6. **WI-6 cancellation (#4; pins Open Q #1)** — control source at max priority (`:171`); reap =
   `disconnect(conn):126` for WS + `selectEvents` exit for process sources (`:166`); synthesize
   cancelled msgs. Two-stage cancellation. The cancellation smoke pins the exact priority value +
   interleave.
7. **WI-7 startup assertions** — fail loudly if `--caps AI` + `-ai/-ai-stub` or `--caps Stream` +
   `--stream-allow-*` are missing (silent-exit-0 trap). Independent; land early.
8. **WI-8 parity suite (G6 a–i) + flag flip** — scripted/provider-stub (`Scripted` `StepProvider`,
   `stub_step.ail:110`; no live network). Flip default `"0"→"1"` only when a–i + startup +
   cancellation smokes are green. Widen `parallel_safe` after flip (read-only-first).

## Must-honor constraints (from the plan/ADR — do not design around these)

- **Flag default = old path** until parity is green. Every WI independently revertible by flag flip.
  Keep `dispatch_calls` in-tree ≥1 release post-flip.
- **Both call sites.** `run_tool_select` replaces `dispatch_calls` at `:1341` (hybrid `[synth_call]`)
  **and** `:1454` (`result.tool_calls`). Same function, no parallel code path.
- **Effect row from source, not the graph.** Declare `run_tool_select`'s row from
  `agent_loop_v2.ail:740` (`{FS,Process,IO,Clock,AI,Env,Net,SharedMem,Stream,Trace}`). The code-graph
  under-approximates it — do not trust `effect_edges`.
- **Substrate-forced (RESEARCH §7, verified in `std/stream.ail`):** no per-`StreamSource` kill
  (`disconnect` is `StreamConn`-only, `:126`; process sources die only on `selectEvents` exit, `:166`);
  an in-flight deferred dispatch cannot be preempted; two arms are separate stages; cooperative single
  loop, not parallelism.
- **The XOR (§5):** model call stays a blocking `std/ai` step. No LLM-as-source.
- **Gotchas (§6):** handler-side effect errors exit 0 silently → keep dispatch **deferred**; surface
  any unavoidable handler error via a `done{status:error}` frame/sentinel, never process exit. The
  `AI` effect needs **both** `--caps AI` and `-ai`/`-ai-stub`; the loop needs `--caps Stream` +
  `--stream-allow-*` (WI-7 asserts both).
- **Extensions unchanged (§10):** no per-package changes; deferred dispatch so a hook hosting its own
  `runEventLoop` (scratchpad's `ws_loopback`) never nests inside the core handler.

## Pitfalls to avoid (same discipline the plan/ADR held)

- **Re-verify the toolchain first.** If local `ailang` is not v0.26.0 / `3b52a24`, **stop** and re-run
  the `./smoke/` proofs + re-confirm the §5 XOR and the `selectEvents` surface before trusting the
  plan's capability claims (plan "Re-validation trigger").
- **Re-grep every anchor before editing.** The plan's `agent_loop_v2.ail` line numbers are exact as of
  2026-07-01 but the file is edited often — confirm `file:line` before each edit.
- **Do not build the live-process arm on assumption.** Run the two substrate smokes above first; the
  stderr/exit-code result may force live-process tools to stay delegated.
- **Do not re-decide.** If you find yourself arguing for in-handler dispatch, LLM-as-source, or one
  interleaved select, stop — those are settled (ADR Rejected Alternatives; the `:166` separate-stages
  finding). Surface genuine *new* findings for the ADR's `## Review Comments`, don't silently diverge.
- **Mark unbuilt Make/CI targets as to-be-created.** No Phase-1 gate may depend on live
  network / Ollama / OpenRouter / an unbuilt CI target — scripted/provider-stub only.
- **Keep frame-protocol failure modes explicit** (malformed/duplicate/out-of-order/unknown → reject
  via `error_result`), never silent-accept.

## Acceptance criteria

- `run_tool_select` replaces `dispatch_calls` at **both** `:1341` and `:1454`, behind
  `MOTOKO_RUN_TOOL_SELECT` with the old path as default fallback.
- Each WI is a **separately shippable, revertible** commit; with the flag off, the full existing suite
  passes unchanged.
- All **8 behavioral contracts** are satisfied by tested code (map each to its WI per the plan's
  traceability table).
- The **parity suite G6(a)–(i)** exists (to-be-created target), is scripted/provider-stub, and passes;
  the flag-flip is gated on it + the startup + cancellation smokes.
- The two **substrate smokes** (stderr/exit-code; name-routing) have run and their outcome is recorded
  (plan updated if the live-process arm is not viable).
- **Open Q #1** is resolved by the cancellation smoke (exact control-source priority + disconnect/exit
  interleave); Q2/Q3 are treated as decided.
- Every load-bearing edit cites a re-verified `file:line`.

## Out of scope for you

Do not implement Phase-2 items, do not build DST, do not make the model call or approval a source, do
not change extension packages. If the plan surfaces a genuine gap (e.g. the stderr/exit-code smoke
fails), record it in the plan's "Plan notes / ADR feedback" and flag it for the ADR's
`## Review Comments` — do not silently diverge from the plan.
