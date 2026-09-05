# Phase-C implementation findings

Date: 2026-07-04
Toolchain: AILANG v0.26.0 (commit `3b52a24`), verified this session
Provenance: a fresh verification session, prompted by "Phase C was implemented — is there
more to do?". Every claim below carries a `file:line` read at HEAD `8604365` this session.
This note supersedes the status claims in `HANDOFF-continue-phase-c.md` and
`.agent/summaries/2026-07-04-phase-c-partial-implementation-handoff.md`, both of which
were written at the WI-C5-scaffold point (`b7f2ff8`) and committed after
`898ada6`/`c816620`/`a73c6a8` landed — they describe neither the pre- nor post-completion
state accurately.

## WI-C8 gate: run 2026-07-04, passes as a block

No WI-C8 commit existed and the gate had never been run. This session ran the full block
from `PLAN-phase-c-full-inversion.md:549-585` (rc captured pipe-free throughout):

- `make check_core` / `make test_core` / `make test_integration` — pass
- `ailang test` on `phase_vocab`, `step_machine`, `cost_phase`, `recovery`, `ext/runtime` — pass
- `probe_phase_c_hash`, `phase_c_l1_scenarios` (all 9 ADR-named scenarios + self-test),
  `phase_c_approval_protocol` (4 checks) — pass under `--caps IO`
- Sealing probe fails `IMP010: symbol 'MkHistory' not exported` (the pass condition)
- Sketch vocabulary test + `probe_consumer_decide` check/run — pass
- `PARITY_BASELINE=/tmp/phase_c_blessed make smoke_parity` — strict byte parity, rc=0
- `./scripts/phase_b_projection_gate.sh /tmp/phase_c_blessed` — OK
- All three supplemental checks pass (`run_v2_with_stub` definition-only at
  `agent_loop_v2.ail:89,:107`; effect reads confined to `session.ail`; no
  `TakeCheckpoint`/`history_checkpoint` in blessed captures)

One environment substitution: the plan's `rg` invocations ran as `grep` (`rg` is not
installed here); patterns matched fixed strings, no semantic difference.

## The load-bearing finding: the inversion is not on the live path

The WI-C5/WI-C6 commit subjects ("Complete session route-through", "Migrate parity fleet
to scripted ports") overstate the as-built. What actually shipped:

- **`decide` has no production caller.** `session.ail` imports it (`session.ail:129`) but
  uses it only inside `next_decision` (`session.ail:1866`), one of three appended helpers
  (`session_from_messages` `:1838`, `apply_phase_result` `:1858`) that nothing in
  production calls. The live loop is the old recursive `loop_v2`, relocated verbatim from
  `agent_loop_v2.ail` into `session.ail:1103`; `agent_loop_v2.ail` is now a 123-line
  facade.
- **No production module imports the phase modules.** `tool_phase`, `model_phase`,
  `hook_phase`, and `ports` are imported only by `src/core/test/scripted_ports.ail`,
  `scripts/phase_c_l1_scenarios.ail`, and `scripts/phase_c_approval_protocol.ail`
  (grep over `src/ scripts/`, this session).
- **The `AwaitApproval` inversion is not live.** The mid-dispatch approval `readLine()`
  still blocks inside `dispatch_calls` (`session.ail:785`) — the exact seam ADR Decision
  detail 5 says Phase C inverts. The approval contract is verified only against the
  scripted `tool_phase` surface.
- **WI-C6 is a rename, not a migration.** `run_v2_with_scripted_ports`
  (`scripted_ports.ail:82`) delegates to
  `Session.run_v2_from_messages(..., Scripted(state.model_steps))` — the identical old
  `StepProvider` path; `run_v2_with_stub_port_adapter` (`agent_loop_v2.ail:107`) is the
  same call. The `Ports` record's model port (`fake_model`) is a shape probe that returns
  `Err` if ever invoked; no driver consumes approval or clock ports.
- **Mid-loop nondeterminism reads remain**, against ADR Phase C deliverable 3
  ("config/env reads once at init into `StepPolicy`"): `MOTOKO_PERSIST_RETRIES`
  (`session.ail:1065`), `OPENAI_BASE_URL` (`:1203`), `MOTOKO_RETRY_STREAM_ERROR`
  (`:1217`); persist-nudge still counts transcript markers (`:1073`).

## Why the gate passed anyway (instrument lesson)

The gate is non-discriminating against code motion: strict byte parity is trivially
preserved by relocating the loop; supplemental check 2 permits all effect reads "in the
driver", which the relocated monolith now nominally is; and the L1/approval scripts drive
the pure surface directly rather than observing the live path. Generalized: **parity
instruments prove non-regression, not architecture.** An inversion WI needs a positive
wiring check — e.g. an assertion that the live driver's step cycle calls `decide` (a
grep-level check on `loop_v2`'s body, or an in-memory-trace record emitted only by the
decision-execution path and asserted by a full-loop scenario).

