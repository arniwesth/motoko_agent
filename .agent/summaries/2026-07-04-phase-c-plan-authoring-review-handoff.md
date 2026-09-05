# Phase C plan authoring, review, and implementation handoff

Date: 2026-07-04
Repo: `/workspaces/motoko_agent`
Branch: `arniwesth/mot-27-phased-core-architecture`

## Session outcome

This session produced and reviewed the Phase C implementation plan for
`ADR-001-phase-oriented-core.md`, then wrote the fresh-session implementation handoff.
It did not implement Phase C code.

Primary artifacts:

- `.agent/projects/004_phase_core_refactor/PLAN-phase-c-full-inversion.md`
- `.agent/projects/004_phase_core_refactor/HANDOFF-implement-phase-c.md`

Relevant commits:

- `34f901a Added Plan C`
- `479268f Review of PLAN C`
- `1d73b7b Added handof for Plan C implementation`

By the time this summary was written, later Phase C implementation commits were already
present in the repository. Those are covered separately by
`.agent/summaries/2026-07-04-phase-c-partial-implementation-handoff.md`.

## Plan content

The plan covers Phase C only:

- pure `decide` in `src/core/step_machine.ail`
- driver execution in `src/core/session.ail`
- `model_phase`, `tool_phase`, `hook_phase`, and `tool_stream_phase`
- scripted ports superseding `run_v2_with_stub`
- approval protocol inversion through `AwaitApproval(ApprovalRequest)`
- real checkpoint/payload digests and checkpoint-chain validation
- in-memory ledger/trace for L1 invariants
- scripted TUI approval scenario
- required L1 scenario family under `--caps IO` or less
- final gate with parity/projection checks

Out of scope is explicit: ABI v3, conformance kit, `compaction_ai` v0.3.0, and registry
publication of `motoko_ext_compaction_structural`.

## Review fixes applied

The initial plan was reviewed until no major issue remained. Important fixes landed in
`479268f`:

- WI-C1 now treats the real `payload_digest` change as an unavoidable production-byte diff:
  it requires a D-B7 expected-diff table, verifies only
  `provider_call_prepared.payload_digest` changed, and creates `/tmp/phase_c_blessed`.
- WI-C2 and later now diff parity against `/tmp/phase_c_blessed`, not
  `/tmp/phase_b_blessed`.
- The final gate handles the sealing probe as an intentional negative check under
  `set -euo pipefail`: failure with `IMP010` is the pass condition.
- DP7 ownership is clarified: `step_machine` owns policy; verifier execution is only a
  port effect/result fed back into state.
- Approval ordering is pinned: event-before-read, EOF/unparseable default behavior, denial
  message behavior, and approved-call execution before the suspended tail.
- The plan provenance was updated from the handoff commit to review HEAD.

## Handoff content

`HANDOFF-implement-phase-c.md` tells the fresh implementer to execute
`PLAN-phase-c-full-inversion.md` WI-C0 -> WI-C8 in order, one commit per WI unless an
expected-diff artifact needs separate evidence.

It highlights:

- reading order and settled decisions
- toolchain pin v0.26.0 / `3b52a24`
- inherited pre-edit checks
- WI-C1 baseline handoff to `/tmp/phase_c_blessed`
- negative sealing-probe handling
- DP7 policy ownership
- approval protocol ordering
- keeping `run_v2_with_stub` alive as a strangler adapter
- avoiding unrelated dirty work

## Verification performed during plan authoring/review

During plan authoring and review, the following checks were run and recorded in the plan:

- `ailang --version` -> v0.26.0 / `3b52a24`
- `PARITY_BASELINE=/tmp/phase_b_blessed make smoke_parity`
- `./scripts/phase_b_projection_gate.sh /tmp/phase_b_blessed`
- `ailang test src/core/phase_vocab.ail`
- sketch vocabulary and separate-module wrapper probes
- production sealing negative probe (`IMP010` expected)
- `ailang run --caps IO --entry main scripts/smoke_ports_record.ail`
- stdlib crypto hash example
- `make check_core`
- `make test_core`
- `make test_integration`
- `git diff --check` on the reviewed plan and implementation handoff

## Worktree note at this summary

Observed status when this summary was written:

```text
 M ailang.lock
?? oh-my-pi/
```

`oh-my-pi/` is unrelated untracked work and should not be touched. The `ailang.lock`
modification was already present at summary time and should be inspected before any commit
that might include it.
