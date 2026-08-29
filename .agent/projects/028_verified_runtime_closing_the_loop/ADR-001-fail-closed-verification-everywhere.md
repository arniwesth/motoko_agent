# ADR-001 — Fail-closed verification, all the way down

Date: 2026-08-29
Status: Proposed
Context session: Motoko live assessment (see NOTE-motoko-session-assessment.md)

## Context

Motoko's distinguishing bet: verification is a commit gate, not a linter. This
is real at the cell level — the scratchpad refuses to mutate state on unproven
AILANG (`not committed: verifier found a counterexample`). But the same
philosophy stops short at three boundaries, each verified live this session:

1. **Finalization**: DP7 gate runs `make check_core` before done, but
   `session.ail:1804` is fail-open (`Err(_) => Approve`) and config-switchable
   (`rt.verification.enabled`). SYSTEM.md literally tells the agent "the
   runtime will not catch this for you" — the tool to catch it exists and
   flinches at the wrong moment.
2. **Batch execution**: one unavailable backend vetoes a whole scratchpad
   batch, reported as success (`exit_code: 0`).
3. **Claims**: agent prose ("56/56 pass", "Lean unavailable") carries no
   provenance requirement, unlike code cells.

## Decision

Adopt **fail-closed** as the default at every enforcement boundary:

- `run_dp7_verifier`: `Err(_) => Reject` with the infra error surfaced as the
  rejection reason; make the gate non-configurable for shipped profiles (a
  deliberate opt-out may exist for dev profiles, but never as a silent
  environment failure).
- Scratchpad availability vetoes: skip CELLS, not BATCHES; skipped cells get
  explicit per-cell results with a `skipped` status; batch exit code
  non-zero when any requested cell could not run.
- Claim provenance: final answers must cite backing tool-call IDs / artifacts
  for factual claims; unbacked claims flagged the way unverified cells are.

## Consequences

- The "verification before declaring done" discipline clause in SYSTEM.md
  becomes runtime-enforced instead of honor-system (msg `06adbc32` closed).
- Failure becomes loud: infra breakage produces a visible rejection with a
  reason, not a silent approval.
- Cost: rejection on verifier infra failure may block legitimate work until
  the environment is fixed — accepted; silent approval is worse (same
  reasoning as the `ohmy_pi` fail-fast guard).
- The TS boundary problem (1,175 unverified files around a verified core)
  remains open — addressed incrementally via `012_continuous_ailang_adoption`
  rather than by this ADR.
