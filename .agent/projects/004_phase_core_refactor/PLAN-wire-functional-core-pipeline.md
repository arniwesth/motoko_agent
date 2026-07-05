# PLAN: Wire the functional-core pipeline into the live Phase C driver

Date: 2026-07-05
Status: Draft (for operator review)
Verified against: branch `arniwesth/mot-27-phased-core-architecture`, commit `fed914c`
Pinned toolchain: AILANG v0.26.0 (commit `3b52a24`)

Fixes: `ISSUE-functional-core-pipeline-not-wired.md` (findings 1–6, as corrected by
the 2026-07-05 independent-verification pass).
Relates to: `ADR-001-phase-oriented-core.md` (D1, D3, D5, D9);
`DIAGRAM-phase-core-architecture.md` §1, §3; `PLAN-phase-c2-live-inversion.md`
(the driver this plan finishes); `NOTE-phase-c-implementation-findings.md`.

---

## Framing

The Phase C driver (`session.ail:c2_loop`) is live and shippable, but it threads
only the cheap half of the functional-core pipeline. The compaction sub-pipeline,
telemetry, totals, transcript-append, and cost are duplicated inside the driver's
own `C2LoopState` flow. This plan makes the live path match the ADR.

**The overriding constraint is strict JSONL parity.** This is the same discipline
as Phases A–C: any change that alters production bytes is classified under D-B7
(expected-diff evidence + baseline re-bless) *before* it lands; everything else
must be byte-neutral against `/tmp/phase_c_blessed`. Most work items here are
byte-neutral refactors. Exactly one (WI-F4, telemetry threading) can change
compaction *behavior* and is fenced accordingly.

## The architectural clarification that reframes findings 1 & 2

The ISSUE reads finding 2 ("driver discards `CallModel`'s payload and runs its own
compaction") as a pure defect. It is half a defect and half a **necessary
consequence of the pure/effectful split**, and the plan must not pretend
otherwise:

- The compactor chain is **effectful**: `dispatch_pre_step_chain`
  (`ext/runtime.ail:185`) carries the 9-effect row
  `{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}`.
- `decide` is **pure** (`step_machine.ail:78`) and can therefore *never* run the
  compactor chain. So `CallModel`'s payload, produced inside pure `decide` via
  `project()`, can only ever be a *pre-chain* value. The driver is right to not
  ship it to the provider as-is.

This matches the ADR's own two-op design (D3/D9, ADR line 208-210): `project()` is
the **pure precheck**; `seal_compacted_payload()` is the **post-chain seal**. The
effectful chain belongs *between* them, in an effectful phase — not in `decide`.

So "wire `project()` into production" is **not** the fix. The fix is:

1. Give `project()` a real pure-precheck job (or retire it if precheck buys
   nothing — see D-F1).
2. Move the effectful compaction+model-call block out of `c2_loop`'s inline body
   into an effectful **`model_phase`** function that the driver calls — the ADR's
   "single logical authority", and the seam that makes the compaction path
   L1-testable instead of reachable only through the whole driver.
3. Thread telemetry and consume the full `StateDelta` / `PhaseResult` so the
   driver stops maintaining a shadow copy of state.

## Decisions (for operator sign-off)

- **D-F1 — `project()`'s fate.** Recommend: keep it, narrowed to a genuine pure
  precheck (pin system prefix + split segment + estimate-based exhaustion
  precheck), and have the effectful phase consume its `PinnedSplit` rather than
  re-running `split_for_compaction`. Rejected alternative: delete `project()` and
  let `CallModel` carry only `{model}`. Rejected because D9's actual-token-gated
  precheck wants a pure, Z3-eligible exhaustion gate, and the ADR names
  `project()` normatively.
- **D-F2 — `apply_phase_result` (finding 5).** Recommend: make it the driver's
  single state-application path (delta + transcript + events + cost), replacing
  the ad-hoc `apply_state_delta` call and the inline `assistant_msg`/`step_cost`
  duplication, then it is no longer dead. Rejected alternative: delete
  `apply_phase_result` + `SessionSnapshot` as scaffolding. Rejected because
  findings 3/5/6 share one root cause and one fix — routing state through the
  single applier the ADR's D5 prescribes — so deleting it would re-entrench the
  duplication findings 3 and 6 describe.
- **D-F3 — telemetry carrier (finding 4).** Recommend: thread real per-step tokens
  through `PhaseResult.delta.telemetry` (already populated by `result_delta`,
  `model_phase.ail:15`) into the next `StepState`, by giving `C2LoopState` a
  `telemetry` field so `c2_step_state` stops hardcoding zero. This is the only
  change that can move compaction decisions; see WI-F4's parity fence.

## Work items

Ordered; each leaves the tree green and shippable. `WI-F0` is setup; `WI-F1..F5`
are the fixes; `WI-F6` is the closing gate.

### WI-F0 — Baseline and instruments
- Re-bless the current parity baseline at `fed914c` (or confirm `/tmp/phase_c_blessed`
  still matches) and record the exact command block. No code change.
- Add an L1 scenario stub file `scripts/phase_f_pipeline_wiring.ail` (named now so
  later gates are executable — same no-phantom-gates discipline as ADR Decision
  detail 6). It will hold the assertions WI-F1..F5 fill in.
- **Gate:** `PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity` green;
  `ailang check scripts/phase_f_pipeline_wiring.ail`.

### WI-F1 — Extract the effectful compaction+model call into `model_phase`
Addresses findings 1 & 2 (structurally, per the reframe above).
- Move the inline block `session.ail:1385-1415` (split → `dispatch_pre_step_chain`
  → `seal_compacted_payload` → `ProviderCallPrepared` → `dispatch_step`) into an
  effectful function in `model_phase.ail`, e.g.
  `run_model_phase(rt, ctx_inputs, split, model, limit, on_chunk) -> ModelPhaseOutput`.
- The driver's `CallModel(_)` arm calls it. `decide` still produces the `CallModel`
  decision; the effectful phase does the chain + seal (the ADR's post-chain seal
  seam). `project()`'s pure precheck output (`PinnedSplit`) is passed in rather
  than recomputed (ties to D-F1 / WI-F5).
- **Parity:** byte-neutral. The moved code is identical; only its home changes.
- **Gate:** strict parity green; `ailang test src/core/model_phase.ail` (new phase
  covered by an L1 test driving it with scripted ports under `--caps IO`).

### WI-F2 — Route state application through `apply_phase_result` (single applier)
Addresses finding 5 and the totals/finish-reason half of finding 3.
- Replace the inline `apply_state_delta` call (`session.ail:1456`) and the
  per-branch `next_state` field-picking with one `apply_phase_result(snapshot,
  phase)` call whose result builds the next `C2LoopState`. `apply_phase_result`
  gains 6 real callers, retiring the dead-code finding.
- Route `totals` and `last_finish_reason` through the applier instead of the
  driver's `new_totals` / branch-literals, *or* consciously record them as
  driver-owned in `apply_phase_result`'s contract (whichever preserves bytes —
  totals are already summed identically; the change is which code owns the sum).
