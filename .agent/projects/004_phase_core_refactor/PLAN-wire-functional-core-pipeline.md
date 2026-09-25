# PLAN: Close the functional-core pipeline gaps in the live Phase C driver

Date: 2026-07-05
Status: Draft (for operator review)
Verified against: branch `arniwesth/mot-27-phased-core-architecture`, commit `fed914c`
Pinned toolchain: AILANG v0.26.0 (commit `3b52a24`)

Fixes: `ISSUE-functional-core-pipeline-not-wired.md` (findings 1–6, as corrected by
the 2026-07-05 independent-verification pass).
Relates to: `ADR-001-phase-oriented-core.md` (D1, D3, D5, D9 + Open Question 4
closure); `DIAGRAM-phase-core-architecture.md` §1, §3;
`PLAN-phase-c2-live-inversion.md` (the driver this plan finishes);
`HANDOFF-continue-phase-c.md` (the "do not start ABI v3" boundary this plan honors).

---

## TL;DR

After grounding every finding against source **and against the ADR's own D9 / Open
Question 4 closure**, the live pipeline is in far better shape than the ISSUE's
severities suggest. Most findings resolve to "not a defect", "deferred to ABI v3 by
design", or "cosmetic". The required, in-scope, **byte-neutral** work is small:

1. **WI-F1** — delete the dead `SessionSnapshot` cluster (finding 5).
2. **WI-F2** — replace `project()`'s misleading stub with honest pure prep, and drop
   the vestigial `ModelRequest.payload` the driver discards (findings 1, 2-residue).

Optional follow-on (byte-neutral but carries an import-cycle cost — D-F3):

