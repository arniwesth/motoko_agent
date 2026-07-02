# ADR-001: A phase-oriented core designed for Deterministic Simulation Testing

Date: 2026-07-02
Status: Proposed (pending independent review — see `HANDOFF-review-adr.md`)
Pinned toolchain: AILANG **v0.26.0** (commit `3b52a24`); `ailang.lock` → `ailang_version: "v0.26.0"`

Relates to:
- `RESEARCH-phase-core-dst-design.md` (this project) — the evidence base and decision log
  (D1–D8); cited throughout as §N. This ADR is normative; the research doc holds elaboration.
- `sketch/` (this project) — checked/runnable vocabulary sketch + opacity probes; the substrate
  proofs for the type design (see `sketch/README.md`).
- `scripts/smoke_ports_record.ail` — substrate proof for the Ports mechanism.
- `../003_CSP_core_refactor/NOTE-why-not-csp-now.md` — the direction note this ADR executes;
  its rejections are incorporated here as non-goals.
- `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` — DST requirements this
  architecture satisfies by construction; resolves its review comments R4, R5, R7, R8, R11.

---

## TL;DR

**Decision:** replace `agent_loop_v2.ail` with a phase-oriented core built as a *functional
core with an imperative shell*: a **pure step machine** returning decisions-as-data, **phases**
that perform effects only through injected **ports** and return `PhaseResult` values, a
**single pure transcript builder** that is the only producer of provider-facing messages, and a
thin **driver** that owns the real effect row, executes decisions, and appends an **append-only
event ledger** that doubles as the DST trace.

DST is not a test suite added afterward; it is a property of this shape. Every design choice
below was validated against AILANG v0.26.0 with checked, runnable artifacts before being
committed here.

---

## Context

Two prior results set the direction:

1. The CSP research (`003_CSP_core_refactor`) concluded that on v0.26.0 a CSP-first core fights
   the substrate (blocking `std/ai`, incomplete process protocol, coarse cancellation) and that
   the core's expensive failures are not concurrency failures. Its direction note prescribes a
   phase-oriented core with strict transcript invariants. This ADR is that core's design.
2. DST ADR-001 requires: deterministic modeling of external contracts, production transition
   code driven by scripted fakes, boundary observations recorded as normalized traces, and
   reusable invariants over those traces — with no dependency on effect-handler mocking.

The current loop demonstrates why a rewrite (not a cleanup) is needed (§1 of the research doc):

- `loop_v2` carries the effect row `{AI, FS, Process, IO, Env, Net, SharedMem, Clock, Stream,
  Trace}` (`src/core/agent_loop_v2.ail:1125`); every test driving it must satisfy ten effects.
- ~30 scattered `emit_event`/`emit_run_summary`/`emit_stream_chunk` call sites make trace
  ordering unreproducible.
- The only DST seam (`StepProvider`, `src/core/test/stub_step.ail:42`) covers the model call
  alone; clock, env reads, tools, and hooks are live effects.
- Features store state steganographically in the transcript because threading new state through
  16 recursive call sites is prohibitive (persist-nudge marker scanning,
  `src/core/agent_loop_v2.ail:1062-1063`).
- Two live bug classes exist today because nothing structural prevents them: extension
  compactors receive system messages (`src/core/rpc.ail:231` builds the system message into the
  list; `agent_loop_v2.ail:1154` forwards the unfiltered list to `dispatch_pre_step`), and the
  shipped `motoko_ext_compaction_ai` v0.2.0 destroys the system prefix above its threshold and
  can sever tool_use/tool_result pairs (`compaction_ai.ail:101`, `:126-148`).

## Decision drivers

- Layer 0/1 DST tests must run with zero or minimal capabilities, no network, no registry
  hydration (DST ADR-001).
- Provider-transcript validity (tool-id correlation, system prefix, pairing) must be enforced
  structurally, not by convention — this is the 400/422 bug class.
- The event stream must be deterministic and replayable; production telemetry and DST traces
  must be one artifact, not two (resolves DST R8).
- Migration must be strangler-style: each phase leaves the system shippable.
- Every substrate assumption must be proven by a checked artifact before this ADR relies on it
  (lesson of the reverted CSP Phase 1).

---

## Decision detail

### 1. Pure step machine — decisions as data (D1)

`decide(StepState, StepPolicy) -> StepDecision` is a pure function. Decisions are values:

