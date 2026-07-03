# Phase-C implementation plan: full inversion, scripted ports, L1 scenarios

Date: 2026-07-03
Status: Implementation-ready plan (implements Phase C only of `ADR-001-phase-oriented-core.md`)
Pinned toolchain: **AILANG v0.26.0** (commit `3b52a24`, built `2026-07-02_15:03:57`).
Verified this session: `ailang --version` reports v0.26.0 / `3b52a24`. Phase B endpoint is
`a9616ad`; the Phase C handoff commit is `0b28c86`; review HEAD is `34f901a` (`Added Plan C`).

Authored by a fresh session, per the same fresh-session rule recorded for the earlier plans:
the Phase C deliverables and gate are read from the ADR's Phase C section, not from prior
line-number memory (`ADR-001-phase-oriented-core.md:443`, `ADR-001-phase-oriented-core.md:458`).
The Phase B implementation range was re-read as the actual commit sequence
`fd933b6^..a9616ad`, whose commits are WI-0 through WI-8 plus WI-7 split commits
(`.agent/summaries/2026-07-03-phase-b-phase-results-implementation.md:8`,
`.agent/summaries/2026-07-03-phase-b-phase-results-implementation.md:20`).

Relates to:
- `ADR-001-phase-oriented-core.md`: normative. Phase C deliverables are pure `decide`, driver
  execution, scripted ports, scripted approval, L1 compaction/checkpoint scenarios, and the
  minimal-caps/no-network gate (`ADR-001-phase-oriented-core.md:443`,
  `ADR-001-phase-oriented-core.md:459`).
- `PLAN-phase-b-phase-results.md`: house style and parity discipline. D-B1 explicitly deferred
  full `PhaseResult` extraction for tool/model phases until Phase C because `tool_pending` had to
  precede `readLine()` in the live protocol (`PLAN-phase-b-phase-results.md:310`,
  `PLAN-phase-b-phase-results.md:322`). D-B7 is inherited: no re-bless without an expected-diff
  table when production bytes change (`PLAN-phase-b-phase-results.md:392`,
  `PLAN-phase-b-phase-results.md:405`).
- `RESEARCH-phase-core-dst-design.md`: P1/P2/P3 define pure decisions, in-memory typed trace, and
  generalized ports (`RESEARCH-phase-core-dst-design.md:86`,
  `RESEARCH-phase-core-dst-design.md:134`); §5 maps the current residual logic to Phase C homes
  (`RESEARCH-phase-core-dst-design.md:297`, `RESEARCH-phase-core-dst-design.md:308`).
- `NOTE-ailang-run-exit-code-false-alarm.md`: measurement discipline. Harnesses must use
  `pipefail`, and exit-code claims must not be read through a pipeline
  (`NOTE-ailang-run-exit-code-false-alarm.md:82`,
  `NOTE-ailang-run-exit-code-false-alarm.md:93`).

## Goal

Land Phase C of ADR-001 and stop there: `decide` becomes pure in `step_machine.ail`; `session.ail`
becomes the driver that executes decisions and is the sole live emitter; ports replace the
test-only `StepProvider` seam; the approval protocol moves from mid-recursion `readLine()` into
`AwaitApproval`; the core L1 scenario family runs under `--caps IO` or less with no real model or
network; checkpoint digests and validation become real. ABI v3, conformance kit work,
`compaction_ai` 0.3.0, and registry publication of the structural package are out of scope.

## Out Of Scope

- ABI v3: no `ExtCtx.ports`, ABI `Compacted` artifact field, ABI telemetry, or extension hook
  constructor migration. The ADR puts that on a parallel track (`ADR-001-phase-oriented-core.md:461`,
  `ADR-001-phase-oriented-core.md:463`).
- The conformance kit and registry-wide conformance gate. The ADR separates core DST gates from
  registry/conformance gates (`ADR-001-phase-oriented-core.md:469`,
  `ADR-001-phase-oriented-core.md:475`).
- `compaction_ai` v0.3.0. Phase C may script fake compactors, but it must not migrate the real
  registry package (`ADR-001-phase-oriented-core.md:283`, `ADR-001-phase-oriented-core.md:295`).
- Registry publication of `motoko_ext_compaction_structural`. Phase B left the in-repo path
  dependency working by vendoring a tiny helper, while registry publication remains ABI-track
  work (`NOTE-phase-b-implementation-findings.md:30`,
  `NOTE-phase-b-implementation-findings.md:42`).
- A broad interactive approval UI. Phase C gates the scripted TUI/runtime wire protocol:
  `tool_pending` event-before-read, TUI-shaped `approve`/`deny` input, default handling, and
  `RunTools` tail reissue. Full UI affordances can follow after the protocol is inverted.

## TL;DR

1. **WI-C0 - instruments and Phase C baseline**: add the L1 scenario harness shell, phase-C parity
   baseline protocol, and the checkpoint-hash probe. No production behavior change.
2. **WI-C1 - checkpoint mechanics become real**: replace labeled length digests with canonical
   SHA-256 content digests, make `payload_digest` use the same content hash family, add
   checkpoint-chain validation APIs, and re-bless only after a D-B7 expected-diff table for the
   mandated `provider_call_prepared.payload_digest` value changes.