3. **WI-F3** — extract the effectful compaction+model call into an effectful
   `model_phase`, consuming `PhaseResult.transcript_append`/`cost_delta_millicents`
   (finding 6 + the organizational half of finding 2 + the ADR's "effectful
   `model_phase`" gap).

Explicitly **deferred to the ABI v3 track** (out of scope here, and forbidden to
start now by `HANDOFF-continue-phase-c.md`):

- **Telemetry threading + actual-token gating** (findings 3-telemetry, 4). Per D9 /
  Open Question 4, core's exhaustion decision is the *effectful* 95%-estimate seal
  (already live and correct); actual-token gating is *compactor-extension policy* fed
  by `ExtCtx.telemetry`, which is ABI v3. Threading telemetry into the loop now has
  no in-scope consumer. See "Deferred" below.

**No item in the required or optional scope changes production bytes**, so no D-B7
fence is needed — a notable simplification from earlier drafts, which wrongly modeled
an actual-token pre-gate as core behavior.

One either/or needs operator sign-off (D-F2, delete vs keep the dead cluster) and one
scoping call (D-F3, whether to take the optional WI-F3 now).

## Framing — why the required scope is this small

The driver carries **`C2LoopState`** (`session.ail:317`): `[Message]`-based, plus
driver-only fields. Each step it converts `C2LoopState → StepState` (`c2_step_state`,
`:400`), calls `decide`, then `apply_state_delta` (`:1456`), then rebuilds
`C2LoopState`. The pipeline is *already* threaded through this loop for the fields
that matter: `pending_tool_calls`, `last_response_text`, `nudges_used` flow from
`applied`; `totals` is driver-summed (the delta carries `None`); `last_finish_reason`
is driver-set for control flow. `apply_state_delta` is the DIAGRAM §1 single applier
and is live.

Adjudicating each finding against source + the ADR's D9 closure:

| # | ISSUE severity | Adjudication | Home |
|---|---|---|---|
| 1 `project()` stub | CRITICAL | Real, but its job is pure *prep*, not exhaustion (D9). Fix = honest prep. | **WI-F2** |
| 2 driver runs own compaction | CRITICAL | **Not a defect** — the compactor chain is effectful; the driver is right to run it. Residue = a vestigial `CallModel` payload. | **WI-F2** (drop payload) |
| 3 delta partially wired | CRITICAL | Only *telemetry* is genuinely dropped; `totals`/`last_finish_reason` are correct-by-design (not defects). Telemetry's consumer is ABI v3. | **Deferred** (telemetry); rest = no-op |
| 4 telemetry always 0 | HIGH | Superseded by D9 — core does not actual-token-gate; the consumer is `ExtCtx.telemetry` (ABI v3). | **Deferred** |
| 5 dead `apply_phase_result` cluster | MEDIUM | Real dead code (0 callers). | **WI-F1** (delete) |
| 6 `transcript_append`/`cost_delta` unused | MEDIUM | Cosmetic; real consumption only exists once the effectful `model_phase` owns the call. | **WI-F3** (optional) |

So the required plan closes findings 1, 2-residue, 5; the optional WI-F3 closes 6 and
the organizational half of 2; and findings 3-telemetry / 4 are dispositioned to ABI v3.

**The overriding constraint is strict JSONL parity.** Every item below is byte-neutral
against the blessed baseline; the plan adds no behavior change, so nothing here needs
D-B7 expected-diff evidence or a re-bless.

## Why finding 2 is not a correctness defect, and why `project()` is prep (not a gate)

- `dispatch_pre_step_chain` (`ext/runtime.ail:185`) carries the 9-effect row; `decide`
  (`step_machine.ail:78`) is pure and can never call it. The fully-compacted payload
  is necessarily produced effectfully, so the driver running compaction inline is
  correct. Its only residue is the discarded `CallModel(ModelRequest{payload})`
  (`CallModel(_)`, `:1382`) — removed in WI-F2.
- Per ADR §4 and Open Question 4's closure: core's **exhaustion decision** is the
  *effectful* `seal_compacted_payload` (95%-estimate over the re-pinned full list vs
  the catalog limit, fail-open at 0) — this is already live and correct at
  `session.ail:1393`. `project()` is the **pure precheck**, i.e. structural prep, not
  an exhaustion gate. The current stub's `t.last_input_tokens >= pol.context_limit`
  Fail is therefore *doubly* misaligned: it is (a) an exhaustion decision that belongs
  in the seal, and (b) an *actual-token* test that D9 assigns to extension policy. WI-F2
  removes it.

A real Fail-capable pre-gate in `decide` is also inherently **not byte-neutral**: it
would fail *before* the effectful compaction attempt, skipping the `ProviderCallPrepared`
/ stage events the current post-compaction failure emits. That is another reason the
pre-gate is out of scope here — if ever wanted, it is a fenced behavior change on the
ABI v3 track, not a "wiring fix."

## Decisions (for operator sign-off)

- **D-F2 — the dead `SessionSnapshot` cluster (finding 5).** Recommend: **delete**
  `apply_phase_result`, `session_from_messages`, `next_decision`, `SessionSnapshot`
  (`session.ail:2061-2103`). They are a bypassed exploratory API (0 callers);
  `apply_state_delta` is already the live single applier. Rejected: keep and build a
  `SessionSnapshot`-based L1 harness — deferred; the live driver has no path to it and
  this plan's L1 coverage drives `decide` directly. *(They were likely intended as a
  snapshot-style loop API the pragmatic C2 driver never adopted.)*
- **D-F3 — the effectful `model_phase` extraction (WI-F3).** **Resolved: defer**
  (operator, 2026-07-05). Not required for correctness (finding 2 is not a defect), and
  it hits a real import cycle — `run_model_phase` needs `ledger_emit`, `mk_v2_ext_ctx`,
  `messages_to_msgs`, all in `session.ail`, which imports `model_phase.ail`. Doing it
  right means relocating those helpers to a lower shared module or injecting them as
  driver-constructed ports/closures (the ADR ports pattern) — a deliberate refactor,
  not a rider on a cleanup. Deferred to the ABI v3 track with the telemetry work.
  **D-F2 (delete the dead cluster) is the only decision still open.**

## Work items

`WI-F0` is setup; `WI-F1..F2` are the required fixes; `WI-F3` is optional; `WI-F4` is
the closing gate.

### WI-F0 — Baseline and instruments
- **Generate** the parity baseline from `fed914c` into a session-local path (the prior
  `/tmp/phase_c_blessed` is ephemeral and will not exist in a fresh session — regenerate
  it or bless a new path and use it consistently). Record the bless command. No code
  change.
- Add L1 scenario file `scripts/phase_f_pipeline_wiring.ail` (named now — the ADR
  Decision-detail-6 no-phantom-gates discipline).
- **Gate:** `PARITY_BASELINE=<baseline> make smoke_parity` green;
  `ailang check scripts/phase_f_pipeline_wiring.ail`.

