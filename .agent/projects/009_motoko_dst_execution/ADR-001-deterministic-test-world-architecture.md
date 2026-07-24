# ADR-001: Deterministic Test-World Architecture for Motoko Logical-Fault DST

Date: 2026-07-24
Status: Proposed

Depends on:
- `../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md` after review disposition
  and acceptance. That ADR owns the definition, scope, and naming gate.

Amends:
- The implementation architecture in
  `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md`. Its production-code,
  explicit-fake, normalized-trace, stable-scenario, and invariant decisions remain in force. This
  ADR replaces the assumption that scripted model results plus normalized traces are a sufficient
  simulated environment.

Relates to:
- `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` — production decisions remain in the
  phase-oriented state machine; the test world supplies effects rather than decisions.
- `../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md` — extension-resident policy
  remains extension-resident; this ADR controls the effects through which that policy observes and
  acts on the world.
- `NOTE-scope-and-sequence.md` — project boundary, rollout order, and acceptance gates.

## Context

Motoko already has valuable deterministic testing infrastructure:

- fixed scenario families and seeded parameter generation;
- a real phase-oriented session driver;
- `Scripted([ScriptedStep])` model results;
- a `Ports` record containing model, approval, clock, environment, tool, and extension-runtime
  functions;
- `ScriptedPortsState` helpers for model results, approvals, and clock values;
- a typed `LedgerTrace` and a traced session entry point; and
- invariant-oriented CI gates.

That is strong scenario testing and property-based testing, but it is not yet a deterministic
simulation environment. The pieces do not form one authoritative world:

- `ScriptedStep` is a successful model-result record, not an execution event or fault sum type.
- The seed chooses scalar parameters; it does not generate the ordering of external events.
- `Ports` is projected into some extension paths, but the main session still performs important
  effects directly. Approval uses `readLine`, session timing uses `std/clock.now`, and native tool
  execution does not uniformly consume `Ports.tool_exec`.
- The clock fixture supplies values but does not advance session-wide time or control a real
  deadline, retry, or timeout.
- the ordinary scripted entry point returns messages, while the traced entry point must be chosen
  separately;
- some error returns have no terminal summary, and emitted summaries are not guaranteed to be part
  of the returned `LedgerTrace`; and
- a seed can replay the current generator only while its mapping remains unchanged. There is no
  authoritative, versioned execution program to replay.

Extending `ScriptedStep` alone cannot close these gaps. Model outcomes, tools, approvals, extension
effects, time, terminal tracing, and replay must share one architecture.

## Decision

### D1. Evolve `Ports` into the authoritative execution-world boundary

Motoko will have one semantic boundary for external observations that can affect session control
flow or the ledger. The existing `src/core/ports.ail` record is the migration root; the project
must evolve it rather than introduce a competing test-only driver.

The authoritative boundary covers:

1. provider request outcomes, including streaming observations;
2. native and delegated tool execution outcomes;
3. approval input;
4. environment/config reads performed during the session;
5. runtime randomness, if any;
6. monotonic time, sleeps, deadline checks, and timeout outcomes; and
7. extension-side model, process, environment, random, and clock effects.

Production constructs this boundary with live adapters. Deterministic tests construct it from an
execution program and virtual world state. Production transition and policy code must not branch on
“test mode.”

An effect is required to cross this boundary when changing its result could change:

- the next state-machine decision;
- messages or tool results appended to history;
- a ledger record;
- retry/finalization behavior;
- budget or timeout behavior; or
- the terminal outcome.

Diagnostic output that cannot influence execution may remain outside the modeled world, but it must
not be used as the only copy of an invariant-bearing terminal fact.

### D2. The simulation input is a versioned execution program

The unit generated from a seed is a typed `ExecutionProgram`, not a bag of scalar inputs and not
only a list of successful model responses.

Conceptually:

