# Handoff: write the Phase-1 CSP-core implementation plan

Date: 2026-07-01
For: the agent writing the implementation plan
Deliverable: `.agent/projects/003_CSP_core_refactor/PLAN-phase1-run-tool-select.md`
(or a numbered set under `.agent/plans/003_CSP_core_phase1/` if it grows past ~1 file — match the
`.agent/plans/omp-style-python-eval/` numbered convention if you split it)
Pinned toolchain: **AILANG v0.26.0** (commit `3b52a24`); `ailang.lock` pins v0.26.0.

## Your task

Turn the **accepted-in-principle decision** in `ADR-001-csp-core-phase1.md` into a concrete,
sequenced, source-grounded **implementation plan** for replacing `loop_v2`'s tool phase
(`dispatch_calls`) with `run_tool_select`. The **decision is settled — do not re-open it**; the ADR
already weighed and rejected the alternatives (in-handler dispatch, raw `ssePost`, full rewrite,
`std/cognition` mailboxes, wait-for-v1.0). Your job is the *how* and the *in-what-order*, not the
*whether*.

The ADR is deliberately an **implementation contract**, not just a decision: it carries **8 behavioral
contracts** and a **rollout + parity-test** section that the plan must turn into ordered work. Treat
those as your spec.

## Read first (in order)

