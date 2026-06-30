# Handoff: write the Phase-1 CSP-core ADR

Date: 2026-06-30
For: the agent drafting the ADR
Deliverable: `.agent/projects/003_CSP_core_refactor/ADR-001-csp-core-phase1.md`
Pinned toolchain: **AILANG v0.26.0** (commit `3b52a24`); `ailang.lock` pins v0.26.0.

## Your task

Write a **Phase-1-scoped** ADR deciding whether and how Motoko's core adopts a CSP-style,
`selectEvents`-based event loop. The feasibility research is **done** — do not re-derive it; cite it.
Your job is to turn it into a decision record that is **review-proof** (see "Avoid these pitfalls").

## Read first (in order)

1. `RESEARCH-csp-core-feasibility.md` — the evidence base. The load-bearing sections:
   §4 (shipped precedent), §5 (capability ledger + the LLM **XOR**), §6 (two gotchas), §7 (hard
   constraints), §9 (DST), §10 (extensions), §11 (CSP without typed channels), **§12 (the Phase-1
   `loop_v2` sketch — this is the heart of the decision)**, §13 (open questions).
2. `DIAGRAM-csp-architecture.md` — §0 current baseline vs §1–§3 proposals.
3. `smoke/` + `smoke/README.md` — the verified capability proofs (Net/AI-in-handler, cognition).
4. The shipped precedent: `packages/motoko_scratchpad/ws_loopback.ail`
   (`collect_one` / `dispatch_deferred_request` / `loop_until_done`).
5. The real loop: `src/core/agent_loop_v2.ail` (`run_v2:1494`, `loop_v2:1107`, `dispatch_calls:731`).
6. Cross-ref: `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` (esp. R7/R8 and
   its review section R1–R15 — your ADR must not repeat those mistakes).

## Scope — decide this, defer that

**IN (Phase 1, no AILANG language dependency):**
- Generalize `loop_v2`'s `dispatch_calls` into a `run_tool_select` that multiplexes tool sources +
  a control/cancel source via `selectEvents` (the localized refactor — RESEARCH §12).