3. **WI-C2 - pure policy modules**: add `step_machine.ail`, `cost_phase.ail`, and `recovery.ail`;
   seed `decide` from the sketch's re-derivation proof and move loop policy into pure tests.
4. **WI-C3 - scripted ports and in-memory ledger**: introduce ports plus an in-memory ledger/trace
   sink, keeping `run_v2_with_stub` as a thin adapter while the fleet migrates.
5. **WI-C4 - approval inversion first**: land `AwaitApproval(ApprovalRequest)` execution and the
   scripted TUI approval scenario before extracting the full tool phase.
6. **WI-C5 - driver and phase split**: add `session.ail`, `model_phase.ail`, `tool_phase.ail`,
   `hook_phase.ail`, and `tool_stream_phase.ail`; `agent_loop_v2.ail` becomes a compatibility
   facade.
7. **WI-C6 - parity fleet migration**: move scripts from `run_v2_with_stub` to scripted ports,
   leaving only the adapter definition; use D-B7 expected-diff tables for any event-order drift.
8. **WI-C7 - L1 scenario family**: complete the named compaction/checkpoint/approval scenarios
   under `--caps IO` or less, with normalized trace failure reports.
9. **WI-C8 - final gate**: run the full toolchain, core tests, Phase B projection gate, Phase C L1
   scenarios, sketch probes, sealing probe, and strict or table-explained parity.

## Grounding: Phase B As Built Vs. Its Plan

1. **Phase B really left `loop_v2` as the driver.** The current loop still owns budget/cost
   checks, compaction, model call, stream retry, response interpretation, DP7, persist nudge, and
   recursion (`src/core/agent_loop_v2.ail:1088`, `src/core/agent_loop_v2.ail:1456`). That matches
   D-B1's deferral: full phase modules were intentionally left for Phase C
   (`PLAN-phase-b-phase-results.md:310`, `PLAN-phase-b-phase-results.md:323`).

2. **The approval seam is still live in recursive dispatch.** Current `dispatch_calls` emits
   `tool_pending` and then blocks on `readLine()` in the same recursive arm
   (`src/core/agent_loop_v2.ail:759`, `src/core/agent_loop_v2.ail:770`). This is the reason
   `AwaitApproval` must land before the tool phase can return fully batched `PhaseResult`s
   (`ADR-001-phase-oriented-core.md:251`, `ADR-001-phase-oriented-core.md:258`).

3. **There is still no in-memory ledger.** `ledger_emit` projects a `LedgerEvent` straight to
   JSONL and Trace (`src/core/agent_loop_v2.ail:255`, `src/core/agent_loop_v2.ail:262`).
   `StagePassed` exists as runtime data but is dropped by `emit_pre_step_stages`
   (`src/core/ext/runtime.ail:29`, `src/core/agent_loop_v2.ail:278`). G-B1 says pass-through
   stage records arrive with Phase C's in-memory ledger (`ADR-001-phase-oriented-core.md:1248`,
   `ADR-001-phase-oriented-core.md:1253`).

4. **`run_v2_with_stub` survived and is load-bearing.** The adapter is still exported from
   `agent_loop_v2.ail` (`src/core/agent_loop_v2.ail:1682`, `src/core/agent_loop_v2.ail:1710`).
   It is used by the parity fleet, including the chain, compaction, DP7, cost-budget, pending,
   fixture, stream, and tool parity smokes (`scripts/smoke_v2_pending_full_loop.ail:46`,
   `scripts/smoke_v2_compaction_chain.ail:9`). Phase C must supersede it by scripted ports with a
   strangler adapter, not delete it in one step.

5. **The validator history matters.** The findings note says WI-5 temporarily narrowed
   `validate_compactor_output`; WI-6 fixed the real bug by comparing against the full output,
   not the shrinking recursion tail (`NOTE-phase-b-implementation-findings.md:5`,
   `NOTE-phase-b-implementation-findings.md:28`). The current predicate has identity and
   pair-severing tests (`src/core/phase_vocab.ail:698`, `src/core/phase_vocab.ail:720`).
   Phase C must not rewrite this predicate without a minimal repro.

6. **The structural extension path-dependency outcome is only partially the plan's happy path.**
   The external probe was positive, but the root package hit MOD011 when the mirrored
   `motoko_core` module collided with the root module (`NOTE-phase-b-implementation-findings.md:32`,
   `NOTE-phase-b-implementation-findings.md:37`). The committed structural package vendors the
   helper instead (`NOTE-phase-b-implementation-findings.md:39`,
   `NOTE-phase-b-implementation-findings.md:42`); registry publication remains out of scope.

7. **Checkpoint and payload digests are still placeholders.** `history_digest` is length-based
   and explicitly labeled as a Phase B/C obligation (`src/core/phase_vocab.ail:39`,
   `src/core/phase_vocab.ail:42`). `payload_digest` is also labeled non-content-hash
   (`src/core/phase_vocab.ail:131`, `src/core/phase_vocab.ail:135`). D-B6 says Phase C replaces
   both labels with the real content-hash work (`PLAN-phase-b-phase-results.md:384`,
   `PLAN-phase-b-phase-results.md:390`).

8. **The hash primitive handoff note is stale in a useful way.** I found `std/crypto.sha256Hex`,
   a pure SHA-256 hex function (`ailang/std/crypto.ail:1`, `ailang/std/crypto.ail:21`), and the
   bundled example runs from the AILANG tree. Phase C should still add a minimal in-repo probe
   before using it in `phase_vocab`, because the handoff correctly required a substrate check.

