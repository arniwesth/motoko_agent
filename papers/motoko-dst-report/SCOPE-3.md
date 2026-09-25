# Scope and evidence notes — integrated third draft

Date: 2026-09-19. Implementation snapshot:
`7e5ec5f9daf7d19076c2792e91701a896fc79126`.

The user agreed to retain the first draft's explanatory structure and to keep
conformance and honest coverage accounting prominent alongside the architecture.
[DRAFT-3.md](DRAFT-3.md) implements that direction, integrating the current-system
material developed in [DRAFT-current.md](DRAFT-current.md).

## Editorial decisions

- Write for an external technical reader who has not read either predecessor.
  Introduce DST, the agent loop, effects, ports, and replay before relying on them.
- Use a short illustrative tool interaction throughout the architecture and
  evaluation sections. Treat park/resume as a separate lifecycle example because
  the initial journal-evaluation tier excludes those boundaries.
- Explain generated and journal-derived worlds as inputs to shared recording,
  replay, and checking machinery. The journal fold remains the resume mechanism.
- Preserve the distinctions between declared coverage, observed behavior,
  substantive exercise, vacuity, and explicit exclusion. Keep this methodology in
  the body of the report, not just its limitations.
- Collect revision-specific implementation and validation status in the evidence
  section. Keep immediate qualifications where omitting one would change a claim.
- Keep internal project history and source navigation in an appendix. The August
  one-of-forty result is a historical example, not a current coverage estimate.
- Let the explanatory draft establish its length before publication formatting.
  The earlier 8–12-page budget is not enforced by deleting needed explanations.

## Corrections carried through the integration

The ledger is important evidence, but the current checks also use interaction
logs, world state, wire frames, and a final-state comparand. Sole emission does not
prove that every environmental effect was observed. Reproduction requires retained
inputs and compatible identities; in journal-derived evaluation, the corpus entry
binds the snapshot, excerpt, selector, and program. The physical-fault exclusion
requires renewed scrutiny now that durable resume exists. Current profile
declarations and CI wiring replace the old counts and coverage assumptions.

The report describes ADR-004's accepted design and integrated synthetic machinery.
At the snapshot, the runner's `RealEntry` admission arm still calls
`jr_real_refused`. Separate evaluator worktrees are outside this implementation
snapshot. Their eventual integration requires an update to the status table and
evidence, not a change in the report's architectural explanation.

## Evidence basis and remaining work

Repository sources were inspected during preparation of the second and third
drafts. The two checker selftests recorded in [SCOPE-current.md](SCOPE-current.md)
remain scoped evidence: the wire checker passed its synthetic selftest and the
driver-leaf inventory selftest reported zero failures. They are not a full DST
sweep. The third draft adds verified primary references for FoundationDB,
TigerBeetle, and Antithesis, with only limited background claims drawn from them.

This writing task does not include new live-provider runs, corpus admission,
performance measurements, a complete profile-coverage census, or a systematic
mutation study. No independent review is claimed. Before publication:

1. Pin the publication revision and refresh the implementation-status table.
2. Run the relevant full suite and derive current coverage from its outputs,
   including refusals, exclusions, and vacuous obligations.
3. Audit runner-to-invariant coverage and the scope of crash/recovery tests.
4. Reconcile any admitted journal corpus and performance claims with the
   integrated evaluator and its validation record.
5. Review the explanatory examples, external references, figures, and claim
   strength as a whole, then finalize publication layout.

A PDF exported during drafting is a reading copy of this working report, not a
claim that the publication checks above have been completed.