- Deferred dispatch (the `ws_loopback` / `loop_until_done` shape — §4).
- The model call **stays a blocking `std/ai.stepWithStream`** (§5 XOR).
- Protocols as runtime-checked frame ADTs (poor-man's session types — §11).

**OUT (defer to a separate Phase-2 ADR, gated on AILANG v1.0/1.1):**
- Typed `Chan` / `send`/`recv` / session types; peer-process extensions; the SharedMem→message
  inversion; in-brain LLM-as-source.

## Load-bearing facts the ADR MUST reflect (with provenance)

- **The LLM XOR (§5):** on 0.26.0 you cannot have the LLM as a `selectEvents` source AND keep
  `std/ai`. Phase 1 keeps a **blocking** `std/ai` step; `selectEvents` wraps only the **tool** phase.
  **Do not claim in-brain LLM-as-source.** (True LLM source later = peer process, §5 option B.)
- **It's a refactor, not a rewrite (§12):** `loop_v2` is already a tail-recursive coordinator
  threading `msgs/step_idx/step_budget/totals/provider` with no shared mutable state. The change is
  **one function** (`dispatch_calls → run_tool_select`); the model call, all four hooks, compaction,
  cost/usage are untouched.
- **Production chose deferred dispatch (§4, §6):** in-handler effectful dispatch is *verified
  possible* (§5 smokes) but `ws_loopback` deliberately uses deferred — because handler-side effect
  errors exit 0 silently (§6 gotcha 2). Recommend deferred; state why.
- **Hard constraints (§7):** no persistent bidirectional subprocess in-brain (peers are external);
  cooperative, not parallel; cancellation is coarse/cooperative, not preemptive.
- **Gotchas to bake into the design (§6):** the brain must launch with `--caps …,Stream` (+
  `--stream-allow-*`) and, for any AI, `--caps AI` *and* `-ai <model>` (the `--help` example omits
  AI); add startup assertions.
- **`std/cognition` mailboxes are NOT a Phase-1 option (§1, §8):** shipped API but `NO_HANDLER` in
  native CLI + `Msg`/`Cog` outside Motoko's effect ceiling.
- **Code-graph correction (§12, source-verified):** `loop_v2` *does* carry the `AI` effect
  (`agent_loop_v2.ail:1125`) via the `StepProvider` seam — code-graph missed the edge. Trust source.

## Decisions the ADR should record (proposed — confirm or revise)

1. Adopt the Phase-1 `selectEvents` / `run_tool_select` model as the core's tool-execution
   mechanism, generalizing `ws_loopback.ail`.
2. Keep the model call blocking (`std/ai`), preserving the provider abstraction.
3. Use **deferred dispatch** (not in-handler) as the default, for error-surfacing.
4. Encode tool/control/loopback protocols as runtime-checked frame ADTs.
5. Defer all typed-channel / session-type / peer-process / SharedMem-inversion work to a Phase-2 ADR.

## Decision drivers (motivation — lead with these, not "feasibility")

- **DST** — observable boundaries + cancellation attack `001_DST/ADR-001` R7/R8 (RESEARCH §9).
- Concurrent tool execution, mid-batch cancellation, live tool output (today: sequential, no cancel).
- Extension-sandboxing trajectory (Phase 2 payoff; Phase 1 needs **zero** extension changes — §10).
- No language dependency for Phase 1 (de-risked: §5 capability ledger).

## Avoid these pitfalls (learned from `001_DST/ADR-001`'s R1–R15 review)

- **No unverified-mechanism claims (R8):** every seam cites verified evidence (RESEARCH §/smoke) or
  is flagged as an explicit risk. The recorder/observability story must name its mechanism.
- **No dangling references (R1):** cite real `file:line` / commits, not invented PR numbers.
- **Pin v0.26.0 and define a re-validation trigger for minor bumps (R10)** — surfaces drift (the
  research already caught stale MCP catalogs and `std/ai` signature churn).
- **Distinguish verified vs inferred** — flag the code-graph approximations explicitly.
- **CI/Make targets that don't exist yet → mark as to-be-created (R12).**
- **Don't list resolved questions as open (R6):** RESEARCH §13 #1/#2 are resolved; carry only the
  genuinely open ones (cancellation teardown, tool-result ordering, concurrency opt-in policy).

## ADR structure (match repo convention — see DST ADR-001)

`# ADR-001: CSP-style event-loop core for Motoko (Phase 1)` → Date · Status: Proposed · Context ·
Decision · Decision Drivers · **Scope (Phase 1 IN / Phase 2 OUT)** · Constraints · **The Phase-1
change** (`run_tool_select`, embed the §12 sketch) · Consequences (positive/negative) · Rejected
Alternatives (in-handler dispatch; raw `ssePost` losing `std/ai`; full rewrite; `std/cognition`
mailboxes; wait-for-v1.0) · Open Questions · leave a `## Review Comments` section for a reviewer.

## Acceptance criteria for the ADR

- Explicitly scoped to Phase 1; Phase 2 deferred with the gating reason (v1.0/1.1).
- Every load-bearing claim cites `RESEARCH §N` or `source file:line`.
- Honors the XOR — no in-brain LLM-as-source claim.
- Pins v0.26.0; names a re-validation trigger.
- Names the **localized** change (`dispatch_calls → run_tool_select`) as the core decision and shows
  what stays unchanged (the "refactor not rewrite" claim).
- Carries the honest caveats as risks: tool-result ordering by `tool_call_id`, non-subprocess tools
  via deferred envelope dispatch, cooperative-only cancellation, opt-in concurrency.
- No dependency on Ollama/OpenRouter/live network or unbuilt CI targets to be valid.

## Out of scope for you

Do not implement code, do not modify `agent_loop_v2.ail`, do not run the smokes (they're already
verified — cite them). Produce the ADR only.