9. **The TUI still has only unknown-event tolerance for `tool_pending`.** The runtime event union
   has typed v2 tool dispatch events but no `tool_pending` variant (`src/tui/src/runtime-process.ts:56`,
   `src/tui/src/runtime-process.ts:101`). The generic `send` path can write arbitrary JSON
   commands to stdin (`src/tui/src/runtime-process.ts:689`, `src/tui/src/runtime-process.ts:692`).
   The Phase C scenario should therefore gate the wire protocol, not assume a finished UI flow.

## Plan-Level Decisions

**D-C1 - Keep `phase_vocab.ail` as the type owner.** The ADR's module table assigns sealed types,
`StepState`, `LedgerEvent`, projection, invariants, and transcript builders to `phase_vocab.ail`
(`ADR-001-phase-oriented-core.md:235`, `ADR-001-phase-oriented-core.md:238`). Do not add a
separate public `ledger.ail` unless implementation discovers a cycle that cannot be solved inside
the current ownership. The in-memory layer can be `LedgerRecord`/`LedgerTrace` in `phase_vocab`,
with `LedgerEvent` staying the wire-projectable subset.

**D-C2 - Stage pass-through is in-memory only.** Phase B admitted only `provider_call_prepared`
and `ext_compaction_rejected` as new JSONL names; `StagePassed` currently produces no wire event
(`scripts/phase_b_projection_gate.sh:20`, `scripts/phase_b_projection_gate.sh:22`,
`src/core/agent_loop_v2.ail:278`). Phase C should record pass-through stages in the in-memory
trace for L1 invariants without adding a JSONL event type.

**D-C3 - Do not change the `StepDecision` constructor set casually.** The ADR's decision set
includes `CallModel`, `RunTools`, `AwaitApproval`, `InjectUserMessage`, `TakeCheckpoint`,
`Finalize`, and `Fail` (`ADR-001-phase-oriented-core.md:96`,
`ADR-001-phase-oriented-core.md:102`), and current `phase_vocab` already exports the same set
(`src/core/phase_vocab.ail:326`, `src/core/phase_vocab.ail:333`). If implementation cannot express
DP7/finalization policy without a new decision variant, stop and record an ADR gap before coding.

**D-C4 - `AwaitApproval` is a driver decision, not a tool-phase side effect.** Current live code
emits `ToolPending`, then reads, then either denies or continues (`src/core/agent_loop_v2.ail:761`,
`src/core/agent_loop_v2.ail:808`). The ADR requires `ApprovalRequest` to carry default behavior,
`stream_id`, and the suspended tail, with event-before-read and tail reissue semantics
(`ADR-001-phase-oriented-core.md:251`, `ADR-001-phase-oriented-core.md:258`). Tool planning may
discover a pending approval, but the driver performs the read.

**D-C5 - `run_v2_with_stub` is superseded by adapter strangling.** The scripted port system must
be the real test seam, but the existing parity fleet depends on `run_v2_with_stub`
(`src/core/agent_loop_v2.ail:1682`, `scripts/phase_a_event_parity.sh:171`). Keep the old entry as
a thin wrapper over scripted ports until all runtime scripts import the new entry; final grep must
show no script/test imports outside the compatibility adapter.

**D-C6 - Minimal-caps L1 means no fake network by accident.** The ports smoke proves fake ports
run under `--caps IO` even when their declared rows include `Clock`/`Env`
(`scripts/smoke_ports_record.ail:23`, `scripts/smoke_ports_record.ail:27`). Phase C L1 scenarios
must run with `--caps IO` or less; any need for `AI`, `Net`, `Stream`, `Process`, or `FS` is a
bug in the scenario harness unless the scenario explicitly exercises that effect.

**D-C7 - Parity risk is ordering, after the known digest-value diff.** Phase B completed typed
projection and the projection subset gate passed
(`.agent/summaries/2026-07-03-phase-b-phase-results-implementation.md:45`,
`.agent/summaries/2026-07-03-phase-b-phase-results-implementation.md:52`). Phase C should avoid
new JSONL names and new event fields. WI-C1 is the one known payload-value exception:
`provider_call_prepared.payload_digest` must change from the labeled interim digest to the real
content hash (`PLAN-phase-b-phase-results.md:384`, `PLAN-phase-b-phase-results.md:390`). That WI
must land a D-B7 expected-diff table, verify no field/order/name changes beyond that digest value,
and re-bless `/tmp/phase_c_blessed`. After that, the remaining parity risk is event ordering from
the control-flow inversion; any such diff needs its own expected-diff table before re-bless
(`PLAN-phase-b-phase-results.md:392`, `PLAN-phase-b-phase-results.md:405`).

## Work Breakdown

Order is load-bearing: instruments before rewrites; checkpoint hash before scenarios consume
digests; pure `decide` before driver inversion; approval before tool-phase batching; adapter before
fleet migration. After every WI, `make smoke_parity` must be identical to the current blessed
baseline or explained by an expected-diff table before re-blessing. WI-C0 starts from
`/tmp/phase_b_blessed`; WI-C1 creates the first Phase C baseline because the digest value diff is
mandatory; WI-C2 and later use `/tmp/phase_c_blessed`.