```text
StepDecision = CallModel(ProviderPayload) | RunTools(ToolPlan)
             | AwaitApproval(ApprovalRequest) | InjectUserMessage(Message)
             | TakeCheckpoint(CheckpointPlan) | Finalize(FinalizeInfo) | Fail(FailInfo)
```

The driver executes decisions and feeds results back as data. All loop policy — budget/cost
caps, stream-retry, persist-nudge, DP7 gating — becomes pure decision logic (Z3-eligible).
Layer 1 DST drives `decide` with scripted results and needs **zero effects**.

Proven: `sketch/sketch_vocabulary.ail` (checks, runs; `decide` composes with the sealed
projection pipeline).

### 2. Ports for every nondeterminism source (D2)

A port is a function passed as a value where code would otherwise name an effect operation
directly (definition and fencing: research doc §2 P3). The driver builds live adapters once at
session init; DST injects pure fakes; recorder-wrapped adapters emit ledger events per call.
Config/env reads happen once at session init and become `StepPolicy` data; clock values enter
`StepState` as fields.

Proven: `scripts/smoke_ports_record.ail` — records of effectful function fields; pure fakes
subsume (even unannotated); **capabilities are charged at effect performance, not row
declaration**, so fake-ported tests run under `--caps IO` alone (resolves DST R7). Parser
constraints recorded there (zero-arg anonymous `func()` does not parse; anonymous `func` cannot
sit directly in record literals — port implementations are named funcs or let-bound lambdas).

### 3. Ledger = trace, with single-point emission (D5)

Phases return `PhaseResult`:

```text
PhaseResult = { delta: StateDelta, transcript_append: [Message],
                events: [LedgerEvent], cost_delta_millicents: int }
```

Exactly one place (the driver) appends and emits events; exactly one function
(`apply_state_delta`) applies state changes. `LedgerEvent` is a typed variant; a
`to_schema_v1 : (LedgerEvent) -> Json` projection preserves the existing production wire
contract (28 event types, inventoried in `sketch/sketch_vocabulary.ail`) consumed by the TUI
and eval harnesses. ADR-001 canonical trace names map 1:1 to constructors. In-memory typed
events are what DST invariants consume; JSONL is the failure-report projection (resolves DST
R4; the recorder-vs-production tension of DST R8 dissolves because the ledger is always-on).

Normative deltas: `StateDelta` is a patch record (`Option` fields, absent = unchanged); the
delta is itself the observation DST records. `PhaseResult` has **no continuation field** — the
step machine re-derives the next decision from applied state.

### 4. Single transcript gate + sealed history types (D3, D7)

`transcript.ail`'s successor (the **vocabulary module**, working name
`src/core/phase_vocab.ail`) owns:

- **`History`** — sealed: a single-constructor variant whose constructor is *not exported*.
  Substrate proof (`sketch/README.md` Q1): unexported variant constructors are unimportable
  (`IMP010`); values still thread through consumers. Consequence (normative): records embedding
  `History` — `StepState` — are **co-located in the vocabulary module**, because unexported
  type names cannot be imported. Exported record types are structurally forgeable, so sealed
  types must be variants.
- **The compaction projection** (pure): `project(History, TokenTelemetry, CompactionPolicy) ->
  Result[{payload, events}, string]`, pipeline per research doc §7.2: pin head system prefix →
  `CompactableSegment` (sealed; cannot contain system messages) → normalize → extension
  compaction (validated output; invalid ⇒ rejected + ledger event + structural fallback) →
  structural tiers → emergency. `ProviderPayload` is sealed and is the **only** type
  `model_phase` accepts. Ephemerality is by construction: nothing can write a payload back into
  history.
- **The checkpoint seam** (D7): `checkpoint(History, CheckpointPlan) -> {history, event}` is
  the sole op producing a rebuilt `History`, returning it together with its audit event
  (digest-chained). Invariant: *History is rewritten only by `checkpoint`, and every rewrite
  has a matching ledger event.* v1 policy **never emits** `TakeCheckpoint` — enforced by
  scenario, not convention.
- **Transcript invariants**: no empty tool ids; exactly one result per call; ids preserved;
  tool_use/tool_result correlation (the Bedrock rule — currently a 20-line comment at
  `agent_loop_v2.ail:1316-1333`, here an enforced property); no live chunks in the transcript;
  system messages form a head prefix (checked at session entry, where
  `run_v2_from_messages`-style resumed histories arrive).