### WI-F1 — Delete the dead `SessionSnapshot` cluster (finding 5)
- Remove `apply_phase_result` (`:2086`), `session_from_messages` (`:2066`),
  `next_decision` (`:2093`), `SessionSnapshot` (`:2061`). Confirm 0 callers first
  (`grep -rn` across `src/`, `scripts/`; `cgq.py q callers` each).
- **Parity:** byte-neutral (dead code).
- **Gate:** strict parity green; `make check_core` clean; `cgq.py q callers
  apply_phase_result` empty.

### WI-F2 — Honest `project()` prep + drop vestigial `ModelRequest.payload` (findings 1, 2-residue)
- Replace the `MkPayload(xs)`-wraps-everything stub (`phase_vocab.ail:160-171`) with an
  honest pure-prep body: pin the system prefix and build the `CompactableSegment`
  (reuse `split_for_compaction`), returning the structural prep. **It does not make an
  exhaustion/Fail decision** — per D9 that lives in the effectful `seal_compacted_payload`
  (unchanged). Keeping `project()` non-failing is what keeps this byte-neutral (no
  early-fail skips events).
- Shrink `ModelRequest` to `{model}` (`phase_vocab.ail:139`); update the sole
  construction site `step_machine.ail:74` to `CallModel({model})`. The driver's
  `CallModel(_)` already ignores the payload; `model_phase` imports `ModelRequest` but
  never reads `.payload`. So this removes the "discarded payload" residue by
  construction.
