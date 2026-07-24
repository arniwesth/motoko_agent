# ADR-001: Deterministic Test-World Architecture for Motoko Logical-Fault DST

Date: 2026-07-24
Status: Proposed — author self-review, streaming spike, and AILANG v0.30.0 upstream recheck
complete; upstream recorded-stream API and independent review required
Grounded at: `7b9b4a4c266b229be85de5c09342f2b654c89fe7`
Upstream rechecked at: AILANG v0.30.0 release commit
`e37b370d1d7a9c4e7136b319e38bec4d5f2bd9a0`

Depends on:
- `../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md` after review disposition
  and acceptance. That ADR owns the definition, scope, and naming gate.

Amends:
- The implementation architecture in
  `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md`. Its production-code,
  explicit-fake, normalized-trace, stable-scenario, and invariant decisions remain in force. This
  ADR replaces the assumption that scripted model results plus normalized traces are a sufficient
  simulated environment.
- `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` for the generated DST axis. Its pure
  `decide`, production phase/state transitions, driver-owned effect execution, append-only ledger,
  and extension-resident policy decisions remain in force. This ADR replaces function-valued ports
  as the complete deterministic-state mechanism, requires returned-trace/emission parity, and
  disallows that ADR's residual raw-effect allowances inside a D5-conformant simulation profile.

Relates to:
- `../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md` — extension-resident policy
  remains extension-resident; this ADR controls the effects through which that policy observes and
  acts on the world.