1. **`ADR-001-csp-core-phase1.md`** — your spec. The load-bearing parts:
   - **TL;DR** + **Decision** (`dispatch_calls → run_tool_select`, three sub-decisions: blocking
     `std/ai` / deferred dispatch / frame ADTs) and **"Scope of the edit, stated honestly"** (two call
     sites `:1341` + `:1454`; not a rename — it swaps the deferred dispatcher).
   - **The Phase-1 change** — the §12 sketch (illustrative pseudocode; the anchor functions are real,
     the `run_tool_select` body is yours to write) and the "two arms / `source_for` is a partition"
     framing.
   - **Behavioral contracts Phase 1 must preserve (#1–#8)** — this is the bulk of the work. Each is a
     binding sub-decision with a source anchor.
   - **Rollout & parity validation** — feature flag + sequential fallback + the 9-case parity list
     G6(a)–(i).
   - **Open Questions** — only Q1 (control-source priority / teardown interleave) is genuinely open;
     Q2/Q3 are resolved into contracts #4/#8.
   - **Version pin & re-validation trigger**, and **Verified vs. inferred** (what is graph-approximate).
2. `RESEARCH-csp-core-feasibility.md` — background only; the ADR already distilled it. Re-read
   **§4** (the `ws_loopback` deferred template you are generalizing), **§6** (the two gotchas), **§7**
   (hard constraints), **§12** (the sketch) if you need the *why* behind a contract.
3. `../001_DST/ADR-001-...md` — the DST ADR. The plan should leave seams the DST recorder can tee
   (ADR "Observability mechanism"); do not build DST itself, just don't foreclose it.
4. The shipped precedent you are generalizing: `packages/motoko_scratchpad/ws_loopback.ail`
   (`collect_one:154` / `dispatch_deferred_request:183` / `loop_until_done:194` /
   `exec_scratchpad_cell_ws:210`; flag `MOTOKO_SCRATCHPAD_WS_LOOPBACK` default-off `:211`).
5. The real loop: `src/core/agent_loop_v2.ail` (`loop_v2:1107`, `dispatch_calls:731`).

## Scope — plan this, defer that

**IN (Phase 1):**
- The `run_tool_select` implementation replacing `dispatch_calls` at **both** call sites
  (`agent_loop_v2.ail:1341` hybrid arm, `:1454` tool-calls arm).
- Delivering **all 8 behavioral contracts** as concrete, testable work items.
- The **feature-flag rollout** with sequential `dispatch_calls` as the default fallback until parity
  passes, plus the **parity test suite** (G6 a–i) and the **startup assertions** (RESEARCH §6:
  `--caps …,Stream` + `--stream-allow-*`; and `--caps AI` + `-ai <model>`).
- The `parallel_safe` per-tool capability flag (contract #8) alongside the existing
  `streaming`/`needs_stderr_live`/`needs_hard_cancel` flags.

**OUT (defer — do not plan these):**
- Anything in the ADR's **Phase 2 — OUT** list: typed `Chan` / session types, `spawn` peers,
  SharedMem→message inversion, in-brain LLM-as-source. All gated on AILANG v1.0/1.1.
- Building DST itself (separate `001_DST` track). The recorder **spike** is a nice-to-have, not on
  the Phase-1 critical path.
- Making the model call a source (the §5 XOR forbids it on v0.26.0).

## The spine of the plan (what to sequence)

A suggested ordering — you own the final sequence, but respect the dependencies:

1. **Scaffold + flag first.** Introduce `run_tool_select` behind the flag with the **old
   `dispatch_calls` path as default**, wired at both call sites, doing nothing new yet (a pass-through
   that still calls the sequential fold). This makes every later step independently shippable and
   reversible. Mirrors how `ws_loopback` itself ships.
2. **Policy preflight (contract #2)** — resolve `dispatch_tool_policy` for the whole batch (settling
   `Deny`/`Pending`, including the blocking `readLine()` approval at `agent_loop_v2.ail:758-769`)
   **before** any source starts. This must land before concurrency, or the select can deadlock on
   stdin.
3. **Partition + dispatch matrix (contracts #1, #8)** — `partition(calls)` into {local-sync,
   live-process, extension-handled, delegated, scratchpad, denied}; keep local-sync tools synchronous;
   preserve the scratchpad special-case (contract #3) ahead of the deferred arm. Wire the
   `parallel_safe` flag.
4. **The select loop itself** — generalize `loop_until_done`: the native-subprocess arm as
   `asyncExecProcess` sources (concurrent, live stdout), the deferred arm as one-at-a-time
   `dispatch_tool_envelope`-style dispatch, the control source at highest priority. Frame ADTs +
   failure modes (contract #7).
5. **Result assembly (contracts #4, #5)** — collect-by-`tool_call_id`, emit-in-call-order; the
   hard invariant is completeness + id-correlation (providers correlate by id, not position —
   `agent_loop_v2.ail:363-365,479`).
6. **Live output + events (contracts #5, #6)** — distinct `stream_id` per `tool_call_id` for tool
   stdout (never the model's `stream_id` at `:1196-1201`); never feed partial stdout to the model
   transcript; keep the batched `native_tool_calls`/`native_tool_results` `request_id` pairing
   (`:1447,1448,1455`); carry `mk_meta` truncation/byte limits.
7. **Cancellation (contract #4)** — the reap sequence (control priority → stop-admit → `disconnect`
   sockets → exit `runEventLoop` to reap process sources → synthesize cancelled), bounded by
   `remaining=32`. Pin the one residual (Open Q #1: exact priority value + disconnect/loop-exit
   interleave) via the cancellation smoke.
8. **Parity suite (G6 a–i)** + flip the flag default once green.

## Must-honor constraints (from the ADR — do not design around these)

- **Substrate-forced (RESEARCH §7):** no persistent bidirectional in-brain subprocess;
  `asyncExecProcess` is read-only and dies with the loop; **no per-source `kill`** (loop-exit is
  all-or-nothing); an in-flight **deferred** dispatch cannot be preempted; cooperative single loop,
  not parallelism.
- **The XOR (§5):** model call stays a blocking `std/ai` step. No LLM-as-source.
- **Gotchas (§6):** handler-side effect errors exit 0 silently → keep dispatch **deferred**; the `AI`
  effect needs **both** `--caps AI` and `-ai`/`-ai-stub`; the loop needs `--caps Stream` +
  `--stream-allow-*`. Add the startup assertions.
- **Extensions unchanged (§10):** no per-package changes; carry `Stream` at hook call sites (already
  in `loop_v2`'s row, `:1125`); deferred dispatch so a hook that hosts its own `runEventLoop`
  (`scratchpad`'s `ws_loopback`) never nests inside the core handler.

## Pre-verified source anchors (cite these — do not re-derive; re-read before editing)

All verified against source on v0.26.0 during ADR review. Trust source over the code-graph
(`invokes`/`effect_edges` are source-parsed approximations; e.g. the graph under-approximates
`dispatch_calls`' effect row and can't see the two call sites' multiplicity).

| Thing | Anchor |
|---|---|
| Two `dispatch_calls` call sites | `agent_loop_v2.ail:1341` (hybrid arm), `:1454` (tool-calls arm) |
| `dispatch_calls` def / fold / effect row | `:731` / `call :: rest` `:743`, recursion `:756` / effect row `:740` |
| Real dispatchers it uses (NOT `dispatch_tool_envelope`) | `dispatch_one` (`tool_dispatch_adapter`), `dispatch_tool_handle` (`ext/runtime`), `delegated_deferred_message` (`agent_loop_v2.ail:675`) |
| Deferred dispatcher the sketch names | `dispatch_tool_envelope` `tool_envelope_dispatch.ail:36`; **errors on scratchpad** `:37-38`; called only by `ws_loopback.ail:188` |
| `Pending` blocking approval | `agent_loop_v2.ail:758-769` (`readLine()`) |
| Scratchpad special-case | `:868-869` (`exec_scratchpad_cell_ws`), import `:63` |
| Batched events + request_id | `native_tool_calls:1448`, `native_tool_results:1455`, `request_id:1447` |
| Model stream / on_chunk / stream_id | `:1196-1201` |
| Tool capability flags + routing | `tool_runtime.ail:118-120`; `needs_delegation_for_process:15-18`; delegated-backend error `:885-886`; `mk_meta` truncation `~:183/851/869/908/917` |
| Provider id-correlation (Q2 hard rule) | `agent_loop_v2.ail:363-365`, `~479`, `~907` |
| `ws_loopback` template | `collect_one:154`, `dispatch_deferred_request:183`, `loop_until_done:194`, flag `:211` |
| Model dispatcher (blocking step) | `dispatch_step` `src/core/test/stub_step.ail:110`, imported `agent_loop_v2.ail:62`, called `:1202` (NB: lives under `src/core/test/`, excluded from the core code-graph profile) |
| Ext hooks | `dispatch_pre_step ext/runtime.ail:164`, `dispatch_response_intercept:252`, `dispatch_solver_candidate:303` |
| Effect ceiling (no `Msg`/`Cog`) | `ailang.toml:47` |
| Today's core has **zero** `std/stream` usage | grep `src/core/**` — you are introducing `selectEvents`/`runEventLoop` into the core |

## Avoid these pitfalls (same discipline the ADR held itself to)

- **Cite real `file:line` / commits** — no invented PR numbers or symbol names (the ADR was reviewed
  hard on exactly this; `001_DST/ADR-001` R1).
- **Mark unbuilt Make/CI targets as to-be-created** (R12) — the parity suite does not exist yet; no
  Phase-1 gate may depend on Ollama/OpenRouter/live network (scripted/provider-stub only).
- **Distinguish verified vs inferred** — flag anything you assert from the code-graph as approximate;
  re-run `tools/code-graph/extract.sh` if you lean on it (it goes STALE).
- **Don't re-decide** — if you find yourself arguing for in-handler dispatch or LLM-as-source, stop;
  that's settled. Surface genuine *new* findings in a "Plan notes / risks" section instead.
- **Keep the flag default = old path** until parity is green; every step independently revertible.
- **Re-validation trigger:** if the local `ailang` is not v0.26.0 (commit `3b52a24`), re-run the
  `./smoke/` proofs and re-confirm the §5 XOR before trusting the plan (ADR "Version pin").

## Suggested plan structure

`# Phase-1 implementation plan: run_tool_select` → Goal (1 paragraph, cite ADR) · Non-goals (the
Phase-2 OUT list) · Work breakdown (the 8-step spine above, each item = files touched + contract(s)
satisfied + test) · Contract-to-work traceability table (contracts #1–#8 → work items) · Parity &
smoke test plan (G6 a–i, scripted; startup-assertion smokes; cancellation smoke for Open Q #1) ·
Rollout & flag flip criteria · Risks / open (Open Q #1; the `parallel_safe` policy widening) ·
Effort/sequencing notes.

## Acceptance criteria for the plan

- Every one of the **8 behavioral contracts** maps to at least one concrete, testable work item
  (traceability table).
- Both `dispatch_calls` call sites (`:1341`, `:1454`) are explicitly addressed.
- The plan is **incrementally shippable behind the flag**, old path as fallback, each step revertible.
- The **parity suite G6(a)–(i)** is specified as scripted/provider-stub tests, marked to-be-created,
  with the flag-flip gated on it passing.
- Startup assertions for the `Stream`/`AI` cap gotchas are a work item.
- Open Q #1 (cancellation control-priority) has a named smoke that resolves it; Q2/Q3 are treated as
  **already decided** (contracts #4/#8), not re-opened.
- No dependency on live network / Ollama / OpenRouter / unbuilt CI to be valid.
- Every load-bearing claim cites a `file:line` from the anchors table or a fresh source read.

## Out of scope for you

Do not write production code, do not modify `agent_loop_v2.ail`, do not implement the parity tests,
do not build DST. Produce the **plan** only. If the plan surfaces a genuine gap in the ADR (not a
re-litigation of a settled decision), note it in a "Plan notes" section and flag it for the ADR's
`## Review Comments` — do not silently diverge from the ADR.
