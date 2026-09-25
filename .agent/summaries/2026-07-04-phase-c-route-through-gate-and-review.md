# 2026-07-04 Phase C route-through, gate, and review findings

Branch: `arniwesth/mot-27-phased-core-architecture`
Toolchain used: AILANG `v0.26.0`, commit `3b52a24`
Active parity baseline: `/tmp/phase_c_blessed`

## What this session did

Continued Phase C from the scaffold state at `b7f2ff8`.

Committed:

- `898ada6 WI-C5 Complete session route-through`
  - Moved the existing live v2 loop implementation into `src/core/session.ail`.
  - Reduced `src/core/agent_loop_v2.ail` to a compatibility facade preserving the historical public signatures.
  - Kept the session scaffold helpers (`session_from_messages`, `apply_phase_result`, `next_decision`).
  - Strict parity against `/tmp/phase_c_blessed` remained byte-identical.

- `c816620 WI-C6 Migrate parity fleet to scripted ports`
  - Added `run_v2_with_scripted_ports(...)` in `src/core/test/scripted_ports.ail`.
  - Rewired parity smokes to import `src/core/test/scripted_ports` instead of `run_v2_with_stub`.
  - Left `run_v2_with_stub` only as compatibility definitions in `src/core/agent_loop_v2.ail`.
  - Strict parity remained byte-identical.

- `a73c6a8 WI-C7 Complete Phase C L1 scenarios`
  - Completed `scripts/phase_c_l1_scenarios.ail` with all ADR-named scenario ids plus the harness self-test.
  - The L1 scenario family runs under `--caps IO` with no real model/network.

The WI-C8 final gate was run successfully as a block:

- `make check_core`
- `make test_core`
- `make test_integration`
- `ailang test src/core/phase_vocab.ail`
- `ailang test src/core/step_machine.ail`
- `ailang test src/core/cost_phase.ail`
- `ailang test src/core/recovery.ail`
- `ailang test src/core/ext/runtime.ail`
- `ailang run --caps IO --entry main scripts/probe_phase_c_hash.ail`
- `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail`
- `ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail`
- sealing negative probe: `scripts/probe_phase_vocab_sealed.ail` failed with `IMP010: symbol 'MkHistory' not exported`
- sketch vocabulary test and `probe_consumer_decide` check/run
- `PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity`
- `./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed`

Supplemental checks passed:

- `rg -n "run_v2_with_stub" scripts src/core/test src/core/agent_loop_v2.ail` shows only the compatibility definitions in `agent_loop_v2.ail`.
- Effect reads are confined to `session.ail` among the checked phase/step modules.
- `/tmp/phase_c_blessed` contains no `TakeCheckpoint` or `history_checkpoint`.

## Review note read afterward

The user asked to read `.agent/projects/004_phase_core_refactor/NOTE-phase-c-implementation-findings.md`.

Important finding: the review says the Phase C gate passes, but the architectural inversion is not actually live yet.

As built:

- `decide` exists and is tested, but the live step cycle does not call it.
- `tool_phase`, `model_phase`, `hook_phase`, and `ports` are still mostly scaffold/test surfaces.
- `AwaitApproval` is not live in production; the old `readLine()` remains inside dispatch in `session.ail`.
- `run_v2_with_scripted_ports` still delegates through the old `Scripted` `StepProvider` path, so WI-C6 is closer to an import migration than a true port-driven runner.
- Mid-loop env/config reads remain inside the relocated monolith.

The review's conclusion is that the current branch is a verified Phase C substrate, not a completed full inversion. The remaining work should be a follow-up WI series with positive architecture guards that fail today, then route the live step cycle through `decide`/phase modules and real scripted ports while preserving strict parity.

Suggested next sequence:

- `WI-C9 Add live inversion guards`
- `WI-C10 Route model step through decide/model_phase`
- `WI-C11 Route tools and approval through tool_phase`
- `WI-C12 Route hooks/DP7 through hook_phase`
- `WI-C13 Replace StepProvider fleet with real scripted Ports`
- `WI-C14 Final Phase C gate with wiring guards`

## Worktree at end

At the time this summary was written, `git status --short --branch` showed the branch at:

`arniwesth/mot-27-phased-core-architecture...origin/arniwesth/mot-27-phased-core-architecture`

with only:

- `?? oh-my-pi/`

`oh-my-pi/` is unrelated and was intentionally left untouched.