### WI-C0 - Instruments, Baseline, And Probe Shells

**Purpose.** Establish Phase C test surfaces with no production behavior change.

**File-level changes.**
- Add `scripts/phase_c_l1_scenarios.ail`: a runner that accepts pure scenario functions, prints
  `scenario=<id> invariant=<name>` on failure, and prints a normalized trace. Start with one
  harness self-test only.
- Add `scripts/phase_c_approval_protocol.ail`: a placeholder runner that imports the same harness
  but does not yet exercise runtime approval.
- Add `scripts/probe_phase_c_hash.ail`: minimal committed probe importing `std/crypto.sha256Hex`
  and checking the known `"hello"` digest from the stdlib docs (`ailang/std/crypto.ail:17`,
  `ailang/std/crypto.ail:21`).
- Add a `phase_c_l1` Makefile target that runs both Phase C scenario scripts under `--caps IO`
  (`Makefile:42`, `Makefile:51` show the existing smoke target style).

**Verification.**
```
ailang --version
ailang run --caps IO --entry main scripts/probe_phase_c_hash.ail
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
PARITY_BASELINE=/tmp/phase_b_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_b_blessed
```

**Rollback.** Revert the new scripts/Makefile target. No parity baseline changes are allowed in
this WI.

### WI-C1 - Real Checkpoint And Payload Digests

**Purpose.** Replace the labeled placeholder digests before any Phase C scenario consumes them.

**File-level changes.**
- `src/core/phase_vocab.ail`: import `std/crypto (sha256Hex)`; implement canonical
  length-delimited encoding for `[Message]` including `role`, `content`, `tool_call_id`, and
  every `ToolCall` id/name/arguments. Use `sha256:<hex>` as the digest string.
- `src/core/phase_vocab.ail`: make `history_digest` and `payload_digest` call the same canonical
  hash family. Keep the JSON field name `payload_digest` for wire compatibility
  (`src/core/phase_vocab.ail:363`, `src/core/phase_vocab.ail:487`).
- `src/core/phase_vocab.ail`: add a resume-validation helper, keeping the existing
  `history_from_seed([Message])` path for fresh histories (`src/core/phase_vocab.ail:25`,
  `src/core/phase_vocab.ail:29`). The new helper should validate checkpoint digest-chain data
  before returning `History`; if implementation cannot define this without a new seed wrapper,
  add the wrapper and update callers deliberately.
- `src/core/phase_vocab.ail`: keep `apply_checkpoint` as the atomic state rewrite path and add
  tests that no caller can receive a rewritten `History` without the event
  (`src/core/phase_vocab.ail:287`, `src/core/phase_vocab.ail:303`).
- Add a committed WI-C1 expected-diff table before re-blessing: either directly in this WI-C1
  section or as a generated expected-diff artifact referenced from this section, not as a second
  phase plan. The only allowed production-byte changes are `provider_call_prepared` lines whose
  `payload_digest` value changes from the labeled interim form to `sha256:<64 hex>`; event type,
  field set, field order, model, counts, and line order must remain unchanged.
- `scripts/phase_c_l1_scenarios.ail`: add the three checkpoint scenarios that do not need the new
  driver yet: `history_rewrite_requires_checkpoint_event`, `checkpoint_output_is_valid_transcript`,
  and a direct `checkpoint_never_emitted_in_v1` check against `step_machine` once WI-C2 lands. In
  this WI, mark only the first two active.

**Verification.**
```
ailang test src/core/phase_vocab.ail
ailang run --caps IO --entry main scripts/probe_phase_c_hash.ail
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
./scripts/phase_a_event_parity.sh /tmp/phase_c_digest_candidate
if diff -ru /tmp/phase_b_blessed /tmp/phase_c_digest_candidate > /tmp/phase_c_wi_c1.diff; then
  echo "expected WI-C1 digest diff, got none" >&2
  exit 1
else
  rc=$?
  test "$rc" -eq 1
fi
rg 'provider_call_prepared.*payload_digest|payload_digest.*provider_call_prepared' /tmp/phase_c_wi_c1.diff
awk '/^[-+][{]/ && $0 !~ /"type":"provider_call_prepared"/ { print; bad=1 } END { exit bad }' /tmp/phase_c_wi_c1.diff
# compare /tmp/phase_c_wi_c1.diff line-for-line with the committed WI-C1 expected-diff table
rm -rf /tmp/phase_c_blessed && cp -a /tmp/phase_c_digest_candidate /tmp/phase_c_blessed
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed
```

**Rollback.** Revert `phase_vocab` and the scenario additions. Re-run
`ailang test src/core/phase_vocab.ail` to prove the placeholder state is restored. Remove the
WI-C1 expected-diff table and restore `/tmp/phase_b_blessed` as the active parity baseline.

### WI-C2 - Pure Step Machine, Cost, And Recovery Policy

**Purpose.** Land pure `decide` and the pure homes for loop policy before the driver uses them.

**File-level changes.**
- Add `src/core/step_machine.ail`: import only exported wrappers/types from `phase_vocab`; define
  `decide(s: StepState, pol: StepPolicy) -> StepDecision` with no effect row. Seed from the sketch:
  `pending_tool_calls -> RunTools`, `last_finish_reason == "stop" -> Finalize`, otherwise
  `CallModel` or `Fail` (`sketch/sketch_vocabulary.ail:389`,
  `sketch/sketch_vocabulary.ail:401`).