- **Parity:** byte-neutral (same values, single owner). Verify with a diff of
  `loop_totals_updated` / `run_summary` events specifically.
- **Gate:** strict parity green; `cgq.py q callers apply_phase_result` now
  non-empty; `ailang test src/core/session.ail`.

### WI-F3 — Consume `transcript_append` and `cost_delta_millicents`
Addresses finding 6.
- Build the assistant message from `phase.transcript_append` instead of the inline
  `step_result_to_message(result)` (`session.ail:1457`); source `step_cost` from
  `phase.cost_delta_millicents` instead of the independent `step_cost_millicents`
  call (`session.ail:1449`).
- `phase_from_result` already computes both identically, so this removes a
  duplicate computation, not a behavior.
- **Parity:** byte-neutral (assert `phase.transcript_append == [step_result_to_message(result)]`
  and `phase.cost_delta_millicents == step_cost` hold before deleting the inline
  forms — a golden-value pure test in `phase_f_pipeline_wiring.ail`).
- **Gate:** strict parity green; golden-value equality test passes.

### WI-F4 — Thread telemetry (finding 4) — behavior-fenced
Addresses finding 4 and the telemetry half of finding 3. **The one item that can
change output.**
- Add `telemetry: TokenTelemetry` to `C2LoopState` (`session.ail:317`), seed it in
  `c2_initial_state`, and set `c2_step_state:406` to read it instead of hardcoding
  zero. Populate the next state's telemetry from `applied.telemetry` (already the
  real tokens via `result_delta`).