### 5. Module structure and residual-logic homes (D4)

| Module | Nature | DST layer |
|---|---|---|
| `phase_vocab.ail` (name TBD) | sealed types, StepState, LedgerEvent, projection, invariants | L0, Z3 candidates |
| `step_machine.ail` | pure `decide` + all loop policy | L0/L1, no effects |
| `model_phase.ail`, `tool_phase.ail`, `hook_phase.ail` | effectful via ports → `PhaseResult` | L1, scripted ports |
| `tool_stream_phase.ail` | contained `selectEvents` island | L1 + supplemental smokes |
| `session.ail` (driver) | real effect row; executes decisions; sole emitter | L3 (driver + scripted ports IS the L3 probe — resolves DST R11) |
| `recovery.ail`, `cost_phase.ail` | pure policy | L0 |

No successor file keeps `agent_loop_v2`'s squatters (mapping per research doc §5): persist-nudge
and cost/retry policy → step machine; hybrid-bash synthesis → response interpreter, with its
correlation patch → transcript invariants; scratchpad's hard-coded dispatch
(`agent_loop_v2.ail:868` region) → a tool-phase **executor registry**
(`Native | Delegated | HandledByExt | WsLoopback | StreamIsland`); the mid-dispatch approval
`readLine()` (`:769`) → `AwaitApproval` decision performed by the driver.

### 6. Extension ABI v3 and conformance kit (D6, D8)

- **ABI v3**: `ExtCtx` gains `ports: ExtPorts` (ai_step, http, proc_exec, kv, clock_now,
  env_get) and `artifacts: Json`; `Compacted` gains an artifacts field. **No effect-row
  changes** (`on_tool_policy`/`on_describe_tools`/`on_build_system_prompt` are already pure in
  ABI 2.2.0; narrowing the four max-row hooks buys nothing once ports exist — calling an
  effectful port still requires the effect in the row). Migration cost is constructor-only:
  hook signatures are unchanged, so packages that ignore ports recompile with zero code
  changes.
- **Conformance kit** (`motoko_ext_conformance`, separate package, lockstep majors with the
  ABI): `invariants` module (pure contract law — **imported by the core transcript gate**, one
  source of law) + `harness` module (test-only). Enforcement is behavioral
  **caps-as-conformance**: fake ports + minimal caps ⇒ raw effect calls fail at performance
  time; per-extension declared-caps allowances record residual raw-effect surface. The kit does
  not test cross-extension composition (fault-isolation rationale: research doc §6.1) — the
  obligations catalog is composition-closed, arbitration is core L1 territory
  (`src/core/ext/runtime.ail:143-164`).
- **Reference migration**: `compaction_ai` v0.3.0 — ports-native, artifact-cached, and the
  kit's acceptance test is that it **rejects v0.2.0's two live bugs for the right reasons**.

---

## Migration plan and gates

Strangler-style; each phase leaves the system shippable.

**Phase A — pure foundations, zero behavior change.**
Deliverables: vocabulary module (seeded from `sketch/sketch_vocabulary.ail`); exported
compaction constants (`OUTPUT_HEADROOM`, actual tiers 60/75/85, estimate tiers 70/85/95 —
DST ADR-001 R5); transcript builder extracted from `step_result_to_message` /
`envelope_to_tool_message` / `tool_result_message`.
Gate: `ailang check` + existing smokes green; no event-stream diff.

