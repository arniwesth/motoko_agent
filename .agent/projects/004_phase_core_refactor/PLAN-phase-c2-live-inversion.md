# Phase-C2 implementation plan: route the live driver through the pure core

Date: 2026-07-04
Status: Completed 2026-07-05 (WI-C14 gate passed; completes Phase C of the
**Proposed** `ADR-001-phase-oriented-core.md`)
Pinned toolchain: **AILANG v0.26.0** (commit `3b52a24`). Verified this session:
`ailang --version` = v0.26.0 / `3b52a24` — the pin has not moved. **Every `file:line`
anchor below was read against HEAD `8604365` this session** (see "Anchor re-verification
log"). The WI-C8 gate block, strict parity vs `/tmp/phase_c_blessed`, the projection gate,
all five pure-module test suites, the L1 scenario family, and the sketch probes were
**re-run this session** before being relied on (all green — see the toolchain table).

Authored per `NOTE-phase-c-implementation-findings.md` (2026-07-04), which is this plan's
problem statement: the WI-C8 gate passes, but **the inversion is not on the live path**.
`PLAN-phase-c-full-inversion.md` remains the parent spec; its decisions D-C1–D-C7 are
inherited, not re-opened. This plan is the `PLAN-phase1b`-style completion document the
one-plan-per-phase convention allows.

Relates to:
- `NOTE-phase-c-implementation-findings.md` — the as-built gap this plan closes, with the
  per-deliverable disposition table.
- `PLAN-phase-c-full-inversion.md` — parent plan; D-C1–D-C7 and WI-C0–C8 definitions.
- `ADR-001-phase-oriented-core.md` — normative; Phase C deliverables 1–4 are the
  acceptance criteria still open (5 and 6 are met).
- `PLAN-phase-b-phase-results.md` — D-B7 parity protocol, inherited unchanged.
- `NOTE-ailang-run-exit-code-false-alarm.md` — measurement discipline (pipefail; minimal
  repro before defect claims; rc captured adjacent, never through a pipe).

---

## Goal

Make the already-built-and-tested pure core the **live** execution path: `session.ail`'s
production loop runs `decide` → execute-decision → `apply_state_delta` every step; the
approval `readLine()` leaves the dispatch recursion and becomes driver-performed
`AwaitApproval`; config/env reads happen once at session init; the in-memory `LedgerTrace`
(including `StagePassed` records, G-B1) is produced by the live path; ports are actually
consumed; and the gate gains the **positive wiring checks** whose absence let a relocation
pass as an inversion. Byte parity with `/tmp/phase_c_blessed` is expected to hold
throughout — this is a control-flow inversion under a frozen wire contract.

## Out of scope

Unchanged from the parent plan: ABI v3, the conformance kit, `compaction_ai` v0.3.0,
registry publication of `motoko_ext_compaction_structural`, and any interactive approval
UI beyond the wire protocol. Additionally out of scope here:
- New JSONL event types or fields ([NEW] whitelist stays closed; D-C2 stands — new
  observability is in-memory `LedgerRecord` variants only).
- Re-litigating the `StepDecision` constructor set (D-C3) or any settled decision.
- The `rpc_loop` legacy path and `src/core/rpc.ail` beyond keeping its
  `run_v2_with_conversation` call site working unchanged.

## TL;DR

1. **WI-C9 — byte reconciliation + instruments.** Fix the pure modules' known
   divergences from live bytes (golden tests transcribed from the live emitters), add the
   `DecisionRecord` in-memory variant, and land the A/B differ protocol. No live routing.
2. **WI-C10 — policy init hoisting.** Env reads move to session entry; `StepPolicy` gains
   the fields the live cycle needs. Parity byte-identical.
3. **WI-C11 — inverted decision cycle behind a transient flag.** A parallel
   `decide`-driven cycle in `session.ail`, A/B-verified byte-identical across the whole
   parity fleet; tool dispatch still delegated whole.
4. **WI-C12 — approval inversion on the flagged path.** `tool_phase` extended to the
   *live* approval protocol; the driver performs the read; `dispatch` no longer blocks.
5. **WI-C13 — flip and delete.** Facades route through the inverted cycle; the flag and
   the old recursion are deleted; tool execution relocates into `tool_phase` with the
   executor registry; ports go live; `run_v2_with_scripted_ports` becomes real.
6. **WI-C14 — final gate.** The WI-C8 block plus the new wiring checks, and the
   documentation closeout (findings-note addendum, stale-doc corrections).

Baseline protocol: `/tmp/phase_c_blessed` is the strict baseline for every WI. **No
expected-diff table is anticipated anywhere in this plan** — any parity diff is a stop,
classified per D-B7 before any code or baseline change. If `/tmp` has been cleared,
regenerate the baseline by running `./scripts/phase_a_event_parity.sh` at the last green
commit before the current WI, verified by a self-diff double run.

---

## Grounding: Phase C as built vs. its plan

`NOTE-phase-c-implementation-findings.md` records the structural gap (relocation, not
inversion; no production caller of `decide` / the phase modules; `readLine()` still at
`session.ail:785`; env reads mid-loop at `session.ail:1065,:1203,:1217`). Beyond that
note, this survey found the **byte-level divergences between the pure surface and the
live emitters** — each one a parity bug waiting to fire the moment the pure surface goes
live, and therefore WI-C9's work list:

1. **`recovery.persist_nudge_message` diverges from the live nudge content twice**:
   it appends ` nudge=${n}/${budget}` and uses `"prose --"` where live uses the em-dash
   `"prose —"` (`src/core/recovery.ail:52`, `src/core/session.ail:1413`).
   Transcript-only, but it changes `provider_call_prepared.payload_digest` (a real
   SHA-256 over content since WI-C1) on any nudge-exercising run.
2. **`decide`'s Fail messages don't match live wire bytes.** `"step budget exhausted"`
   vs. live `"v2 loop: step budget exhausted"` (`src/core/step_machine.ail:65`,
   `src/core/session.ail:1123-1126`); `"cost cap reached"` vs. live
   `"cost cap reached: ${X} of ${Y} millicents used"` (`src/core/step_machine.ail:67`,
   `src/core/session.ail:1137`). These land in `run_summary.error` / `error` events —
   byte-visible in the cost-budget smoke. **The cost-cap guard itself also diverges**:
   live trips the cap only when `cost_rates.input_per_1m_millicents > 0` (unmetered
   providers never exhaust, `src/core/session.ail:1130`); `decide`
   (`src/core/step_machine.ail:66`) and `cost_phase.cost_cap_exceeded`
   (`src/core/cost_phase.ail:15`) lack the metered-rates condition.
3. **`await_approval_from_calls` hardcodes `stream_id: "step-${show(0)}"`**
   (`src/core/step_machine.ail:57`) — must derive from `s.step_idx`.
4. **`decide`'s `CallModel` hardcodes `model: "phase-c-model"`**
   (`src/core/step_machine.ail:81`); `StepPolicy` has no model field
   (`src/core/phase_vocab.ail:238`).
5. **`model_phase.phase_from_result` zeroes `step`, `tool_calls`, `cost_usd`**
   (`src/core/model_phase.ail:31-37`) — not yet parity-capable for the `thinking` event.
6. **`tool_phase.parse_approval_command` is not the live protocol.** It accepts only
   exact strings (`src/core/tool_phase.ail:53-57`); live code JSON-decodes, reads
   `type`/`reason`, and produces exact default reasons `"timeout — no approval
   received"`, `"unparseable response — default deny applied"`, `"unknown approval
   command — default deny applied"`, `"denied by operator"`
   (`src/core/session.ail:771-797`). `tool_phase.denial_message` builds JSON by string
   interpolation (`src/core/tool_phase.ail:69-76`) where live uses `encode(jo(...))`
   (`src/core/session.ail:710-723`) — same field order today, but no escaping.
7. **`phase_vocab.project()` is still the Phase A scaffold** (pure precheck +
   passthrough, `src/core/phase_vocab.ail:111-122`): the real payload is produced by the
   driver's effectful chain composition (`src/core/session.ail:1141-1164`). `decide`
   consuming `project()` therefore cannot be the payload source for the live model call —
   see D-C2-1 below.
8. **What is genuinely reusable as-is**: `cost_phase` reproduces the live threshold logic
   exactly (`src/core/cost_phase.ail:19-28` vs `src/core/session.ail:1268-1281`);
   `recovery.should_retry_stream_error` matches the live guard
   (`src/core/recovery.ail:13` vs `src/core/session.ail:1217-1218`);
   `tool_stream_phase.stream_delta_event` matches `append_stream_delta`'s mapping
   (`src/core/tool_stream_phase.ail:8-14` vs `src/core/session.ail:353-373`);
   `step_machine.dp7_rejection_message` matches the live retry message
   (`src/core/step_machine.ail:44` vs `src/core/session.ail:1042`); `hook_phase` +
   `LedgerRecord`/`LedgerTrace` (`src/core/phase_vocab.ail:476-506`) and
   `SessionSnapshot`/`session_from_messages`/`apply_phase_result`
   (`src/core/session.ail:1833-1863`) are the intended substrate, currently uncalled.

Live-loop event-order facts the inversion must reproduce (read this session):
`thinking_stream_start` (`src/core/session.ail:1181`) → `provider_call_prepared`
(`:1196`) → deltas (mid-call, handle installed `:1195`) → `thinking_stream_end` →
`thinking`; `run_summary` **before** `done` on every success path
(`src/core/session.ail:1369,:1425`); `tool_pending` emitted before the approval read
(`src/core/session.ail:776,:785`); batch `native_tool_calls` before dispatch and **one**
`native_tool_results` after the entire call set resolves — including across the approval
pause, which today blocks *inside* the batch (`src/core/session.ail:1457,:1464`). The
inverted RunTools → AwaitApproval → RunTools(remaining) split must therefore accumulate
tool messages across the approval boundary and emit the single results batch only when
the original call set is fully resolved; two per-segment batches would be a wire
regression the differ will catch but the design must prevent.

## Plan-level decisions

**D-C2-1 — Sealed payload construction for the effectful chain.** The ADR says a
`ProviderPayload` is obtainable only via `project()`, but `project()` is pure while the
D9 compactor chain is effectful — the ADR's §7.2 pipeline cannot run inside a pure
function on this substrate. Resolution: `phase_vocab` (the definer module — sealing
unaffected, fact 17) gains one op,
`seal_compacted_payload(split: PinnedSplit, chain_msgs: [Message], model: string,
limit: int) -> Result[ProviderPayload, string]`, which re-pins the prefix, applies the
exhaustion check (`exhaustion_pct()`, fail-open at limit 0 — exact live semantics,
`src/core/session.ail:1160-1165`), and on exhaustion returns the **live reason bytes**
(`"compaction_exhausted: context at ${pct}% of ${model} limit after compactor chain"`,
`src/core/session.ail:1165`), golden-tested in `phase_vocab`. `decide`'s embedded `project()` remains the
pure precheck; `CallModel` means "a model call is due", and the driver's hook phase
produces the actual sealed payload. Ephemerality holds: nothing can write a payload back
into `History`. Recorded as ADR input in "ADR gaps found" — this is the one place the
as-built substrate forced a vocabulary addition the ADR did not name.

**D-C2-2 — The sentinel `finish_reason` protocol is the continuation encoding.** The
as-built `decide` already keys on driver-written sentinels in `last_finish_reason`
(`await_approval`, `dp7_rejected`, `dp7_approved`, `dp7_fail_open`, `persist_nudge` —
`src/core/step_machine.ail:70-77`). This is the proven "continuation is state" form
(P3-R3). This plan extends the table rather than inventing a channel: new sentinels
`stream_error` (drives the retry arm), `solver_feedback` (drives
`InjectUserMessage(feedback)`), `intercept_handled` and `hybrid_bash` (drive the next
cycle's arms). Contract: **every sentinel the driver writes has a `decide` arm and a pure
test**; a sentinel without an arm is a bug the wiring scenario must catch (it surfaces as
a wrong decision in the `DecisionRecord` sequence). One rule is load-bearing: **the raw
provider `finish_reason` is interpretation input and is never written into
`last_finish_reason` verbatim.** Live control flow runs intercept → hybrid → solver →
persist-nudge → DP7 *after* a `"stop"` result (`src/core/session.ail:1296-1440`), but
`decide` finalizes on `"stop"` (`src/core/step_machine.ail:77`) — so the driver writes
`"stop"` only when interpretation is complete and finalization is approved; intermediate
outcomes get their own sentinels. A DP7-enabled wiring scenario asserts no premature
`Finalize` appears in the `DecisionRecord` sequence.

**D-C2-3 — Strangler via a transient routing flag, deleted before the final gate.**
WI-C11/WI-C12 run the inverted cycle behind `MOTOKO_PHASE_C2_DRIVER=1`, read **once** at
session entry. This makes the A/B differ nearly free: run the existing parity harness
twice, flag off and on, and `diff -r` the outputs — no smoke edits, full-fleet coverage.
The flag is not a supported configuration: WI-C13 deletes it, and the WI-C14 gate greps
for its absence. Rationale over parallel-entry-points: the fleet exercises the facades;
switching inside the facades tests exactly what will ship.

**D-C2-4 — The positive wiring check is a trace assertion, not a grep.** The gate lesson
from the findings note: parity proves non-regression, not architecture. The instrument:
`LedgerRecord` gains `DecisionRecord({ step: int, decision: string })`; the driver appends
one per executed decision; a new entry
`run_v2_session_traced(...) -> { result, trace: LedgerTrace }` (same routing as the
production facades) lets `scripts/phase_c2_wiring_scenarios.ail` assert the decision
sequence (`CallModel → RunTools → … → Finalize`) and the G-B1 stage records (including
`StagePassed`) for scripted runs. In-memory only — no JSONL change (D-C2 stands).

**D-C2-5 — Golden bytes are transcribed before wiring, not after.** Every string the
pure modules must produce on the live path (Fail messages, nudge content, denial
payloads, approval default reasons, dp7 retry message) gets a pure golden test whose
expected value is transcribed from the live emitter *in WI-C9*, so WI-C11/C12 wire
against an already-verified surface. This is the WI-1-golden-tests discipline from Phase
B applied to strings instead of projections.

**D-C2-6 — Tool execution relocates last, approval inverts first.** The approval read is
the only structural blocker inside `dispatch_calls` (D-B1); executor-registry relocation
into `tool_phase.ail` is file placement. Order: WI-C12 splits only the `Pending` arm out
of the recursion; WI-C13 relocates the execution bodies (native / delegated /
handled-by-ext / ws-loopback) into `tool_phase` with `ExecutorKind` routing
(`src/core/phase_vocab.ail:310`) once the flip has proven the cycle. Scratchpad becomes a
`WsLoopback` executor registration built at session init (`src/core/session.ail:864-883`
is the current hard-code); hybrid-bash synthesis keeps its transcript-correlation
obligation with the builders (research §5) and its `decide` arm via the `hybrid_bash`
sentinel.

## Work breakdown

Strangler discipline: after every WI, `make check_core`, `make test_core`,
`make test_integration` are green and `PARITY_BASELINE=/tmp/phase_c_blessed make
smoke_parity` is **byte-identical** (no expected diffs are planned; a diff is a stop).
Commit subjects continue the Phase C sequence (WI-C9 …).

### WI-C9 — Byte reconciliation and instruments (no live routing)

**Files.**
- `src/core/recovery.ail`: drop the ` nudge=…` suffix from `persist_nudge_message`
  (match `src/core/session.ail:1413` bytes exactly); golden test.
- `src/core/step_machine.ail`: Fail messages take the live forms (budget message
  verbatim; cost message composed from `s.totals.cost_millicents` and
  `pol.max_cost_millicents`); the cost-cap arm gains the live metered-rates guard
  (grounding item 2 — a `cost_metered: bool` policy fact, or rates in `StepPolicy`;
  `cost_phase.cost_cap_exceeded` gains the same condition with tests);
  `await_approval_from_calls` derives `stream_id` from a new
  `step_idx` parameter (or reads `s.step_idx` — implementer's choice, tested);
  `CallModel` model comes from `StepPolicy` (see WI-C10 — in this WI, thread a
  parameter and keep the placeholder default so nothing changes for existing tests);
  golden tests transcribed from `session.ail:1123-1126,:1137,:1042`.
- `src/core/tool_phase.ail`: extend to the **live** approval protocol:
  `parse_approval_command` JSON-decodes (`type`, `reason`) with the exact live default
  reasons; `denial_message` builds via `encode(jo(...))` (escaping-safe) and a golden
  test pins byte equality with `policy_denied_message`'s output for the same input
  (`src/core/session.ail:710-723`); keep the simplified string forms as additional
  accepted inputs only if the live TUI sends them (survey says it does not — drop them).
- `src/core/phase_vocab.ail`: add `DecisionRecord({ step, decision })` to `LedgerRecord`
  (+ `ledger_record_name` arm + tests; blast radius checked this session — the only
  out-of-module `LedgerRecord` matches, `scripts/phase_c_l1_scenarios.ail:275-282`,
  carry `_ =>` wildcards, so the variant addition is non-breaking); add
  `seal_compacted_payload` (D-C2-1) with pure tests: seals, re-pins, exhausts at ≥95
  with the live reason bytes (`src/core/session.ail:1165`), fail-open at limit 0.
- `scripts/phase_c2_ab_parity.sh` (new, small): runs `phase_a_event_parity.sh` into
  `/tmp/c2_ab_off`, then with `MOTOKO_PHASE_C2_DRIVER=1` into `/tmp/c2_ab_on`, then
  `diff -r`. In this WI the flag does not exist yet, so the script must pass trivially
  (off ≡ on) — committed now so WI-C11 has its instrument on day one. `set -euo
  pipefail`.
- `scripts/phase_c2_wiring_scenarios.ail` (new): harness in the
  `phase_c_l1_scenarios.ail` style; in this WI only a self-test asserting
  `DecisionRecord` append/name round-trip (the driver assertions arrive in WI-C11 —
  named now, no phantom gate: the script exists, runs, and its driver scenarios are
  added in the WI that makes them satisfiable).
- `scripts/phase_c_approval_protocol.ail`: update to the live-protocol `tool_phase`
  surface (exact default-reason strings asserted).

**Verification.**
```
make check_core && make test_core && make test_integration
ailang test src/core/step_machine.ail        # incl. new golden string tests
ailang test src/core/recovery.ail
ailang test src/core/tool_phase.ail
ailang test src/core/phase_vocab.ail
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
ailang run --caps IO --entry main scripts/phase_c2_wiring_scenarios.ail
bash scripts/phase_c2_ab_parity.sh           # trivially identical
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity   # byte-identical
```
**Rollback.** Revert the commit; pure modules and scripts only, nothing live changed.

### WI-C10 — Policy init hoisting (env reads once)

**Files.**
- `src/core/phase_vocab.ail`: `StepPolicy` gains `model: string` and
  `provider_base_url: string` — plus the WI-C9 metered-cost fact if it was deferred to
  ride this field addition (definer module; blast radius verified this session: literal
  constructors exist only in `step_machine.ail:91,:172` and
  `scripts/phase_c_l1_scenarios.ail:100`).
- `src/core/session.ail`: a `session_policy_init(...)` built once per entry
  (`run_v2`, `run_v2_from_messages`, `run_v2_with_conversation`, `run_v2_with_stub`)
  resolving `MOTOKO_PERSIST_RETRIES` (`:1064-1071`), `MOTOKO_RETRY_STREAM_ERROR`
  (`:1217`), `OPENAI_BASE_URL` (`:1203`), and threading them as loop parameters;
  the three mid-loop `getEnvOr` calls are deleted. `MOTOKO_HEADLESS` in
  `conversation_loop_v2` (`:1607`) hoists to a parameter resolved at entry.
- `src/core/step_machine.ail`: `CallModel` model now reads `pol.model` (placeholder
  default removed).

**Verification.** WI-C9 command set, plus:
```
grep -n "getEnvOr" src/core/session.ail   # hits only in init/derive_session_id/entry funcs
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity   # byte-identical
```
**Rollback.** Revert the commit (restores mid-loop reads).

### WI-C11 — Inverted decision cycle behind the transient flag

**Files.**
- `src/core/session.ail`: new `session_cycle(snapshot, policy, ports-ish params, …)`
  implementing decide → execute → `apply_phase_result` for **all non-tool decisions**:
  - `CallModel`: hook phase runs `split_for_compaction` → `dispatch_pre_step_chain` →
    stage events (wire) + `stage_record`s incl. `StagePassed` (trace, via
    `hook_phase.stage_record`) → `seal_compacted_payload` → exhaustion path with live
    bytes → `thinking_stream_start` / `provider_call_prepared` / `dispatch_step` with
    the stream handle / `thinking_stream_end` / `thinking`, in exactly the live order
    (`src/core/session.ail:1181-1253`); `model_phase.result_delta` extended
    (`phase_from_result` gains step/cost/n_calls parameters) supplies the delta;
    `cost_phase` supplies totals/warning thresholds with live `cost_warning` bytes.
  - Model error: sentinel `stream_error`; `recovery.should_retry_stream_error` gates the
    retry arm in `decide`; `stream_error_retry` emitted by the driver on that
    transition; non-retry → live error path bytes.
  - Post-model interpretation writes sentinels (D-C2-2: raw `finish_reason` never
    written verbatim): intercept (`intercept_handled` + tool msg append; **intercept
    preempts tool dispatch** — live checks it before the `finish_reason` branch,
    `src/core/session.ail:1296` — so the delta clears `pending_tool_calls`), solver
    feedback (`solver_feedback`), hybrid (`hybrid_bash` + synthetic call in
    `pending_tool_calls` + augmented assistant message per the Bedrock correlation rule,
    `src/core/session.ail:1319-1351`), dp7 outcomes, persist nudge
    (`recovery.should_inject_persist_nudge` on `nudges_used` state — marker scanning
    retired on the flagged path).
  - **Transcript-append deferral**: the assistant message from `model_phase` is applied
    to history only *after* interpretation, because the hybrid path must swap in the
    augmented assistant message (tool_calls patched in) in its place — appending early
    would orphan the synthetic tool_result (the Bedrock 400 class,
    `src/core/session.ail:1330-1350`).
  - **Step accounting is driver-owned**: `StateDelta` deliberately has no `step_idx`
    field (`src/core/phase_vocab.ail:258-266`); the driver increments `step_idx` when
    it executes `CallModel` — the live loop's one-recursion-one-model-call equivalence
    (stream-retry consumed a step there too, and does here via its re-`CallModel`).
  - **ExtCtx fidelity**: the live loop builds two differently-shaped `ExtCtx` per step —
    pre-step with the segment-compensated effective limit over the raw history
    (`src/core/session.ail:1153`) and post-model with the raw catalog limit over
    `msgs_with_assistant` (`:1257`) — the cycle reproduces both (extensions observe
    `history_slice` and `context_limit`).
  - `Finalize`: `run_summary` before `done`, source field per accept path;
    `steps_executed` is `step_idx + 1` on success paths and `step_idx` on failure paths
    (live bytes, `src/core/session.ail:1369,:1123`).
  - `Fail`: exact live event/summary bytes (WI-C9 goldens).
  - `InjectUserMessage`, `TakeCheckpoint` (executes `apply_checkpoint` faithfully; v1
    policy never returns it — the scenario stays the cage), `RunTools` (this WI:
    delegate the whole plan to the existing `dispatch_calls` unchanged, approval still
    inside), `AwaitApproval` (unreachable this WI: driver does not write the
    `await_approval` sentinel until WI-C12; assert-fail arm with a clear message).
  - Every executed decision appends a `DecisionRecord`; the trace lives in
    `SessionSnapshot` and threads through the cycle.
- Facades: when `MOTOKO_PHASE_C2_DRIVER=1` (read once at entry), `run_v2`,
  `run_v2_from_messages`, `run_v2_with_conversation`, `run_v2_with_stub` route into the
  cycle; otherwise the old `loop_v2`. New `run_v2_session_traced` export (D-C2-4)
  routes unconditionally through the cycle and returns `{ result, trace }`.
- `src/core/model_phase.ail`: parameter extension above, golden `thinking` bytes test
  against `phase_vocab`'s projection.
- `scripts/phase_c2_wiring_scenarios.ail`: the real assertions — scripted prose run
  yields `[CallModel, Finalize]`; tool run yields `[CallModel, RunTools, CallModel,
  Finalize]`; chain fixture run's trace carries `StagePassed`/`StageApplied`/
  `StageRejected` records in registry order (G-B1 consumer); nudge-configured run shows
  `InjectUserMessage`; `checkpoint_never_emitted_in_v1` re-asserted over
  `DecisionRecord`s from the live cycle; the D-C2-2 no-premature-`Finalize` scenario
  (DP7 rejection) — note it executes the verifier command in a fixture workdir like
  `smoke_v2_dp7_gate`, so it needs `Process`. Runs under the minimal caps the cycle's
  performed effects need (scripted provider, deny/fixture rt — expect
  `IO,Env,Clock,Trace` + `Process` for the DP7 scenario; record the exact set in the
  script header).

**Verification.**
```
make check_core && make test_core && make test_integration
ailang test src/core/step_machine.ail && ailang test src/core/model_phase.ail
ailang run --caps IO,Env,Clock,Trace,Process --entry main scripts/phase_c2_wiring_scenarios.ail
bash scripts/phase_c2_ab_parity.sh        # THE gate: flag-on fleet ≡ flag-off fleet, bytes
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity   # flag off: byte-identical
```
**Expected-diff protocol.** The A/B differ diffing non-empty is the designed failure
mode: classify every line (order / missing / payload) per D-B7; fix the cycle — do not
bless. The blessed baseline never changes in this WI.
**Sub-commits.** This is the largest WI; internal sub-commits (e.g. by decision-arm
family) are allowed because the shipped path is flag-off: each sub-commit needs strict
parity (flag off) and green module tests only; the A/B differ and the wiring scenarios
are the **WI-boundary** completion criteria, not per-sub-commit gates.
**Rollback.** Revert the commit(s); the flag and cycle disappear, facades unconditional.

### WI-C12 — Approval inversion on the flagged path

**Files.**
- `src/core/session.ail` (flagged path only): the tool executor processes the plan
  entry-by-entry; on a `Pending` policy decision it **returns** the suspended state
  (executed results so far + `PendingApprovalPlan` from
  `tool_phase.plan_pending_approval`) instead of reading stdin. The driver emits the
  `ToolPending` event (`tool_phase.tool_pending_event` — event-before-read), writes the
  `await_approval` sentinel + pending calls into state; `decide` returns
  `AwaitApproval(req)`; the driver executes it: approval port read (live adapter =
  `readLine()` + `tool_phase.resolve_approval` with the live default reasons), then
  denial message or approved-call execution, then `RunTools` re-issued with
  `req.remaining` in original order (`tool_phase.approval_resume_plan`,
  `execution_order_after_approval` invariant). **Batch accumulation spans the approval
  boundary**: the live path emits one `native_tool_calls` before dispatch and exactly
  one `native_tool_results` after the entire call set resolves, blocking mid-batch on
  the read (`src/core/session.ail:1457,:1464`) — so the driver carries the accumulated
  tool messages through the AwaitApproval decision and emits the single results batch
  only when the original call set is fully resolved (grounding, event-order facts). The
  differ proves equivalence; the pending smoke's devnull stdin pins the EOF-default
  path.
- `src/core/ports.ail` + `src/core/test/scripted_ports.ail`: `approval_read` becomes the
  seam the driver calls; scripted approvals thread through `ScriptedPortsState`
  (`scripted_approval_next`, `src/core/test/scripted_ports.ail:49-60`) in the wiring
  scenarios.
- `scripts/phase_c2_wiring_scenarios.ail`: approval scenarios — approve, deny-with-
  reason, EOF-default-allow, EOF-default-deny, unparseable-input; each asserts the
  `DecisionRecord` sequence contains `AwaitApproval` and the tail re-issue, plus the
  denial-message bytes.
- `scripts/phase_c_approval_protocol.ail`: gains the same live-protocol cases at the
  pure `tool_phase` level (already partly done in WI-C9).

**Verification.** WI-C11 command set (differ + strict parity, flag off), plus
`smoke_v2_pending_full_loop` scrutinized line-by-line in the A/B diff output (it is the
only **parity-fleet** smoke exercising `tool_pending`; `smoke_v2_pending.ail` and
`smoke_v2_policy_denial.ail` also name it but are outside the fleet and type-broken at
HEAD — the G8 hygiene list).
**Rollback.** Revert; the flagged path falls back to whole-plan delegation (WI-C11
state), old path untouched.

### WI-C13 — Flip, delete, and relocate (sub-commits a–c)

**a — Flip.** Facades route through the inverted cycle unconditionally; the
`MOTOKO_PHASE_C2_DRIVER` flag is deleted and `scripts/phase_c2_ab_parity.sh` is retired
with it (its job is done — post-flip it would only duplicate `make smoke_parity`'s
self-diff mode, and keeping it would trip the flag-absence grep); `run_v2_with_stub` and
`run_v2_with_stub_port_adapter` stay as facades over the cycle. Strict parity vs
`/tmp/phase_c_blessed` now proves the new path on the whole fleet.
**b — Delete.** The old `loop_v2` recursion (`src/core/session.ail:1103-1500`-region)
and the blocking `Pending` arm of `dispatch_calls` are removed; `dispatch_calls`'s
remaining body becomes the executor implementations.
**c — Relocate.** Executor bodies move into `src/core/tool_phase.ail` behind
`ExecutorKind` routing; the executor registry (incl. scratchpad `WsLoopback`, the
`is_scratchpad_tool_name` + `exec_scratchpad_cell_ws` hard-code, and the
delegated/native split) is built once at session init; `session.ail` shrinks to driver +
init + emission; `run_v2_with_scripted_ports` passes real scripted `Ports`
(model/approval/clock) instead of unwrapping to `Scripted(steps)`; live `Ports` built
once at entry. **The as-built `Ports.model_step` signature cannot carry the streaming
protocol** — it has no chunk callback (`src/core/ports.ail:18`), while the ADR's
streaming exception requires the driver-issued append handle to reach the call
mid-flight. The model port signature widens to
`(string, [Message], (StreamChunk) -> () ! {IO, Trace}) -> Result[StepResult, AIError]`;
the live adapter wraps `stepWithStream` + `tools_with_extensions(rt)` + the cache
breakpoints (today's `dispatch_step` LiveAI arm, `src/core/test/stub_step.ail:130-132`);
the scripted adapter plays `chunks` (the Scripted arm, `:133-143`). Ripple is test-only:
`ports_shape_probe`/`fake_model` (`src/core/ports.ail:36-48`,
`src/core/test/scripted_ports.ail:68-80`). Hybrid-bash synthesis and the
assistant-message augmentation stay with the response interpretation + transcript
builders (D-C2-6).

**Verification (after each sub-commit).**
```
make check_core && make test_core && make test_integration
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity     # byte-identical, new path
./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed
ailang run --caps IO,Env,Clock,Trace,Process --entry main scripts/phase_c2_wiring_scenarios.ail
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
grep -rn "MOTOKO_PHASE_C2_DRIVER" src scripts && exit 1 || true   # flag gone (13a+)
grep -n "readLine(" src/core/session.ail    # conversation_loop + approval-port adapter only
grep -c "decide(" src/core/session.ail      # >0, in the live cycle
```
**Rollback.** 13c reverts alone (relocation); 13a+13b revert together (restores flag +
old loop). Each sub-commit leaves the fleet green.

### WI-C14 — Final gate and closeout

Run the parent plan's WI-C8 block verbatim (`PLAN-phase-c-full-inversion.md:549-585`,
`grep` substituting for `rg` where the environment lacks it), **plus** the Phase C2
additions:

```
ailang run --caps IO,Env,Clock,Trace,Process --entry main scripts/phase_c2_wiring_scenarios.ail
grep -rn "MOTOKO_PHASE_C2_DRIVER" src scripts; test $? -eq 1   # flag and differ script gone
grep -n "getEnvOr\|readLine(" src/core/session.ail        # init/entry/adapter sites only
grep -rln "src/core/tool_phase\|src/core/model_phase\|src/core/hook_phase\|src/core/ports" \
  src/core/session.ail                                    # session consumes the phase modules
```

Closeout: append the resolution to `NOTE-phase-c-implementation-findings.md` (each
disposition table row flipped to met, with the WI that closed it); replace the stale
banner text in `HANDOFF-continue-phase-c.md` with a pointer to this plan's completion;
write the session summary; commit `ailang.lock` if still dirty (inspect first).

## ADR gaps found

- **G-C2-1 (design addition, dispositioned by D-C2-1; operator sign-off received
  2026-07-04):** the
  ADR's "no other way to obtain a `ProviderPayload` than `project()`" (Decision detail 4)
  is unimplementable as stated once D9 made the compaction chain effectful — a pure
  `project()` cannot run extension hooks. `seal_compacted_payload` in the definer module
  preserves the sealing intent (construction only in `phase_vocab`, gate + exhaustion
  enforced at the seam, ephemerality by dataflow). The ADR's wording should widen to "no
  way to obtain one outside `phase_vocab`'s exported projection ops".
- No other gap: the sentinel-protocol extension (D-C2-2) is within the ADR's
  "continuation is state" claim as proven by P3-R3.

## Toolchain and artifacts verified this session (2026-07-04, HEAD `8604365`)

| Check | Result |
|---|---|
| `ailang --version` | v0.26.0 / `3b52a24` — pin holds |
| WI-C8 gate block (parent plan `:549-585`) | all positive checks pass; sealing probe fails `IMP010` as required |
| `PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity` | rc=0, byte-identical |
| `./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed` | OK |
| `phase_c_l1_scenarios` | 10/10 pass under `--caps IO` |
| `phase_c_approval_protocol` | 4/4 pass under `--caps IO` |
| Module tests (`phase_vocab`, `step_machine`, `cost_phase`, `recovery`, `ext/runtime`) | green |
| Sketch vocabulary test + `probe_consumer_decide` check/run | green |
| Supplemental greps (stub surface, effect reads, no checkpoint events) | pass as written |
| `ailang.lock` dirt | regenerated hashes/timestamp only |

## Anchor re-verification log

Read at HEAD `8604365` this session — the load-bearing set:
`src/core/session.ail` (1875 lines): `ledger_emit` `:270`, stage emission `:280-283`,
stream delta `:353-373`, `derive_session_id` `:379-382`, `emit_run_summary` `:424`,
`dispatch_calls` `:747-1016` (approval region `:761-859`, scratchpad `:864-883`),
dp7 `:1016-1048`, persist-nudge helpers `:1060-1101`, `loop_v2` `:1103-1500` (env reads
`:1065,:1203,:1217`; cost-cap guard incl. metered-rates condition `:1130`; Fail/summary
bytes `:1123-1126,:1137`; exhaustion reason `:1165`; order-critical emission
`:1181-1253` — stream start `:1181`, `provider_call_prepared` `:1196`, dispatch `:1203`;
cost warnings `:1272-1278`; intercept-before-branch `:1296`; hybrid `:1319-1351`; nudge
content `:1413`; summary-before-done `:1369,:1425`; batch tool events `:1457,:1464`;
the two per-step `ExtCtx` builds `:1153,:1257`; dp7 retry message `:1042`),
entries `:1500-1736`, snapshot helpers `:1833-1875`.
`src/core/agent_loop_v2.ail` (123 lines): facades `:89,:107`.
`src/core/step_machine.ail`: `decide` `:63-83`, divergences `:57,:65,:67,:81`, 12 tests.
`src/core/tool_phase.ail`: pending plan `:33-51`, parse/resolve `:53-67`, denial `:69-76`,
resume/order `:78-91`.
`src/core/model_phase.ail`: `result_delta` `:14-24`, `phase_from_result` zeros `:31-37`.
`src/core/hook_phase.ail`: `stage_record` `:14-21`.
`src/core/cost_phase.ail`: thresholds `:19-28`. `src/core/recovery.ail`: retry `:13`,
nudge message + suffix divergence `:46-56`.
`src/core/ports.ail`: `Ports` `:17-24`, `ports_shape_probe` `:36-48`.
`src/core/test/scripted_ports.ail`: state threading `:20-66`, runner delegation `:82-99`.
`src/core/phase_vocab.ail` (1071 lines): `project` scaffold `:111-122`, in-memory ledger
`:476-506`, checkpoint chain validation `:508+`.
Scripts: `phase_a_event_parity.sh` (fleet list `:171-185`), `phase_b_projection_gate.sh`
(allowlist `:20-22`), `phase_c_l1_scenarios.ail` (scenario roster `:332-379`),
`phase_c_approval_protocol.ail` (imports `:13-15`).
Line numbers exact as of this read; **re-grep before editing** (house rule).
