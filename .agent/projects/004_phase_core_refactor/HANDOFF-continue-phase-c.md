# Handoff: continue Phase C implementation

> **CLOSED (2026-07-05).** This handoff is historical. Phase C2 completed the live
> inversion and WI-C14 passed as a block. Current status is in
> `NOTE-phase-c-implementation-findings.md` ("Phase C2 resolution addendum") and
> `PLAN-phase-c2-live-inversion.md`.

Audience: a fresh implementer session continuing `PLAN-phase-c-full-inversion.md`.
This handoff is intentionally narrow. The plan remains the spec.

## Current state

- Branch: `arniwesth/mot-27-phased-core-architecture`.
- Active Phase C baseline: `/tmp/phase_c_blessed`.
- Completed and committed:
  - `011cb66 WI-C0 Add Phase C instruments`
  - `f1ef84c WI-C1 Use real checkpoint digests`
  - `99458c4 WI-C2 Add pure step policy modules`
  - `cc62e92 WI-C3 Add scripted ports and ledger trace`
  - `3209ddf WI-C4 Add approval protocol inversion`
- Current HEAD:
  - `b7f2ff8 WI-C5 Add phase module surfaces`
- Important: `b7f2ff8` is only WI-C5 scaffolding. It is not full WI-C5 completion.
- At handoff, worktree dirt observed:
  - `M ailang.lock`
  - `?? oh-my-pi/`
  Do not touch `oh-my-pi/`; it was unrelated before Phase C implementation started.

## What is actually done

WI-C0 through WI-C4 were implemented and verified against the plan.

WI-C1 intentionally changed production bytes only for
`provider_call_prepared.payload_digest`, captured the D-B7 expected-diff evidence in
`.agent/projects/004_phase_core_refactor/EVIDENCE-phase-c-wi-c1-expected-diff.md`,
and blessed `/tmp/phase_c_blessed`.

WI-C2 added pure policy modules:

- `src/core/step_machine.ail`
- `src/core/cost_phase.ail`
- `src/core/recovery.ail`

WI-C3 added ports and trace substrate:

- `src/core/ports.ail`
- `src/core/test/scripted_ports.ail`
- in-memory ledger records in `src/core/phase_vocab.ail`
- compatibility adapter `run_v2_with_stub_port_adapter(...)` in `src/core/agent_loop_v2.ail`

WI-C4 added the approval protocol inversion surface:

- `src/core/tool_phase.ail`
- `AwaitApproval` decision path in `src/core/step_machine.ail`
- active scripted approval protocol checks in `scripts/phase_c_approval_protocol.ail`

WI-C5 scaffolding added:

- `src/core/session.ail`
- `src/core/model_phase.ail`
- `src/core/tool_stream_phase.ail`
- `src/core/hook_phase.ail`

However, production driver entrypoints are still not routed through `session.ail`.
The live loop still runs through `src/core/agent_loop_v2.ail`.

## Why Phase C stopped here

The remaining work is the hardest semantic inversion, not mechanical file movement.
WI-C5 requires routing `run_v2`, `run_v2_from_messages`, `run_v2_with_conversation`,
and `run_v2_with_stub` through the new session/module split while preserving strict
JSONL parity, approval ordering, stream ordering, checkpoint behavior, and all
Phase B projection guarantees.

Doing that late in a long session risked producing an unreviewable route-through
diff. The current state is shippable through the last verified boundary, but not a
complete Phase C implementation.

## Recommended next step

Continue with WI-C5. Because `b7f2ff8` already exists as an incomplete WI-C5 scaffold,
prefer a follow-up commit such as:

`WI-C5 Complete session route-through`

Do not rewrite history unless explicitly requested.

The completion criteria for WI-C5 are still the plan criteria, especially:

- `run_v2`, `run_v2_from_messages`, `run_v2_with_conversation`, and
  `run_v2_with_stub` become facades over `session.ail`.
- `run_v2_with_stub` remains alive as a compatibility adapter until WI-C6.
- Any parity diff is classified under D-B7 before code changes or baseline changes.
- If event ordering differs, classify it precisely; do not bless a new baseline by
  inspection.

## Verification already green after `b7f2ff8`

These were green after the scaffold commit:

```bash
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

Before continuing, re-run at least:

```bash
ailang --version
git status --short
PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed
ailang test src/core/phase_vocab.ail
(cd .agent/projects/004_phase_core_refactor/sketch && ailang check probe_consumer_decide.ail)
```

`ailang --version` must still report v0.26.0 / `3b52a24`.

## Remaining work

Continue the plan in order:

1. Finish WI-C5 route-through and run its verification block.
2. WI-C6 migrate the parity fleet to scripted ports, leaving `run_v2_with_stub` only
   as compatibility.
3. WI-C7 complete the L1 scenario family under `--caps IO` or less, with no real
   model/network.
4. WI-C8 run the final gate exactly as written.

Done means the WI-C8 final gate passes as a block:

- minimal-caps L1 scenarios
- scripted approval protocol
- pure-module tests
- sketch probes
- sealing negative probe
- strict parity against the final Phase C blessed baseline
- Phase B projection gate

## Hazards to preserve

- Use `/tmp/phase_c_blessed`, not `/tmp/phase_b_blessed`, after WI-C1.
- The sealing probe is negative: failure with `IMP010` is the pass condition.
- DP7 policy belongs in `step_machine`; the verifier command is only a port effect.
- Approval order is pinned:
  - emit event before approval read
  - EOF/unparseable defaults must match the plan
  - denial message behavior must match the plan
  - approval executes the approved call before the suspended `remaining` tail is
    reissued in original order
- Capture command rc adjacent to negative probes; do not inspect `$?` after a pipe.
- Do not start ABI v3, conformance kit work, `compaction_ai` v0.3.0, or registry
  publication for `motoko_ext_compaction_structural`.