**Phase B — phases return `PhaseResult`; driver keeps current control flow.**
Deliverables: all event emission through the ledger + `to_schema_v1`; provider-call recording
seam (DST ADR-001's required first seam) as ledger events around the model phase; core-side
system-prefix fix (pass `CompactableSegment`, not the raw list, to `dispatch_pre_step` — zero
ABI cost, closes the live gap).
Gate: **all 28 production schema-v1 event types** emitted via projection only, byte-compatible
with current TUI/eval consumers; DST scenario `system_messages_hidden_from_compactors` goes
from unrepresentable-in-new-code to verified-in-wiring.

**Phase C — full inversion.**
Deliverables: pure `decide`; driver executes decisions; `run_v2_with_stub` superseded by
scripted ports; Layer 1 compaction scenario family live
(`actual_tokens_drive_next_step`, `emergency_exhaustion_estimate_gated`,
`provider_payload_vs_uncompacted_history_pressure`, `telemetry_reflects_payload_not_history`,
`ext_compaction_invalid_rejected`, `summary_cache_replay_stable`,
`history_rewrite_requires_checkpoint_event`, `checkpoint_never_emitted_in_v1`).
Gate: L1 scenarios pass under minimal caps with no network; every DST failure prints scenario
id, first failed invariant, and normalized trace.

**ABI v3 track (parallel to B/C):** ABI 3.0 + conformance kit 3.0 + `compaction_ai` 0.3.0;
gate: kit rejects v0.2.0, accepts v0.3.0; registry runs the kit for every package in
`registry_generated.ail`.

## Acceptance criteria

1. Phase A lands with zero behavior change (existing smokes + event-stream parity).
2. Phase B's 28-event projection gate passes; the provider-call recording seam emits
   `provider_call_prepared`/`provider_result` ledger events consumed by at least one L1 test.
3. The two `compaction_ai` v0.2.0 live bugs are demonstrated by failing conformance scenarios
   *before* the v0.3.0 fix and pass after (mirrors DST ADR-001's PR-#76-style criterion, but
   against bugs verified in this research).
4. Phase C: `decide` is pure (no effect row), and the compaction L1 family runs with
   `--caps IO` or less, no Ollama/OpenRouter/network.
5. No DST gate depends on effect-handler mocking or real providers.

## Consequences

Positive: provider 400/422 classes become type errors or gated rejections; deterministic,
replayable event stream; L0/L1 tests with near-zero caps; extension effects observable via
recorder-wrapped ports; state changes and event emission each have exactly one code path;
long-session ceiling has a designed, audited escape (checkpoint) instead of a silent death.

Negative / accepted costs: an ABI major bump (constructor-only for most packages); the
vocabulary module is large by necessity (opacity forces co-location — a real loss of module
granularity); `StateDelta` patch records add boilerplate per phase; the 28-event projection is
a wide compatibility surface that must be maintained until consumers migrate; full inversion
(Phase C) restructures control flow that currently works.

## Rejected alternatives

- **CSP-first core** — rejected in `NOTE-why-not-csp-now.md`; incorporated as a non-goal.
  Stream islands remain tactical (tool-phase executor), not architectural.
- **Host-runtime (TypeScript) kernel** — violates the project direction (move logic into
  AILANG).
- **Waiting for AILANG effect-handler mocking** — unshipped; ports are proven today.
- **Full-state returns instead of `StateDelta`** — loses the delta-as-observation property DST
  wants; rejected in the sketch (Q3).
- **`continuation` field in `PhaseResult`** — redundant with state-derived decisions; keeps
  control flow in two places instead of one.
- **Narrowing hook effect rows in ABI v3** — buys nothing once ports exist; three hooks are
  already pure in 2.2.0.
- **Conformance kit inside the ABI package** — drags test machinery into every extension's
  dependency closure; the ABI's own header mandates purity/lightness.
- **Ephemeral-only compaction with no checkpoint seam** — leaves long sessions a designed
  death; retrofitting the seam later means fighting the invariant suite built to prevent
  exactly that mutation (research doc §7.4).
- **Big-bang rewrite** — the strangler phases each ship; a big bang repeats the CSP Phase-1
  failure mode.

## Open questions (non-blocking)

1. Final name and home of the vocabulary module (`phase_vocab.ail` vs. expanding
   `transcript.ail`); pure naming decision, Phase A.
2. `artifacts` as raw `Json` vs. a typed artifact record — start `Json`, revisit when a second
   artifact consumer exists.
3. Exact `ExtPorts` field list — freeze during the `compaction_ai` v0.3.0 migration, not
   before.

## Review Comments

_Reviewer: GPT-5 Codex, 2026-07-02. Grounded against current source, the pinned local toolchain
(`ailang --version` -> `AILANG v0.26.0`, commit `3b52a24`), the phase-core research/sketch
artifacts, the why-not-CSP note, and DST ADR-001's R1-R15 review style._

### R1. The sealed-type proof contradicts the proposed module split

`ProviderPayload` is specified as sealed and as the only type `model_phase` accepts, but the same
opacity result used to force `StepState` co-location means a separate `model_phase.ail` cannot name
an unexported sealed type in its signature. Grounding: the ADR says unexported type names cannot be
imported (`ADR-001-phase-oriented-core.md:137-148`) while also listing `model_phase.ail` as a
separate module (`ADR-001-phase-oriented-core.md:163-169`); `probe_sealed_name.ail` reproduces the
substrate limit with `Error: IMP010: symbol 'Sealed' not exported by 'hist_opaque'`, while
`probe_sealed_thread.ail` only proves consumers can thread inferred values without naming the type.
**Action:** either co-locate every module that must name `History`, `CompactableSegment`, or
`ProviderPayload`; relax those types to validated exported records/variants; or add a new checked
probe proving an abstract exported type name with hidden constructors is expressible on v0.26.0.

### R2. The 28-event compatibility gate is stale against current production output

The ADR's Phase B and acceptance gates require "all 28 production schema-v1 event types," but
current source has 27 unique `emit_event` names plus two direct stream JSON event names,
`thinking_delta` and `reasoning_delta`, for 29 JSONL `type` values if stream chunks are in scope.
Grounding: `src/core/agent_loop_v2.ail:249-270` emits `thinking_delta` and `reasoning_delta`
directly via `emit_json`; `rg -o 'emit_event\\([^\\n]*\"[^\"]+\"' src/core/agent_loop_v2.ail | ... |
sort -u` found 27 real `emit_event` names; the sketch inventory includes `thinking_delta` but omits
`reasoning_delta` (`sketch/sketch_vocabulary.ail:212-229`). **Action:** replace the hand-maintained
"28" with a checked event-inventory artifact that includes or explicitly excludes direct stream
chunk events, and make the Phase B gate compare against that generated inventory.

### R3. Single-point ledger emission conflicts with live streaming semantics

The ADR says phases return events and exactly one driver location emits them, but today's streaming
events are emitted from the provider callback during `dispatch_step`, before the model call returns,
which is observable TUI behavior. Grounding: the callback is installed at
`src/core/agent_loop_v2.ail:1192-1202`; `emit_stream_chunk` writes JSONL immediately at
`src/core/agent_loop_v2.ail:249-270`; comments state the TUI appends `text_delta` in arrival order
at `src/core/agent_loop_v2.ail:1196-1198`. A post-call `PhaseResult.events` batch cannot be
byte-compatible with that timing, while allowing the model phase to emit directly violates
`ADR-001-phase-oriented-core.md:120-126` and the Phase B projection-only gate
(`ADR-001-phase-oriented-core.md:212-218`). **Action:** specify a streaming event sink/ledger append
protocol that preserves live JSONL timing while keeping one logical emission authority, and add a
byte-parity test for `thinking_stream_start` -> delta chunks -> `thinking_stream_end`.

### R4. Checkpoint auditability is asserted, not enforced

Returning `{history, event}` from `checkpoint` does not force the caller to append the event, and
the digest-chain rule has no concrete digest algorithm, session-entry validation, or atomic driver
operation in the ADR. Grounding: the invariant is stated at `ADR-001-phase-oriented-core.md:150-154`;
the research admits DST must verify the chain rather than the type making it impossible
(`RESEARCH-phase-core-dst-design.md:647-654`); the sketch digest is explicitly a placeholder
(`sketch/sketch_vocabulary.ail:51-53`) and the demo emits `before_digest:"h2", after_digest:"h1"`,
which is length-based and forgeable. **Action:** define the real history digest, include previous
checkpoint/event digest in the ledger event, make the driver expose a single atomic
`apply_checkpoint` path that appends the event with the history rewrite, and require resume/session
entry to validate the chain before accepting a seeded `History`.

### R5. `AwaitApproval` does not preserve the existing approval protocol timing

The ADR moves mid-dispatch `readLine()` into a driver `AwaitApproval` decision but does not specify
the required ordering: emit `tool_pending`, block for exactly that call, apply the default on EOF or
bad input, then resume the remaining tool calls in order. Grounding: current behavior emits
`tool_pending` at `src/core/agent_loop_v2.ail:758-766`, immediately calls `readLine()` at
`src/core/agent_loop_v2.ail:767-769`, and resolves `AllowAfterTimeout`/`DenyAfterTimeout` in the
same dispatch recursion at `src/core/agent_loop_v2.ail:770-790`; the ADR only says
"readLine() (`:769`) -> `AwaitApproval` decision performed by the driver"
(`ADR-001-phase-oriented-core.md:172-177`). **Action:** add an approval-state contract to
`ToolPlan`/`AwaitApproval` covering event-before-read ordering, default semantics, correlation by
tool call id, and continuation of the partially executed tool plan; gate it with a scripted TUI
approval scenario.

### R6. The conformance-kit acceptance gate names no verifiable target

Acceptance criterion 3 requires failing conformance scenarios before `compaction_ai` v0.3.0 and
passing after, but the ADR does not name the package path, scenario files, or commands that will
make that gate executable. Grounding: `rg -n 'motoko_ext_conformance|ext_compaction_invalid_rejected|
system_messages_hidden_from_compactors' . scripts src Makefile` found no current implementation
targets; the ABI track only says "ABI 3.0 + conformance kit 3.0 + `compaction_ai` 0.3.0" and
"registry runs the kit" (`ADR-001-phase-oriented-core.md:231-233`). DST ADR-001 R12 treated
phantom CI targets as a finding for the same reason. **Action:** add concrete future deliverables:
package path, scenario ids, exact `ailang check/run/test` commands, and the registry-generated
probe that must execute the kit for installed extensions.

### R7. The ABI migration-cost claim is too broad

The ADR says ABI v3 is "constructor-only" and packages that ignore ports recompile with zero code
changes, but the same bullet also changes `Compacted` by adding an artifacts field, which breaks
any extension that constructs `Compacted` even if its hook signatures do not change. Grounding:
current ABI 2.2.0 defines `Compacted(msgs: [Msg], note: string)` at
`~/.ailang/cache/registry/sunholo/motoko_ext_abi/2.2.0/types.ail:121-127`; the shipped compactor
constructs it at
`~/.ailang/cache/registry/sunholo/motoko_ext_compaction_ai/0.2.0/compaction_ai.ail:145-148`;
the ADR's migration claim is at `ADR-001-phase-oriented-core.md:181-187`. **Action:** narrow the
claim to non-compactor packages and fixtures, and explicitly list constructor updates required for
compactor packages and tests.

### R8. "No registry hydration" is not true for the ABI/conformance part of the design

The decision drivers say Layer 0/1 DST needs no registry hydration, but the ABI track requires
running the conformance kit for every package in `registry_generated.ail`; those are different
gates and the ADR does not separate them operationally. Grounding: the no-hydration driver is at
`ADR-001-phase-oriented-core.md:66-67`; the registry-wide conformance gate is at
`ADR-001-phase-oriented-core.md:231-233`; DST ADR-001's preconditions warn that generated-registry
imports can block Layer 1/3 until package hydration is fixed. **Action:** split the gates into
"core L0/L1, no registry hydration" and "registry/conformance, hydration required," and make CI
target names reflect that separation.

### What is accurate

The core citations for the current loop are accurate: `loop_v2` really carries the ten-effect row
at `src/core/agent_loop_v2.ail:1125`; `StepProvider` is at
`src/core/test/stub_step.ail:42`; persist-nudge marker scanning is documented at
`src/core/agent_loop_v2.ail:1062-1063`; system messages are built into the initial list at
`src/core/rpc.ail:230-232` and passed unfiltered to `dispatch_pre_step` at
`src/core/agent_loop_v2.ail:1154`; the Bedrock correlation comment exists at
`src/core/agent_loop_v2.ail:1316-1333`; and first-`Compacted`-wins lives in
`src/core/ext/runtime.ail:143-164`. Required artifacts reproduced: `ailang check`, `ailang run
--caps IO --entry main`, and `ailang test` pass for `sketch_vocabulary.ail`; the sealed forge/name
probes fail with `IMP010`; `scripts/smoke_ports_record.ail` checks and its fake entry runs under
`--caps IO`, while `main_live` fails under `--caps IO` with `effect 'Clock' requires capability`.

### Recommended pre-implementation actions

1. Resolve the sealed-type/module-boundary contradiction before creating `phase_vocab.ail`.
2. Generate the production event inventory and fix the 28/29 event gate before Phase B.
3. Specify the streaming ledger protocol before centralizing event emission.
4. Define checkpoint digest-chain mechanics and resume validation before blessing `TakeCheckpoint`.
5. Add the approval protocol contract and scripted approval scenario before moving `readLine`.
6. Turn the conformance kit and registry gate into concrete files/commands.
7. Narrow the ABI migration-cost claim and list constructor updates for compactors.
8. Split no-hydration core DST gates from registry-hydrated conformance gates.
