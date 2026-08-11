# Project 009: Motoko DST execution — scope and sequence

Date: 2026-07-24
Status: Proposed project boundary

## Why this is a new project

Project 007 consolidated the deterministic test surface: it wired gates into CI, consolidated
scenario infrastructure, organized scripts, and documented the as-built framework. Its recorded
boundary explicitly excluded scenario behavior changes and changes to the conformance kit's
ABI-lockstep contract
(`../007_dst_consolidation/NOTE-dst-consolidation-scope-and-sequence.md`).

The next step is not consolidation. Earning the name **single-actor, logical-fault DST** requires
new behavior and a new architectural boundary:

- all session-relevant nondeterminism must be controllable by one deterministic test world;
- a seed must generate an execution program, not only scenario parameters;
- that program must contain logical faults and meaningful clock advances;
- the real session driver must return a complete trace on every terminal path; and
- failures must replay from the recorded program even after generator ranges change.

Those decisions cross `session`, model dispatch, native and delegated tool execution, approval
input, extensions, clock use, the ledger contract, and the test harness. They are larger and more
durable than a plan-local implementation choice, so they belong to a new project-level ADR.

## Authority and dependencies

This project depends on:

1. `../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md`, after its review
   findings are dispositioned and the ADR is accepted. That ADR owns what the term “DST” means,
   the logical-fault/single-actor scope, and the naming gate.
2. `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md`. Its decisions to run
   production transition code, use explicit fakes, record normalized traces, and assert structural
   invariants remain inputs. Project 009 replaces only the incomplete implementation architecture
   for the simulated environment, schedule, faults, clock, and replay contract.
3. The phase-oriented core and harness-policy decisions. Project 009 may route effects through a
   common environment boundary, but it does not move behavioral policy back into core.

The project must not label its generated test axis “DST” or “simulation” until the conformance gate
owned by project 007 passes. Working names such as `trajectory_pbt` or `deterministic_trajectory`
remain honest during construction.

## In scope

- A project-level architecture decision for the deterministic test world.
- Making the existing port/environment seam authoritative for all ledger- or control-flow-relevant
  external observations:
  - provider outcomes and streaming;
  - native and delegated tool outcomes;
  - approval input;
  - environment/config reads used during a run;
  - runtime randomness, if any;
  - monotonic time, sleeps, deadlines, and timeouts;
  - extension-side AI, process, environment, random, and clock effects.
- A versioned, typed execution-program representation generated from a seed.
- Logical-fault outcomes at the provider, tool, approval, and extension-facing boundaries.
- A stepped virtual clock that can change an observable retry, timeout, or deadline outcome.
- A traced session result that contains exactly one terminal record on success and every abnormal
  return.
- Trace invariants, deterministic replay artifacts, generator-schema versioning, and failure
  reporting.
- Migration of existing scripted fixtures and fixed scenarios onto the new boundary where useful,
  without deleting the fixed regression suite.
- CI/search policy for fixed seeds, rotating seeds, and promoted counterexamples.
- Updating the as-built framework document after the capability lands.

## Explicitly out of scope

- Physical storage faults, torn writes, disk corruption, network partitions, replication, and
  crash recovery. Motoko currently has no physical-durability contract for those to test.
- Multi-actor scheduling or a concurrent interleaving search. The current ledger-affecting loop is
  sequential.
- Injecting internal state-machine decisions directly. Faults enter through modeled external
  boundaries and the production state machine decides how to react.
- Replacing fixed scenario tests, pure property tests, conformance tests, or live-provider
  calibration smokes.
- Treating trace normalization as a substitute for virtual time where time changes behavior.
- A production resume-from-ledger or durable event-log design.

## Revisit tripwires

The single-actor exclusion must be reopened before landing any feature that can mutate or influence
one session ledger concurrently, including:

- parallel native or delegated tool execution;
- ledger-sharing subagents;
- background extension callbacks whose result can race the main loop; or
- streaming callbacks that can independently advance session state.

The physical-fault exclusion must be reopened before adding a crash-recovery, fsync, WAL,
resume-from-ledger, or replicated-state correctness contract.

These tripwires belong both in the taxonomy ADR and beside the execution runner so a future feature
cannot silently invalidate the simulator model.

## Work sequence

### Track 0 — accept the decisions

1. Disposition the review of the project-007 definition/taxonomy ADR.
2. Review and accept `ADR-001-deterministic-test-world-architecture.md` in this project.
3. Do not author a source-dense implementation plan until both decisions are stable.

### Track 1 — authoritative effects and complete traces

- Route session-level model, tool, approval, environment, and clock observations through the
  decided environment boundary.
- Preserve live adapters for production.
- Return a trace for setup errors and every terminal path.
- Put the terminal summary in the returned trace rather than only emitting it to an external sink.

Gate: two executions of the same fixed program produce the same normalized trace, and every tested
terminal path contains exactly one terminal record.

### Track 2 — generated programs, logical faults, and virtual time

- Add the typed execution-program schema and deterministic generator.
- Add the minimum logical-fault catalogue.
- Add clock advancement and at least one time-dependent behavior whose result changes when the
  program advances time differently.
- Execute programs through the real traced session entry point.

Gate: a seed generates ordering, fault placement, and clock advancement; the resulting execution
reaches production recovery behavior and passes or fails trace invariants deterministically.

### Track 3 — replay, search, and adoption

- Persist or print the exact generated program, its schema version, generator version, seed, and
  relevant run configuration on failure.
- Replay the exact program independently of the current generator.
- Add shrinking or a deliberately documented deferred-minimization policy.
- Establish fixed PR seeds, rotating scheduled seeds, and counterexample promotion.
- Apply the project-007 naming gate and update the as-built document.

Gate: a CI failure can be copied into a local replay command and reproduce the same normalized
terminal trace without relying on the generator still mapping the seed to the same program.

## Artifact placement

The architecture ADR is context-heavy and belongs in the session that made the boundary decisions.
Implementation plans are source-heavy and must be authored in a fresh session grounded against the
accepted ADRs and current HEAD, following
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`.

Expected project artifacts:

```text
.agent/projects/009_motoko_dst_execution/
├── ADR-001-deterministic-test-world-architecture.md
├── NOTE-scope-and-sequence.md
├── HANDOFF-write-implementation-plan.md   # after ADR acceptance
└── PLAN-*.md                              # authored fresh from accepted decisions
```

The durable as-built description remains
`design_docs/implemented/motoko_agent/m-motoko-dst-framework.md` and changes only after the new
behavior is implemented.

## Project exit criteria

Project 009 is complete when:

1. the objective conformance gate in the project-007 taxonomy ADR passes;
2. faults and time affect real session executions through the deterministic test world;
3. all terminal outcomes are returned in complete invariant-bearing traces;
4. exact generated programs replay deterministically;
5. fixed and rotating search gates run in CI under an agreed budget; and
6. the as-built documentation accurately distinguishes fixed scenarios, seeded PBT, and the new
   logical-fault DST axis.