- Rewrite the stale stub comment ("not called from production" — it *is* called by
  `decide` via `call_model_or_fail`, `step_machine.ail:72`; state that its prep output
  is consumed only once the optional WI-F3 lands, and that exhaustion is the seal's job).
- **Parity:** byte-neutral (`project()`'s output is still discarded by the driver until
  WI-F3, and it never Fails, so no event-stream change; the `ModelRequest` shrink is an
  internal-type change with one construction site).
- **Gate:** strict parity green; `ailang test src/core/phase_vocab.ail`;
  `ailang test src/core/step_machine.ail`.

### WI-F3 — (OPTIONAL, deferred by D-F3) Extract the effectful `model_phase`
Addresses finding 6 + the organizational half of finding 2 + the ADR gap
(`model_phase.ail` is pure-only today; the ADR wants it "effectful via ports →
`PhaseResult`"). **Not required for correctness. Do not land inside the F1–F2 series.**
- Move the inline block (`session.ail:~1385-1415`: `split_for_compaction` →
  `dispatch_pre_step_chain` → `seal_compacted_payload` → `dispatch_step`) into an
  effectful `run_model_phase` in `model_phase.ail`, returning
  `{ next_provider, dispatched_result, stages, phase, compacted_msgs, stream_id }`.
  Retry, `ThinkingStream{Start,End}`, totals, and `next_state` stay in `c2_loop`, which
  resumes on `dispatched_result`. It consumes `project()`'s prep (from WI-F2) instead
  of recomputing the split — finally giving `project()` a real consumer.
- **Resolve the import cycle first** (D-F3): relocate `ledger_emit`, `mk_v2_ext_ctx`,
  `messages_to_msgs` to a lower shared module, **or** pass them plus the `on_chunk`
  handle and a discrete-event emit handle as **driver-constructed ports/closures** so
  `model_phase` never imports `session` (single emission authority stays in the driver;
  ADR D5).
- Have `run_model_phase` compute cost (`step_cost_millicents`, `cost_phase.ail:10`) so
  `phase.cost_delta_millicents` is genuinely phase-sourced; then the driver consumes
  `phase.transcript_append` (already phase-computed) and `phase.cost_delta_millicents`
  instead of the inline `step_result_to_message` (`:1457`) / `step_cost_millicents`
  (`:1449`).
- **Parity:** byte-neutral (relocation + identical-value dedup). Guard with golden-value
  checks (`phase.transcript_append == [step_result_to_message(result)]`,
  `phase.cost_delta_millicents == step_cost`; field-wise if `[Message]` `==` is
  unavailable) **and** the streaming byte-parity test
  (`thinking_stream_start → N×delta → thinking_stream_end`) — a phase-boundary mis-cut
  silently reorders ledger events.
- **Fixture:** L1 test needs a no-extension `ExtRuntime` (pass-through chain) + a
  `Scripted` provider under `--caps IO` (fake ports ⇒ the 9-effect row isn't performed —
  the `smoke_ports_record` result).
- **Gate:** strict parity green; golden-value + streaming-parity checks;
  `ailang test src/core/model_phase.ail`.

### WI-F4 — Closing gate
- Run the verification block as a unit (below).
- Update `ISSUE-functional-core-pipeline-not-wired.md` to Resolved with per-finding
  dispositions matching the table above (2 = not-a-defect/residue-only; 3-totals/finish
  = not defects; 3-telemetry + 4 = deferred to ABI v3; 6 = optional WI-F3).
- **Gate:** the WI-C8-equivalent block passes as a block.

## Deferred to the ABI v3 track (out of scope; do not start now)

`HANDOFF-continue-phase-c.md` explicitly bars starting ABI v3 / conformance /
`compaction_ai` 0.3.0. Findings 3-telemetry and 4 land there because that is where
their *consumer* is:

- Per D9 / Open Question 4, actual-token gating is **compactor-extension policy** fed by
  `ExtCtx.telemetry`. That field arrives with ABI v3. Until then, threading real
  telemetry into `C2LoopState`/`StepState` (replacing the `c2_step_state:406` zero) has
  no in-scope consumer, so it is deliberately *not* done here (no unconsumed state,
  no 14-site edit for zero current benefit).
- When ABI v3 lands: add `telemetry: TokenTelemetry` to `C2LoopState`, seed it, populate
  from `applied.telemetry` (already the real tokens via `result_delta`,
  `model_phase.ail:15`), and surface it through `ExtCtx.telemetry`. That work carries
  its own D-B7 fence *iff* a compactor then gates on it and changes output.

## Sequencing & dependencies

```
WI-F0 → WI-F1 → WI-F2 → WI-F4
                    ⇧
       WI-F3 (optional; any time after F2, gated separately)
```
Linear for the required series (all byte-neutral). WI-F3, if taken, depends on WI-F2
(it consumes `project()`'s prep) and is gated on its own parity + streaming-parity run.

## Parity classification summary

| WI | Required? | Changes bytes? | Fence |
|---|---|---|---|
| F1 | yes | No (dead-code deletion) | strict parity + 0-callers proof |
| F2 | yes | No (`project()` never Fails; internal-type shrink) | strict parity |
| F3 | optional | No (relocation + identical-value dedup) | strict parity + golden-value + streaming-parity |

## Blast radius

Grounded against `fed914c`. Required work touches 3 modules; optional F3 adds a 4th.
Extension side, compaction primitives, telemetry/ABI v3, and all `run_v2*` entrypoints
untouched.

**Modules modified:**

| Module | What changes | WIs |
|---|---|---|
| `src/core/session.ail` | delete `SessionSnapshot` cluster (F1); *[opt]* compaction block → `run_model_phase`, consume `transcript_append`/`cost_delta` (F3) | F1,(F3) |
| `src/core/phase_vocab.ail` | `project()` stub → honest pure prep; `ModelRequest` → `{model}` (F2) | F2 |
| `src/core/step_machine.ail` | `CallModel({model})` at `:74` (F2) | F2 |
| `src/core/model_phase.ail` | *[opt]* new **effectful** `run_model_phase` (F3) | (F3) |

**Type / signature ripples:**
- `ModelRequest` → `{model}` (F2): sole consumer `step_machine.ail:74`; driver's
  `CallModel(_)` ignores it; `model_phase` never reads `.payload`. Safe.
- `project()` return (F2): flows to `step_machine.ail:72-74`.
- `SessionSnapshot` deletion (F1): removes 4 exported symbols; 0 callers.
- *[opt]* `run_model_phase` (F3): consumed only in `c2_loop`'s `CallModel` arm; its
  9-effect row and the import-cycle resolution are the F3 cost (D-F3).

**No `C2LoopState` field changes** in the required scope — the telemetry field (and its
14 constructor sites: the 13 `next_state` literals + `c2_initial_state:417`) belongs to
the deferred ABI v3 work, not here.

**Effect-row / purity:** required work adds no effect rows. *[opt]* F3 introduces the
9-effect row into `model_phase.ail` (pure today); its existing pure funcs
(`result_delta`, `phase_from_result`) stay pure.

**Deliberately NOT touched (containment boundary):**
- Extension ABI / ABI v3, `ExtCtx.telemetry`, `dispatch_pre_step_chain`
  (`ext/runtime.ail:185`), compaction extensions.
- `compaction.ail` / `seal_compacted_payload` — the live, correct exhaustion decision.
- `totals` accumulation (`c2_add_step_totals`) and `last_finish_reason` control-flow
  overrides — **intentional** (the delta carries neither; changing them regresses
  `decide`).
- The driver's inline effectful compaction — **correct as-is** unless the optional F3
  relocates it.
- The pre-existing `step_cost_millicents` duplication (`cost_phase.ail:10` vs
  `session.ail:842`) — noted, out of scope.
- All `run_v2*` entrypoints and the `agent_loop_v2.ail` facade / `rpc.ail` entry —
  `c2_loop`'s signature is unchanged. **Re-verify, don't edit.**

**Gates / baselines:** parity fleet + baseline (no re-bless — nothing changes bytes),
`phase_b_projection_gate.sh`, and `scripts/phase_f_pipeline_wiring.ail`.

## Rejected alternatives

- **Give `project()` a real Fail-capable exhaustion pre-gate** — misaligned with D9
  (exhaustion is the effectful seal; actual-token gating is extension/ABI-v3 policy) and
  inherently not byte-neutral (early-fail skips events). If ever wanted, it is a fenced
  behavior change on the ABI v3 track.
- **Thread telemetry now** — no in-scope consumer (ABI v3 owns it); adds unconsumed
  state and a 14-site edit for zero current benefit; barred by the handoff.
- **Route live state through `apply_phase_result` as "the single applier"** —
  `apply_state_delta` already *is* that path (DIAGRAM §1) and is live;
  `apply_phase_result` is a dead wrapper (`= apply_state_delta` + trace passthrough) and
  `StateDelta` carries no `history`, so it could not own transcript anyway. Deleted (D-F2).
- **"Fix" `totals`/`last_finish_reason` to flow from the delta** — a regression: the
  delta carries no `totals` (accumulation is driver-owned) and `last_finish_reason` is a
  driver control signal `decide` branches on.
- **Extract the effectful `model_phase` as part of the correctness fix** — not required
  (finding 2 is not a defect) and hits a `session ↔ model_phase` import cycle; kept
  optional and separate (D-F3).

## Risks

- **F2 must keep `project()` non-failing** to stay byte-neutral; a reviewer might
  "helpfully" re-add an exhaustion Fail. The stub-comment rewrite must state that
  exhaustion is the seal's job and the pre-gate is deferred, so the constraint is
  explicit in-code.
- **[opt] F3 phase-boundary mis-cut.** The model block is not a clean span — retry,
  stream Start/End, totals interleave. A wrong cut silently reorders ledger events;
  guard with the streaming byte-parity test. (One more reason it is deferred.)
- **[opt] F3 import-cycle resolution** is the real work; underestimating it (treating
  it as a mechanical move) is the trap — hence D-F3 defers it to a deliberate refactor.

## Verification block (WI-F4, run as a unit)

```bash
ailang --version                                   # must be v0.26.0 / 3b52a24
git status --short
PARITY_BASELINE=<baseline> make smoke_parity
./scripts/phase_b_projection_gate.sh <baseline>
make check_core && make test_core && make test_integration
ailang test src/core/step_machine.ail
ailang test src/core/phase_vocab.ail
ailang test src/core/session.ail
# F3 only, if taken:
# ailang test src/core/model_phase.ail
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
ailang run --caps IO --entry main scripts/phase_f_pipeline_wiring.ail
(cd .agent/projects/004_phase_core_refactor/sketch && ailang check probe_consumer_decide.ail)
```

## Open questions

1. **Take the optional WI-F3 now, or defer with the ABI v3 track?** — **Resolved:
   defer** (operator, 2026-07-05). WI-F3 is out of this plan's execution scope; it rides
   the ABI v3 track alongside the deferred telemetry work. Required scope is now exactly
   **WI-F0 → WI-F1 → WI-F2 → WI-F4**, all byte-neutral. Finding 6 and the organizational
   half of finding 2 are deferred with it.
2. **Stream-delta append handle ownership** — **Resolved: driver-owned** (operator: "go
   with your recommendation", 2026-07-05); relevant only if WI-F3 is taken. `on_chunk`
   (and any discrete-event emit handle) stays driver-constructed and is passed into
   `run_model_phase`, preserving single logical emission authority (ADR D5).