```text
ExecutionProgram {
  schema_version
  generator_version
  seed
  initial_configuration
  instructions[]
}

Instruction =
    ProviderOutcome(...)
  | ToolOutcome(...)
  | ApprovalOutcome(...)
  | EnvironmentOutcome(...)
  | RandomOutcome(...)
  | AdvanceClock(...)
  | ExtensionEffectOutcome(...)
```

The exact AILANG type names are plan-level, but these semantics are architectural:

- Instructions are ordered.
- Each external request consumes the next compatible instruction.
- Before delivering the next requested external outcome, the world consumes any leading
  `AdvanceClock` instructions and advances the shared monotonic clock. Reading the clock returns
  its current value; a read does not independently advance time.
- An unexpected request, wrong instruction kind, exhausted program, unused required instruction, or
  backward clock movement is a **harness error**, not a simulated system fault.
- The program contains concrete outcomes. Replay never calls the generator.
- The seed and generator version explain how a program was discovered; the serialized program is
  the authoritative reproduction artifact.
- Runtime randomness is either absent or supplied by recorded `RandomOutcome` instructions. Replay
  never reads an ambient RNG.

Generation may also choose ordinary configuration and message inputs, but scalar input generation
does not count as the schedule. To satisfy the trajectory requirement, the generator must choose
the length and ordering of multiple environment instructions.

### D3. Logical faults are modeled outcomes, not injected internal decisions

Faults enter through the same boundary as successful external outcomes. The state machine and
session driver remain production code and decide how to react.

The minimum catalogue required before adopting the DST name is:

| Boundary | Required fault classes |
|---|---|
| Provider | retryable error, non-retryable error, malformed or protocol-inconsistent result, truncated stream/response, empty terminal response |
| Tool | denial, non-zero/error result, timeout, malformed output/result envelope |
| Approval | explicit denial and input exhaustion/interruption |
| Extension-facing effects | provider/process failure where an installed hook performs that effect |

The implementation plan must map every modeled class to a real production error or result type and
name the recovery branch it is intended to reach. A decorative fault variant that cannot influence
the production session does not satisfy this decision.

Directly forcing `StepDecision`, editing ledger state, or bypassing validation is rejected as fault
injection: it would test a second test-only transition system.

The catalogue can grow without a new ADR when additions preserve this boundary. Adding physical
faults or changing the system’s durability contract requires revisiting the project scope.

### D4. One monotonic virtual clock controls all time-bearing behavior

The deterministic world owns a monotonic clock. Session code and extensions read it through the
authoritative boundary; they do not read ambient wall time when the value can affect behavior or an
asserted trace.

`AdvanceClock(delta)` must reject negative movement. A program may hold time still or advance it by
an explicit duration. Timeout, retry, backoff, and deadline calculations use this clock.

Clock normalization remains appropriate for nondeterministic display-only fields. It does not
satisfy this decision. Before adopting the DST name, at least one generated trajectory must
demonstrate that different legal clock advances lead to different production timeout, retry, or
deadline behavior while each trajectory remains deterministically replayable.

If no production behavior observes time, merely carrying unused clock instructions does not meet
the gate.

### D5. Execution uses the real traced session driver

The runner executes an `ExecutionProgram` through `Session.run_v2_session_traced` or a successor
that retains the same production driver and returns a complete trace. The ordinary
`run_v2_from_messages` message-only result is not the DST oracle.

Test-only code may:

- generate and decode programs;
- implement the deterministic world;
- collect replay metadata; and
- evaluate invariants.

It may not reimplement state transitions, recovery policy, tool-history construction, compaction,
or finalization.

Fixed scenarios and pure property tests may continue using narrower entry points. Their existence
does not satisfy this decision unless the generated DST axis drives the real traced session.

### D6. Every run returns one complete terminal trace

The DST runner returns a result containing:

```text
{
  outcome,
  ledger_trace,
  replay_metadata,
  harness_diagnostics
}
```

The exact representation may reuse existing types, but the contract is:

1. Every production terminal path has exactly one terminal record in `ledger_trace`.
2. Success, budget exhaustion, maximum steps, compaction exhaustion, provider/tool failure,
   rejected policy outcomes, setup failure after a run is established, and internal driver errors
   are distinguishable.