- Extend `src/core/phase_vocab.ail` state/policy as needed for pure policy: stream retry counters,
  write-attempt state for persist nudge, pending approval state, finalization/DP7 status, and
  clock/session fields. The existing re-derivation fields already exist
  (`src/core/phase_vocab.ail:253`, `src/core/phase_vocab.ail:255`).
- Keep DP7 policy in `step_machine`: `decide` chooses whether a final answer is pending
  verification, whether a verifier rejection becomes `InjectUserMessage`, and whether disabled or
  fail-open verification may proceed to `Finalize`. The verifier command itself is only a port
  execution result fed back into `StepState`. If the current `FinalizeInfo`/`StepState` shapes
  cannot express that without a new `StepDecision` constructor, stop and record an ADR gap before
  coding (`ADR-001-phase-oriented-core.md:100`, `RESEARCH-phase-core-dst-design.md:305`).
- Add `src/core/cost_phase.ail`: move `step_cost_millicents`, warning-threshold calculation, and
  cap checks into pure functions (`src/core/agent_loop_v2.ail:959`,
  `src/core/agent_loop_v2.ail:963`).
- Add `src/core/recovery.ail`: move stream-retry and persist-nudge decisions into pure functions;
  retire marker scanning from the future path (`src/core/agent_loop_v2.ail:1047`,
  `src/core/agent_loop_v2.ail:1065`).
- Add inline tests for every decision branch: step budget, cost cap, stream retry, retry exhausted,
  persist nudge, compaction exhaustion -> `Fail`, pending tools -> `RunTools`, DP7 approve,
  DP7 reject -> `InjectUserMessage`, DP7 missing-infrastructure/fail-open -> `Finalize`, model
  stop -> `Finalize`, and v1 policy never returning `TakeCheckpoint`.

**Verification.**
```
ailang check src/core/step_machine.ail
ailang test src/core/step_machine.ail
ailang test src/core/cost_phase.ail
ailang test src/core/recovery.ail
ailang test src/core/phase_vocab.ail
(cd .agent/projects/004_phase_core_refactor/sketch && ailang check probe_consumer_decide.ail)
(cd .agent/projects/004_phase_core_refactor/sketch && ailang run --caps IO --entry main probe_consumer_decide.ail)
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
```

**Rollback.** Revert the new modules and any `phase_vocab` state-field additions. If any existing
tests were updated for new fields, revert them in the same commit. No production code should be
using these modules yet, so parity must return to byte-identical.

### WI-C3 - Scripted Ports And In-Memory Ledger

**Purpose.** Add the new DST seam and typed in-memory trace while keeping live behavior routed
through the current loop.

**File-level changes.**
- Add `src/core/ports.ail`: define the live port record for model calls, stream append, tool
  execution, extension hooks, approval input, clock, and environment/config reads. Follow the
  parser constraints from the ports smoke: no zero-arg anonymous `func()` expressions and no direct
  anonymous `func` in record literals (`scripts/smoke_ports_record.ail:17`,
  `scripts/smoke_ports_record.ail:21`).
- Add `src/core/test/scripted_ports.ail`: generalize `StepProvider` into scripted model,
  approval, clock, env, tool, and hook fakes. Keep external scripted state threading, matching
  `StepProvider` (`scripts/smoke_ports_record.ail:52`, `scripts/smoke_ports_record.ail:60`).
- `src/core/phase_vocab.ail`: add `LedgerRecord`/`LedgerTrace` types and append/normalize helpers.
  `LedgerEvent` remains the projectable wire event set (`src/core/phase_vocab.ail:413`,
  `src/core/phase_vocab.ail:445`). Add in-memory compaction stage records, including pass-through,
  without adding a `to_schema_v1` arm.
- `src/core/agent_loop_v2.ail`: add a compatibility function that builds live ports from the
  current effect calls but still delegates to the old `loop_v2` path. Do not route production
  through `session.ail` yet.
- `src/core/test/stub_step.ail`: keep exported helpers for existing smokes, but add conversion to
  scripted ports. The `ScriptedStep` and chunk behavior remain source-compatible
  (`src/core/test/stub_step.ail:33`, `src/core/test/stub_step.ail:44`).

**Verification.**
```
ailang check src/core/ports.ail
ailang test src/core/test/scripted_ports.ail
ailang test src/core/phase_vocab.ail
ailang run --caps IO --entry main scripts/smoke_ports_record.ail
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed
```

**Rollback.** Revert new ports/trace files and compatibility glue. Existing smokes must still use
`run_v2_with_stub` directly and strict Phase B parity must pass.

### WI-C4 - Approval Protocol Inversion

**Purpose.** Move pending approval from recursive `dispatch_calls` into `AwaitApproval` before the
full tool phase is batched.

**File-level changes.**
- `src/core/phase_vocab.ail`: add any state delta fields needed to suspend and resume a tool plan.
  The existing `ApprovalRequest` already carries `default_allow`, `stream_id`, and `remaining`
  (`src/core/phase_vocab.ail:315`, `src/core/phase_vocab.ail:320`).
- `src/core/step_machine.ail`: return `AwaitApproval(req)` when state has a suspended approval
  request, and return `RunTools` with the remaining tail after the driver records the resolution.