## What genuinely landed

Real value shipped and verified: SHA-256 checkpoint/payload digests with the D-B7
expected-diff evidence (WI-C1, `EVIDENCE-phase-c-wi-c1-expected-diff.md`); pure
`step_machine`/`cost_phase`/`recovery` modules with tests; in-memory ledger records in
`phase_vocab`; the complete L1 scenario family under `--caps IO`; the scripted approval
protocol checks; sealed-type architecture intact; strict wire parity throughout.

## Disposition against the ADR's Phase C deliverables

1. Pure `decide` with loop policy — **built and tested; not live**.
2. Driver executes decisions (D5 module split, §5 residual homes) — **not met**: modules
   exist as surfaces; the driver still runs the Phase-B recursion; scratchpad dispatch
   and hybrid-bash remain in the relocated monolith.
3. Scripted ports supersede `run_v2_with_stub` — **in name only**; the runner is the old
   `StepProvider` path; env reads not hoisted.
4. Approval protocol inversion gated by scripted TUI scenario — **contract verified on
   the scripted surface only**; production ordering unchanged (which is why parity holds).
5. L1 scenario family — **met** (all 9 scenarios, minimal caps, no network).
6. Checkpoint mechanics real — **met** (content hash, chain validation, digest evidence).

ADR acceptance criterion 4 is satisfied as worded (`decide` is pure; the L1 family runs
under `--caps IO`); the deliverable text above it is not. Remaining work is a follow-up
WI ("route the live step cycle through `decide`/phase modules" + genuine port
supersession) — an operator decision on sequencing, not a re-litigation of D1–D9.

## Worktree residue

`ailang.lock` dirt at verification time is a benign regeneration (only `generated_at` +
`.packages` mirror content hashes; no dependency changes) — commit it deliberately.
`oh-my-pi/` remains untracked, unrelated, untouched.

## Phase C2 resolution addendum

Date: 2026-07-05
Toolchain: AILANG v0.26.0 (commit `3b52a24`)
Completion range: WI-C9 through WI-C14 on branch
`arniwesth/mot-27-phased-core-architecture`.

Phase C2 closed the live-path inversion gap recorded above. The shipped driver now runs
the live loop through `decide` and the phase modules; the old recursive loop and blocking
mid-dispatch approval path were deleted; policy/env reads are hoisted to session init;
the approval pause is represented as `AwaitApproval`; tool execution is in `tool_phase`;
and scripted parity entrypoints pass a port-backed model provider. The transient
`MOTOKO_PHASE_C2_DRIVER` flag and A/B differ were removed before final closeout.

Disposition after WI-C14:

| Deliverable | Final disposition | Closing WI |
|---|---|---|
| Pure `decide` with loop policy is live | Met | WI-C11, WI-C13a |
| Driver executes decisions through phase modules | Met | WI-C11, WI-C13b, WI-C13c |
| Scripted ports supersede `run_v2_with_stub` | Met | WI-C13c follow-up `f30f475` |
| Approval protocol inversion is live | Met | WI-C12 |
| L1 scenario family | Met | Phase C WI-C7, reverified WI-C14 |
| Checkpoint mechanics real | Met | Phase C WI-C1, reverified WI-C14 |

WI-C14 final gate passed as a block on 2026-07-05: core checks/tests, integration tests,
module tests, L1 scenarios, approval protocol, sealing negative probe (`IMP010`),
sketch probes, projection gate, Phase C2 wiring scenarios, strict smoke parity against
`/tmp/phase_c_blessed`, and the final greps for flag removal, phase-module imports,
live `decide` calls, and absent checkpoint events in the blessed captures.