- `NOTE-scope-and-sequence.md` — project boundary, rollout order, and acceptance gates.
- [`sunholo-data/ailang-world`](https://github.com/sunholo-data/ailang-world) and
  `NOTE-ailang-world-overlap.md` — AILANG World's persistent production effect broker, immutable
  transition history, and replay machinery overlap conceptually with this ADR's effect boundary
  and artifacts. The note records the layer boundary, possible reuse, and terminology risk; AILANG
  World does not replace the seed-driven deterministic test world.

## TL;DR

Motoko earns the name **single-actor, logical-fault DST** by running its real traced session driver
against one explicit, driver-threaded deterministic world. Seeded discovery reacts to the external
requests production code actually makes, chooses modeled outcomes, logical faults, and virtual
latencies, and records the resulting ordered `ExecutionProgram`. Replay consumes that exact
program without invoking the generator. Provider, typed tool, approval, environment, runtime
randomness, conformant extension effects, logical resource state, and time share this boundary;
every system termination returns one complete `LedgerTrace`, and whole-execution invariants decide
the result. The simulator stays sequential and does not model physical faults.

The DST name remains unavailable until the automated conformance gate passes for a named,
fail-closed profile. The checked streaming spike proved that pinned AILANG v0.26.0 cannot both keep
provider chunks immediately visible and return the identical ordered chunks in the immutable
trace: the API rejects both state-returning callbacks and callback-side `SharedMem` capture. Before
this ADR can be accepted, an upstream recorded-stream API must land and pass the spike's direct
integration probe. A 2026-07-24 recheck using the repository-configured AILANG MCP identified
v0.30.0 as latest; its released source and compiler preserve the same callback and result contract,
so upgrading from v0.26.0 to v0.30.0 does not remove this blocker.

## Context

Motoko already has valuable deterministic testing infrastructure:

- fixed scenario families and seeded parameter generation;
- a real phase-oriented session driver;
- `Scripted([ScriptedStep])` model results;
- a function-valued `Ports` record containing model, approval, clock, environment, tool, and
  extension-runtime functions;
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
- The function-valued `Ports` shape has no explicit state transition. `Scripted` works because the
  driver threads the provider tail, while `scripted_ports_from_steps` derives an index from message
  history. Neither mechanism can safely consume one ordered program across provider, tool,
  approval, environment, and clock requests.
- `Ports.hooks_runtime` has no production consumer, and several effectful extensions do not use
  `ExtCtx.ports`: MCP, scratchpad, compose, context-mode, and similar hooks can perform
  `Process`/`Net`/`FS`/`SharedMem` effects directly. “Ported core” therefore does not imply a
  hermetic extension profile.
- The clock fixture supplies values but does not advance session-wide time or control a real
  deadline, retry, or timeout. AILANG v0.26.0 does provide runtime virtual time
  (`--virtual-time`; `std/clock.sleep` advances it), but the seeded axis does not drive that clock
  and OS-process timeouts do not inherit it.
- Provider streaming is push-based: `stepWithStream` invokes a callback returning `()`. The current
  compatibility wrapper explicitly leaves its returned `chunks` empty because it cannot accumulate
  callback values without a reference. Live chunks can therefore be projected immediately, but
  current Motoko code has no lossless, run-scoped way to return those same chunks in `LedgerTrace`.
  The project-009 spike confirms that this is an upstream API constraint, not merely a missing
  Motoko helper. AILANG v0.30.0 retains the same closed `{IO}` callback and final
  `Result[StepResult, AIError]`, with no recorded-stream result or API.
- The ordinary scripted entry point returns messages, while the traced entry point must be chosen
  separately;
- some error returns have no terminal summary, and emitted summaries are not guaranteed to be part
  of the returned `LedgerTrace`; and
- a seed can replay the current generator only while its mapping remains unchanged. There is no
  authoritative, versioned execution program to replay.

Extending `ScriptedStep` alone cannot close these gaps. Model outcomes, tools, approvals, time,
terminal tracing, replay, and the declared extension profile must share one architecture.

Load-bearing current-source anchors:

| Premise | Grounding |
|---|---|
| `Ports` is function-valued and its tool seam is stringly | `src/core/ports.ail:17-24` |
| Existing scripted state demonstrates explicit `result + next` for three separate queues, but is not threaded through the session | `src/core/test/scripted_ports.ail:20-65` |
| `ScriptedStep` contains only successful-result fields | `src/core/test/stub_step.ail:34-41` |
| `TracedSessionResult` currently contains only `result + trace` | `src/core/session.ail:146-149` |
| Approval and session clock bypass `Ports` | `src/core/session.ail:1610-1617,1989-1995` |
| Success emits `RunSummary`/`DoneEvent` without appending them to the returned trace; other errors return directly | `src/core/session.ail:1525-1557,1609-1614` |
| Native tools execute sequentially and directly against FS/Process | `src/core/tool_runtime.ail:151-165` |
| Core tool dispatch is serial; MCP execution is a blocking call; provider chunks are callback-ordered | `src/core/tool_phase.ail:302-357`; `packages/motoko-ext-mcp/exec.ail:63-70,165-176`; `src/core/test/stub_step.ail:175-204` |
| The current streaming wrapper cannot return the chunks it projects live | `packages/motoko-ext-ai-compat/ai_compat.ail:31-37,60-71,197-220` |
| Neither state-returning nor `SharedMem`-capturing callbacks fit the pinned real API | `spike/README.md`; `spike/probe_state_returning_callback_rejected.ail`; `spike/probe_sharedmem_callback_rejected.ail` |
| Latest upstream does not close the streaming-capture gap | AILANG MCP `ailang_versions` reports v0.30.0 latest; release `std/ai.ail:330-337` at `e37b370d1d7a9c4e7136b319e38bec4d5f2bd9a0` retains `on_chunk: (StreamChunk) -> () ! {IO}` and returns only `Result[StepResult, AIError]`; both negative probes reproduce under the checksum-verified v0.30.0 compiler |
| The pinned AILANG runtime already supplies a virtual clock | `ailang run --virtual-time --caps IO --no-print scripts/smoke_ports_record.ail` prints `Virtual time enabled` and exits 0 on v0.26.0; `std/clock` defines virtual `now`/`sleep` |
| Existing delegated adapters have real timeout contracts that can ground the first virtual-time seam | `packages/motoko-ext-mcp/exec.ail:45-70,165-170`; `packages/motoko-ext-context-mode/context_mode.ail:120-128,171-185` |
| The extension ABI exposes function-valued `ExtPorts`, while reached hooks may perform broad effects | `packages/motoko-ext-abi/types.ail:62-66,151-164` |
| Effectful extensions can bypass `ExtCtx.ports` | `packages/motoko_scratchpad/scratchpad.ail:90-101`; `packages/motoko-ext-mcp/exec.ail:165-170` |
| Core provider retry policy is count/budget based | `src/core/recovery.ail:12-18` |

## Decision

### D1. Use a driver-owned, state-threaded execution-world protocol

Motoko will have one semantic boundary for external observations that can affect session control
flow or the ledger. The boundary is a state transition, conceptually:

```text
handle(world_state, world_request)
  -> Result({
       intermediate_emissions[],
       response,
       next_world_state,
       observations
     }, HarnessError)
```

The real session driver owns and threads `world_state` alongside its existing loop state. Every
request returns the next state explicitly, including error outcomes. The implementation must not
hide the program cursor or clock in `SharedMem`, process-global mutation, an ambient RNG, or a
mutable test singleton: those would reintroduce order dependence and make parallel test processes
unsafe. D4's pinned runtime virtual clock is permitted only as a synchronized, asserted mirror of
the explicit clock value—not as an unrecorded source of simulator state.

A request may yield ordered intermediate emissions before its final response. Provider stream
chunks are the current case. The provider exchange result must contain a lossless ordered emission
log as well as the final `StepResult`/`AIError`. A live adapter also projects each chunk to the UI
at arrival; after the call returns, the driver appends the adapter's identical emission log to the
authoritative `LedgerTrace` in arrival order before it applies the final response transition. A
deterministic adapter supplies timed emissions from the program, and the driver projects and
appends each at its virtual arrival point. The two paths must produce the same event ordering and
content without double-projecting live chunks.

This requirement is a blocking substrate gate, not an implementation detail. The checked spike in
`spike/` dispositions the two candidate representations against pinned AILANG v0.26.0:

1. A modeled provider result that preserves immediate projection and returns the ordered chunks
   passes success and partial-stream-then-error parity under `--caps IO`, but the real API exposes
   no such result.
2. A CAS-claimed, request-scoped `SharedMem` recorder passes success, partial-error,
   collision/cleanup, interleaved-scope, and eight-process isolation probes, but the real
   `stepWithStream` callback's closed `{IO}` row rejects `SharedMem`.
3. The real API's IO-only positive control streams `ContentDelta` and `Usage` and returns a final
   result, while a state-returning callback fails type unification against `()`.

The 2026-07-24 latest-upstream recheck does not change that disposition. The configured AILANG MCP
reported v0.30.0 as latest. An empty diff between the v0.26.0 and v0.30.0 `stepWithStream`
signatures confirmed that v0.30.0 still requires a unit-returning, closed `{IO}` callback and still
returns only `Result[StepResult, AIError]`. A full-source search found no recorded-stream variant.
The checksum-verified v0.30.0 compiler reproduced both intended failures: the state-returning
callback fails `()` versus list unification, and the recorder callback fails closed-row unification
because of `SharedMem`. The official v0.30.0 IO-only streaming example checks and runs with
`--ai-stub`, so these failures are specific to capture rather than evidence that streaming itself
was removed.

Therefore the selected prerequisite is an evolved upstream provider/runtime API that preserves
immediate callbacks and returns the lossless ordered observed chunks with the final result. A
row-polymorphic callback plus scoped recorder is not the default fallback: it adds `SharedMem` to
the deterministic profile and weakens capability-based hermeticity, so selecting it would require
an explicit amendment. A process-global, unscoped, or silently colliding recorder remains rejected.
Delaying all chunk projection until provider completion also remains rejected because it changes
current live UX semantics.

Before this ADR is accepted, the upstream recorded-stream API must be pinned and a direct positive
version of the spike must prove immediate projection, exact returned-log parity, success,
partial-stream-then-error, and no duplicate delivery. Until then, complete streaming trace parity
is blocked and production migration must not begin.

`world_state` is more than a cursor. It contains the virtual clock, generator/replay state,
synthetic environment and runtime-random stream, and any logical resource state promised by the
selected profile—for example an in-memory file map, tool/MCP availability, or approval-channel
state. A profile may treat an opaque external tool as a scripted typed boundary instead of
emulating its internals, but must say so; it may not imply filesystem/server semantics it does not
model.

The authoritative request surface covers:

1. provider requests and streaming, tagged by origin (main loop or extension);
2. native and delegated tool execution as a typed request/result contract;
3. approval input;
4. environment/config reads performed during the established run;
5. runtime randomness, if any;
6. monotonic time and time-bearing completion/deadline decisions; and
7. conformant extension-side external effects (D5).

The existing `src/core/ports.ail` record is the migration root and live-adapter vocabulary, but its
function-valued shape is not itself the final world protocol. In particular:

- the provider exchange wraps the existing typed `Result[StepResult, AIError]` with its ordered
  intermediate-emission log;
- the tool contract must carry a typed `ToolCallEnvelope`, timeout/deadline information, and a typed
  result/error rather than `tool_exec(string, string) -> string`;
- approval remains a typed `ApprovalResolution`; and
- clock reads return the current world time without advancing it.

The world ends at the external result boundary. Production code still validates and interprets
`StepResult`/`AIError`, correlates tool-call ids, converts typed tool outcomes into history
messages, applies approval/policy decisions, updates budgets, and records ledger events. Moving
those operations into the simulator would violate D5.

The unused `Ports.hooks_runtime` callback is not a world-state carrier. The implementation plan
must either give it a separate demonstrated production purpose or remove/deprecate it; hiding the
simulator behind that callback is rejected.

A live world delegates requests to evolved production adapters. A deterministic world interprets
the recorded program. The driver uses the same request/response types and transition code in both
cases; production state-machine and policy code does not branch on “test mode.” A small adapter
dispatch between `LiveWorld` and `DeterministicWorld` is mechanism, analogous to the current
`StepProvider`, not a second behavior implementation.

An effect is required to cross this boundary when changing its result could change:

- the next state-machine decision;
- messages or tool results appended to history;
- a ledger record;
- retry/finalization behavior;
- budget or timeout behavior; or
- the terminal outcome.

Diagnostic output that cannot influence execution may remain outside the modeled world, but it must
not be used as the only copy of an invariant-bearing fact. The deterministic executor accumulates
its result, trace, and diagnostics first; a wrapper may print them afterward. A live projection
sink may mirror events during production, while the deterministic profile uses a collecting/no-op
sink so reporting `IO` does not justify ambient input during execution.

### D2. Discovery is seed-driven; replay consumes a resolved execution program

Precomputing exact expected requests would require duplicating the session logic to predict them.
Motoko therefore separates **discovery** from **replay**.

During discovery, a deterministic seeded world receives each real D1 request as the production
driver makes it. A schema-versioned generator chooses a compatible response, fault, and latency
from that request plus explicit generator state. The choice changes the next production state and
therefore which request arrives next. The world records every actual request projection and chosen
outcome into a resolved `ExecutionProgram`.

Replay receives that resolved program and never calls the generator:

```text
DiscoveryConfig {
  schema_version
  generator_id
  generator_version
  seed
  initial_world {
    messages_and_policy
    synthetic_environment
    clock_epoch
    extension_profile
  }
}

ExecutionProgram {
  schema_version
  generator_id
  generator_version
  seed
  initial_world
  interactions[]
}

Interaction =
    ExpectProvider(origin, request_matcher, timed_outcome)
  | ExpectTool(origin, request_matcher, deadline, timed_outcome)
  | ExpectApproval(request_matcher, deadline, timed_outcome)
  | EnvironmentRead(key, value_or_missing)
  | RuntimeRandomDraw(bounds, value)
  | AdvanceClock(delta)
```

The exact AILANG type names are plan-level, but these semantics are architectural:

- Discovery chooses only at requests the real driver actually makes. It never invents a tool,
  approval, or extension-effect request disconnected from production control flow. A generated
  provider outcome may contain a tool call and thereby cause a later production tool request; the
  seed controls the resulting trajectory without a test copy of the state machine.
- Each discovery choice is a deterministic function of generator id/version, seed, generator
  state, the bounded request projection, and current world state. No ambient RNG participates.
- The resolved interactions are an ordered expected protocol, not anonymous response queues. Each
  records (a) a stable causal identity used to decide whether the outcome can be delivered and
  (b) a bounded full request projection/digest used for strict reproduction and invariants.
  Every interaction identity includes a global encounter ordinal. Provider identity additionally
  includes kind, origin, step, and model; tool and approval identity additionally includes kind,
  origin, call id, and name. The ordinal keeps repeated production call ids representable so an
  invariant can reject them as system behavior rather than the program decoder rejecting the
  artifact. Arguments and message/payload digests are recorded projections, not silently
  discarded.
- Replay has two explicit modes. **Strict replay** (the reproduction contract) requires causal
  identity and recorded projections to match under the recorded execution manifest/profile.
  **Regression replay** on a newer revision requires compatible causal identity, records
  projection differences, and may continue so the same environment outcomes exercise changed
  production logic. A wrong kind/origin, unsafe identity mismatch, exhausted program, or unused
  interaction is a
  `HarnessFailure`, not a simulated system fault. Regression replay never weakens tool-call/result
  correlation or delivers an outcome to a different logical request.
- `timed_outcome` carries deterministic latency or completion time. Before delivery, the world
  advances its monotonic clock by the recorded non-negative amount. Explicit `AdvanceClock`
  interactions model time between response-bearing requests. Clock reads return the current value
  and do not independently advance it.
- A provider timed outcome may contain ordered stream chunks with non-decreasing virtual offsets
  followed by a final `StepResult` or `AIError`. The driver records each chunk at its offset before
  the final response. Chunk callbacks remain serial within the provider request; they do not become
  independent actors under this ADR.
- Environment reads and runtime random draws are also recorded in encounter order. Discovery uses
  synthetic environment values and the seeded world; replay returns the recorded values. Unknown
  required keys, incompatible random bounds, or stream exhaustion are harness failures.
- The program contains concrete outcomes and the bounded actual request projections needed to
  diagnose mismatches. The generator id/version and seed explain discovery; the serialized
  resolved program is the authoritative reproduction artifact.
- Program decoding and a pure structural validator run before replay. They reject malformed
  schemas, negative time, duplicate interaction identities, impossible static references, and
  absent required initial values.
- Each generator schema declares hard bounds for interactions, stream chunks, payload bytes,
  logical-resource size, and clock advancement. Exceeding a bound is a generator/harness failure,
  not an unbounded test run.
- The discovery gate reports generator failures and forbidden-effect/harness-failure counts; all
  must be zero. A harness failure deliberately created by a conformance probe is reported
  separately from the search corpus.

Generation may also choose ordinary configuration and message inputs, but scalar input generation
does not count as the trajectory. To satisfy the naming gate, seeded choices at multiple real
effect boundaries must influence ordering, fault placement, and time across the resulting
execution.

### D3. Logical faults are modeled outcomes, not injected internal decisions

Faults enter through the same boundary as successful external outcomes. The state machine and
session driver remain production code and decide how to react.

The minimum catalogue required before adopting the DST name is:

| Boundary | Required fault classes |
|---|---|
| Provider | retryable `AIError`, non-retryable `AIError`, protocol-inconsistent typed result, partial stream followed by error, empty terminal response |
| Tool | typed execution error/non-zero result, protocol-inconsistent result (for example wrong call id), and completion after its declared deadline |
| Approval | explicit denial and no response before a declared approval deadline, where that deadline is enabled by the production policy |
| Conformant extension effect | the corresponding provider/tool/process failure when the selected D5 profile contains an effectful hook using that world request |

The implementation plan must map every modeled class to a real production error or result type and
name the recovery branch it is intended to reach. A decorative fault variant that cannot influence
the production session does not satisfy this decision.

Every successful or faulty outcome also defines its logical world transition. Write-like tool
faults specify whether the all-or-nothing logical update occurred; server-drop faults update
availability for subsequent calls; deadline outcomes specify whether work completed before or
after the observation. Torn/partial physical writes remain excluded, but “timeout” cannot leave
the simulator's logical state ambiguous.

The injection boundary matters. A malformed `ToolCall.arguments` string or inconsistent
`StepResult` can be delivered through the typed provider boundary and exercises session validation.
A malformed raw HTTP/SSE payload exercises a provider adapter parser, not the session, unless that
adapter is explicitly inside the selected simulation profile. The fault catalogue must not claim
wire-parser coverage from a typed post-parse result.

Timeout is not a freely selected error label for purposes of pillar 5. The deterministic world
derives it from the generated completion time and the production request's deadline. An explicitly
scripted `Timeout` that would occur regardless of clock advancement counts as logical fault
injection, but not as virtual-time evidence.

Directly forcing `StepDecision`, editing ledger state, or bypassing validation is rejected as fault
injection: it would test a second test-only transition system.

The catalogue can grow without a new ADR when additions preserve this boundary. Adding physical
faults or changing the system’s durability contract requires revisiting the project scope.

### D4. One monotonic virtual clock controls all time-bearing behavior

The deterministic world owns a monotonic clock. Session code and conformant extensions read it
through the authoritative boundary; they do not read ambient wall time when the value can affect
behavior or an asserted trace.

Deterministic discovery and replay run with the pinned AILANG runtime's `--virtual-time` enabled.
The world's `AdvanceClock(delta)` uses the corresponding `std/clock.sleep(delta)` through its clock
adapter, so residual core `std/clock.now` calls observe the same virtual clock during migration.
The explicit `world_state` value remains authoritative: setup records the runtime's fixed virtual
epoch, every advance updates the explicit value and runtime clock by the same checked delta, and a
conformance assertion compares them. Each deterministic run uses a fresh evaluator/process (or a
checked runtime reset primitive) so one seed cannot inherit another seed's virtual time. Those
residual direct reads must still be routed or classified before profile conformance: runtime
virtualization makes them deterministic but does not record why they were read. External shell,
MCP, or OS-process timeout mechanisms remain real-time operations and are never invoked as the
clock oracle in a deterministic run.

`AdvanceClock(delta)` and timed outcomes must reject negative or overflowing movement. A program may
hold time still or advance it by an explicit duration. When a world request carries a deadline, the
deterministic adapter compares the generated completion time with that deadline and returns the same
typed completion/timeout result that the live adapter exposes. Production retry, timeout, and
deadline derivation remains production code. Completion-versus-deadline resolution is a shared pure
helper or an explicit conformance-tested adapter contract, not duplicated ad hoc in the generator.

Clock normalization remains appropriate for nondeterministic display-only fields. It does not
satisfy this decision. Before adopting the DST name, at least one generated trajectory pair must
hold the request and underlying completion result constant while changing only latency/clock
advancement, and demonstrate the expected different observed completion-versus-timeout (or
equivalent deadline/retry) behavior. Both programs must replay deterministically.

If no production behavior observes time, merely carrying unused clock interactions does not meet
the gate. At HEAD, the core retry loop is count/budget based and session `now()` calls primarily
derive ids and durations; several tool/process adapters enforce real external timeouts. The first
time-bearing seam should therefore be a typed tool or delegated-process request whose existing
timeout becomes an explicit live/deterministic adapter contract. The project must not invent a new
agent retry policy merely to make the clock observable.

### D5. Execution uses the real traced driver and a named conformant profile

The runner executes an `ExecutionProgram` through `Session.run_v2_session_traced` or a successor
that retains the same production driver, threads D1 world state, and returns a complete trace. The
ordinary `run_v2_from_messages` message-only result is not the DST oracle.

Every run names its **simulation profile** and records an **execution manifest**. The stable,
versioned profile defines the extension hooks, adapter/parser boundaries, resource models, and
effect policy included in the system under test. The per-run manifest pins the core revision,
toolchain, and exact extension/package/ABI versions that realized that profile. “Motoko DST” means
the core under the named profile and recorded manifest; it does not imply that every installable
production extension is hermetic or covered.

A versioned profile definition records:

- profile id/version;
- included extension ids and per-hook classifications (effect-free, world-mediated, or explicitly
  excluded);
- included and excluded provider/tool adapter and parser boundaries;
- logical resource models promised by the profile;
- permitted diagnostic projections; and
- forbidden ambient effects/capabilities during execution.

Changing any of those semantic scope fields requires a profile-version change. The execution
manifest separately records source revision, toolchain, extension package versions, ABI version,
profile id/version, and normalized profile configuration. Source or package updates therefore
remain exactly reproducible without pretending that every build creates a new semantic profile;
if an update changes the profile's coverage or effect classification, the profile version must
also change.

An extension may appear as covered in a conformant profile only when every hook reachable within
that profile is either:

1. deterministic and effect-free for its explicit inputs; or
2. effectful only through D1 world-mediated ports, with origin tagged by extension id and explicit
   world state returned to the host.

An explicitly excluded hook is not covered, must be named in the result, and causes a fail-closed
`HarnessFailure` if dispatch reaches it. Thus a run cannot gain coverage credit merely because its
seed happened not to exercise a direct-effect hook.

Direct `AI`, `Process`, `Net`, `FS`, `SharedMem`, `Clock`, environment, or random effects from a
reached hook fail the profile's hermeticity probe. Bounded `IO`/`Trace` projection may remain only
when it cannot feed back into the decision and is not the oracle. Current effectful extensions that
bypass `ExtCtx.ports` are excluded until migrated; pure guards and deterministic fixture hooks may
form the initial profile. Changing an effectful extension to use state-threaded world ports may
require an `motoko-ext-abi` major and its existing lockstep rollout.

An effectful hook cannot retain the current “callback returns only a decision” shape while hiding
world mutation behind `ExtCtx.ports`. A conformant ABI must pass an explicit/opaque world token into
the hook's effect adapter and return the successor token with the hook decision, or provide an
equivalent host-owned linear state protocol. The implementation plan may choose the representation,
but hidden mutable port state is prohibited by D1.

The simulation boundary begins after the runner has decoded and validated its synthetic
configuration and constructed the named runtime/profile. Host configuration discovery, package
hydration, and TypeScript child-process setup remain in the existing harness-boundary tests. No
live secrets or inherited host environment values enter the deterministic world.

Capability flags are necessary but not sufficient because broad `IO` can permit both reporting and
`readLine`, and broad effect rows do not prove which operation was performed. Each profile's
hermeticity gate therefore combines:

- the narrowest executable capabilities, with generation and reporting separated where practical;
- a source/ABI routing audit for direct ambient calls in every in-profile module;
- poison/negative probes for provider, tool, approval, environment, clock, random, and reached
  extension-effect bypasses; and
- profile-definition validation and runtime routing that fail closed when an unclassified
  extension, hook, or adapter is loaded or reached.

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

The DST runner returns one of two disjoint result classes:

```text
SystemRun {
  outcome,
  ledger_trace,
  interaction_log,
  replay_metadata
}

HarnessFailure {
  kind,
  interaction_position,
  actual_request_projection,
  partial_ledger_trace,
  replay_metadata
}
```

The exact representation may reuse existing types, but the contract is:

1. Every `SystemRun`, whether successful or failed, has exactly one canonical `RunSummary` record in
   `ledger_trace`; it is the final record for the established run.
2. A typed internal termination reason maps exhaustively to the wire `finish_reason`. Success,
   budget exhaustion, maximum steps, compaction exhaustion, provider failure, unrecovered tool
   failure, invalid history, and internal driver failure are distinguishable. The implementation
   must derive this list from reachable terminal returns rather than preserve the current
   integer-code helper or stale labels.
3. `DoneEvent` may remain a success event, but it is not a second terminal record. Returned outcome,
   `DoneEvent` when present, and `RunSummary` must agree.
4. Every logical `LedgerEvent` produced by the driver is appended to the returned trace by the same
   transition that projects it to IO/Trace. Display-only telemetry excluded from the ledger is
   classified separately. An external `ledger_emit` call is not evidence that the event is in
   `LedgerTrace`; the returned trace is authoritative.
5. Display-only fields such as duration and session id use virtual time or normalization and cannot
   change invariant results.
6. A program mismatch, invalid program, exhausted interaction stream, or forbidden effect is a
   `HarnessFailure`, not a production `RunSummary`. If it occurs after execution begins, the result
   contains the partial trace and actual request projection needed to diagnose it.
7. Setup failure before the deterministic world and profile are established is also a typed
   `HarnessFailure`; it must not appear as a successful empty trace.
8. Captured console output is diagnostic only.

The implementation should centralize “append to returned trace + emit projection” so new
invariant-bearing events cannot silently update one channel without the other.

### D7. Invariants are evaluated over the whole execution

The runner applies reusable invariants to the returned outcome and complete trace. At minimum, the
name-adoption gate requires:

- exactly one final `RunSummary` for every `SystemRun`, and none synthesized for a harness failure;
- parity between all logical ledger emissions and returned trace records;
- legal phase/state transitions;
- valid tool-call/tool-result pairing, including denial and failure paths;
- monotonically valid budget/cost accounting;
- bounded retry and progress behavior under the modeled fault catalogue;
- checkpoint/compaction history invariants already owned by the framework;
- agreement between returned outcome and terminal summary;
- strict-replay request equality, safe regression-replay compatibility, and complete interaction
  consumption;
- valid logical-world transitions, including declared commit/no-commit behavior under faults;
- monotonic virtual time and deadline derivation; and
- zero discovery-generator failures, matcher mismatches, forbidden effects, and ambient RNG reads.

The discovery contract is itself an invariant: under the same execution manifest/profile,
`(schema_version, generator_id, generator_version, seed, initial_world)` run twice must produce the
same resolved program, interaction log, outcome, and normalized trace.

Example-based assertions remain useful, but a generated run that checks only its final prose or a
golden snapshot is not the new DST axis.

Liveness claims must be bounded and operational—for example, “terminates or reaches a named retry
bound within N decisions”—rather than relying on an unbounded test run.

### D8. Replay records the program, not just the seed

Every generated failure reports and preserves:

- execution-program schema version;
- stable generator id/family;
- generator version;
- seed;
- the exact serialized program;
- source revision and AILANG/toolchain version;
- the named profile plus its exact execution manifest;
- the normalized run configuration and policy/model-registry inputs needed to interpret it;
- the first failed invariant;
- the terminal outcome; and
- the normalized trace or a stable location containing it.

Replay consumes the exact program and does not regenerate it. This keeps historical failures valid
when generator distributions, draw order, or ranges change.

Programs use a deterministic, diffable encoding with an explicit compatibility policy. The
implementation plan may select the encoding and storage path, but CI output must provide a
copy-pasteable local replay command or artifact reference.

Any change to the PRNG algorithm, draw order, generator ranges, boundary strategy, or default
initial world that can remap a seed requires a generator-version change. A pinned generator canary
for each stable generator id must fail if such a remap occurs without that bump.

The reproducibility promise is precise:

- Repeating discovery under the recorded execution manifest/profile and seed must reproduce the same
  resolved program.
- Under the recorded execution manifest/profile, the exact program must reproduce the same normalized
  interaction log, terminal outcome, and trace.
- Under a newer revision, the program remains the same regression input, but a changed outcome or
  trace may be the intended evidence that a bug was fixed. Compatibility-aware regression mode may
  continue across recorded request-projection differences, but stops on unsafe causal mismatch.
  Replay does not promise identical output across code changes.
- A schema migration must either preserve old-program decoding or provide a pinned runner/artifact;
  silently reinterpreting an old program is forbidden.

Programs contain synthetic values only. Environment maps and interaction artifacts must reject or
redact secret-shaped/live credentials before persistence. Large exact payloads may live in a CI
artifact addressed by digest; a digest without retained bytes is not sufficient for replay.

Shrinking operates on programs, not only seeds, preserves request causality and schema validity, and
revalidates the failure after every reduction. It may land after the first name-adoption gate if the
project records that deferral explicitly, but replay of the unshrunk failing program is not
optional.

### D9. The simulator is sequential until the production contract changes

The deterministic world consumes one expected interaction at a time at production effect
boundaries and threads one explicit world state. It does not add a concurrent scheduler for the
current agent loop.

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
passes for a documented baseline profile and the project-007 definition/taxonomy ADR is accepted.
Every report names the profile; additional profiles earn coverage separately.

Existing historical target names are handled by the taxonomy ADR’s grandfathering decision; this
ADR does not broaden that exception.

### D11. Search is a first-class gate, not a collection of fixed seeds

The generated axis has two complementary corpora:

1. a blocking PR corpus containing fixed seeds and exact promoted regression programs; and
2. a scheduled rotating corpus whose seed window changes deterministically and is reported.

Every run reports generator id/version, attempted seeds, completed `SystemRun` count,
harness/generator failures, fault classes reached, terminal reasons reached, and elapsed budget. PR
and scheduled jobs each declare an operator-accepted minimum seed count; the gate asserts that
exact count completed. A zero, silently truncated, or below-minimum window fails. The fixed coverage
bank must collectively reach every required fault class; rotating search expands beyond it. A
scheduled failure retains its exact resolved program and is promoted to the fixed regression corpus
before or with the fix.

The implementation plan selects seed counts, rotation, retention, and sharding from measured CI
cost. Parallel workers run independent world states and programs; this is search parallelism, not
multi-actor simulation inside one run.

## Mapping to the project-007 conformance profile

| Project-007 pillar | Architectural evidence in this ADR |
|---|---|
| 1 Hermetic determinism | D1 explicit state; D5 named profile, capability/routing audits, and bypass probes |
| 2 Logical simulated environment | D1 modeled world/resource state; D3 typed outcomes and state transitions; D5 honest profile boundary |
| 3 Seed-driven trajectory | D2 reactive seeded discovery and resolved ordered program |
| 4 Logical fault injection | D3 fault catalogue mapped to production branches |
| 5 Controlled time | D4 virtual latency, deadlines, and shared timeout semantics |
| 6 Invariant oracle | D6 authoritative complete trace; D7 whole-execution invariants |
| 7 Search and reproduction | D8 strict replay/artifacts; D11 fixed and rotating search corpora |

## Acceptance test for the name

A reviewer can approve the generated axis as **Motoko single-actor, logical-fault DST** only when
all answers below are supported by an automated gate:

| Question | Required evidence |
|---|---|
| Does one seed generate an execution rather than only values? | At multiple real effect requests, the seeded world chooses responses/faults/latencies that influence subsequent production requests; discovery has zero unexpected harness failures and records the resolved interaction sequence. |
| Is there a modeled logical environment? | Provider, typed tool execution, approval, synthetic environment, runtime randomness if used, clock, and profile-declared logical resource state flow through one explicit state-threaded world with checked transition semantics. |
| Is the tested boundary honest? | The result names the execution manifest and profile; every profile-reachable hook is effect-free or world-mediated, excluded hooks and adapter/parser boundaries are listed, and dispatch to an exclusion fails closed. |
| Do injected faults reach production recovery code? | A bounded seed corpus generated by the real generator reaches and replays every required fault class and its mapped production branch. |
| Does virtual time matter? | Discovery/replay run under pinned runtime virtual time, and two replayable programs holding non-time inputs constant but changing generated latency/clock movement produce the expected completion-versus-timeout or equivalent deadline result without invoking an OS timeout. |
| Is production logic under test? | The runner calls the real traced session driver with threaded world state; no test transition loop computes state-machine decisions or history. |
| Is the oracle complete? | Every enumerated `SystemRun` terminal path returns exactly one final `RunSummary`; all logical ledger emissions appear in the returned trace and all D7 invariants pass. |
| Are harness failures separate? | Deliberate mismatch/forbidden-effect probes return typed `HarnessFailure` with partial evidence and no synthetic production summary. |
| Are discovery and replay stable? | Repeated discovery with the same seed produces the same resolved program; exact-program replay reproduces its interaction log and normalized trace under the recorded execution manifest/profile without invoking the generator. |
| Is hermeticity enforced? | Generate and execute phases run under declared capabilities; probes show ambient effect, host-env, clock, and RNG bypasses fail or are detected for the baseline profile. |
| Is there actual search? | PR and rotating scheduled corpora complete their declared minimum counts, the fixed bank reaches every required fault class, counters are reported, and exact counterexample programs are retained/promoted. |

Passing only the current seeded scalar families, replaying only a seed, normalizing timestamps, or
adding fault-shaped constructors without reaching recovery behavior fails this acceptance test.

## Alternatives considered

### Extend `ScriptedStep` with fault variants

Rejected as the complete architecture. `ScriptedStep` currently describes successful model results;
it does not control approval input, typed tool execution, time, terminal tracing, or explicit world
state. It may be migrated into the provider-outcome portion of `ExecutionProgram`, but cannot
represent the whole world by itself.

### Keep the current function-valued `Ports` shape and hide a mutable cursor behind it

Rejected. The callback record does not return next state. A cursor in `SharedMem`, a process global,
or a mutable closure would make replay depend on ambient call ordering and make concurrent test
processes unsafe. D1 requires state to be owned and threaded visibly by the driver.

### Treat all installed extensions as covered once core is ported

Rejected. Many current hooks perform direct effects outside `ExtCtx.ports`, and the ABI's
function-valued ports do not thread deterministic world state. D5 requires a named conformant
profile and honest exclusions; profile coverage expands only as extensions become effect-free or
world-mediated.

### Build a second simulation-only session loop

Rejected. A parallel loop would make deterministic tests precise about the wrong implementation
and allow production recovery behavior to drift.

### Inject state-machine decisions directly

Rejected. The simulator supplies external outcomes; production code owns decisions. Direct decision
injection bypasses the behavior the tests are intended to validate.

### Keep normalizing time instead of virtualizing it

Rejected for time-dependent behavior. Normalization makes traces comparable but cannot search
timeout, retry, deadline, or backoff trajectories.

### Script `Timeout` as an arbitrary outcome and call that virtual time

Rejected. It usefully tests recovery from a timeout, but it does not prove the clock influences
behavior. Pillar-5 evidence derives completion-versus-timeout from generated latency and the
production request deadline.

### Require a concurrent event scheduler now

Rejected. No ledger-affecting interleaving was found in the current loop, tool dispatch, MCP
subprocess, streaming, or compose-subagent paths. A sequential interaction program is the smallest
faithful model. D9 records the conditions that invalidate this choice.

### Store only seed plus generator version

Rejected. A generator version identifies code but does not preserve a failure if that code becomes
unavailable or its dependencies change. The exact program is the durable replay unit, stored inline
or as a retained artifact.

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
- Coverage claims name their extension and adapter/parser profile instead of implying the entire
  installable ecosystem is hermetic.
- The architecture remains proportional to a sequential agent loop; it does not import a
  distributed-systems scheduler without a concurrency contract.

Costs and risks:

- Threading world state touches session recursion, provider dispatch, tool/approval phases, and
  traced entry points.
- Complete returned streaming traces depend on an upstream recorded-stream API that neither pinned
  AILANG v0.26.0 nor latest-checked v0.30.0 provides; this external prerequisite blocks production
  migration.
- The typed tool/deadline boundary replaces the current stringly `Ports.tool_exec` seam.
- Effectful extension coverage may require an extension-ABI major and lockstep package rollout;
  until then those extensions remain outside the baseline profile.
- The trace contract changes error handling and may expose terminal cases currently visible only in
  logs.
- A typed program schema, request matchers, interaction log, and compatibility policy become
  maintained test infrastructure.
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

The checked spike in `spike/` is complete and negative against pinned AILANG v0.26.0, and its two
load-bearing negative compiler results reproduce on latest-checked AILANG v0.30.0. Before
acceptance, the upstream recorded-stream API selected by D1 must land, the toolchain must be
repinned to a version containing it, and the direct positive integration probe must pass. This
prerequisite may change the AILANG dependency and spike artifacts, but it must not begin the Motoko
production migration or silently select the forbidden delayed-projection fallback.

After that upstream gate passes and this ADR and the project-007 taxonomy ADR are accepted, a fresh
session should survey every effect call site and write the implementation plan. It must re-verify:

- the direct positive D1 streaming-capture evidence and the recorded-stream API's ABI/runtime
  impact;
- every construction and consumer of `Ports` and `StepProvider`;
- the feasibility and ABI impact of explicitly threading world state through `C2LoopState`,
  provider dispatch, tool phases, approval resumption, and traced results;
- all direct `readLine`, `std/clock`, environment, process, filesystem, network, stream, and random
  effects reachable during a session;
- the typed request/result and timeout contracts for native, delegated, MCP, and extension tools;
- every hook reachable in the proposed baseline profile, whether it uses `ExtCtx.ports`, and every
  direct effect that would exclude it or require an ABI migration;
- every return from the traced session driver;
- the ledger event vocabulary, terminal-summary consumers, and all sites where `ledger_emit` is not
  paired with `ledger_append`;
- current seeded-family and CI behavior; and
- all exhaustive matches affected by world requests, typed termination reasons, programs, and
  outcome types.

The plan must preserve user changes and current behavior while migrating one effect class at a time.
No implementation target should adopt “DST” or “simulation” merely because this ADR exists.

## Latest AILANG upstream recheck

Date: 2026-07-24

The repository-configured MCP endpoint in `.mcp.json` was queried first. Its `ailang_versions` tool
reported v0.30.0 as latest. The MCP snapshot was not sufficient by itself: `stdlib_module` and
`stdlib_search` omitted `stepWithStream` even though the same version's guide still documented it,
the listed streaming design document could not be fetched, and the manual-install asset name
returned 404. Those inconsistencies were treated as MCP indexing/metadata defects, not evidence
that the API had been removed. The v0.30.0 source and example also describe the callback effect row
as “open,” but the exported `! {IO}` signature and the compiler's closed-row rejection of
`SharedMem` make that prose stale or incorrect; the executable contract is load-bearing here.

The MCP-selected version was therefore checked against AILANG's official v0.30.0 tag and released
compiler. The release archive's SHA-256 was verified as
`58561c11ca7be7710b3b4eca9ddfdf263f39bc4e36428969a1968175f10b84b6`; the compiler reports v0.30.0
at commit `e37b370d1d7a9c4e7136b319e38bec4d5f2bd9a0`. The authoritative result is:

- `std/ai.ail:330-337` has the same `stepWithStream` signature as pinned v0.26.0;
- the callback still returns `()` and has the closed `{IO}` effect row;
- the call still returns only `Result[StepResult, AIError]`;
- no recorded-stream API or returned chunk log exists in the v0.30.0 AILANG source;
- both project spike negative probes fail for their intended type/effect reason on v0.30.0; and
- AILANG's v0.30.0 IO-only streaming example checks and runs under `--ai-stub`.

Ruling: no ADR decision changes. The D1 acceptance blocker is current through AILANG v0.30.0.

## Author self-review record

Reviewer: Codex (`GPT-5`), 2026-07-24. This is an iterative author-side review, not the independent
review required before acceptance.

The review used five adversarial passes:

1. **Current-source feasibility.** Rejected the draft's assumption that the function-valued
   `Ports` record could consume one cross-effect program; replaced it with explicit driver-threaded
   world state and recorded the load-bearing source anchors.
2. **Simulation semantics.** Split reactive seeded discovery from resolved-program replay, added
   ordinal causal request identity, strict versus regression replay, logical resource state, and
   explicit fault state transitions.
3. **Clock and trace attack.** Required timeout to derive from generated completion time plus a real
   production deadline; verified and incorporated AILANG v0.26.0 runtime virtual time; exposed the
   callback/immutable-trace substrate gap; ran the checked capture spike, which proved an upstream
   recorded-stream API is required; and made the returned ledger complete with one final canonical
   `RunSummary`.
4. **Boundary and prior-decision consistency.** Added fail-closed versioned extension profiles,
   separated their semantic definitions from per-run execution manifests, prohibited hidden
   mutable port state, and explicitly amended the phase-core port/raw-effect decisions while
   preserving its functional-core and policy boundaries.
5. **Enforceability and search.** Added capability-plus-routing hermeticity checks, deliberate
   harness-failure probes, generator bounds/version canary, profile evidence, required fault
   reachability, fixed/rotating corpora, and counterexample promotion.

No further decision-level defect was found after those revisions. The ADR intentionally remains
Proposed until the upstream D1 recorded-stream API lands and the direct positive spike passes.
Other residual implementation risks are explicit rather than hidden: AILANG ergonomics may affect
the concrete state-token representation; an effectful-extension profile may require an ABI major;
and the first baseline profile and measured CI seed counts still require operator approval in the
fresh implementation plan. A fresh independent review must attack the revised decisions before
this ADR becomes Accepted.