- Add `src/core/tool_phase.ail` with the first narrow surface: policy planning for one pending
  call, `ToolPending` event construction, denial message construction, and tail preservation. Do
  not move all native execution yet.
- Extend `scripts/phase_c_approval_protocol.ail`: a scripted scenario with at least four cases:
  approve, deny with reason, EOF/default allow, unparseable/default deny. Each case asserts:
  `tool_pending` appears before the approval-read record; the request carries the call id and
  stream id; denial produces a tool-role denial message; approval executes the approved call
  before reissuing the suspended `remaining` entries in original order.
- Optionally add a focused TUI parser test for `tool_pending` if the implementation chooses to
  type it in `AgentEvent`; otherwise keep the TUI side to generic `send`/stdin protocol because
  `RuntimeProcess.send` already writes arbitrary command JSON (`src/tui/src/runtime-process.ts:689`,
  `src/tui/src/runtime-process.ts:692`).

**Verification.**
```
ailang test src/core/step_machine.ail
ailang check src/core/tool_phase.ail
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
ailang test src/core/phase_vocab.ail
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
```

**Rollback.** Revert `tool_phase`, approval scenario, and new state fields. Existing
`smoke_v2_pending_full_loop.ail` should again be the only full-loop pending coverage and must pass
through parity (`scripts/smoke_v2_pending_full_loop.ail:1`,
`scripts/smoke_v2_pending_full_loop.ail:20`).

### WI-C5 - Full Driver And Phase Split

**Purpose.** Route the v2 loop through the Phase C architecture while preserving the wire stream.

**File-level changes.**
- Add `src/core/session.ail`: the only live driver. It owns the real effect row, initializes
  `StepPolicy` from config/env exactly once, initializes clock/session fields in `StepState`, runs
  `decide`, executes decisions, applies state deltas, appends in-memory ledger records, and emits
  projectable wire events.
- Add `src/core/model_phase.ail`: consumes `ModelRequest` carrying sealed `ProviderPayload`
  (`src/core/phase_vocab.ail:90`) and returns `PhaseResult`. It receives a driver-built append
  handle for stream deltas only, preserving the ADR streaming exception
  (`ADR-001-phase-oriented-core.md:150`, `ADR-001-phase-oriented-core.md:157`).
- Add `src/core/tool_stream_phase.ail`: the contained streaming callback/island; keep the
  `append_stream_delta` mapping for `ContentDelta` and `ThinkingDelta`
  (`src/core/agent_loop_v2.ail:338`, `src/core/agent_loop_v2.ail:356`).
- Expand `src/core/tool_phase.ail`: migrate scratchpad dispatch to an executor registry, native
  dispatch, delegated deferral, extension-handled results, and batch `native_tool_calls` /
  `native_tool_results`. The scratchpad special case currently sits in dispatch recursion
  (`src/core/agent_loop_v2.ail:864`, `src/core/agent_loop_v2.ail:883`).
- Add `src/core/hook_phase.ail`: migrate pre-step compaction chain, response intercept, solver
  candidate, and DP7 verifier port execution/result normalization. The hook phase may execute the
  verifier effect, but it must not own the gating policy; `step_machine` decides what a normalized
  verifier result means. Keep `dispatch_pre_step_chain` in `ext/runtime.ail`; it already returns
  data (`src/core/ext/runtime.ail:149`, `src/core/ext/runtime.ail:186`).
- `src/core/agent_loop_v2.ail`: turn `run_v2`, `run_v2_from_messages`,
  `run_v2_with_conversation`, and `run_v2_with_stub` into facades over `session.ail`.
- `src/core/rpc.ail`: keep the public entry path stable; it currently calls
  `run_v2_with_conversation` (`src/core/rpc.ail:228`, `src/core/rpc.ail:239`).

**Verification.**
```
make check_core
make test_core
make test_integration
ailang test src/core/step_machine.ail
ailang test src/core/phase_vocab.ail
ailang test src/core/ext/runtime.ail
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed
```

**Expected-diff protocol.** This is the WI most likely to alter event ordering. If strict parity
diffs, stop and classify every changed line as event-order-only, missing/extra, or payload change.
Payload changes require a bug fix or a new expected-diff table with rationale. Re-bless only after
the table is committed, per D-B7 (`PLAN-phase-b-phase-results.md:392`,
`PLAN-phase-b-phase-results.md:405`).

**Rollback.** Revert the new phase modules and facade changes as one unit. Restore the prior
`agent_loop_v2.ail` monolith and run strict parity against the latest `/tmp/phase_c_blessed`.

### WI-C6 - Scripted-Port Fleet Migration

**Purpose.** Make scripted ports the scenario and parity entrypoint; leave `run_v2_with_stub` only
as compatibility glue.

**File-level changes.**
- Rewrite parity smokes that import `run_v2_with_stub` to import the scripted-port runner instead:
  `smoke_phase_a_tool_parity`, `smoke_v2_cost_budget_full_loop`, `smoke_v2_compaction_full_loop`,
  `smoke_v2_pending_full_loop`, `smoke_v2_dp7_gate`, `smoke_v2_ext_fixture_parity`,
  `smoke_v2_compaction_chain`, and `smoke_v2_stream_parity`. The current `rg` surface is rooted at
  `scripts/smoke_v2_compaction_chain.ail:9` and `scripts/smoke_v2_pending_full_loop.ail:46`.
