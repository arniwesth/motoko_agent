# Phase C partial implementation and handoff summary

Date: 2026-07-04
Repo: `/workspaces/motoko_agent`
Branch: `arniwesth/mot-27-phased-core-architecture`

## Session outcome

This session implemented Phase C through WI-C4 and added WI-C5 scaffolding, but did
not complete the full Phase C inversion. The final Phase C WI-C8 gate was not run.

The session ended by writing a continuation handoff:

- `.agent/projects/004_phase_core_refactor/HANDOFF-continue-phase-c.md`

That file is the best starting point for the next implementer. The normative spec
remains `.agent/projects/004_phase_core_refactor/PLAN-phase-c-full-inversion.md`.

## Commits produced before handoff

- `011cb66 WI-C0 Add Phase C instruments`
- `f1ef84c WI-C1 Use real checkpoint digests`
- `99458c4 WI-C2 Add pure step policy modules`
- `cc62e92 WI-C3 Add scripted ports and ledger trace`
- `3209ddf WI-C4 Add approval protocol inversion`
- `b7f2ff8 WI-C5 Add phase module surfaces`

Important: `b7f2ff8` is only WI-C5 scaffolding. It is not a completed WI-C5.

## Baselines and verification state

Active Phase C baseline:

- `/tmp/phase_c_blessed`

WI-C1 intentionally changed production bytes for
`provider_call_prepared.payload_digest` only, recorded the D-B7 expected diff in:

- `.agent/projects/004_phase_core_refactor/EVIDENCE-phase-c-wi-c1-expected-diff.md`

After `b7f2ff8`, these checks were reported green:

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

Before continuing, re-run the inherited gate checks and confirm
`ailang --version` still reports v0.26.0 / `3b52a24`.

## Implemented work

WI-C0 added Phase C instruments:

- `scripts/probe_phase_c_hash.ail`
- `scripts/phase_c_l1_scenarios.ail`
- `scripts/phase_c_approval_protocol.ail`
- Makefile target `phase_c_l1`

WI-C1 made checkpoint and payload digests real in `src/core/phase_vocab.ail`,
including canonical SHA-256 digesting and checkpoint-chain validation helpers.
It blessed `/tmp/phase_c_blessed`.

WI-C2 added pure modules:

- `src/core/step_machine.ail`
- `src/core/cost_phase.ail`
- `src/core/recovery.ail`

WI-C3 added ports and trace substrate:

- `src/core/ports.ail`
- `src/core/test/scripted_ports.ail`
- in-memory ledger records in `src/core/phase_vocab.ail`
- compatibility adapter `run_v2_with_stub_port_adapter(...)` in
  `src/core/agent_loop_v2.ail`

WI-C4 added approval inversion:

- `src/core/tool_phase.ail`
- `AwaitApproval` decision path in `src/core/step_machine.ail`
- active approval protocol assertions in `scripts/phase_c_approval_protocol.ail`

WI-C5 scaffolding added:

- `src/core/session.ail`
- `src/core/model_phase.ail`
- `src/core/tool_stream_phase.ail`
- `src/core/hook_phase.ail`

## Remaining work

Continue with WI-C5. Production entrypoints are not yet routed through
`session.ail`; the live loop still runs through `src/core/agent_loop_v2.ail`.

Because an incomplete WI-C5 scaffold commit already exists, prefer a follow-up
commit like:

```text
WI-C5 Complete session route-through
```

Then continue WI-C6, WI-C7, and WI-C8 in order.

Do not claim Phase C complete until the WI-C8 final gate passes as a block:

- minimal-caps L1 scenarios
- scripted approval protocol
- pure-module tests
- sketch probes
- sealing negative probe
- strict parity against the final Phase C blessed baseline
- Phase B projection gate

## Current worktree dirt at summary time

Observed status:

```text
 M ailang.lock
?? .agent/projects/004_phase_core_refactor/HANDOFF-continue-phase-c.md
?? oh-my-pi/
```

`oh-my-pi/` was unrelated untracked work and should not be touched. The
continuation handoff was intentionally created by this session. The `ailang.lock`
change was present before this summary was written and should be inspected before
any commit that includes it.

## Hazards for the next session

- Use `/tmp/phase_c_blessed`, not `/tmp/phase_b_blessed`, after WI-C1.
- Keep `run_v2_with_stub` alive as a compatibility adapter until WI-C6.
- Classify any parity diff under D-B7 before code changes or baseline changes.
- The sealing probe is a negative test: failure with `IMP010` is the pass
  condition.
- DP7 policy belongs in `step_machine`; the verifier command is only a port
  effect.
- Approval ordering is pinned: event before read, default handling for EOF and
  unparseable input, denial message behavior, and approved call execution before
  the suspended tail.
- Capture negative probe rc adjacent to the command; do not inspect `$?` after a
  pipe.
- Do not start ABI v3, conformance kit work, `compaction_ai` v0.3.0, or registry
  publication of `motoko_ext_compaction_structural`.

