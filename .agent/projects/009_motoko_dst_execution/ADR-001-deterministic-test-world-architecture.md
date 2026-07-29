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
  **Satisfied 2026-07-26** — 007 is Accepted. This ADR's remaining acceptance blockers are its own:
  the upstream recorded-stream API and an independent review.

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
  It additionally **replaces 004's stream-delta ledger-append handle** — the mechanism by which a
  streaming callback was to append deltas to the ledger as they arrived. That resolution is not
  merely superseded, it is unbuildable: the provider callback returns unit and its effect row is
  closed, so it cannot append, accumulate, or tee, which is the finding the spike in `spike/`
  established and the reason for the upstream request. D1's returned ordered emission log replaces
  it — the driver appends the log after the call returns, in arrival order, before the final
  response transition. **004's Phase-B byte-parity test for the
  `thinking_stream_start → N×delta → thinking_stream_end` sequence is retained and relocated to
  that returned-log path.** The ordering and payload it protects is a live TUI contract, not an
  internal detail, and moving where deltas come from must not change what the TUI receives.

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
  deadline, retry, or timeout. The pinned toolchain supplies no virtual clock to fall back on:
  `--virtual-time` prints a status banner, after which `std/clock.now` still returns real wall-clock
  epoch and `std/clock.sleep` still blocks for real time. Session-wide time must therefore be
  modeled entirely in explicit world state (D4).
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
| The pinned AILANG runtime supplies **no** usable virtual clock, so time must be modeled explicitly | `ailang run --virtual-time --caps IO,Clock` on a `now/sleep/now` probe returns real epoch and blocks for real time (`delta=3001` for a 3000 ms sleep, `real 0m3.139s`); identical with `--seed`, with `AILANG_SEED`, and on the prototype toolchain. `std/clock.ail:1-5,20-22` documents virtual advancement, which the implementation does not provide — the docstring is stale, not the contract |
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
unsafe. The clock is no exception and gets no exemption: per D4 the explicit value in `world_state`
is the only clock, and no runtime clock participates in a deterministic run.

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
  execution_manifest        -- or a named sidecar the validator requires
  interactions[]
}

Interaction =
    ExpectProvider(origin, request_matcher, timed_outcome)
  | ExpectTool(origin, request_matcher, deadline, timed_outcome)
  | ExpectApproval(request_matcher, deadline, timed_outcome)
  | ExpectExtensionEffect(origin, request_matcher, deadline, timed_outcome)
  | EnvironmentRead(key, value_or_missing)
  | RuntimeRandomDraw(bounds, value)
  | AdvanceClock(delta)
```

`ExpectExtensionEffect` closes what would otherwise be a hole: D1 puts conformant extension-side
external effects on the authoritative request surface, D3 requires the corresponding
provider/tool/process failure for an effectful hook, and D5 admits such hooks only through
world-mediated ports — but a program with no interaction for them could record neither the request
nor its outcome, so the class would be unreplayable. Its `origin` is the extension id, and its
class id is the same stable identifier D3's catalogue and D11's coverage counters use, so a
process-failure class cannot be counted as reached under one name and mapped under another. An
implementation may instead represent extension `proc_exec` as `ExpectTool`, but only by stating that
normatively and giving the conversion and identity rules; leaving the choice implicit is not
permitted.

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
  includes kind, origin, step, and model; extension-effect identity additionally includes kind,
  origin (the extension id), the effect class id, and call id where the effect has one; tool and
  approval identity additionally includes kind,
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

**That mapping is a versioned, machine-readable artifact that the gate reads — not prose in an
implementation plan.** One catalogue is the single source of truth, and for every class it carries:
a stable class id; the applicability condition, if the class is conditional; the production result
or error constructor it is delivered as; the **named recovery-branch id** it is intended to reach;
and its logical-state transition. A decorative fault variant that cannot influence the production
session does not satisfy this decision, and "cannot influence" must be decidable by reading the
artifact rather than by inspecting the implementation.

Two of the required classes above are conditional — the approval deadline exists only where
production policy enables it, and the extension-effect class only where the selected profile
contains an effectful hook using that world request. A profile may therefore legitimately not
exercise them. **When it does not, the run report and the D5 profile definition must name each
waived class and the condition that waived it**, so a coverage claim is readable against D3's full
table rather than silently against its applicable subset. An unstated waiver is a coverage claim
this decision does not grant.

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
faults or changing the system's durability contract requires revisiting the project scope. That
exclusion is bound to accepted 007 D1.3 and carries its triggers verbatim rather than a looser
paraphrase: **reopen before adding a crash-recovery, fsync, WAL, resume-from-ledger, or
replicated-state correctness contract.** Any one of those five gives Motoko a physical durability
contract it does not have today, and the moment it has one, the physical-fault exclusion stops
being a scope decision and becomes an untested gap.

### D4. One monotonic virtual clock controls all time-bearing behavior

The deterministic world owns a monotonic clock. Session code and conformant extensions read it
through the authoritative boundary; they do not read ambient wall time when the value can affect
behavior or an asserted trace.

**The explicit clock value in `world_state` is the only clock.** No runtime clock participates in a
deterministic run: there is no runtime epoch to record, no mirrored advance, and no conformance
assertion comparing an explicit value against a runtime one. `AdvanceClock(delta)` and the latency
carried by a timed outcome update the explicit value and nothing else.

This is a correction, not a preference. An earlier revision of this decision required deterministic
runs under the pinned runtime's `--virtual-time`, with `AdvanceClock(delta)` driving
`std/clock.sleep(delta)` so that residual direct `std/clock.now` reads would observe the same
virtualized clock during migration. **That mechanism does not exist.** On pinned v0.26.0 the flag
prints a status banner and changes nothing observable:

```text
$ ailang run --virtual-time --caps IO,Clock --entry main vclock.ail
  ⏰ Virtual time enabled