- `src/core/test/integration_tests.ail`: move off assumptions that name `run_v2_with_stub`;
  preserve the existing pending/cost/compaction assertions
  (`src/core/test/integration_tests.ail:15`, `src/core/test/integration_tests.ail:56`).
- `src/core/agent_loop_v2.ail`: keep `run_v2_with_stub` as a deprecated adapter over the scripted
  ports until external callers are audited. Final grep may show the definition only.
- `scripts/phase_a_event_parity.sh`: no new event names. If ordering changes are intentional,
  document them in this plan's expected-diff table before re-blessing
  (`scripts/phase_a_event_parity.sh:171`, `scripts/phase_a_event_parity.sh:185`).

**Verification.**
```
rg -n "run_v2_with_stub" scripts src/core/test src/core/agent_loop_v2.ail
make check_core
make test_integration
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed
```

**Rollback.** Revert the smoke/import rewrites. Restore the previous blessed baseline path used by
the last green WI and rerun strict parity.

### WI-C7 - L1 Scenario Family

**Purpose.** Complete the ADR-named Phase C L1 scenarios under minimal caps, using the in-memory
trace rather than scraping JSONL.

**File-level changes.**
- `scripts/phase_c_l1_scenarios.ail`: add all required scenario ids:
  `provider_payload_vs_uncompacted_history_pressure`, `ext_compaction_invalid_rejected`,
  `summary_cache_replay_stable`, `history_rewrite_requires_checkpoint_event`,
  `checkpoint_never_emitted_in_v1`, `checkpoint_output_is_valid_transcript`,
  `compactor_chain_order_is_registry_order`, `invalid_stage_skipped_chain_continues`,
  and `zero_compactors_exhaustion_behavior` (`ADR-001-phase-oriented-core.md:447`,
  `ADR-001-phase-oriented-core.md:451`).
- Reuse the Phase B chain fixture rather than duplicating it. The existing smoke already proves
  A -> rejected B -> C order (`scripts/smoke_v2_compaction_chain.ail:138`,
  `scripts/smoke_v2_compaction_chain.ail:163`); factor shared fixture helpers into
  `src/core/test/compaction_chain_fixture.ail` if needed.
- Add summary-cache replay as a scripted hook-port scenario over `StepState.ext_artifacts`, not as
  ABI v3 artifact work. `StepState` already has `ext_artifacts` (`src/core/phase_vocab.ail:252`).
- Add zero-compactor exhaustion with an empty hook registry and overfull history. Core keeps the
  exhaustion decision (`src/core/compaction.ail:30`), and D9 says zero compactors should honestly
  exhaust (`RESEARCH-phase-core-dst-design.md:726`, `RESEARCH-phase-core-dst-design.md:733`).
- Ensure every failure report prints scenario id, first failed invariant, and normalized trace, as
  required by the ADR gate (`ADR-001-phase-oriented-core.md:458`,
  `ADR-001-phase-oriented-core.md:459`).

**Verification.**
```
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
make check_core
make test_core
make test_integration
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
```

**Rollback.** Revert the scenario additions and any fixture extraction. If production files were
changed to satisfy a scenario, revert those in the same rollback and prove the previous WI's gate
is green.

### WI-C8 - Final Gate Checklist

All positive commands must pass on the finished branch. `phase_c_blessed` means the current strict
blessed baseline after any committed D-B7 expected-diff table and re-bless. The sealing probe is
the one intentional negative check; capture its rc next to the `ailang check` invocation and then
inspect the saved output, matching the measurement discipline in the exit-code false-alarm note
(`.agent/projects/004_phase_core_refactor/NOTE-ailang-run-exit-code-false-alarm.md:84`,
`.agent/projects/004_phase_core_refactor/NOTE-ailang-run-exit-code-false-alarm.md:92`).

```
set -euo pipefail
ailang --version                                      # v0.26.0 / 3b52a24, else STOP
make check_core
make test_core
make test_integration
ailang test src/core/phase_vocab.ail
ailang test src/core/step_machine.ail
ailang test src/core/cost_phase.ail
ailang test src/core/recovery.ail
ailang test src/core/ext/runtime.ail
ailang run --caps IO --entry main scripts/probe_phase_c_hash.ail
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
tmp=$(mktemp)
if ailang check scripts/probe_phase_vocab_sealed.ail >"$tmp" 2>&1; then
  cat "$tmp"
  rm -f "$tmp"
  echo "expected sealed probe to fail with IMP010" >&2
  exit 1
fi
rg "IMP010: symbol 'MkHistory' not exported" "$tmp"
rm -f "$tmp"
(cd .agent/projects/004_phase_core_refactor/sketch && ailang test sketch_vocabulary.ail)
(cd .agent/projects/004_phase_core_refactor/sketch && ailang check probe_consumer_decide.ail)
(cd .agent/projects/004_phase_core_refactor/sketch && ailang run --caps IO --entry main probe_consumer_decide.ail)
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed
```

Supplemental checks:
- `rg -n "run_v2_with_stub" scripts src/core/test src/core/agent_loop_v2.ail` shows only the
  compatibility adapter definition and any explicitly retained comments.
- `rg -n "getEnvOr|now\\(|readLine\\(" src/core/session.ail src/core/*_phase.ail src/core/step_machine.ail`
  shows env/clock/input only in driver or live port construction, not in pure `step_machine.ail`.