3. The terminal record contains or references the run summary used by invariants.
4. Emitting a summary to IO, tracing, or an external ledger sink does not substitute for returning
   it in `ledger_trace`.
5. Harness errors are distinct from simulated system outcomes and include the consumed instruction
   position.
6. The returned trace is the oracle; captured console output is diagnostic only.

If initialization can fail before a session ledger exists, the runner must return a typed harness
or setup outcome. It must not present that failure as a successful empty trace.

### D7. Invariants are evaluated over the whole execution

The runner applies reusable invariants to the returned outcome and complete trace. At minimum, the
name-adoption gate requires:

- exactly one terminal record;
- legal phase/state transitions;
- valid tool-call/tool-result pairing, including denial and failure paths;
- monotonically valid budget/cost accounting;
- bounded retry and progress behavior under the modeled fault catalogue;
- checkpoint/compaction history invariants already owned by the framework;
- agreement between returned outcome and terminal summary; and
- complete consumption rules for required execution-program instructions.

Example-based assertions remain useful, but a generated run that checks only its final prose or a
golden snapshot is not the new DST axis.

Liveness claims must be bounded and operational—for example, “terminates or reaches a named retry
bound within N decisions”—rather than relying on an unbounded test run.

### D8. Replay records the program, not just the seed

Every generated failure reports and preserves:

- execution-program schema version;
- generator version;
- seed;
- the exact serialized program;
- the run configuration needed to interpret it;
- the first failed invariant;
- the terminal outcome; and
- the normalized trace or a stable location containing it.

Replay consumes the exact program and does not regenerate it. This keeps historical failures valid
when generator distributions, draw order, or ranges change.

Programs use a deterministic, diffable encoding with an explicit compatibility policy. The
implementation plan may select the encoding and storage path, but CI output must provide a
copy-pasteable local replay command or artifact reference.

Shrinking operates on programs, not only seeds. It may land after the first name-adoption gate if
the project records that deferral explicitly, but replay of the unshrunk failing program is not
optional.

### D9. The simulator is sequential until the production contract changes

The deterministic world consumes one instruction at a time at production effect boundaries. It
does not add a concurrent scheduler for the current agent loop.

This decision must be revisited before introducing parallel ledger-affecting tools, ledger-sharing
subagents, state-mutating background callbacks, or independently state-advancing stream handlers.
At that point, reproducibility may require explicit actor identities, runnable sets, and
seed-selected interleavings. Adding concurrency without revisiting this ADR invalidates the
simulation model.

### D10. Existing tests remain, and naming changes only at the conformance gate

Fixed deterministic scenarios, seeded scalar PBT, conformance tests, and live-provider smokes test
different things and remain valuable. The new axis complements them.

During implementation, new code and targets use a non-simulation working name. The unqualified
“DST”/“simulation” label is adopted for the generated axis only after the acceptance test below
passes and the project-007 definition/taxonomy ADR is accepted.

Existing historical target names are handled by the taxonomy ADR’s grandfathering decision; this
ADR does not broaden that exception.

## Acceptance test for the name

A reviewer can approve the generated axis as **Motoko single-actor, logical-fault DST** only when
all answers below are supported by an automated gate:

| Question | Required evidence |
|---|---|
| Does one seed generate an execution rather than only values? | The recorded program contains multiple ordered external instructions whose kinds/order were generator choices. |
| Is there a modeled logical environment? | Provider, tool, approval, environment, any runtime randomness, relevant extension effects, and the clock are supplied by one deterministic world boundary. |
| Do injected faults reach production recovery code? | At least one generated/replayed program per required fault class reaches its named production branch. |
| Does virtual time matter? | Two replayable programs differing in clock advancement produce the expected different timeout/retry/deadline behavior. |
| Is production logic under test? | The runner calls the real traced session driver; no test transition loop computes the outcome. |
| Is the oracle complete? | Every enumerated terminal path returns exactly one terminal record and all invariants run over the returned trace. |
| Is replay stable? | The exact recorded program reproduces the normalized terminal trace without invoking the generator. |
| Is hermeticity enforced? | The gate succeeds under its declared narrow capabilities and a conformance probe proves that bypassing the world fails or is detected. |