t0=1785301954869 t1=1785301957870 delta=3001
real  0m3.139s
```

`now()` returns real wall-clock epoch, a 3000 ms `sleep` blocks for ~3000 ms of real time, and the
delta varies run to run. The same holds with `--seed`, with `AILANG_SEED`, and on the prototype
toolchain. The evidence previously cited for this row — that the flag parses and the run exits 0 —
established only that the flag is accepted.

The architecture does not depend on that mechanism being fixed upstream. It never needed a runtime
clock to be *correct*; the explicit value was always authoritative, and the runtime mirror existed
only as a migration convenience. Removing it costs the convenience and buys a simpler contract.

What it costs is specific and belongs in the implementation plan rather than being discovered
during it: **the clock seam must be routed completely before a profile can claim conformance, not
incrementally.** With no runtime virtualization there is no interval in which a residual direct
`std/clock.now` read is merely unrecorded-but-deterministic — such a read is nondeterministic, so it
is a hermeticity failure like any other unrouted ambient effect, and it is caught by the same D5
mechanisms rather than by a clock-specific one. Two detectors apply, and they are different in kind:
the **source and ABI routing audit** locates such reads precisely and is the one a profile depends
on; **withholding the `Clock` capability** from a deterministic run is a coarse fail-closed backstop
that stops the run rather than returning a typed result, so it is a build-and-profile-level gate,
not an in-execution one.

Because no real sleeping occurs, modeled time is free: a program that advances the clock past a
thirty-second deadline costs no wall-clock time, where the mirrored design would have blocked for
thirty real seconds. Determinism no longer trades against gate runtime.

External shell, MCP, and OS-process timeout mechanisms remain real-time operations and are never
invoked as the clock oracle in a deterministic run. Each deterministic run still uses a fresh
evaluator or process, now for ambient-state isolation generally rather than to prevent one seed
inheriting another's runtime virtual time.

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

These two requirements are distinct and must not be conflated during planning. *Which* seam
demonstrates that time matters is a choice, and a tool or delegated-process deadline is the cheapest
first one. *How much* of the clock must be routed is not a choice: complete routing of every
profile-reachable time read is a precondition of conformance, because there is no longer a
virtualization layer under which an unrouted read would still be deterministic. A profile may be
narrow, but within its declared scope the clock seam is all-or-nothing.

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
- permitted diagnostic projections;
- forbidden ambient effects/capabilities during execution; and
- every required D3 fault class the profile waives, each with the condition that waives it.

Changing any of those semantic scope fields requires a profile-version change. The execution
manifest separately records source revision, toolchain, extension package versions, ABI version,
profile id/version, event-vocabulary version (D6), and normalized profile configuration. Source or package updates therefore
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
4. Every logical `LedgerEvent` produced by the driver reaches the returned trace, and the obligation
   is **parity**, not a shared transition. Where the substrate permits it, append and project in one
   transition — that is the strongest form and the default. **Stream emissions are the named
   exception where it is not permitted**: the provider callback's closed effect row means projection
   happens during the call and the append happens after it returns, so a single shared transition is
   impossible by construction (D1). For that class the obligation is discharged by an explicitly
   checked invariant instead: the projected sequence and the returned emission log must match
   exactly in order and content, with no duplicate and no omission. Display-only telemetry excluded
   from the ledger is classified separately, by the event-vocabulary artifact below. An external
   `ledger_emit` call is not evidence that the event is in `LedgerTrace`; the returned trace is
   authoritative.
5. Display-only fields such as duration and session id use virtual time or normalization and cannot
   change invariant results.
6. A program mismatch, invalid program, exhausted interaction stream, or forbidden effect is a
   `HarnessFailure`, not a production `RunSummary`. If it occurs after execution begins, the result
   contains the partial trace and actual request projection needed to diagnose it. **This applies to
   violations the runner can observe** — a profile-routing or exclusion violation detected inside the
   runner, which can return a typed value because the driver is still running. It does **not** apply
   to a raw capability bypass: a denied ambient effect terminates evaluation, so no typed result and
   no partial trace can be returned. That case is an expected non-zero run, and the two must not be
   conflated in either the contract or the probes that test it. If both are ever required to return
   the same typed value, an effect-interposition mechanism that preserves the driver-owned partial
   trace must be named and proven on the pinned substrate first; none exists today.
7. Setup failure before the deterministic world and profile are established is also a typed
   `HarnessFailure`; it must not appear as a successful empty trace.
8. Captured console output is diagnostic only.

The implementation should centralize “append to returned trace + emit projection” so new
invariant-bearing events cannot silently update one channel without the other.

**The event vocabulary is a versioned artifact, and it is the fifth recorded axis.** Project 007,
now accepted, records the terminal trace and its wire projection as a maintained compatibility
surface alongside the program schema, generator version, profile version, and execution manifest.
This ADR carries that obligation here rather than leaving it delegated to decisions that do not
mention it. One artifact binds, for every `LedgerEvent` variant:

- the variant itself;
- its wire name;
- its payload schema;
- and its **classification as logical or display-only** — the distinction D6.4 and D7's parity
  invariant both depend on, and which exists nowhere today.

At HEAD the vocabulary has 34 variants whose wire names live in trailing source comments rather
than in a type, and whose consumer is a `switch` in a separate TypeScript process. That is a mapping
which can drift silently, and once the returned trace is the oracle it must not. The artifact is
validated at load and **fails closed on an unclassified variant**, so a new event cannot enter the
ledger without declaring which side of the logical/display-only line it falls on. The preferred form
derives the wire name from the type, making drift a compile error rather than a runtime surprise;
that also makes the inventory regenerable instead of hand-maintained. Its version is recorded in the
execution manifest (D5) and preserved in the failure record (D8), on the same footing as the other
four axes. A change to any variant, wire name, payload schema, or classification is a version
change, and the compatibility rule for old traces is the one D8 applies to old programs: preserve
decoding or pin a runner, never silently reinterpret.

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
- the event-vocabulary version under which the trace was written (D6), without which the trace's
  wire names and logical/display-only classifications cannot be interpreted later;
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
harness/generator failures, fault classes reached, **named recovery branches reached**, waived fault
classes with their waiving conditions, terminal reasons reached, and elapsed budget. Class-reached
and branch-reached are separate counters read from D3's catalogue artifact: reaching a fault class
is not evidence that the production branch it targets was executed, and only the second is the
coverage the acceptance test asks for. PR
and scheduled jobs each declare an operator-accepted minimum seed count; the gate asserts that
exact count completed. A zero, silently truncated, or below-minimum window fails. The fixed coverage
bank must collectively reach every required fault class that the profile does not waive, and each
waiver must be declared per D3; rotating search expands beyond it. A
scheduled failure retains its exact resolved program **together with the execution manifest it ran
under** and is promoted to the fixed regression corpus before or with the fix. The two travel as one
artifact. D8's reproducibility promise is conditioned on the recorded manifest and profile, so a
program promoted without one is not a reproduction unit — it is a program nobody can state the
meaning of. A corpus member whose manifest is stale or unresolvable is not silently reinterpreted:
strict replay fails closed, and regression replay may proceed only with the difference recorded.

The implementation plan selects seed counts, rotation, retention, and sharding from measured CI
cost. Parallel workers run independent world states and programs; this is search parallelism, not
multi-actor simulation inside one run.

## Mapping to the project-007 conformance profile

| Project-007 pillar | Architectural evidence in this ADR |
|---|---|
| 1 Hermetic determinism | D1 explicit state; D5 named profile, capability/routing audits, and bypass probes |
| 2 Logical simulated environment | D1 modeled world/resource state; D3 typed outcomes and state transitions; D5 honest profile boundary |
| 3 Seed-driven trajectory | D2 reactive seeded discovery and resolved ordered program |
| 4 Logical fault injection | D3 requires a versioned, checked class→production-branch map, and D11 reports branch-reached counters reading it |
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
| Do injected faults reach production recovery code? | A bounded seed corpus generated by the real generator reaches and replays every required fault class the profile does not waive, together with its mapped production branch, evidenced by D11's branch-reached counters read from D3's catalogue; every waived class is named with its waiving condition. |
| Does virtual time matter? | Every time-bearing read reachable in the profile is routed through the world clock — no residual direct `std/clock` read survives the routing audit — and two replayable programs holding non-time inputs constant but changing generated latency/clock movement produce the expected completion-versus-timeout or equivalent deadline result without invoking an OS timeout. |
| Is production logic under test? | The runner calls the real traced session driver with threaded world state; no test transition loop computes state-machine decisions or history. |
| Is the oracle complete? | Every enumerated `SystemRun` terminal path returns exactly one final `RunSummary`; all logical ledger emissions appear in the returned trace and all D7 invariants pass. |
| Are harness failures separate? | Deliberate mismatch and in-runner routing/exclusion probes return typed `HarnessFailure` with partial evidence and no synthetic production summary; raw capability-bypass poison probes fail the run non-zero, which is the expected and distinct outcome for that class. |
| Are discovery and replay stable? | Repeated discovery with the same seed produces the same resolved program; exact-program replay reproduces its interaction log and normalized trace under the recorded execution manifest/profile without invoking the generator. |
| Is hermeticity enforced? | Generate and execute phases run under declared capabilities; probes show ambient effect, host-env, clock, and RNG bypasses fail or are detected for the baseline profile. |
| Is there actual search? | PR and rotating scheduled corpora complete their declared minimum counts, the fixed bank reaches every required non-waived fault class, class-reached and branch-reached counters are reported, and exact counterexample programs are retained/promoted with their manifests. |

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

## Review Comments

_Reviewer: Claude Code (model: `claude-opus-5`), 2026-07-26. Independent review for acceptance._

_Revision used: HEAD `d894638375471ced85c3bc0477975489b08c041b` (branch
`arniwesth/mot-43-l1-seeded-families`). The ADR is grounded at `7b9b4a4c` and HEAD has moved five
commits, but `git diff --stat 7b9b4a4c..HEAD -- src packages scripts Makefile .github` is **empty** —
every commit since is `.agent/`, `design_docs/`, `bun.lock`, `package.json`. Every source anchor in
this ADR is therefore evaluable at HEAD without re-grounding, and 007's HEAD-verified single-actor
and physical-fault rulings carry forward unchanged. Toolchains exercised: pinned AILANG v0.26.0
(`3b52a24`, `~/.local/bin/ailang`) and the local prototype (`~/src/ailang/bin/ailang`, `dev`
`24120ade2-dirty`)._

---

### R1. D4's virtual clock does not exist on the pinned toolchain, and the Context row that grounds it proves only that a flag is accepted

**Defect:** `--virtual-time` is a status banner. On pinned v0.26.0, `std/clock.now()` returns real
wall-clock epoch and `std/clock.sleep(ms)` blocks for `ms` of *real* time with a run-to-run variable
delta, with or without the flag. Every mechanism in D4 that depends on the runtime clock —
the fixed virtual epoch, the checked-delta mirror, the conformance assertion comparing explicit and
runtime clocks, and the migration safety net that makes residual `std/clock.now` reads deterministic
— is unimplementable as written, on the pinned toolchain *and* on the prototype the D1 probes ran
against.

**Grounding:** Probe (`scratchpad/rowprobe/vclock.ail`): `t0 = now(); sleep(5000); t1 = now();
sleep(1000); t2 = now()`. All five activation paths on pinned v0.26.0:

```text
$ ailang run --virtual-time --caps IO,Clock --entry main vclock.ail
t0=1785077152822 t1=1785077157823 t2=1785077158824 d1=5001 d2=1001
$ ailang run --seed 42 --caps IO,Clock --entry main vclock.ail
t0=1785077158870 t1=1785077163871 t2=1785077164872 d1=5001 d2=1001
$ ailang run --virtual-time --seed 42 --caps IO,Clock --entry main vclock.ail
t0=1785077164923 t1=1785077169927 t2=1785077170928 d1=5004 d2=1001
$ AILANG_SEED=42 ailang run --caps IO,Clock --entry main vclock.ail
t0=1785077170997 t1=1785077176001 t2=1785077177002 d1=5004 d2=1001
$ ailang run --caps IO,Clock --entry main vclock.ail          # no flags, control
t0=1785077177057 t1=1785077182054 t2=1785077183055 d1=4997 d2=1001
```

`t0` is real epoch in every case; `d1` for a 5000 ms sleep ranges 4997–5004 across runs; wall-clock
elapsed is ~6.0 s (`time` reported `real 0m6.102s` under `--virtual-time`, `0m6.033s` without).
Identical on the prototype: `~/src/ailang/bin/ailang run --virtual-time … → t0=1785077068981 …
d1=5001`, `real 0m6.320s`.

Source explanation, offered as diagnosis rather than as the finding: `--virtual-time` and `--seed`
are printed and not otherwise threaded (`~/src/ailang/cmd/ailang/main_run_exec.go:184-189`); the
clock's deterministic branch gates on `ctx.Env.Seed != 0`
(`/tmp/ailang-v030-audit.7DwR3w/internal/effects/clock.go:47,96` — the v0.30.0 release tree), and
`EffEnv.Seed` is populated only from `AILANG_SEED` (`internal/effects/context.go:495-502`), which
also failed to activate it above. I did not diagnose why the env path fails; that is upstream's, not
this ADR's.

The affected ADR text: `ADR:90-91` ("AILANG v0.26.0 does provide runtime virtual time
(`--virtual-time`; `std/clock.sleep` advances it)"); `ADR:124` (the Context row); and D4 at
`ADR:401-411` in full. `ADR:124`'s cited command reproduces *exactly* — `ailang run --virtual-time
--caps IO --no-print scripts/smoke_ports_record.ail` prints `⏰ Virtual time enabled` and exits 0 —
which is the point: the evidence establishes that the flag parses, not that a clock is virtualized.
The stdlib docstring agrees with the ADR and contradicts the implementation
(`~/.local/share/ailang/std/clock.ail:1-5,20-22`: "advances virtual time in deterministic mode").
This is precisely the failure mode the ADR itself named for streaming — "the v0.30.0 source and
example also describe the callback effect row as 'open,' … the executable contract is load-bearing
here" (`ADR:862-864`) — applied to the callback and not to the clock.

Consequences beyond D4. (a) `AdvanceClock(delta)` mapped to `sleep(delta)` makes replay cost real
wall time proportional to modeled latency, which destroys D11's seed budget and, because the delta
is not exact, breaks D7's "monotonic virtual time" as a *deterministic* invariant. (b) The migration
sequencing changes materially: D4 currently leans on runtime virtualization so that un-routed reads
are merely unexplained ("runtime virtualization makes them deterministic but does not record why
they were read", `ADR:407-409`). They are not deterministic. Every residual `now()` —
`src/core/session.ail:788,839,1990,2089` — is a live nondeterminism source until routed, so complete
`std/clock` routing becomes a hard precondition of D5 conformance rather than an incremental
convenience. (c) Acceptance-test row 5 (`ADR:709`) opens with "Discovery/replay run under pinned
runtime virtual time", which no toolchain I tested can satisfy.

**Action:** Delete the runtime-clock mirror from D4 and rely solely on the explicit `world_state`
clock, which D4 already declares authoritative (`ADR:404-406`) and which needs no upstream support.
Concretely: drop the `--virtual-time` requirement, the fixed-epoch/checked-delta/conformance-assertion
paragraph, and the fresh-evaluator-per-seed clause; replace the migration allowance with a hard D5
requirement that no in-profile module may reach `std/clock` directly, enforced by the D5 routing
audit and a `Clock`-capability poison probe. Rewrite acceptance row 5's first clause to test the
explicit clock. Re-ground `ADR:90-91` and `ADR:124` on the executable result above. If the runtime
mirror is retained instead, record it as a **second** upstream blocker of equal standing to the
recorded-stream API and say so in the Status line — but the world-clock-only route is cheaper,
needs no upstream, and is what D1 already requires. The stdlib-docstring/implementation divergence is
independently worth an upstream report, alongside the compile-cache one.

### R2. The ADR amends 004 but leaves in force 004's normative stream-delta ledger-append handle, which this ADR's own spike proves unbuildable

**Defect:** 004 resolved the identical streaming/trace-ordering problem with a *normative* mechanism
— a driver-supplied ledger append handle used *during* the model call — and carried a Phase-B
byte-parity test for it. This ADR's `Amends:` clause preserves 004's "append-only ledger" and
"driver-owned effect execution" and replaces only "function-valued ports as the complete
deterministic-state mechanism" (`ADR:22-26`). It never names 004's append handle, which is not
merely superseded by D1 but *impossible* on any AILANG the spike tested. A future implementer
reading 004 builds the handle; reading this ADR, the emission log. Two live normative answers to one
question, one of which cannot compile.

**Grounding:** `../004_phase_core_refactor/ADR-001-phase-oriented-core.md:152-159`: "**Streaming
protocol** (review P1-R3/P2-R4): … Normative resolution: the driver hands the model phase a **ledger
append handle** (a port) scoped to stream-delta events only; deltas are appended through it in
arrival order while the call is in flight. The handle is driver-constructed, so single logical
authority holds… Phase B carries a byte-parity test for the `thinking_stream_start → N×delta →
thinking_stream_end` sequence." Such a handle must mutate shared state from inside `on_chunk`, whose
row is closed at `{IO}`. The spike settles `SharedMem`; I extended it to `Trace`, which the append
handle would also need:

```text
$ ailang check trace_cb.ail   # top-level func render(chunk) -> () ! {IO, Trace}
Error: … failed to unify parameter 4: failed to unify effect rows:
  incompatible closed rows: r1 has extra labels [], r2 has extra labels [Trace]