- **Consequence:** `project()`'s exhaustion precheck (`t.last_input_tokens >=
  limit`) and any actual-token-gated compactor policy now see real numbers. This
  *can* change when compaction fires ⇒ a real parity diff.
- **Parity:** classify under D-B7 *before* landing. Capture the expected-diff (which
  sessions now compact earlier/later, which `compaction_*` events appear) as
  `EVIDENCE-phase-f-telemetry-expected-diff.md`, then re-bless. If the diff is
  empty on the parity fleet (likely — the fleet is short sessions below any tier),
  record that and land as byte-neutral.
- **Gate:** D-B7 evidence recorded; new baseline blessed if nonempty; L1 scenario
  `actual_tokens_reach_project` asserts `c2_step_state` telemetry is nonzero after
  a scripted multi-step run.

### WI-F5 — Narrow `project()` to a real pure precheck
Addresses finding 1 (the stub body) and closes D-F1.
- Replace the `MkPayload(xs)`-wraps-everything stub (`phase_vocab.ail:160-171`)
  with: pin system prefix, split segment (reuse `split_for_compaction`), and an
  estimate-based exhaustion precheck against `pol.context_limit`. It returns the
  `PinnedSplit` (or a sealed precheck payload) the effectful phase consumes in
  WI-F1. It does **not** run the compactor chain (it cannot — pure).
- Update or delete the stale stub comment ("not called from production").
- **Parity:** byte-neutral if the precheck's exhaustion threshold matches the
  driver's `seal_compacted_payload` gate (`exhaustion_pct()`); assert equivalence
  in a pure test so the pure precheck and effectful seal cannot disagree.
- **Gate:** strict parity green; `ailang test src/core/phase_vocab.ail` (precheck
  vs. seal agreement test); `ailang test src/core/step_machine.ail`.

### WI-F6 — Closing gate
- Run the full Phase C verification block as a unit (parity, projection gate,
  minimal-caps L1 family, approval protocol, pure-module tests, sketch probes,
  sealing negative probe).
- Update `ISSUE-functional-core-pipeline-not-wired.md` status to Resolved with a
  per-finding disposition and the commit that closed each.
- **Gate:** the WI-C8-equivalent block passes as a block (commands below).

## Sequencing & dependencies

```
WI-F0 ─┬─> WI-F1 ─> WI-F2 ─> WI-F3 ─> WI-F5 ─> WI-F6
       └─> WI-F4 (independent; land last of F1–F5 so its D-B7 diff is isolated)
```
WI-F1 is the enabling structural move; F2/F3/F5 are byte-neutral consolidations on
top of it; F4 is fenced and lands isolated so its parity diff is never entangled
with a refactor's.

## Parity classification summary

| WI | Changes bytes? | Fence |
|---|---|---|
| F1 | No (code relocation) | strict parity |
| F2 | No (single owner, same values) | strict parity + totals/summary diff check |
| F3 | No (dedup of identical computation) | golden-value equality test first |
| F4 | **Possibly** (telemetry gates compaction) | **D-B7 evidence + re-bless** |
| F5 | No (precheck ≡ seal threshold) | strict parity + agreement test |

## Rejected alternatives

- **Run the compactor chain inside pure `decide`/`project()`** — impossible;
  `dispatch_pre_step_chain` is effectful. This is why finding 2 is partly
  structural, not a pure defect.
- **Delete `apply_phase_result`, `transcript_append`, `cost_delta_millicents`,
  `project()` as unused scaffolding** — re-entrenches the duplication findings
  3/5/6 name, and contradicts D5/D3 which are normative. Consolidation, not
  deletion.
- **Fix telemetry (F4) folded into the F1–F3 refactor commits** — mixes a
  behavior change into byte-neutral refactors, producing an unreviewable parity
  diff (the exact failure mode `HANDOFF-continue-phase-c.md` warns about). Kept
  isolated.

## Risks

- **Hidden parity diff in F2/F3.** The claim "same values" must be *proven* by
  golden-value equality tests before the inline forms are deleted, not assumed.
- **F4 telemetry changes more than compaction.** Real tokens flowing into
  `StepState` could feed any actual-token consumer added since; grep
  `last_input_tokens` consumers before landing.
- **`project()`/seal threshold drift (F5).** If the pure precheck and effectful
  seal use different limits/percentages they will disagree on exhaustion; the
  agreement test is mandatory, not optional.

## Verification block (WI-F6, run as a unit)

```bash
ailang --version                                   # must be v0.26.0 / 3b52a24
git status --short
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed
make check_core && make test_core && make test_integration
ailang test src/core/step_machine.ail
ailang test src/core/phase_vocab.ail
ailang test src/core/model_phase.ail
ailang test src/core/session.ail
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
ailang run --caps IO --entry main scripts/phase_f_pipeline_wiring.ail
(cd .agent/projects/004_phase_core_refactor/sketch && ailang check probe_consumer_decide.ail)
```

## Open questions

1. Does the parity fleet contain any session long enough for WI-F4 to produce a
   nonempty compaction diff? If not, F4 is byte-neutral in practice and the D-B7
   evidence records "no fleet session reaches a tier" — but the L1 scenario must
   still prove telemetry is nonzero synthetically.
2. Should `model_phase` also absorb the stream-delta append handle (currently
   `on_chunk` built inline at `session.ail:1406`), or does that stay driver-owned?
   Leaning driver-owned (single logical authority for the ledger), passed in.