Passing only the current seeded scalar families, replaying only a seed, normalizing timestamps, or
adding fault-shaped constructors without reaching recovery behavior fails this acceptance test.

## Alternatives considered

### Extend `ScriptedStep` with fault variants

Rejected as the complete architecture. `ScriptedStep` currently describes successful model results;
it does not control approval input, native tools, all extension effects, time, or terminal tracing.
It may be migrated into the provider-outcome portion of `ExecutionProgram`, but cannot represent the
whole world by itself.

### Build a second simulation-only session loop

Rejected. A parallel loop would make deterministic tests precise about the wrong implementation
and allow production recovery behavior to drift.

### Inject state-machine decisions directly

Rejected. The simulator supplies external outcomes; production code owns decisions. Direct decision
injection bypasses the behavior the tests are intended to validate.

### Keep normalizing time instead of virtualizing it

Rejected for time-dependent behavior. Normalization makes traces comparable but cannot search
timeout, retry, deadline, or backoff trajectories.

### Require a concurrent event scheduler now

Rejected. No ledger-affecting interleaving was found in the current loop, tool dispatch, MCP
subprocess, streaming, or compose-subagent paths. A sequential instruction program is the smallest
faithful model. D9 records the conditions that invalidate this choice.

### Store only seed plus generator version

Rejected. A generator version identifies code but does not preserve a failure if that code becomes
unavailable or its dependencies change. The exact program is small enough to be the durable replay
unit.

### Split faults, clock, tracing, and generation into separate ADRs

Rejected initially. These mechanisms share the same environment boundary and reproduction contract.
Splitting them before that boundary is decided risks incompatible abstractions. A separate ADR is
warranted later only for a genuinely independent production contract, such as crash recovery or
durable ledger restoration.

## Consequences

Positive:

- “Motoko DST” gains a mechanical, reviewable architecture rather than a naming aspiration.
- Production and test execution share one effect boundary and one state machine.
- Failures survive generator evolution because the exact program is replayable.
- Logical faults and time exercise real recovery behavior.
- The architecture remains proportional to a sequential agent loop; it does not import a
  distributed-systems scheduler without a concurrency contract.

Costs and risks:

- Making `Ports` authoritative touches session, tool, approval, extension, and clock paths.
- The trace contract changes error handling and may expose terminal cases currently visible only in
  logs.
- A typed program schema and compatibility policy become maintained test infrastructure.
- Generated trajectories enlarge the failure space and make shrinking more valuable.
- The sequential design can become stale if a concurrency feature lands without triggering D9.

## Non-goals

- Physical-fault or distributed-systems simulation.
- A production durable ledger, session resume, or crash-recovery mechanism.
- Declaring every deterministic Motoko test to be DST.
- Removing fixed scenarios or seeded PBT.
- Selecting exact AILANG syntax, module names, serialization library, CI seed counts, or rollout
  commit boundaries; those belong to fresh, source-grounded implementation plans.

## Implementation handoff

After this ADR and the project-007 taxonomy ADR are accepted, a fresh session should survey every
effect call site and write the implementation plan. It must re-verify:

- every construction and consumer of `Ports` and `StepProvider`;
- all direct `readLine`, `std/clock`, environment, process, filesystem, network, stream, and random
  effects reachable during a session;
- native, delegated, MCP, and extension tool-runtime paths;
- every return from the traced session driver;
- the ledger event vocabulary and terminal-summary consumers;
- current seeded-family and CI behavior; and
- all exhaustive matches affected by the chosen program and outcome types.

The plan must preserve user changes and current behavior while migrating one effect class at a time.
No implementation target should adopt “DST” or “simulation” merely because this ADR exists.