```

I also tested the obvious escape hatch — declaring the widened row on an intermediate function's
*parameter* rather than at the `stepWithStream` call site. It fails, and fails at the outer
application, because the inner call narrows the declared parameter row to `{IO}`:

```text
$ ailang check smuggle.ail
Error: … type unification failed at [function application at smuggle.ail:20:11]:
  … incompatible closed rows: r1 has extra labels [], r2 has extra labels [SharedMem]
```

(This also explains why `src/core/test/stub_step.ail:185` can declare `on_chunk: (StreamChunk) -> ()
! {IO, Trace}` and still typecheck — `ailang check src/core/test/stub_step.ail` → `✓ No errors
found!` — while no `{IO, Trace}` function can actually be passed to it. The annotation is inert.)

**Action:** Add 004 §3's stream-delta append-handle resolution to this ADR's explicit amendment list,
stating that D1's returned ordered emission log replaces it and why (the mechanism is unbuildable,
not merely superseded), and say what becomes of 004's Phase-B byte-parity test for the
`thinking_stream_start → N×delta → thinking_stream_end` sequence — the ordering it protects is a live
TUI contract and D1 must preserve it.

### R3. 007 delegates a fifth versioned surface — the ledger event vocabulary and its wire projection — to D5/D8/D11, and none of them carries it

**Defect:** Accepted 007 books the ledger/wire event vocabulary as a maintained compatibility
surface and assigns its "encoding, migration mechanism, and compatibility policy" to this ADR's D5,
D8, and D11. D5's manifest enumerates six recorded fields and the vocabulary is not among them; D8's
compatibility policy is scoped to *program* encoding; D11 is search policy. So an accepted ADR
promises something this ADR does not supply.

**Grounding:** `../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md:311-337` —
"*The ledger event vocabulary and its wire projection.* `LedgerEvent` already carries 34 variants
(`src/core/phase_vocab.ail:597-631`) … the mapping lives in a trailing comment … and the consumer is
a TypeScript `switch` in a separate process (`src/tui/src/index.ts:428`). D2's trace oracle makes
that mapping load-bearing in both directions … Versioning is therefore not one number but four
independent axes … **plus a wire vocabulary shared with the TUI** … The encoding, migration
mechanism, and compatibility policy belong to `../009_motoko_dst_execution/ADR-001-…` (D5, D8,
D11)." Against `ADR:457-461` (the manifest records "source revision, toolchain, extension package
versions, ABI version, profile id/version, and normalized profile configuration") and `ADR:612-614`
(D8's encoding/compatibility policy, scoped to programs).

Verified at HEAD: 34 variants, and all 34 wire names are trailing comments —
`sed -n '598,631p' src/core/phase_vocab.ail | grep -c '^  [=|]'` → `34`, and `| grep -c -- '--'` →
`34`. One variant maps to two wire names (`StreamDelta … -- [prod] thinking_delta |
reasoning_delta`, `phase_vocab.ail:631`). The one recorded guard is already broken: 004's documented
regeneration command, run at HEAD, returns nothing, because `agent_loop_v2.ail` is now a 123-line
compatibility facade —

```text
$ grep -o 'emit_event(session_id, "[a-z_]*"' src/core/agent_loop_v2.ail | wc -l
0
```

— so the "29 event types" inventory pinned in `src/core/phase_vocab.ail:467-470` and
`004/ADR-001:139-147` is both stale against 34 and unregenerable. D6.2 makes this worse before
better: it requires replacing today's `finish_reason_str(r: int)` helper
(`src/core/session.ail:817,835,857`) with a derived typed enumeration, which is exactly the
TUI-observable contract 007 flags.

**Action:** Either add the ledger event vocabulary and the typed termination-reason enumeration as a
fifth recorded axis — versioned in D5's profile/manifest and preserved in D8's failure record — or
state explicitly that this ADR declines 007's delegation and route it back with a named owner. Do
not leave it assigned to three decisions that do not mention it. If adopted, the cheapest form is
the one 007's Open Questions already suggest: derive the wire name from the type so drift is a
compile error, which would also repair the unregenerable inventory.

### R4. D6.4 is unsatisfiable for the one event class this ADR spends most of its effort on, and D1 prescribes the mechanism that violates it

**Defect:** D6.4 requires every logical `LedgerEvent` to be appended to the returned trace *by the
same transition that projects it*. For stream chunks that is structurally impossible, and D1 says so
itself: projection happens inside the callback during the call, the append happens after the call
returns. A reviewer applying D6.4 mechanically must fail the streaming path.

**Grounding:** `ADR:548-551` — "Every logical `LedgerEvent` produced by the driver is appended to the
returned trace by the same transition that projects it to IO/Trace." Against `ADR:156-161` — "A live
adapter also projects each chunk to the UI at arrival; **after the call returns**, the driver appends
the adapter's identical emission log…". The callback cannot do both: its row rejects `Trace` (R2's
first probe) as well as `SharedMem`. `spike/README.md:184-188` records exactly this and rules it "a
note for the implementation plan, not a defect" — but the ADR body, which is the normative document
and the thing the gate is applied to, carries no exception. Acceptance row 7 (`ADR:711`) then asks
for "all logical ledger emissions appear in the returned trace", which parity *can* deliver;
D6.4's stronger same-transition clause cannot.

**Action:** Restate D6.4 as a *parity* obligation — same transition where the mechanism permits,
otherwise an explicitly checked parity invariant — and name stream deltas as the class where
projection and append are necessarily distinct transitions, citing the closed callback row. One
clause; it changes nothing architectural and removes a gate a conformant implementation would fail.

### R5. Acceptance row 4 demands evidence that D3 does not require to exist and D11 does not require to be reported

**Defect:** The fault row of the acceptance test asks for a corpus that reaches "every required fault
class **and its mapped production branch**", but D3 defers the class→branch mapping to the
implementation plan and requires no checkable artifact, and D11's mandated counters report fault
classes only. A reviewer cannot reach yes/no from the gate output; they must judge. That is 007 R8's
defect surviving inside this ADR's fix for it.

**Grounding:** `ADR:708` (row 4) versus `ADR:368-370` — "The **implementation plan** must map every
modeled class to a real production error or result type and name the recovery branch it is intended
to reach" — and `ADR:673-675`, which requires reporting "generator id/version, attempted seeds,
completed `SystemRun` count, harness/generator failures, **fault classes reached**, terminal reasons
reached, and elapsed budget". No branch-level coverage is required anywhere. The mapping table
compounds this by claiming delivery: `ADR:693` reads "4 Logical fault injection | D3 fault catalogue
**mapped to production branches**", which D3 does not do. This now propagates: accepted 007 D2 names
this ADR's D3 as the normative minimum catalogue (`007/ADR-001:190-192`), so the overclaim is
load-bearing outside this project.

**Action:** In D3, require the fault-class→production-branch map to be a machine-readable artifact
that the gate reads (007's Open Question "Fault-catalogue ownership" asks for exactly one source of
truth). In D11, add branch-reached counters alongside fault-class counters. Correct `ADR:693` to say
D3 *requires* the mapping rather than supplies it.

### R6. The promoted regression artifact is the program alone, but the reproducibility promise is conditioned on a manifest the program does not contain

**Defect:** D2 calls the serialized program "the authoritative reproduction artifact" and D11
promotes the program to the fixed corpus, while D8's reproducibility promise holds only "under the
recorded execution manifest/profile" — which is not a field of `ExecutionProgram`. A corpus member
therefore does not carry what its own strict-replay contract requires, and 007 makes the corpus's
oldest member the compatibility floor.

**Grounding:** `ADR:282-289` — `ExecutionProgram` fields are `schema_version, generator_id,
generator_version, seed, initial_world, interactions[]`; `initial_world` carries `extension_profile`
(`ADR:274-279`) but no manifest. `ADR:336-338` — "the serialized resolved program is the
authoritative reproduction artifact". `ADR:620-625` — "Under the recorded execution
manifest/profile, the exact program must reproduce the same normalized interaction log, terminal
outcome, and trace." `ADR:679-680` — "A scheduled failure retains its exact resolved program and is
promoted to the fixed regression corpus." D8's failure *report* does list the manifest
(`ADR:602-603`), but the promoted corpus artifact is specified as the program.

**Action:** Make the manifest travel with the promoted program as one artifact — either a field of
`ExecutionProgram` or a named sidecar the D2 structural validator requires — and state what a corpus
member whose manifest is stale or unresolvable means: strict replay fails closed, regression replay
may proceed with the difference recorded. `NOTE-ailang-world-overlap.md:105-116` already recommends
the stronger form (content-address program, trace, and manifest; retain bytes; fail explicitly on an
unavailable pinned artifact); adopting it here would close this.

### R7. D6.4's logical-versus-display-only classification is required but unlocated, so D7's parity invariant and acceptance row 7 are not decidable

**Defect:** D6.4 requires display-only telemetry to be "classified separately" but names no artifact,
owner, validation, or version for that classification — unlike the profile (D5 gives it a versioned
definition and fail-closed runtime validation) and the program (D2 gives it a structural validator).
D7's "parity between all logical ledger emissions and returned trace records" and acceptance row 7
both quantify over a set nothing defines.

**Grounding:** `ADR:548-551` (the classification requirement, one sentence, no home) and `ADR:552-553`
(only duration and session id are named as display-only). The set is not small at HEAD: `session.ail`
has 37 `ledger_emit` call sites against 14 `ledger_append` sites, and `tool_phase.ail`'s eight
emissions flow through `emit: (LedgerEvent) -> () ! {IO, Trace}` (`tool_phase.ail:311`), a
unit-returning callback that structurally cannot append, into a `ToolDispatchOutcome` that carries no
trace (`tool_phase.ail:148-150`). A concrete instance the Context row does not mention:
`ThinkingStreamEnd` is emitted at `src/core/session.ail:1770` and is absent from the trace expression
built at `:1778`, which appends only `start_event`, `prepared_event`, and `phase.events`.

**Action:** Give the classification the same treatment as the profile — a versioned artifact,
validated at load, fail-closed on an unclassified `LedgerEvent` — and fold it into R3's fifth axis so
one surface carries variant, wire name, and logical/display-only class together.

### R8. Two of D3's four required fault classes are conditional, and nothing requires a run to declare that it waived them

**Defect:** D3's approval row is conditioned on a deadline "enabled by the production policy" and its
extension row on the selected profile containing an effectful hook. Neither condition holds at HEAD
or in the baseline profile D5 sketches, so the normative minimum that accepted 007 defers to can
shrink to provider + tool without any report saying so.

**Grounding:** `ADR:365-366` (both conditions) against `ADR:477-479` — "Current effectful extensions
that bypass `ExtCtx.ports` are excluded until migrated; pure guards and deterministic fixture hooks
may form the initial profile" — and HEAD's approval path, which is a blocking `readLine()` with no
timer (`src/core/session.ail:1616`); `AllowAfterTimeout`/`DenyAfterTimeout`
(`src/core/tool_phase.ail:152-156`) are policy defaults with no deadline behind them. D11 requires
reporting classes *reached* (`ADR:673-675`); nothing requires reporting classes *waived*. Accepted
007 D2 pillar 4 points at D3 as "the normative minimum" (`007/ADR-001:190-192`), so a reader of 007
will over-read what a passing gate proves.

This is honest engineering, not a hole — D4 rightly refuses to invent a retry policy to make the
clock observable (`ADR:430-431`). The defect is silence, not scope.

**Action:** Require the run report and the D5 profile definition to name every required fault class
that the profile waives and the condition that waived it, so a coverage claim is readable against
D3's full table rather than against its applicable subset.

### R9. D3's physical-fault tripwire is weaker than the one accepted 007 D1.3 binds it to

**Defect:** 007 D1.3 names five concrete reopen triggers and says the tripwires "belong both in the
taxonomy ADR and beside the execution runner". This ADR carries the concurrency tripwire precisely
(D9) but reduces the physical-fault tripwire to a general clause naming no trigger.

**Grounding:** `007/ADR-001:175-178` — "**Reopen before adding a crash-recovery, fsync, WAL,
resume-from-ledger, or replicated-state correctness contract.**" Against `ADR:392-393` — "Adding
physical faults or changing the system's durability contract requires revisiting the project scope."
`NOTE-scope-and-sequence.md:92-93` does carry the named triggers, but that NOTE is "Proposed project
boundary", not the normative decision. By contrast D9 (`ADR:648-652`) matches 007 D1.1's four
triggers item for item, which is the standard to meet.

**Action:** Restate D3's physical-fault clause with 007 D1.3's five named triggers, so both
exclusions are equally hard to trip over.

---

## What is accurate

Re-executed or re-read at HEAD `d894638`, not assumed. The three rulings the handoff asked for come
first.

**Ruling 1 — D1's explicitly-threaded world state is threadable through the real driver. Confirmed.**
This is the keystone and it holds. `C2LoopState` is already an explicit record threaded through
`c2_loop`'s recursion and already carries both adapter state and the trace
(`src/core/session.ail:338-357,1509-1524`); adding a `world` field is the same move the record
already makes for `provider: StepProvider` and `trace: LedgerTrace`. Provider dispatch already
returns a successor — `dispatch_step(...) -> { result, next_provider }`
(`src/core/test/stub_step.ail:180-186`) — so `{ result, emissions, next_world }` is an extension of
an existing shape, not a new discipline; the D1 vertical slice models exactly that and compiled
first try. Approval sits directly in the driver branch that already builds the successor state
(`session.ail:1609-1617,1675`). The traced entry point constructs initial state in one place
(`:1989-1995`, `run_v2_session_traced` at `:1999`). There is one driver: `agent_loop_v2.ail` is a
123-line compatibility facade re-exporting `session` (`src/core/session.ail:17`), so no second loop
has to be threaded. The two genuinely hard seams are correctly identified by the ADR and no others
were found: `ToolDispatchOutcome` returns neither state nor trace and must gain both across four
signatures in `tool_phase.ail` and one call site (`session.ail:1658`); and `ExtensionHooks` returns
decisions with broad effect rows and no successor (`packages/motoko-ext-abi/types.ail:151-164`),
which is the ABI major D5 already books. The one seam that cannot be threaded at all is the chunk
callback — which is exactly the upstream ask. D1's "production code does not branch on test mode" is
reachable: the `StepProvider` match in `dispatch_step` is adapter dispatch on a value, which is the
analogy D1 itself draws (`ADR:236-238`).

**Ruling 2 — the single-actor boundary holds, and D9 is correctly scoped.** 007's D1.1 evidence was
verified at `a7932c6`; `src`, `packages`, `scripts`, `Makefile`, and `.github` are byte-identical
between that revision and HEAD, so the ruling carries without re-derivation. Spot-checked anyway:
tool entries recurse in list order (`tool_phase.ail:314-357`), native batches are sequential
(`run_native_batch_rec`, `tool_runtime.ail:151-165`), MCP is a blocking `exec("bash", …)`
(`packages/motoko-ext-mcp/exec.ail:63-70`, reached from `run_mcp_tool` at `:165-170`). D9's four
reopen triggers match 007 D1.1's four item for item, and `NOTE-ailang-world-overlap.md:196-199`
adds the right fourth-party trigger (a World scheduler introducing concurrent ledger-affecting
execution).

**Ruling 3 — the streaming disposition is correct, the gate is genuinely open, and the chunk-timestamp
conclusion survives independent re-derivation.** Re-derived rather than accepted: D2's stream offsets
are *generated* by the seeded generator during discovery and *read from the program* during replay
(`ADR:329-332`), and discovery runs against a deterministic world, not a live provider
(`ADR:261-264`) — so no path in this ADR requires observing a real chunk arrival time. The live
adapter needs arrival *order* only, which the proposed API supplies. D2's "non-decreasing virtual
offsets" clause is therefore reachable, the upstream ask is complete, and it should not acquire a
timestamp requirement. The negative results all reproduce at HEAD (after `rm -rf .ailang` — the
cache caveat is real):
`probe_state_returning_callback_rejected.ail` → `cannot unify type constructor () with *types.TList`;
`probe_sharedmem_callback_rejected.ail` → `incompatible closed rows: … extra labels [SharedMem]`;
`probe_real_stream_callback.ail` under `--caps AI,IO --ai-stub` → `PASS real_stream_callback stop`.
I extended the spike with two escape routes it did not test — a `{IO, Trace}` callback, and the
widened row declared on an intermediate *parameter* — and both fail (see R2), which strengthens the
disposition rather than weakening it. The gate is unambiguously **not** cleared: the prototype is
uncommitted working-tree modifications to `std/ai.ail` and three Go files on `dev`, and the committed
tree has none of it —

```text
$ cd ~/src/ailang && git show 24120ade2:std/ai.ail | grep -c stepWithStreamRecorded
0
$ git show 24120ade2:std/ai.ail | grep -n "^export func stepWithStream"
330:export func stepWithStream(
```

— so the blocker is current on `dev` as well as on v0.26.0 and v0.30.0. `spike/README.md:5-7,43-47`
states this correctly and cannot be read as claiming otherwise. Both new probes pass against the
prototype and are load-bearing: `run_world_slice.sh` → `world_slice: PASS — live and deterministic
paths agree on both outcomes`, including `program_non_empty (emissions=2)`, which is the assertion
that makes a vacuous pass impossible.

**Citation audit — all seventeen Context anchors verified, plus the v0.30.0 line cite.** Every row of
`ADR:109-127` resolves to the claimed construct at HEAD: `ports.ail:17-24` (six function-valued
fields, `tool_exec: (string, string) -> string`); `scripted_ports.ail:20-65` (`ScriptedPortsState`
at 20; `scripted_model_next`/`_approval_next`/`_clock_next` at 38/50/62, each returning `result +
next`); `stub_step.ail:34-41` (exact — the six-field success-only record); `session.ail:146-149`
(exact — `TracedSessionResult { result, trace }`); `:1610-1617` (`readLine()` at 1616);
`:1989-1995` (`now()` at 1990); `:1525-1557` (exact — `InvalidHistory` direct return at 1527-1528,
`emit_run_summary` at 1551 and `DoneEvent` at 1552 both absent from `trace_after_empty_floor`);
`:1609-1614` (pending-approval direct return); `tool_runtime.ail:151-165`; `tool_phase.ail:302-357`;
`packages/motoko-ext-mcp/exec.ail:63-70,165-176` and `:45-70,165-170`;
`stub_step.ail:175-204`; `ai_compat.ail:31-37,60-71,197-220` (`chunks: []` on both arms, docstring
"populating it would require an AILANG Ref"); `motoko-ext-abi/types.ail:62-66,151-164`;
`motoko_scratchpad/scratchpad.ail:90-101` (`on_tool_handle` performs `{Net}` directly, no
`ExtCtx.ports`); `recovery.ail:12-18` (`should_retry_stream_error`, no time dimension). The v0.30.0
cite is exact: `std/ai.ail:330-337` in the release tree is `export func stepWithStream(` through
`_ai_step_with_stream(...)`, with `on_chunk: (StreamChunk) -> () ! {IO}` at 335. The only anchor I
would call imprecise is `scripted_ports.ail:20-65`, which stops one line inside
`scripted_clock_next`; not worth a finding. `ADR:124` is the sole row whose *evidence* reproduces
while its *premise* fails (R1).

**Other claims confirmed by execution or reading.** `Ports.hooks_runtime` has no production consumer
— every occurrence is the declaration and builder (`ports.ail:23,38,46`), a test shape probe
(`stub_step.ail:144,154,167`), or a DST script (`scripts/dst/long_qwen_compaction_dst.ail:186,257`);
its disposition in `ADR:230-232` is a real architectural ruling (it cannot be the world-state
carrier) with only the housekeeping choice deferred, which I read as adequate. D4's HEAD claims hold:
the retry loop is count/budget based (`recovery.ail:17-18`), session `now()` calls derive ids and
durations (`session.ail:788,839,1990,2089`), and MCP/context-mode timeouts are real OS mechanisms
that cannot inherit a virtual clock (`exec.ail:45-61` builds `timeout "${secs}s"` into a bash
script). D6.2's premise is right: `finish_reason_str(r: int)` at `session.ail:817` with
`finish_code: int` at `:835` is the integer-code helper that must be replaced. The
mapping-to-007-pillars table (`ADR:686-696`) holds row by row except row 4 (R5). The rejection of
splitting this ADR (`ADR:775-780`) survives attack: D2/D8 share the program identity, D3/D4 share
deadline derivation, D5/D7 share what invariants may observe, and D1 is upstream of all of them —
the only decision with an independent contract is D11's CI budget policy, which is small enough that
extracting it would cost more than it clarifies.

## Recommended pre-acceptance actions

Ordered by dependency. Items 1–4 are this ADR's to fix before acceptance; 5–7 are body edits that can
land in the same pass; item 8 is not this ADR's to clear.

1. **Resolve R1 first — it changes D4, the acceptance test, and the migration order.** Decide between
   the world-clock-only route (recommended: no upstream dependency, and D1 already declares the
   explicit clock authoritative) and a second upstream blocker. Everything else in D4 and
   acceptance row 5 follows from that choice.
2. **R2 — complete the amendment of 004** before an implementer can act on either document, and
   dispose of 004's Phase-B byte-parity test explicitly.
3. **R3 — settle the wire-vocabulary axis** with accepted 007, since 007 cannot be edited to route it
   elsewhere without reopening an accepted decision. R7's classification folds into whatever surface
   this creates.
4. **R4 — restate D6.4 as parity.** One clause, and it unblocks a gate a correct implementation would
   otherwise fail.
5. **R5, R6, R8, R9** — four bounded edits to D3, D11, D2/D8, and the mapping table.
6. Re-ground `ADR:90-91` and `ADR:124` on executed results, and add the R1 probe to `spike/` so the
   clock claim is defended the same way the streaming claim is.
7. Update the Status line to reflect however many upstream prerequisites survive item 1.
8. **The recorded-stream API remains open and is not mine to clear.** It is unlanded on v0.26.0,
   v0.30.0, and committed `dev` `24120ade2`; the working prototype is uncommitted local changes. D1's
   condition is that the API *land* and the toolchain be *repinned* — a prototype does not satisfy
   it, and `spike/README.md` correctly refuses to claim otherwise.

Belonging to the implementation plan rather than to this ADR: the `ToolDispatchOutcome` and
`tool_phase` emit-callback rework (R7's grounding sizes it), the `motoko-ext-abi` major, the
`ledger_emit`/`ledger_append` pairing audit, and the concrete `DeterministicTestWorld`/`AilangWorld`
naming choice that `NOTE-ailang-world-overlap.md:180-193` defers.

## Accept / revise recommendation

**Revise, then accept.** The architecture is sound and D1 — the keystone — is genuinely threadable
through the real driver; nothing here calls for a redesign. But R1 removes a mechanism D4 is built on
and that the acceptance test requires, R2 leaves a contradictory normative answer live in an ADR this
one claims to amend, and R3 is an unmet obligation to a decision that is already Accepted. Those
three plus R4 should land in the body before acceptance; R5–R9 are bounded edits that can ride along.
The upstream recorded-stream API stays exactly where the ADR puts it — open, external, and blocking
production migration — and R1 should be resolved so it does not silently become a second one.

**Residual risk, recorded as the handoff anticipated.** The migration is under-estimated in a way the
ADR's own warning does not quite cover: R1 means the clock seam must be routed *completely* rather
than incrementally, which moves work from Track 2 into Track 1 and removes the safety net that made a
partial port safe. And the D9 staleness risk is real but well-guarded — the tripwire is stated in
three places and matches 007's wording, so the likelier silent invalidation is not a concurrency
feature but a new `LedgerEvent` variant landing with a wire name in a trailing comment and no
classification, which is precisely what R3 and R7 exist to prevent.

## Review Comments

_Reviewer: Codex (model: `GPT-5`), 2026-07-26. Independent review for acceptance._

_Revision used: HEAD `d894638375471ced85c3bc0477975489b08c041b` (branch
`arniwesth/mot-43-l1-seeded-families`). The ADR is grounded at `7b9b4a4c`; the exact command
`git diff --stat 7b9b4a4c..HEAD -- src packages scripts Makefile .github` produced no output, and
`git diff --name-only -- src packages scripts Makefile .github` also produced no output. Source is
therefore unchanged both since the ADR's grounding revision and in the worktree. Toolchains
executed: pinned AILANG v0.26.0 (`3b52a24d24431c372ed5605289ef039592209514`) and the local
prototype at `/home/motoko/src/ailang`, committed `dev`
`24120ade2ade3560af35e45fddd496fb1901c836` plus uncommitted changes._

### R1. D4 and its Context anchor rest on a false executable claim: `--virtual-time` does not virtualize `std/clock`

**Defect:** On every activation path tested, `std/clock.now()` returned a real epoch and
`std/clock.sleep()` consumed wall time, so D4's runtime mirror, residual-read safety net,
conformance assertion, and acceptance row 5 cannot be implemented as written.

**Grounding:** I checked a probe whose body is `t0 = now(); sleep(200); t1 = now(); sleep(100);
t2 = now()`:

```text
$ TIMEFORMAT='wall=%R'; time env -u AILANG_SEED ailang run --virtual-time --caps IO,Clock --entry main /tmp/motoko_adr_vclock.ail
t0=1785078295805 t1=1785078296006 t2=1785078296106 d1=201 d2=100
wall=0.406

$ time env -u AILANG_SEED ailang run --seed 42 --caps IO,Clock --entry main /tmp/motoko_adr_vclock.ail
t0=1785078296177 t1=1785078296378 t2=1785078296479 d1=201 d2=101
wall=0.373

$ time env -u AILANG_SEED ailang run --virtual-time --seed 42 --caps IO,Clock --entry main /tmp/motoko_adr_vclock.ail
t0=1785078296534 t1=1785078296735 t2=1785078296835 d1=201 d2=100
wall=0.351

$ time env AILANG_SEED=42 ailang run --caps IO,Clock --entry main /tmp/motoko_adr_vclock.ail
t0=1785078296882 t1=1785078297083 t2=1785078297184 d1=201 d2=101
wall=0.351
```

The local prototype behaves the same:

```text
$ /home/motoko/src/ailang/bin/ailang run --virtual-time --caps IO,Clock --entry main /tmp/motoko_adr_vclock.ail
t0=1785078302670 t1=1785078302871 t2=1785078302971 d1=201 d2=100
wall=0.642
```

The ADR's cited command itself reproduces:

```text
$ ailang run --virtual-time --caps IO --no-print scripts/smoke_ports_record.ail
⏰ Virtual time enabled
[fake] fake drive: t=1234567890 home=(unset)
[fake] emit-only path ok
[fake] scripted: 7, 11, -1
```

That proves only that the flag parses and prints a banner. The prototype source confirms the
disconnect: `/home/motoko/src/ailang/cmd/ailang/main_run_exec.go:184-189` only prints `seed` and
`virtualTime`; the clock implementation selects virtual behavior through `ctx.Env.Seed != 0`
(`/home/motoko/src/ailang/internal/effects/clock.go:46-53,95-104`), and the executed environment
path did not activate it. The load-bearing false claims are `ADR:89-91`, `ADR:124`, D4
`ADR:401-411`, and acceptance row 5 at `ADR:709`.

**Action:** Make the explicit `world_state` clock the only deterministic clock: delete the runtime
mirror, `--virtual-time`, fixed-runtime-epoch, checked-delta, reset, and residual-read-safety
requirements; require every in-profile `std/clock` read to be routed before conformance and enforce
that with the D5 audit plus a no-`Clock` execution capability. Rewrite acceptance row 5 to test the
explicit clock. If the runtime mirror is retained, name a working pinned runtime as a second
upstream blocker and prove it with this behavioral probe rather than the banner.

### R2. D5's capability poison and D6's typed forbidden-effect result have no compatible mechanism on the pinned runtime

**Defect:** A raw ambient-effect bypass denied by AILANG capabilities terminates evaluation instead
of returning a typed value, while D6 and acceptance row 8 require that same forbidden effect to
return `HarnessFailure` with the driver's partial immutable trace.

**Grounding:** D5 requires direct ambient effects to fail the hermeticity probe and combines
capabilities with bypass poison probes (`ADR:474-501`); D6 says a forbidden effect after execution
begins is a typed `HarnessFailure` containing `partial_ledger_trace` (`ADR:528-534,554-556`), and
acceptance row 8 requires deliberate forbidden-effect probes to return that value (`ADR:712`).
The spike already contains a direct capability poison:

```text
$ cd .agent/projects/009_motoko_dst_execution/spike
$ ailang run --caps IO --entry main_scoped stream_capture_probe.ail
Error: execution failed: effect 'SharedMem' requires capability, but none provided
Hint: Run with --caps SharedMem
$ echo $?
1
```

No AILANG `Result`, `HarnessFailure`, or returned partial trace crosses that process failure. An
outer wrapper cannot reconstruct the authoritative immutable trace from `ledger_emit`, because D6
correctly says the returned trace—not external projection—is authoritative (`ADR:548-551`).

**Action:** Separate two cases in D5/D6 and the gate: profile-routing/exclusion violations detected
inside the runner may return typed `HarnessFailure`; a raw capability-bypass poison may be an
expected non-zero evaluator failure but cannot promise a returned partial trace. If both must return
the same typed value, name and substrate-prove an effect-interposition/trapping mechanism that
preserves the driver-owned partial trace before acceptance.

### R3. D2 cannot record one of the external-effect classes D1, D3, and D5 require it to replay

**Defect:** `ExecutionProgram.Interaction` has no extension-effect or process interaction even
though conformant extension-side process effects are part of the authoritative world and required
fault surface.

**Grounding:** D1 includes “conformant extension-side external effects” in the request surface
(`ADR:205-213`); D3 requires the corresponding “provider/tool/process failure” for an effectful hook
(`ADR:366`); and D5 permits effectful hooks only through world-mediated ports (`ADR:463-468`).
But D2's exhaustive conceptual interaction list is only `ExpectProvider`, `ExpectTool`,
`ExpectApproval`, `EnvironmentRead`, `RuntimeRandomDraw`, and `AdvanceClock`
(`ADR:291-298`). The current ABI makes the missing case concrete:
`packages/motoko-ext-abi/types.ail:62-66` contains a distinct
`proc_exec: (string, string) -> string`; it is not a typed tool-call envelope.

**Action:** Add a typed `ExpectProcess`/`ExpectExtensionEffect` interaction with origin, causal
identity, bounded request projection, deadline/timing, typed result, and state transition; or state
normatively that extension `proc_exec` is represented by `ExpectTool` and give the conversion and
identity rules. Ensure D3 process failures and D11 coverage use the same stable class id.

### R4. The amendment of 004 leaves an impossible, contradictory streaming mechanism normative

**Defect:** 004 still requires the live chunk callback to append through a driver-issued ledger
handle while this ADR requires a returned emission log precisely because callback-side append
effects cannot fit the real API.

**Grounding:** `../004_phase_core_refactor/ADR-001-phase-oriented-core.md:152-159` calls the append
handle the “Normative resolution” and requires a Phase-B byte-parity test. This ADR's amendment
metadata (`ADR:22-26`) does not name or supersede that mechanism, while D1 appends only after the
provider call returns (`ADR:154-161`). A direct probe using a
`(StreamChunk) -> () ! {IO, Trace}` callback confirms the handle cannot be passed:

```text
$ ailang check /tmp/motoko_adr_trace_callback.ail
Error: ... failed to unify parameter 4: failed to unify effect rows:
  incompatible closed rows: r1 has extra labels [], r2 has extra labels [Trace]
```

The existing `SharedMem` negative probe independently fails for the same closed-row reason.

**Action:** Add 004's stream-delta append-handle resolution to the explicit amendment list and say
that D1's returned ordered emission log replaces it. Retain and relocate 004's
`thinking_stream_start → N×delta → thinking_stream_end` byte/order parity test to the returned-log
path.

### R5. The wire vocabulary delegated by accepted 007 is absent from D5, D8, and D11

**Defect:** Accepted 007 makes the ledger-to-TUI wire vocabulary a maintained compatibility surface
owned here, but this ADR versions neither its encoding nor its migration/compatibility policy.

**Grounding:** Accepted 007 records the `LedgerEvent`/wire mapping and TUI consumer at
`../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md:310-337`, then assigns its
encoding, migration mechanism, and compatibility policy to this ADR's D5/D8/D11. D5's manifest
fields (`ADR:456-461`) omit it, D8's compatibility policy is for execution programs
(`ADR:612-631`), and D11 contains search policy. At HEAD:

```text
$ sed -n '598,631p' src/core/phase_vocab.ail | rg -c '^  [=|]'
34
$ sed -n '598,631p' src/core/phase_vocab.ail | rg -c -- '--'
34
```

All 34 wire names live in comments, with `StreamDelta` mapping to two names
(`src/core/phase_vocab.ail:597-631`). The separate-process consumer is also not validating the
contract: `src/tui/src/runtime-process.ts:103-112` accepts any string-valued `type` and casts the
object to `AgentEvent`; its union at `:56-101` contains only a subset of ledger variants.

**Action:** Define a versioned event-vocabulary artifact that derives or validates
`LedgerEvent variant ↔ wire name ↔ payload schema ↔ TUI consumer`, record its version in the
profile/manifest and replay artifact, and give it an explicit compatibility/migration rule.

### R6. D6.4 contradicts D1 for stream chunks and would fail a conformant implementation

**Defect:** D6.4 requires projection and trace append to occur in the same transition, but D1
requires live projection during the callback and trace append after the provider call returns.

**Grounding:** Compare `ADR:548-551` with `ADR:154-161`. The direct `{IO, Trace}` callback probe in
R4 fails, so the two operations cannot share a callback transition. The world slice says the same
thing explicitly at `spike/README.md:183-188`: stream projection and append are necessarily
separate and must be checked by parity.

**Action:** Make D6.4 a parity obligation. Require one shared append+project transition where the
substrate permits it, but name stream emissions as the required exception and enforce exact
ordered/no-duplicate parity between the callback projection and returned emission log.

### R7. The fault-to-production-branch gate has no machine-readable map or branch evidence

**Defect:** Acceptance row 4 requires every fault class to reach its mapped production branch, but
D3 delegates the map to prose in an implementation plan and D11 reports only fault-class counters.

**Grounding:** D3 says the implementation plan must map classes and name branches
(`ADR:368-370`); D11 reports “fault classes reached” and terminal reasons, not recovery branches
(`ADR:674-680`); the mapping table nevertheless claims D3 already maps the catalogue
(`ADR:693`); and acceptance row 4 requires the missing evidence (`ADR:708`). The catalogue also uses
open labels such as “protocol-inconsistent typed result” and “corresponding ... process failure,”
so stable sub-class ids are necessary before “every required fault class” is enumerable. Accepted
007 now points to D3 as the normative minimum
(`../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md:189-191`).

**Action:** Require one versioned machine-readable fault catalogue containing stable class id,
applicability condition, production result/error constructor, named recovery-branch id, and
logical-state transition. Make D11 report both class-reached and branch-reached counters from that
artifact, and correct the mapping-table wording from “mapped” to “requires a checked map” until it
exists.

### R8. The promoted reproduction unit omits the manifest under which D8 promises reproduction

**Defect:** D2/D11 call the serialized program the authoritative promoted artifact, while strict
reproduction is conditioned on an execution manifest that is not part of that program.

**Grounding:** `ExecutionProgram` contains schema/generator/seed/initial-world/interactions but no
manifest (`ADR:282-289`); D2 calls that serialized program authoritative (`ADR:336-338`); D8
promises reproduction only under the recorded manifest/profile (`ADR:620-625`); and D11 promotes
the exact program to the fixed corpus (`ADR:679-680`). D8's failure report separately lists the
manifest (`ADR:595-607`), but nothing requires the promoted corpus member to retain or resolve that
sidecar.

**Action:** Define the reproduction artifact as an envelope containing the exact program and
normalized execution manifest, or require a content-addressed manifest sidecar in the program
validator. Specify fail-closed strict replay when the pinned manifest is unavailable and
compatibility-aware regression replay when a newer manifest is deliberately substituted.

### R9. The logical-versus-display-only event set has no owner, version, or fail-closed validator

**Defect:** D6/D7 quantify trace parity over “logical” events but never define the set, so a reviewer
cannot decide whether a missing returned record is a parity defect or permitted telemetry.

**Grounding:** D6.4 introduces the classification without a home (`ADR:548-553`), and D7 requires
parity over that undefined set (`ADR:569-581`). Current source demonstrates why inference is unsafe:

```text
$ rg -c 'ledger_emit\\(' src/core/session.ail
37
$ rg -c 'ledger_append\\(' src/core/session.ail
14
```

For example, `ThinkingStreamEnd` is emitted at `src/core/session.ail:1769-1770` but omitted from the
trace constructed at `:1778`; `ToolDispatchOutcome` carries neither events nor trace
(`src/core/tool_phase.ail:148-150`) while its callbacks emit unit (`:196,219,297,311`).

**Action:** Put logical/display-only classification in R5's versioned event-vocabulary artifact,
fail profile validation on every unclassified variant, and generate the D7 parity set from it.

### R10. Conditional D3 fault classes can disappear from a passing profile without a recorded waiver

**Defect:** Approval timeout and conformant-extension faults are called part of the minimum
catalogue but are conditional, and neither the profile nor D11 must report that they were waived.

**Grounding:** The approval timeout applies only where production policy enables a deadline, and
the extension class only where the selected profile includes an effectful hook (`ADR:365-366`).
HEAD approval blocks on `readLine()` with no deadline (`src/core/session.ail:1609-1617`), while
`AllowAfterTimeout`/`DenyAfterTimeout` are only policy-default variants
(`src/core/tool_phase.ail:152-156`); D5 allows the baseline to exclude current effectful hooks
(`ADR:474-479`). D11 reports reached classes only (`ADR:674-680`).

**Action:** Require each profile and run report to enumerate every D3 class as required,
inapplicable, or waived, with the exact applicability condition and evidence. The fixed-bank gate
must compare coverage against that declared set.

### R11. D3's physical-fault tripwire is weaker than binding 007 D1.3

**Defect:** This ADR replaces 007's named physical-contract reopen triggers with a generic
“physical faults or durability contract” clause, making the runner-side tripwire easier to miss.

**Grounding:** Accepted 007 requires reopening before “crash-recovery, fsync, WAL,
resume-from-ledger, or replicated-state correctness” is added
(`../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md:175-178`); D3 says only
that physical faults or a changed durability contract require revisiting scope (`ADR:392-393`).
The exact list exists in `NOTE-scope-and-sequence.md:92-96`, but that note is informational project
scope rather than this ADR's execution decision.

**Action:** Copy 007 D1.3's five named triggers into D3 and require the same tripwire beside the
execution runner, matching D9's precise concurrency treatment.

## What is accurate

The following rulings were re-executed or re-read at HEAD `d894638`; they are not inherited from
the author review or the earlier independent review.

**D1 threadability — confirmed.** `C2LoopState` is already one explicit value containing provider
state and `LedgerTrace` (`src/core/session.ail:338-357`) and is passed through `c2_loop`
(`:1509-1524`). `dispatch_step` already returns `result + next_provider`
(`src/core/test/stub_step.ail:180-204`). Approval suspension stores the request in the same state
and recurses (`session.ail:1661-1682`), then resumes inside the driver (`:1609-1634`). The traced
entry point constructs and returns that state in one place (`:1989-2015`). The exact sizing commands
returned 13 `next_state: C2LoopState` literals and 16 `c2_loop(` call sites; invasive is accurate,
but no control-flow rewrite is required merely to add and pass a world field.

The hard seams are real and already budgeted: `ToolDispatchOutcome` returns no successor world
(`src/core/tool_phase.ail:148-150,288-364`), and `ExtensionHooks` returns decisions without a world
token (`packages/motoko-ext-abi/types.ail:151-164`), requiring the D5 ABI change. A sum-valued adapter
dispatch can preserve common request/response and transition code just as `StepProvider` does now;
production policy need not branch on a test flag. The local vertical slice passed both outcomes:

```text
$ AILANG_SRC=/home/motoko/src/ailang AILANG_BIN=/home/motoko/src/ailang/bin/ailang ./run_world_slice.sh
mode=success       ... PASS program_non_empty (emissions=2) ... PASS trace_parity
mode=partial_error ... PASS program_non_empty (emissions=2) ... PASS trace_parity
world_slice: PASS — live and deterministic paths agree on both outcomes
```

That slice validates the API/world-request shape, not threading through the real Motoko driver; the
source audit above supplies the latter ruling. `Ports.hooks_runtime` also has a real disposition:
`rg -n 'hooks_runtime' --glob '*.ail' . --hidden -g '!.git/**' -g '!**/.ailang/**'` found only its
declaration/builders, a test-shape probe, and one DST script—no production read. Requiring a
demonstrated purpose or removal while forbidding it as a state carrier is adequate.

**Single-actor boundary — confirmed.** Tool entries recurse in list order
(`src/core/tool_phase.ail:314-357`), native batches recurse synchronously
(`src/core/tool_runtime.ail:151-165`), MCP execution blocks in `exec("bash", ...)`
(`packages/motoko-ext-mcp/exec.ail:63-70,165-176`), and delegated TUI calls are awaited in a
`for` loop (`src/tui/src/runtime-process.ts:618-642`). No ledger-mutating interleaving was found.
D9's four concurrency triggers match accepted 007 D1.1. Search workers with independent worlds do
not violate this boundary. The residual risk is correctly stated: a future parallel tool,
ledger-sharing subagent, background hook, or state-advancing stream handler invalidates the model.

The physical-fault exclusion also matches current source: the exact
`rg -ni --glob '*.ail' --glob '*.ts' '\\b(fsync|write[- ]ahead|wal|resume[-_ ]from[-_ ]ledger|replicated[-_ ]state)\\b' src packages`
command returned no hits, and restart emits `SessionSuspend` then exits without restoring history
(`src/core/session.ail:2209-2216`). R11 is about preserving the accepted tripwire, not current scope.

**Streaming disposition — confirmed.** On a clean copy of the spike:

```text
$ ailang check probe_state_returning_callback_rejected.ail
exit 1: cannot unify type constructor () with *types.TList
$ ailang check probe_sharedmem_callback_rejected.ail
exit 1: incompatible closed rows: ... extra labels [SharedMem]
$ ailang run --caps AI,IO --ai-stub --entry main probe_real_stream_callback.ail
LIVE content {"kind":"Wait"}
LIVE usage
PASS real_stream_callback stop
```

Both prototype probes pass, including partial-stream-then-error and non-empty program parity:

```text
$ AILANG_SRC=/home/motoko/src/ailang AILANG_BIN=/home/motoko/src/ailang/bin/ailang ./run_integration_probe.sh
integration_probe: PASS — all five D1 properties hold on both outcomes
$ AILANG_SRC=/home/motoko/src/ailang AILANG_BIN=/home/motoko/src/ailang/bin/ailang ./run_world_slice.sh
world_slice: PASS — live and deterministic paths agree on both outcomes
```

The prototype is not the gate:

```text
$ git -C /home/motoko/src/ailang rev-parse HEAD
24120ade2ade3560af35e45fddd496fb1901c836
$ git -C /home/motoko/src/ailang status --short
 M internal/builtins/ai.go
 M internal/builtins/ai_step.go
 M internal/effects/ai_step.go
 M std/ai.ail
?? internal/effects/ai_step_with_stream_recorded_test.go
?? probe_recorded_stream.ail
$ committed_count=$(git -C /home/motoko/src/ailang show HEAD:std/ai.ail | rg -c stepWithStreamRecorded || true)
$ printf 'committed_recorded_count=%s\n' "${committed_count:-0}"
committed_recorded_count=0
```

The committed `dev` signature remains the unit-returning closed `{IO}` API at
`std/ai.ail:330-337`; stock v0.26.0 makes both new probe scripts exit 1 with
`IMP010: symbol 'stepWithStreamRecorded' not exported by 'std/ai'`. The API has not landed and no
toolchain has been repinned, exactly as `spike/README.md:43-47` warns.

Chunk timestamps are not a missing upstream requirement. I executed an independent callback probe:

```text
$ ailang check /tmp/motoko_adr_clock_callback.ail
Error: ... incompatible closed rows: r1 has extra labels [], r2 has extra labels [Clock]
```

D2 discovery nevertheless generates the latency/offset as part of the deterministic provider
outcome (`ADR:260-264,325-332`); replay reads it from the program. A live provider is not D2
discovery and needs arrival order, not virtual timestamps. The “non-decreasing virtual offsets”
clause is reachable without observing wall-clock arrival, so the upstream ask is complete.

**Citation audit — all file anchors resolve, with R1 the one false premise.** Every Context-table
source range at `ADR:113-128` was opened at HEAD. The cited constructs are present: six
function-valued `Ports` fields and stringly tool seam; three separate scripted `result + next`
queues; the success-only `ScriptedStep`; `TracedSessionResult {result, trace}`; direct approval and
clock reads; missing returned summaries; serial tool/MCP/provider paths; empty live-wrapper chunks;
real adapter timeout contracts; broad extension effects and direct bypasses; and count/budget
provider retry. The supplied, previously executed v0.30.0 release result is consistent with the
committed `dev` signature I independently inspected. Only the runtime-clock premise fails despite
its cited banner command succeeding.

Other source-grounded D1-D11 claims also hold: the four direct `now()` sites are
`session.ail:788,839,1990,2089`; MCP/context-mode timeouts are real process mechanisms;
`finish_reason_str(int)` is the current terminal helper (`session.ail:817-867`); current
effectful hooks can bypass `ExtCtx.ports`; and no production consumer of `hooks_runtime` exists.

Accepted 007's four independent reproduction axes are all named here: program schema and generator
version in D2/D8, profile version in D5, and execution manifest in D5/D8. R8 is about binding them
into the promoted unit, and R5 is the separate wire-vocabulary obligation. The mapping table's
pillars 1, 3, and the core of 2/5/6/7 have corresponding decisions; pillar 4 overclaims a completed
branch map (R7), pillar 5's runtime mechanism is false (R1), and pillar 6's trace mechanism needs
R5/R6/R9.

**D5 hermeticity is largely buildable, with the R2 distinction required.** Narrow capabilities can
deny `AI`, `Process`, `Net`, `FS`, `SharedMem`, `Clock`, `Env`, and `Rand`; a complete source/ABI
routing audit handles broad `IO`; fail-closed profile validation can reject unclassified
hooks/adapters before dispatch; and runtime routing can return a typed exclusion failure. A raw
capability poison also proves that a bypass cannot silently succeed. What it cannot prove on this
runtime is D6's stronger claim that the capability failure itself returns the driver's typed
partial trace.

**Acceptance-test application at HEAD.** This exact command returned no hits:

```text
$ rg -n 'ExecutionProgram|DiscoveryConfig|HarnessFailure|SimulationProfile|execution_manifest|profile_version|generator_version|DeterministicWorld|LiveWorld|world_state' src packages scripts Makefile .github
```

All eleven rows therefore return **No** at HEAD, not “unknown”:

| Row | HEAD result | Future mechanical status |
|---|---|---|
| Seed generates execution | No | Decidable after D2 implementation |
| Modeled logical environment | No | Decidable after D1/D2, including R3 |
| Honest tested boundary | No | Decidable from the versioned D5 profile |
| Faults reach recovery | No | Not decidable until R7/R10 |
| Virtual time matters | No | Unsatisfiable as written; R1 |
| Production logic under test | No | Decidable by entrypoint/source evidence |
| Complete oracle | No | Not decidable until R5/R6/R9 |
| Harness failures separate | No | Forbidden-effect case needs R2 |
| Discovery/replay stable | No | Decidable after D2/D8 and R8 binding |
| Hermeticity enforced | No | Decidable after D5, with R2's two failure classes |
| Actual search | No | Decidable after D11, but coverage set needs R7/R10 |

Amendment fidelity otherwise holds. This ADR preserves 001's production-code, explicit-fake,
normalized-display-trace, stable-scenario, and invariant decisions while replacing its definition
and incomplete environment/replay architecture as accepted 007 permits. It preserves 004's pure
decision core, production phase transitions, extension-resident policy, and driver ownership; R4
is the unamended streaming exception, while R5 covers the now-load-bearing wire contract. The
rejection of splitting the ADR also survives: D1 is the common boundary; D2/D8 share replay
identity; D3/D4 share deadline semantics; D5/D7 share oracle visibility; and D11 gates the exact
fault/program artifacts those decisions define. D10 and parts of D11 are independently editable
policy, but extracting them would not remove an architectural ambiguity found here.

## Recommended pre-acceptance actions

This ADR must fix, in dependency order:

1. Resolve R1 first: select the explicit-world-only clock or add a second proven upstream blocker;
   then update Context, D4, D5 migration order, acceptance row 5, and Status consistently.
2. Resolve R2's forbidden-effect semantics so the hermeticity and `HarnessFailure` rows demand
   evidence the pinned substrate can return.
3. Complete the 004 amendment and reconcile D1/D6 streaming transitions (R4/R6), retaining the
   live byte/order/no-duplicate parity test.
4. Complete the program's request surface for extension-side process effects (R3).
5. Define and version the ledger/wire/classification surface delegated by 007 (R5/R9).
6. Make the normative fault catalogue and branch/waiver evidence machine-readable (R7/R10).
7. Bind program and manifest into one promoted reproduction artifact (R8).
8. Copy the binding physical-fault tripwires into D3 (R11), then update the status line to list the
   actual remaining blockers.

The fresh implementation plan, not this ADR, owns the concrete `WorldState` representation; edits
to the 13 `C2LoopState` successor literals and tool-phase return shapes; the extension-ABI major;
complete routing of all four current clock reads; centralized terminal finalization; the concrete
event-vocabulary codec and TUI changes; profile source-audit tooling and poison fixtures; branch
instrumentation; CI seed counts/rotation/retention; and either a demonstrated production purpose
for `Ports.hooks_runtime` or its removal. The migration remains feasible but should be estimated as
a cross-cutting redesign of effect routing and trace returns, not as a small diff.

The recorded-stream API remains an external pre-acceptance blocker: the local prototype proves the
proposed shape, but it has not landed on committed `dev`, no release contains it, and Motoko has not
repinned. Clearing that blocker belongs upstream and is not claimed by this review.

## Accept / revise recommendation

**Revise.** D1 is threadable and the streaming/sequential architecture is sound, but R1 makes D4 and one gate row false, R2/R5/R7 leave required evidence non-mechanical, and R3/R4/R6/R8–R11 require bounded architectural corrections; the unlanded recorded-stream API remains a separate external blocker that this review does not clear.