- `! rg -n "TakeCheckpoint|history_checkpoint" /tmp/phase_c_blessed` succeeds for v1 parity
  captures. The scenario `checkpoint_never_emitted_in_v1` is the authoritative check.

## ADR Gaps Found

No blocking ADR gap was found. The ADR, Phase B findings, and Phase B as-built commits were enough
to produce the Phase C plan.

Non-blocking notes for implementers:
- Research §7.4 still uses the word `Checkpoint(CheckpointPlan)` in one explanatory paragraph
  (`RESEARCH-phase-core-dst-design.md:656`, `RESEARCH-phase-core-dst-design.md:675`), while the
  ADR and production vocabulary use `TakeCheckpoint` (`ADR-001-phase-oriented-core.md:100`,
  `src/core/phase_vocab.ail:331`). Treat the ADR/source spelling as normative.
- The handoff's hash residual was under-informed by current AILANG stdlib: `std/crypto.sha256Hex`
  exists and is pure (`ailang/std/crypto.ail:1`, `ailang/std/crypto.ail:21`). This is not an ADR
  gap; WI-C0 still requires an in-repo probe before relying on it.

## Toolchain And Artifacts Verified This Session

| Check | Command | Result |
|---|---|---|
| Toolchain pin | `ailang --version` | v0.26.0 / `3b52a24`, matches pin |
| HEAD / Phase B range | `git log --oneline -20`; `git log --oneline --reverse fd933b6^..a9616ad` | review HEAD `34f901a`; Phase B WI-0..WI-8 sequence present |
| Phase B parity | `PARITY_BASELINE=/tmp/phase_b_blessed make smoke_parity` | pass |
| Phase B projection gate | `./scripts/phase_b_projection_gate.sh /tmp/phase_b_blessed` | pass |
| Core vocabulary | `ailang test src/core/phase_vocab.ail` | 17 pass / 0 fail |
| Sketch vocabulary | `ailang test .agent/projects/004_phase_core_refactor/sketch/sketch_vocabulary.ail` | 1 pass / 0 fail |
| Separate-module wrapper probe | `(cd .agent/projects/004_phase_core_refactor/sketch && ailang check probe_consumer_decide.ail && ailang run --caps IO --entry main probe_consumer_decide.ail)` | pass; prints `decide=CallModelP payload=20 hist=3` |
| Production sealing negative probe | `ailang check scripts/probe_phase_vocab_sealed.ail` | rc=1, `IMP010: symbol 'MkHistory' not exported` |
| Ports substrate | `ailang run --caps IO --entry main scripts/smoke_ports_record.ail` | pass; fake ports run under IO only |
| Hash stdlib example | `(cd ailang && ailang run --caps IO --entry main examples/runnable/crypto_hashing.ail)` | pass; SHA-256 example prints expected hello digest |
| Core make targets | `make check_core`; `make test_core`; `make test_integration` | all pass |

## Anchor Re-Verification Log

Source anchors read against review HEAD `34f901a` on 2026-07-03:

- ADR Phase C deliverables and gate: `ADR-001-phase-oriented-core.md:443`,
  `ADR-001-phase-oriented-core.md:459`.
- ADR D1/D2/D5: decisions as data, ports, ledger/streaming: `ADR-001-phase-oriented-core.md:94`,
  `ADR-001-phase-oriented-core.md:157`.
- ADR D7/D4/D5 module split and approval contract: `ADR-001-phase-oriented-core.md:163`,
  `ADR-001-phase-oriented-core.md:258`.
- ADR dispositions G1-G8 and G-B1-G-B7: `ADR-001-phase-oriented-core.md:1044`,
  `ADR-001-phase-oriented-core.md:1284`.
- Research P1/P2/P3, module mapping, ports substrate, residual homes, scenarios, checkpoint seam,
  D9 chain facts, and facts 13/17: `RESEARCH-phase-core-dst-design.md:86`,
  `RESEARCH-phase-core-dst-design.md:866`.
- Phase B plan D-B1/D-B7 and final gate: `PLAN-phase-b-phase-results.md:310`,
  `PLAN-phase-b-phase-results.md:405`, `PLAN-phase-b-phase-results.md:834`.
- Phase B findings and summary: `NOTE-phase-b-implementation-findings.md:5`,
  `NOTE-phase-b-implementation-findings.md:42`,
  `.agent/summaries/2026-07-03-phase-b-phase-results-implementation.md:43`,
  `.agent/summaries/2026-07-03-phase-b-phase-results-implementation.md:72`.
- Current source: `src/core/phase_vocab.ail` sealed/history/digest/state/decision/ledger/tests at
  `:23`, `:41`, `:246`, `:326`, `:413`, `:861`; `src/core/agent_loop_v2.ail` driver/approval/
  compaction/model/finalization/stub at `:255`, `:732`, `:1088`, `:1181`, `:1456`, `:1684`;
  `src/core/ext/runtime.ail` chain data at `:29`, `:151`, `:186`; `src/core/test/stub_step.ail`
  StepProvider at `:33`, `:145`; `scripts/phase_a_event_parity.sh` smoke list at `:171`,
  `:185`; `scripts/phase_b_projection_gate.sh` admission set at `:20`, `:22`.
