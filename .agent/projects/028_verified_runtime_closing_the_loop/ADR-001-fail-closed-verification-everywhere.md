# ADR-001 — Fail-closed verification, all the way down

Date: 2026-08-29
Status: Proposed
Context session: Motoko live assessment (see NOTE-motoko-session-assessment.md)

**Superseded in part, from 2026-10-10.** The finalization item is superseded
by [005 ADR-001](../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md),
Amendment 1. See the note under Decision. The batch-execution and claims items
are not touched by that amendment.

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

  > **Superseded, from 2026-10-10,** by
  > [005 ADR-001](../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md),
  > Amendment 1 (A1 and the operator's ruling of 2026-10-09). The DP7 verifier
  > is removed from core and nothing replaces it, so there is no gate left to
  > make fail-closed or non-configurable. `run_dp7_verifier` no longer exists.
  > The first consequence below goes with it: the runtime does not enforce the
  > SYSTEM.md clause, and SYSTEM.md now says the check is the model's to run.
  > The text is left as written.

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
