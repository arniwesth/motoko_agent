# ADR-001: A phase-oriented core designed for Deterministic Simulation Testing

Date: 2026-07-02; revised 2026-07-03 after three independent review passes (see Review
Comments and the Author Response & Disposition log at the end); amended same day by **D9**
(operator decision: compaction policy is extension-resident — compactor chain over a core
scaffold, bundled `motoko_ext_compaction_structural` default, telemetry in ABI v3; closes
Open Question 4); further amended 2026-07-03 by the **Phase-A plan-authoring findings
G1–G7** (the fresh-session ADR-completeness test prescribed by
`NOTE-plan-authoring-session-choice.md`; see the Plan-Authoring Findings & Dispositions log
at the end; closes Open Question 1); further amended 2026-07-03 by the **Phase-B
plan-authoring findings G-B1–G-B7** (same fresh-session test, second application; see the
Phase-B Findings & Dispositions log at the end; closes Open Question 4's remaining
sub-question)
Status: Proposed (review findings addressed; dispositions recorded)
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
  architecture satisfies by construction; resolves its review comments R4, R7, R8, R11. Its R5
  (export compaction constants) is resolved **in amended form**: the actual/estimate tier split
  R5 described has since been removed from source (verified 2026-07-03; see Phase A and Open
  Questions), so the export applies to the current single tier table.

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
- 48 scattered emission call sites (39 `emit_event`, 7 `emit_run_summary`, 2
  `emit_stream_chunk`, plus 4 direct `emit_json`; measured 2026-07-03 via
  `grep -c` on `src/core/agent_loop_v2.ail`) make trace ordering unreproducible.
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

The driver is the single **logical emission authority**; exactly one function
(`apply_state_delta`) applies state changes. `LedgerEvent` is a typed variant whose
constructor names are the DST-canonical layer; a `to_schema_v1 : (LedgerEvent) -> Json`
projection targets the **production wire stream** — **29** event types (27 `emit_event` names
plus `thinking_delta` and `reasoning_delta` emitted directly via `emit_json`,
`agent_loop_v2.ail:255,:265`; inventory regenerated mechanically, never hand-counted; scope
is `agent_loop_v2`'s stream — `rpc.ail`'s raw `v2_mode` and `ai_compat`'s call-stream events
are outside it, G-B6 2026-07-03) consumed
by the TUI and eval harnesses. Projected names fall in two classes (normative): **[prod]**
constructors project onto existing production names and must be byte-compatible; **[NEW]**
constructors (`provider_call_prepared`, `loop_totals_updated`, `history_checkpoint`,
`ext_compaction_rejected`) introduce additive names, admitted only after a TUI unknown-type
tolerance check. In-memory typed events are what DST invariants consume; JSONL is the
failure-report projection (resolves DST R4; the recorder-vs-production tension of DST R8
dissolves because the ledger is always-on).

**Streaming protocol** (review P1-R3/P2-R4): stream-delta events (`thinking_delta`,
`reasoning_delta`) are emitted *during* the blocking model call today, in arrival order the
TUI depends on. A post-call `PhaseResult.events` batch cannot reproduce that timing. Normative
resolution: the driver hands the model phase a **ledger append handle** (a port) scoped to
stream-delta events only; deltas are appended through it in arrival order while the call is in
flight. The handle is driver-constructed, so single logical authority holds; batched
`PhaseResult.events` remains the path for all non-streaming events. Phase B carries a
byte-parity test for the `thinking_stream_start → N×delta → thinking_stream_end` sequence.

Normative deltas: `StateDelta` is a patch record (`Option` fields, absent = unchanged); the
delta is itself the observation DST records. `PhaseResult` has **no continuation field** — the
step machine re-derives the next decision from applied state.

### 4. Single transcript gate + sealed history types (D3, D7)

The **vocabulary module**, `src/core/phase_vocab.ail` (name settled 2026-07-03 — G1 / Open
Question 1; the successor of the transcript helpers currently inline in
`agent_loop_v2.ail:361-501` — there is no `transcript.ail` in source), owns:

- **`History`** — sealed: a single-constructor variant whose constructor is *not exported*.
  Substrate proof (`sketch/README.md` Q1): unexported variant constructors are unimportable
  (`IMP010`); values still thread through consumers. Consequence (normative, scope corrected
  2026-07-03 after review adjudication): co-location applies to **definers only** — the
  vocabulary module defines the sealed types *and* every exported wrapper that names them
  (`StepState`, `StepDecision`, `ModelRequest`). Consumer modules (`step_machine.ail`,
  `model_phase.ail`) import the exported wrappers and operate freely; sealing holds
  transitively (proven: `sketch/vocab_probe.ail` + `sketch/probe_consumer_decide.ail` — a
  separate module defines `decide` over wrapper types, constructs decision variants, and
  pattern-matches sealed payloads). Bare sealed-type parameters in foreign signatures remain
  impossible — sealed values cross module boundaries only inside exported wrappers. Exported
  record types are structurally forgeable, so sealed types must be variants.
- **The compaction projection** (amended 2026-07-03, **D9** — operator decision: compaction
  policy is **extension-resident**; core keeps only the scaffold). Core owns the scaffold: pin
  head system prefix → `CompactableSegment` (sealed; cannot contain system messages) →
  normalize → the **compactor chain** → the exhaustion decision. Compaction *policy* — elision
  ladders, tier thresholds, AI summarization, any future strategy — lives in compaction
  **extensions**. Chain semantics (normative; replaces first-`Compacted`-wins for compactors):
  each registered compactor receives the previous stage's segment and returns `PassThrough` or
  `Compacted`; the gate validates **every stage** (invalid ⇒ `ext_compaction_rejected` ledger
  event, stage skipped, chain continues — subsuming the old hard-coded structural fallback);
  registry order is pipeline order; the ledger records each stage *(wire scope, G-B1
  2026-07-03: Phase B records applied and rejected stages — `compaction_extension` /
  `ext_compaction_rejected`; pass-through stages have no admitted [NEW] name and are
  recorded once Phase C's in-memory ledger exists)*. This preserves today's
  semantics — extension compaction and structural elision already compose sequentially
  (`agent_loop_v2.ail:1154→1171`); under first-wins the relocated ladder would silently stop
  chaining. The current 70/85/95 ladder (`compaction.ail:134-141`) relocates into a **bundled
  default extension** `motoko_ext_compaction_structural` (pure; registered last; the
  conformance kit's trivial reference consumer alongside effectful `compaction_ai`). Core
  exports the measurement primitives — `estimate_tokens_messages` and
  `usage_percent_with_limit` (names corrected 2026-07-03, G2/G3: `estimate_tokens` is a
  different, `[Msg]`-typed function in `context_usage.ail:12`; the model-name-keyed
  `usage_percent` is dead surface since limits moved to the model catalog in `a7589b8`) — so
  compactors never duplicate them (the `compaction_ai` v0.2.0 duplication defect, fixed
  structurally). With
  zero compactors installed, core behavior is honest exhaustion: `Fail(ContextExhausted)`
  (later `TakeCheckpoint`, once emitted). `ProviderPayload` is sealed; `model_phase` receives
  it inside the exported `ModelRequest` wrapper (it cannot name the sealed type — see
  co-location scope above) and there is no other way to obtain one outside
  `phase_vocab`'s exported projection/sealing ops (`project()` for pure precheck,
  `seal_compacted_payload()` for effectful post-chain sealing; C2 sign-off 2026-07-04).
  Ephemerality is by construction: nothing can write a payload back into history. Actual-token
  gating (the path removed from source; P2-R1/P3-R4) is now simply **compactor policy**: any
  extension can implement it against the telemetry ABI v3 exposes — the former Open Question 4
  is closed by D9.
- **The checkpoint seam** (D7), mechanics tightened per review (P1-R4/P2-R6/P3-R1):
  `checkpoint(History, CheckpointPlan) -> {history, event}` is the sole op producing a rebuilt
  `History`. Normative mechanics: (a) `history_digest` is a **content hash** (the sketch's
  length-based digest is a labeled placeholder); (b) each `CheckpointTaken` event carries the
  **previous** digest so the chain is verifiable end-to-end; (c) the driver's only rewrite path
  is the atomic `apply_checkpoint(StepState, CheckpointPlan) -> {state, event}` — no code path
  takes the rebuilt history without its event (shape proven in the sketch); (d)
  `history_from_seed` validates the digest chain before accepting a resumed `History`; (e)
  **checkpoint output carries the same transcript-validity obligations as ext compaction**
  (system prefix preserved, pairing preserved, ids preserved), enforced by the same gate and by
  scenario `checkpoint_output_is_valid_transcript` — a v1 obligation, not deferred to v2.
  Invariant: *History is rewritten only by `checkpoint`, and every rewrite has a matching
  ledger event.* v1 policy **never emits** `TakeCheckpoint` — enforced by scenario, not
  convention.
- **Transcript invariants**: no empty tool ids; exactly one result per call; ids preserved;
  tool_use/tool_result correlation (the Bedrock rule — currently a 20-line comment at
  `agent_loop_v2.ail:1316-1333`, here an enforced property); no live chunks in the transcript;
  system messages form a head prefix (checked at session entry, where
  `run_v2_from_messages`-style resumed histories arrive).

### 5. Module structure and residual-logic homes (D4)

| Module | Nature | DST layer |
|---|---|---|
| `phase_vocab.ail` (name settled — G1) | sealed types, StepState, LedgerEvent, projection, invariants, transcript builders | L0, Z3 candidates |
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

**Approval protocol contract** (review P1-R5/P2-R5 — the live flow's ordering invariants,
`agent_loop_v2.ail:758-790`, are preserved normatively): `ApprovalRequest` carries the
`PolicyDefault` (`default_allow`), the `stream_id` and `call_id` the `tool_pending` event
correlates on, and the **suspended tail** of the `ToolPlan` (`remaining`). The driver emits
`tool_pending` *before* blocking on input (event-before-read ordering); EOF/unparseable input
resolves via the carried default; on resolution the driver appends the denial or approval
result and re-issues `RunTools` with the remaining entries, preserving call order. Gated by a
scripted TUI approval scenario before Phase C inverts the dispatch recursion.

### 6. Extension ABI v3 and conformance kit (D6, D8)

- **ABI v3**: `ExtCtx` gains `ports: ExtPorts` (ai_step, http, proc_exec, kv, clock_now,
  env_get), `artifacts: Json`, and (added by D9) **`telemetry`** — the per-step usage numbers
  from `StepResult` (`last_input_tokens`, output/cache tokens) so compactor extensions can
  implement actual-token-gated policy without core deciding it for them; `Compacted` gains an
  artifacts field. **No effect-row changes** (`on_tool_policy`/`on_describe_tools`/`on_build_system_prompt` are already pure in
  ABI 2.2.0; narrowing the four max-row hooks buys nothing once ports exist — calling an
  effectful port still requires the effect in the row). Migration cost (narrowed per review
  P1-R7/P2-R8): hook signatures are unchanged, so **non-compactor packages that do not
  construct `Compacted`** recompile with zero code changes (constructor-only breaks: core's
  `mk_v2_ext_ctx` + extension test fixtures). **Compactor packages break at the source level**:
  `Compacted(msgs, note)` gains an artifacts field, so every `Compacted(...)` construction site
  must be updated — `compaction_ai` v0.3.0 is the first and currently only such package
  (`compaction_ai.ail:146-148`).
- **Conformance kit** (`motoko_ext_conformance`, separate package, lockstep majors with the
  ABI; plain-language definition in §6.1 below): `invariants` module (pure contract law —
  **imported by the core transcript gate**, one source of law) + `harness` module (test-only). Enforcement is behavioral
  **caps-as-conformance**: fake ports + minimal caps ⇒ raw effect calls fail at performance
  time; per-extension declared-caps allowances record residual raw-effect surface. The kit does
  not test cross-extension composition (fault-isolation rationale: research doc §6.1) — the
  obligations catalog is composition-closed, arbitration is core L1 territory
  (`src/core/ext/runtime.ail:143-164`).
- **Reference migration**: `compaction_ai` v0.3.0 — ports-native, artifact-cached, and the
  kit's acceptance test is that it **rejects v0.2.0's two live bugs for the right reasons**.
- **Concrete targets** (review P1-R6/P2-R7 — no phantom gates; these are *future deliverables*
  named now so the gate is executable when it arrives):
  - package: `packages/motoko_ext_conformance/` (modules `invariants.ail`, `harness.ail`);
  - fail-then-pass scenario ids: `conformance.compactor.system_prefix_preserved` (v0.2.0 live
    bug 1) and `conformance.compactor.tool_pairing_preserved` (live bug 2), plus
    `conformance.compactor.deterministic_replay` and
    `conformance.compactor.artifact_cache_effective`;
  - commands: `ailang check packages/motoko_ext_conformance/harness.ail`, then
    `ailang run --caps IO --entry main packages/motoko_ext_conformance/harness.ail` pointed at
    the package under test (exact arg convention frozen with the kit);
  - registry probe: a generated `scripts/conformance_registry_probe.ail` that imports
    `registry_generated.ail`'s package list and runs the harness per package in core CI.

### 6.1 The conformance kit, exactly (explainer)

_Added 2026-07-03 at operator request. The bullets above are the decision; this subsection is
the plain-language definition. Elaboration with the full obligations catalog: research doc
§6.1._

**One sentence:** the conformance kit is a separate AILANG package that turns the extension
contract from prose into an executable question — *"does this extension behave the way the
core is entitled to assume?"* — answerable in any extension's own CI, with no network, no
model, and almost no capabilities.

**The problem it exists for.** The ABI's types constrain *shapes*, not *behavior*.
`compaction_ai` v0.2.0 type-checks perfectly against ABI 2.2.0 and still destroys the system
prefix, can sever tool_use/tool_result pairs, and re-summarizes on every step — three
behavioral contract violations the type system cannot see. Those obligations ("preserve
pairing", "preserve ids", "be deterministic given the same inputs") have to be *executable
checks*, and they have to live somewhere that both core and extension authors run, or the two
sides' understandings of the contract drift apart.

**What is physically in the package** — two modules with different audiences:

1. `invariants.ail` — **the contract law.** Pure predicates over hook inputs and outputs,
   e.g. `pairing_preserved(segment_in, msgs_out)`, `ids_preserved(segment_in, msgs_out)`,
   `no_system_in_output(msgs_out)`, `envelope_well_formed(call, result_env)`. Pure means: no
   effects, runnable under `ailang test` with zero caps, Z3-eligible. The crucial move is who
   imports it: **core's transcript gate imports these same functions and runs them in
   production** — when a compactor returns `Compacted(...)` at runtime, the gate validates it
   with the *identical* predicate an extension's CI ran before shipping. One implementation of
   the law; disagreement between "what core enforces" and "what extensions were tested
   against" is impossible by construction.
2. `harness.ail` — **the test rig.** Test-only; core never imports it. It drives one
   extension's `ExtensionHooks` through scenarios: synthetic `ExtCtx` values, fixture
   histories/segments, and **fake ports** (pure, scripted — the same pattern as
   `scripts/smoke_ports_record.ail`). It runs the invariants over the hook outputs and, on
   failure, reports scenario id + first failed invariant + a normalized trace in the same
   JSONL shape as the core ledger, so a conformance failure reads exactly like a core DST
   failure.

**How enforcement actually works (caps-as-conformance).** "This extension only reaches the
world through `ctx.ports`" sounds like it needs static analysis AILANG doesn't have. It
doesn't, because capabilities are checked when an effect is *performed* (§4 Q5): the harness
runs scenarios with fake ports under minimal caps (e.g. `--caps IO`). If the extension
bypasses ports and calls `std/ai.step` or `Net.httpGet` directly, that call needs the `AI` or
`Net` capability at runtime — which the harness did not grant — so the scenario fails at the
exact bypassing call site. The runtime is the analyzer. Extensions with legitimate remaining
raw effects (e.g. context-mode's `SharedMem` frames before its ports migration) declare them
in a per-extension **caps allowance** — a machine-readable list of exactly which effects that
extension still performs outside ports; migrating it to empty is the progress metric.

**Who runs it, and when.**
- *Extension CI* (every `motoko-ext-*` repo): the harness against that package's own hooks.
  Fast, deterministic, no network, no registry hydration — an extension author gets a contract
  verdict locally before publishing.
- *Core CI* (registry gate; hydration **required** — the other gate class): the generated
  registry probe runs the harness against every package in `registry_generated.ail`, turning
  "certified against conformance vN" into a checkable registry-inclusion condition instead of
  a README claim.

**A worked example — why v0.2.0 fails and v0.3.0 passes.** The harness hands `compact_with_ai`
a fixture segment sitting above its threshold, with a fake `ai_step` port returning a canned
summary. v0.2.0 splits by position and drops messages: the output severs a tool pair ⇒
`pairing_preserved` returns false ⇒ scenario `conformance.compactor.tool_pairing_preserved`
fails, naming the invariant. A second scenario re-runs with run-one's artifacts and an *empty*
`ai_step` script; v0.2.0 (no cache) calls the port again and gets the poison sentinel ⇒
`artifact_cache_effective` fails. v0.3.0 — ports-native, prefix-aware, artifact-cached —
passes all four compactor scenarios. That fail-then-pass pair is the kit's own acceptance
test: **the kit is correct when it rejects the shipped v0.2.0 for the right reasons.**

**What it deliberately does NOT do** (each exclusion has an owner): cross-extension
composition — chain order and arbitration are core L1 scenarios, because the composition set
is a deployment property and the fold under test is core's; provider acceptance of final
payloads — core's transcript gate; cross-package `id` uniqueness — the registry; resource/time
budgets — out of scope v1. The obligations are chosen to be *composition-closed* (if every
compactor preserves pairing/ids/prefix, any chain of them does too), which is what makes the
exclusion safe: a composition failure always decomposes into "one extension broke its
contract" (kit's job) or "core's chain is wrong" (core's job) — and if neither, the contract
gains a new obligation.

**Versioning.** Lockstep majors with the ABI (kit `3.x` certifies ABI `3.x`); the kit exports
`conformance_abi_version()` and the harness refuses a mismatched ABI loudly, so version skew
is an error, never a silent pass.

---

## Migration plan and gates

Strangler-style; each phase leaves the system shippable.

**Phase A — pure foundations, zero behavior change.**
Deliverables: vocabulary module (seeded from `sketch/sketch_vocabulary.ail`); exported
compaction constants **re-grounded on current source** (P2-R1/P3-R4): the single tier table
`ELIDE_TIER_PCT=70`, `ELIDE_HARD_TIER_PCT=85`, `EMERGENCY_PCT=95` and the keep-last counts
(10/5) from `compaction.ail:134-141`, plus (G5, 2026-07-03) the emergency keep-lasts (3/1)
and the emergency re-check literals at `compaction.ail:111-118` — the full inline-literal
set of the ladder, seven named exports as house-style zero-arg `export pure func`s —
`OUTPUT_HEADROOM` and the 60/75/85 actual tiers are
**struck** (no referent in source; DST ADR-001 R5/R15 amended 2026-07-03). Under
D9 these tier constants are a stepping stone: they relocate with the ladder into
`motoko_ext_compaction_structural` in Phase B, while the measurement primitives
(`estimate_tokens_messages`, `usage_percent_with_limit` — already `export pure func` in
`compaction.ail`; names corrected per G2/G3) stay in
core permanently as the shared surface compactors build on. Transcript builder extracted from
`step_result_to_message` / `envelope_to_tool_message` / `tool_result_message` — plus the
plan survey's finds: `cap_tool_message_content`, `result_env_model_content`,
`msgs_to_messages`, and a new `handled_tool_message` consolidating three duplicated inline
tool-message literals (full call-site enumeration in `PLAN-phase-a-pure-foundations.md`).
Gate: `ailang check` + existing smokes green; no event-stream diff — byte-identical **modulo
declared volatile fields** (G4: session id pinned via `MOTOKO_SESSION_ID`; `duration_ms`
normalized — empirically the complete volatile set at HEAD), checked mechanically by the
plan's parity harness (`scripts/phase_a_event_parity.sh` + `make smoke_parity`, both
to-be-created in plan WI-0; named here so the gate is executable when it arrives — G6, the
same no-phantom-gates discipline as Decision detail 6).

**Phase B — phases return `PhaseResult`; driver keeps current control flow.**
Deliverables: all event emission through the ledger + `to_schema_v1`; provider-call recording
seam (DST ADR-001's required first seam) as ledger events around the model phase; core-side
system-prefix fix (pass `CompactableSegment`, not the raw list, to `dispatch_pre_step` — zero
ABI cost, closes the live gap); (D9) `dispatch_pre_step` converted from first-`Compacted`-wins
to the **compactor chain** (no ABI change — the hook signature already supports fold-through),
and the 70/85/95 ladder extracted from `compaction.ail` into the bundled
`motoko_ext_compaction_structural` extension registered last — a behavior-preserving
relocation *at the result level* (byte-level residues — exhaustion-reason wording, stage
events for genuinely-applied elision, the segment measurement basis with its effective-limit
compensation — are enumerated in the Phase B plan's expected-diff tables; G-B3 2026-07-03),
since chain(ext…, structural-last) equals today's sequential composition.
Added 2026-07-03 (plan-authoring findings): (G3) with the ladder relocation, **retire the
vestigial model-name-keyed pure wrappers** (`compact_step`, `usage_percent`,
`try_emergency_compaction`, `context_limit_for`) — production limits come from the model
catalog (`catalog_context_limit_for`, `{Env, FS}`) since commit `a7589b8` (2026-06-24) and
the static `context_limit_for` returns 0 for every model, so the model-keyed forms are dead
policy surface; the shared measurement surface is the limit-parameterized variants. (G7) a
**minimal in-repo test extension** (scripted `Handled` + `ContinueWithFeedback` +
`InterceptHandled` fixture — the intercept arm added 2026-07-03, G-B4:
`envelope_to_tool_message`'s only call site is the intercept path) so
extension-path provider-message construction is e2e-coverable by the parity harness before
emission rewires — Phase A pins those paths with golden-value pure tests only.
Gate (per review R2-family): the projection's emitted `type` set for [prod] constructors is a
**byte-compatible subset of the mechanically generated 29-name production inventory**
(regenerated from source, never hand-counted; includes `reasoning_delta`; byte-compatibility
as defined by the Phase A gate — modulo declared volatile fields, G4); [NEW] names admitted
only after the TUI unknown-type tolerance check; the streaming byte-parity test
(`thinking_stream_start → N×delta → thinking_stream_end` in arrival order) passes; DST scenario
`system_messages_hidden_from_compactors` goes from unrepresentable-in-new-code to
verified-in-wiring.

**Phase C — full inversion.**
Deliverables: pure `decide`; driver executes decisions; `run_v2_with_stub` superseded by
scripted ports; the scripted TUI approval scenario (approval contract above); Layer 1
compaction scenario family live
(`provider_payload_vs_uncompacted_history_pressure`, `ext_compaction_invalid_rejected`,
`summary_cache_replay_stable`, `history_rewrite_requires_checkpoint_event`,
`checkpoint_never_emitted_in_v1`, `checkpoint_output_is_valid_transcript`, plus the D9 chain
scenarios: `compactor_chain_order_is_registry_order`, `invalid_stage_skipped_chain_continues`,
`zero_compactors_exhaustion_behavior`).
`single_tier_ladder_selects_correctly` relocates with the ladder: it becomes a conformance
scenario of `motoko_ext_compaction_structural`, not a core scenario. The previously listed
`actual_tokens_drive_next_step` / `emergency_exhaustion_estimate_gated` /
`telemetry_reflects_payload_not_history` scenarios are **retired from core** (P2-R1/P3-R4 +
D9): actual-token gating is compactor policy now, so their successors live in whichever
compactor package implements it, written against `ExtCtx.telemetry`.
Gate: L1 scenarios pass under minimal caps with no network; every DST failure prints scenario
id, first failed invariant, and normalized trace.

**ABI v3 track (parallel to B/C):** ABI 3.0 (ports + artifacts + telemetry) + conformance kit
3.0 + `compaction_ai` 0.3.0 + (D9) `motoko_ext_compaction_structural` 1.0 (the bundled
default; note it is pure and needs no ports, so it can ship early against ABI 2.2.0 during
Phase B and re-certify on 3.0);
gate: kit rejects v0.2.0, accepts v0.3.0 and the structural compactor (scenario ids and
commands in Decision detail 6); registry probe runs the kit for every package in
`registry_generated.ail`.

**Gate separation** (review P1-R8/P2-R9): the migration gates split into two operationally
distinct classes with distinct CI targets — **core DST gates** (Phases A–C: no registry
hydration, `--caps IO` or less, no network) and **registry/conformance gates** (ABI track:
hydration *required*, runs in core CI against hydrated extensions). The decision driver "no
registry hydration" applies to the former only; a no-hydration gate must never be conflated
with a hydration-required one.

## Acceptance criteria

1. Phase A lands with zero behavior change (existing smokes + event-stream parity).
2. Phase B's projection gate passes against the mechanically generated 29-name inventory
   (subset for [prod], tolerance-checked for [NEW]); the provider-call recording seam emits
   `provider_call_prepared` ledger events (typed `ProviderResult` projecting to production
   `thinking`) consumed by at least one L1 test; the streaming byte-parity test passes.
3. The two `compaction_ai` v0.2.0 live bugs are demonstrated by failing conformance scenarios
   (`conformance.compactor.system_prefix_preserved`,
   `conformance.compactor.tool_pairing_preserved`) *before* the v0.3.0 fix and pass after
   (mirrors DST ADR-001's PR-#76-style criterion, but against bugs verified in this research).
   Requires registry hydration (registry/conformance gate class).
4. Phase C: `decide` is pure (no effect row), and the compaction L1 family — including
   `checkpoint_output_is_valid_transcript` — runs with `--caps IO` or less, no
   Ollama/OpenRouter/network (core DST gate class).
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
- **Core-resident compaction policy** (rejected 2026-07-03, D9) — keeping the elision ladder
  in core makes core a privileged compactor exempt from the contract machinery built to police
  compactors, and hard-codes fallback semantics the compactor chain expresses naturally.
  Rejected in favor of extension-resident policy over a core scaffold; see Decision detail 4.

## Open questions (non-blocking)

1. ~~Final name and home of the vocabulary module (`phase_vocab.ail` vs. expanding
   `transcript.ail`); pure naming decision, Phase A.~~ **Closed 2026-07-03 (G1)**:
   `src/core/phase_vocab.ail`, transcript builders included. The "expanding
   `transcript.ail`" option was void — no such file exists in source; the transcript
   helpers live inline in `agent_loop_v2.ail:361-501`. Full justification in
   `PLAN-phase-a-pure-foundations.md` ("Decision: module name and builder home").
2. `artifacts` as raw `Json` vs. a typed artifact record — start `Json`, revisit when a second
   artifact consumer exists.
3. Exact `ExtPorts` field list — freeze during the `compaction_ai` v0.3.0 migration, not
   before.
4. ~~Reintroduce actual-token compaction gating?~~ **Closed by D9 (2026-07-03)**: tier policy
   — including actual-vs-estimate gating — is compactor-extension policy, not a core decision.
   ABI v3's `ExtCtx.telemetry` supplies what such a compactor needs; DST ADR-001 R5/R15 still
   need their amendment to the single-table source reality (that part stands). The remaining
   sub-question (whether the D9 default `motoko_ext_compaction_structural` also absorbs the
   emergency path, or core keeps a minimal final elision before `Fail`) is decided during the
   Phase B extraction — current lean: it moves too, and zero-compactor core behavior is honest
   exhaustion. **Sub-question closed 2026-07-03 (Phase-B plan, decision D-B5, operator
   sign-off): the emergency path moves into the extension; core keeps a single
   `exhaustion_pct() = 95` exhaustion decision measured over the re-pinned full list against
   the catalog limit, fail-open at limit 0.**

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

---

## Review Comments (Independent Review, Pass 2)

_Reviewer: GLM 5.2 (`openrouter/z-ai/glm-5.2`), 2026-07-02. Grounded against current source
(`src/core/agent_loop_v2.ail`, `src/core/compaction.ail`, `src/core/rpc.ail`,
`src/core/ext/runtime.ail`, `src/core/test/stub_step.ail`, the registry cache
`motoko_ext_abi/2.2.0/types.ail` and `motoko_ext_compaction_ai/0.2.0/compaction_ai.ail`), the
pinned local toolchain (`ailang --version` -> `AILANG v0.26.0`, commit `3b52a24`), the phase-core
research/sketch artifacts (all re-run), the why-not-CSP note, and DST ADR-001's R1-R15 review
style. Every `file:line` citation in the ADR body was verified; artifacts were re-run._

### R1. The Phase A compaction-constant gate references tiers and constants that no longer exist in source

The ADR's Phase A deliverable and acceptance gate cite "exported compaction constants
(`OUTPUT_HEADROOM`, actual tiers 60/75/85, estimate tiers 70/85/95 -- DST ADR-001 R5)" (lines
206-208), inherited from DST ADR-001 R5 (grounded 2026-06-27). Against current source (2026-07-02)
these are stale: `src/core/compaction.ail` has a **single** tier table -- 70/85/95 with emergency
at >=95 (`compaction.ail:136-138`) -- and no `compact_step_actual` function, no `OUTPUT_HEADROOM`
literal (no `75000` anywhere in `src/core`), and no actual/estimate distinction. The loop calls
`compact_step_with_limit(msgs_after_ext, model, context_limit)` in one place
(`agent_loop_v2.ail:1171`); a grep for `last_input_tokens|actual|estimate` across
`agent_loop_v2.ail` returns zero hits, so the `last_input_tokens`-gated "actual token" path the
DST review described is gone. This is load-bearing: Phase C's L1 scenario list (lines 224-227)
includes `actual_tokens_drive_next_step` and `emergency_exhaustion_estimate_gated`, which
presuppose the actual/estimate split. **Action:** re-ground Phase A against current
`compaction.ail`: export the single 70/85/95 tier table (or confirm whether the actual/estimate
split was intentionally collapsed and update DST ADR-001 R5/R15 accordingly); strike
`OUTPUT_HEADROOM=75000` unless it is re-introduced; and reconcile the Phase C scenario list with
the source's current behavior (the `actual_tokens_*` scenarios may be unrepresentable as written).

### R2. The "28 event types" gate is wrong: production emits 29, and the sketch inventory omits `reasoning_delta`

The ADR (line 123) and Phase B gate (line 217) require "all 28 production schema-v1 event types,
inventoried in `sketch/sketch_vocabulary.ail`." Re-running the inventory against source: there are
**27** distinct `emit_event` name strings in `agent_loop_v2.ail` (verified by extracting every
`emit_event(..., "NAME", ...` call and de-duplicating) plus **2** direct stream-JSON `type` values
emitted by `emit_stream_chunk` via `emit_json` -- `thinking_delta` (`agent_loop_v2.ail:255`) and
`reasoning_delta` (`agent_loop_v2.ail:265`) -- for **29** distinct JSONL `type` values. The sketch's
comment inventory (`sketch_vocabulary.ail:221-228`) lists 28 names: it includes `thinking_delta`
but **omits `reasoning_delta`**. The `to_schema_v1` projection in the sketch (lines 263-276) has no
constructor mapping to `reasoning_delta` either. A byte-compatibility gate built on the wrong
membership will pass while missing a live event type the TUI already renders. **Action:** generate
the production event inventory mechanically (grep `emit_event` + `emit_json` `type` fields across
`src/core`), add `reasoning_delta` to both the sketch inventory and the `LedgerEvent`/
`to_schema_v1` projection, and make the Phase B gate compare the projection's emitted `type` set
against that generated inventory, not a hand-maintained count.

### R3. The sealed-type opacity result forces `step_machine.ail` to co-locate too, not just `phase_vocab.ail` and `model_phase.ail`

The ADR's opacity claim (lines 137-142) is verified: `probe_sealed_forge.ail` fails with
`IMP010: symbol 'MkSealed' not exported by 'hist_opaque'`; `probe_sealed_name.ail` fails with
`IMP010: symbol 'Sealed' not exported by 'hist_opaque'`; `probe_sealed_thread.ail` runs (values
thread without naming the type). The co-location consequence is therefore real for any module that
must name `History`, `CompactableSegment`, or `ProviderPayload` in a signature or record field. The
ADR's module table (lines 163-169) lists `step_machine.ail` as a separate module, but
`decide(StepState, StepPolicy) -> StepDecision` must name `StepState` (embeds sealed `History`) and
`StepDecision` (whose `CallModel(ProviderPayload)` variant names sealed `ProviderPayload`) -- both
unimportable type names per the probe. So `step_machine.ail` cannot be a separate file unless those
types are relaxed to exported (and thus forgeable). This widens the co-location consequence beyond
the `model_phase.ail` case the prior review (R1) raised: the **pure decision logic the ADR wants as
its L0/Z3 target is itself trapped in the vocabulary module**. **Action:** either co-locate
`decide` (and `model_phase`'s signature) inside `phase_vocab.ail`, accepting that the L0 pure core
is one large module; or relax `ProviderPayload`/`History` to exported validated types and rely on
the transcript gate (not opacity) for integrity -- and state which choice is taken before Phase A.

### R4. Single-point ledger emission cannot be byte-compatible with live streaming timing

The ADR (lines 120-126) says phases return `PhaseResult` with an `events` list and "exactly one
place (the driver) appends and emits events," and Phase B's gate (line 217) requires
byte-compatibility with current TUI/eval consumers. But today's stream events are emitted
**during** the blocking `dispatch_step` call, via the per-chunk callback installed at
`agent_loop_v2.ail:1201` (`let on_chunk = \chunk. emit_stream_chunk(...)`), which calls `emit_json`
immediately on each `ContentDelta`/`ThinkingDelta` (lines 249-270) -- before the model call returns.
The TUI appends `text_delta` in arrival order (comment at `:1196-1198`). A post-call
`PhaseResult.events` batch emitted by the driver **after** the model phase returns cannot reproduce
that inter-chunk timing: either the deltas are buffered (changing observable byte order and
breaking live render) or the model phase emits directly (violating the single-emission-authority
claim at lines 120-126). **Action:** specify a streaming-sink protocol: the driver hands the model
phase a ledger append handle (or the model phase returns a streaming-event stream distinct from the
batched `events` list) that writes `thinking_delta`/`reasoning_delta` JSONL in arrival order while
the call is in flight, and add a byte-parity test asserting `thinking_stream_start` -> N x
`thinking_delta` -> `thinking_stream_end` ordering against current production output.

### R5. `AwaitApproval` as a decision does not specify the ordering invariants the live approval protocol depends on

The ADR (line 177) maps the mid-dispatch `readLine()` (`agent_loop_v2.ail:769`) to an
`AwaitApproval` decision "performed by the driver" but does not specify the required ordering. In
the current code the approval flow is: emit `tool_pending` (`:760-766`), immediately block on
`readLine()` (`:769`), resolve `AllowAfterTimeout`/`DenyAfterTimeout` on EOF or unparseable input
(`:770-790`), then **continue dispatching the remaining tool calls in the same `dispatch_calls`
recursion** (`:856-857`). Inverting this into a decision returned to the driver means the partially
executed `ToolPlan` must be suspendable and resumable, the `tool_pending` event must precede the
read (not be batched into `PhaseResult.events`), and the default-deny/default-allow semantics must
carry through the decision payload. The ADR's `AwaitApproval(ApprovalRequest)` (line 87) has no
fields for the default policy, the stream_id, or the continuation state. **Action:** extend
`ApprovalRequest` to carry `default_allow: bool` (or `PolicyDefault`), `stream_id`, and `call_id`;
specify that `tool_pending` is emitted by the driver before blocking (preserving event-before-read
ordering); define how a partially executed `ToolPlan` is represented across the decision boundary
(e.g., `RunTools` re-issued with the remaining entries); and gate this with a scripted TUI approval
scenario before Phase C inverts the dispatch recursion.

### R6. The checkpoint digest-chain is a placeholder with no enforcement, and the return-type trick does not force event append

The ADR (lines 150-154) states "History is rewritten only by `checkpoint`, and every rewrite has a
matching ledger event" and that `checkpoint(History, CheckpointPlan) -> {history, event}` makes the
invariant "nearly hold by construction." Verified against the sketch: `history_digest` is
`"h${show(length(xs))}"` (`sketch_vocabulary.ail:53`) -- purely length-based and trivially forgeable
(two different histories of the same length produce the same digest); the demo emits
`before_digest:"h2", after_digest:"h1"` (line 337). Returning `{history, event}` from `checkpoint`
hands the caller both values but **does not force the caller to append the event** -- a driver that
discards the `event` field and uses only `history` has a rewritten history with no ledger record,
undetectable by the type system. The research doc itself concedes "DST then only verifies the digest
chain" (`RESEARCH-phase-core-dst-design.md:652-654`), i.e. enforcement is a test obligation, not a
type-level guarantee. **Action:** define a real content hash for `history_digest` (not length);
include the previous checkpoint/event digest in each `CheckpointTaken` event so the chain is
verifiable; expose a single atomic driver path `apply_checkpoint` that appends the event and applies
the history rewrite in one step (so there is no code path that takes the history without the event);
and require session-entry (`history_from_seed`) to validate the chain before accepting a resumed
`History`.

### R7. The conformance-kit acceptance criterion names no verifiable package, scenario, or command

Acceptance criterion 3 (lines 240-242) requires "failing conformance scenarios *before* the v0.3.0
fix and pass after," but the ADR names no package path, no scenario files, and no `ailang` commands
that would make that gate executable. A grep for `motoko_ext_conformance|ext_compaction_invalid_rejected|
system_messages_hidden_from_compactors` across `src`, `scripts`, and `Makefile` finds no current
implementation targets. The ABI track (lines 231-233) says only "ABI 3.0 + conformance kit 3.0 +
`compaction_ai` 0.3.0; gate: kit rejects v0.2.0, accepts v0.3.0; registry runs the kit." DST
ADR-001's R12 treated phantom CI targets (`make test_dst`) as a finding for the same reason: an
acceptance criterion that cannot be located cannot gate. **Action:** add concrete future
deliverables: the package path (e.g. `packages/motoko_ext_conformance/`), the scenario ids that
must fail-then-pass (name them -- they correspond to section 7.0's two live bugs), the exact
`ailang check/run/test` commands, and the `registry_generated.ail` probe that must execute the kit
for installed extensions.

### R8. The ABI v3 "constructor-only / zero code changes" migration claim is too broad for compactor packages

The ADR (lines 184-187) says ABI v3 migration is "constructor-only" and "packages that ignore ports
recompile with zero code changes." But the same bullet (lines 181-183) adds an `artifacts` field to
`Compacted`, which is a variant constructor -- any extension that constructs `Compacted(...)` breaks.
Verified: ABI 2.2.0 defines `Compacted(msgs: [Msg], note: string)` (`types.ail:124-127`); the
shipped compactor constructs it at `compaction_ai.ail:146-148` (`Compacted(compacted, "AI-summarized
...")`). Adding a field to a variant constructor is a source-level break for every compactor
package, not a "zero code change" recompile. The claim holds only for non-compactor packages whose
hooks don't construct `Compacted`. **Action:** narrow the claim to "non-compactor packages that do
not construct `Compacted` recompile with zero code changes"; explicitly list the constructor update
required for compactor packages (`Compacted(msgs, note, artifacts)` with `artifacts: Json` or
`Option[Json]`); and note that `compaction_ai` v0.3.0 is the first package that must make this
change.

### R9. "No registry hydration" is asserted for all DST but the conformance track requires it

Decision drivers (lines 66-67) say "Layer 0/1 DST tests must run with zero or minimal capabilities,
no network, no registry hydration." This holds for the pure-core L0/L1 tests (proven by
`smoke_ports_record.ail` running under `--caps IO` alone). But the ABI v3 track (lines 231-233)
requires "registry runs the kit for every package in `registry_generated.ail`" -- that gate needs
hydrated registry packages, the opposite precondition. DST ADR-001's constraints (lines 53-54) warn
that generated-registry imports can block Layer 1/3 until package hydration is fixed. The ADR does
not operationally separate these two gates. **Action:** split the acceptance criteria into
"core L0/L1 DST -- no registry hydration, `--caps IO` or less" and "registry/conformance --
hydration required, runs in core CI against hydrated extensions," and make the CI target names
reflect that separation so a no-hydration gate is not conflated with a hydration-required one.

### What is accurate

Every `file:line` citation in the ADR body verified against current source: the ten-effect row at
`agent_loop_v2.ail:1125`; `StepProvider` at `stub_step.ail:42`; persist-nudge marker scanning at
`:1062-1063`; the system message built into the init list at `rpc.ail:230-232` and forwarded
unfiltered to `dispatch_pre_step` at `:1154`; first-`Compacted`-wins at `ext/runtime.ail:143-164`;
the Bedrock correlation comment at `:1316-1333`; scratchpad hard-coded dispatch at `:868`;
mid-dispatch `readLine()` at `:769`; the `compaction_ai` v0.2.0 live bugs (`split_msgs` at `:101`,
`compact_with_ai` at `:126-148`, direct `std/ai.step` at `:89-91`, `Compacted` construction at
`:145-148`); the ABI 2.2.0 hook effect-row differentiation (`types.ail:128-142`); and
`conversation_loop_v2`'s history preservation at `:1520-1523`. All required artifacts reproduced
exactly: `ailang check`/`run --caps IO`/`test` pass on `sketch_vocabulary.ail`; the forge probes
fail with `IMP010` (`probe_sealed_forge`: `MkSealed`; `probe_sealed_name`: `Sealed`);
`probe_sealed_thread`, `probe_opacity_legal`, `probe_rec_structural`, and `probe_opacity_forge`
run/check as claimed; `scripts/smoke_ports_record.ail` checks and its `main` entry runs under
`--caps IO` alone while `main_live` fails with `effect 'Clock' requires capability`. The core
design thesis (functional core, imperative shell; ports-as-values; ledger-as-trace; sealed
transcript types) is sound and substrate-proven. The compaction-ephemerality-by-dataflow and
system-message-hiding gap findings are accurate and verified.

### Recommended pre-implementation actions

1. Re-ground Phase A's compaction constants against current `compaction.ail` (R1) -- the
   actual/estimate split and `OUTPUT_HEADROOM` do not exist in source.
2. Generate the production event inventory mechanically and fix the 28->29 gate before Phase B (R2).
3. Resolve the sealed-type co-location for `step_machine.ail` and `model_phase.ail` before creating
   `phase_vocab.ail` -- decide co-location vs. relaxed-validated-types (R3).
4. Specify the streaming ledger protocol before centralizing event emission (R4).
5. Add the approval-protocol contract and a scripted approval scenario before moving `readLine` (R5).
6. Define checkpoint digest-chain mechanics, atomic `apply_checkpoint`, and resume validation
   before blessing `TakeCheckpoint` (R6).
7. Turn the conformance kit and registry gate into concrete files, scenario ids, and commands (R7).
8. Narrow the ABI migration-cost claim and list constructor updates for compactor packages (R8).
9. Split no-hydration core DST gates from registry-hydrated conformance gates in CI (R9).

---

## Review Comments (Independent Review, Pass 3)

_Reviewer: Claude Opus 4.8 (`claude-opus-4-8`), 2026-07-02. Grounded against current source, the
pinned local toolchain (`ailang --version` → `AILANG v0.26.0`, commit `3b52a24`, built
`2026-07-02_15:03:57`), and the phase-core research/sketch artifacts (all re-run). This pass reads
the two prior passes (GPT-5 Codex, GLM 5.2) and does not restate their nine findings except to
confirm reproduction (see "Convergent with prior passes" below). The five findings numbered here are
the ones the prior two passes did not surface — three of them are defects **inside the artifacts the
ADR cites as its substrate proofs**, which is where an independent re-run earns its keep._

### R1. The one concrete `checkpoint` implementation destroys the system prefix — the exact bug class the design exists to prevent

D7's `checkpoint` is cited as substrate-proven ("the self-auditing checkpoint shape runs end-to-end",
`sketch/README.md:37-38`; ADR line 150-154). But the sketch's `checkpoint` rebuilds history as
`MkHistory([summary_msg])` where `summary_msg` is a single **assistant**-role message
(`sketch_vocabulary.ail:112-114`) — it discards the entire prior history including the pinned system
message. Re-running the demo confirms it: `history after cp: len=1` where the seed was
`[system, user]` (length 2), so the system message is gone. This is byte-for-byte the same failure
mode as `compaction_ai` v0.2.0's live bug #1 (system-prefix loss, research §7.0), which this
architecture is built to make unrepresentable. The research assigns checkpoint the obligation
"checkpoint output passes the same transcript-builder gate (system prefix preserved, pairing
preserved)" (`RESEARCH-phase-core-dst-design.md:677-679`) but defers it to v2
(`:695-697`), and the ADR's Phase C gates for checkpoint are only
`history_rewrite_requires_checkpoint_event` and `checkpoint_never_emitted_in_v1` (lines 227, 694) —
**neither asserts the rewritten history is a valid transcript.** So a checkpoint that corrupts the
system prefix or severs a tool pair passes every stated v1 gate, and "runs end-to-end" is doing more
rhetorical work than the artifact supports (running ≠ preserving invariants). **Action:** add a v1
transcript-validity obligation on `checkpoint` output (system-prefix-preserved, pairing-preserved,
ids-preserved) enforced by the same gate as ext compaction, and a scenario
`checkpoint_output_is_valid_transcript` that fails against the current sketch shape; and correct
`sketch/README.md:37-38` so "runs end-to-end" is not read as "preserves the checkpoint obligations."

### R2. The projection artifact cited as the byte-compat proof actually emits four non-production event names and mis-maps `ProviderResult`

The ADR says `to_schema_v1` "preserves the existing production wire contract (28 event types … )
consumed by the TUI and eval harnesses" and that "ADR-001 canonical trace names map 1:1 to
constructors" (lines 123-126). Re-running the sketch, the projection emits **four `type` strings that
are not in the 28-event production inventory it lists**: `provider_call_prepared`,
`loop_totals_updated`, `history_checkpoint`, and `ext_compaction_rejected`
(`sketch_vocabulary.ail:265,273,274,270`; demo prints `{"type":"history_checkpoint",…}`). These are
DST-canonical / new names, not production schema-v1 names (cf. the inventory at
`sketch_vocabulary.ail:221-228`, which contains none of them). Worse, `ProviderResult` maps to
`"thinking"` (`:266`), not `provider_result` as the comment at `:230-235` claims. So the single
artifact the ADR points to as evidence that projection *preserves* the wire contract in fact
demonstrates a projection that (a) is a **superset** — it injects new event types into the same JSONL
stream the TUI reads — and (b) contains a mis-route. "Byte-compatible with current TUI/eval consumers"
(line 218) cannot be asserted from this artifact; it is untested whether the TUI tolerates unknown
`type` values interleaved with the 28 it knows. This is distinct from the prior passes' count finding
(28 vs 29): the count is a *membership* error; this is a *direction* error (the projection adds names
and mislabels one). **Action:** separate the two wire contracts explicitly — the production schema-v1
stream (the 28/29 names the TUI consumes) vs. the DST/ledger canonical names — and state which stream
`to_schema_v1` targets; fix the `ProviderResult → thinking` mis-map; and make the Phase B gate assert
the projection's emitted `type` set is a **subset** of (not merely overlapping with) the generated
production inventory.

### R3. The rejection of a `continuation` field is not substrate-proven — the sketch smuggles one and never exercises re-derivation

The ADR rejects a `continuation` field in `PhaseResult` on the grounds that "the step machine
re-derives the next decision from applied state" (lines 130, 270; Q4, `sketch/README.md:62-64`). The
cited proof is `decide` in `sketch_vocabulary.ail:285-294` — but that `decide` **only ever returns
`CallModel`** (or `Fail`); it never returns `RunTools`, `AwaitApproval`, `TakeCheckpoint`,
`InjectUserMessage`, or `Finalize`. The load-bearing re-derivations — "the last model result carried
tool_calls ⇒ `RunTools`" vs "… carried a final answer ⇒ `Finalize`" — are exactly the transitions a
`continuation` field would have carried, and none is demonstrated. Tellingly, `StepState` carries a
field `pending_decision_seed: string` explicitly annotated "placeholder for continuation-ish data"
(`sketch_vocabulary.ail:153`) — the artifact reintroduces continuation state under another name while
the ADR claims it was eliminated. Whether the post-model decision is truly re-derivable from
`StepState` (which has no typed field for "last response kind" or "pending tool calls" beyond digging
into the sealed `History` tail) is unproven. Per the review constraints this attacks the
*justification* of a settled decision with artifact evidence, not the decision itself. **Action:**
either extend the sketch's `decide` to derive `RunTools`/`Finalize` from `StepState` (retiring
`pending_decision_seed`), proving re-derivation, or add the typed state field(s) re-derivation needs
and drop the "no continuation" claim to "continuation is state, not a separate result field."

### R4. Confirmed and sharpened: the compaction actual/estimate split the ADR builds on no longer exists in source

I independently reproduce Pass-2 R1: `src/core/compaction.ail` has a **single** 70/85/95 tier table
with emergency at ≥95 (`compaction.ail:136-138`), no `compact_step_actual`, no `OUTPUT_HEADROOM`, and
no `75000` literal anywhere in `src/core`; the only entry point is
`compact_step_with_limit`/`compact_step` (`:134,:142`), and `grep -n 'actual\|estimate\|
last_input_tokens' src/core/compaction.ail` finds only the tier *comments*, not an actual-token code
path. The additional consequence the prior pass did not draw: this ADR opens by claiming it "resolves
[DST ADR-001's] review comments R4, R5, R7, R8" (line 16), but DST R5's remedy was "export
`ACTUAL_TIERS={60,75,85}` and `ESTIMATE_TIERS={70,85,95}`" — **half of which no longer has a
referent.** So the ADR inherits a resolution built on a premise that has since been deleted from
source, and Phase C's `actual_tokens_drive_next_step` / `emergency_exhaustion_estimate_gated`
scenarios (lines 224-227) are unrepresentable against the current single-tier compactor. **Action:**
before Phase A, resolve whether the actual-token path was intentionally collapsed (update DST ADR-001
R5/R15 and this ADR's line-16 claim accordingly) or regressed and must be restored; do not carry the
`actual_tokens_*` scenarios into Phase C until the source path they name exists.

### R5. Minor: the "~30 scattered emit call sites" figure understates the actual surface by ~60%

The Context section motivates the rewrite partly on "~30 scattered
`emit_event`/`emit_run_summary`/`emit_stream_chunk` call sites" (line 51; research §1 "~30 inline").
Actual counts in `src/core/agent_loop_v2.ail`: **39** `emit_event`, **7** `emit_run_summary`, **2**
`emit_stream_chunk` = **48** call sites (plus 4 direct `emit_json`). The argument is if anything
stronger than stated, but a load-bearing motivating number should be right. **Action:** replace "~30"
with the measured figure (48 emission call sites), or cite the exact command so it stays honest as the
file changes.

### Convergent with prior passes (independently reproduced, not re-numbered)

I re-ran every artifact and re-checked every prior-pass citation; the following prior findings hold
and I reproduce their grounding, so they should be treated as confirmed by a third independent tool,
not as single-reviewer opinion: sealed-type co-location extends to `step_machine.ail`/`model_phase.ail`
(probes fail `IMP010`: `MkSealed`, `Sealed`; `probe_sealed_thread` runs) — Pass-1 R1 / Pass-2 R3;
the 28→29 event membership error incl. omitted `reasoning_delta` (`agent_loop_v2.ail:265`) — Pass-1
R2 / Pass-2 R2; live-streaming timing cannot be byte-compatible with post-call batched emission
(`emit_stream_chunk` fires per-chunk mid-call at `:249-270`, callback at `:1201`) — Pass-1 R3 /
Pass-2 R4; the checkpoint digest is length-based and forgeable (`sketch_vocabulary.ail:52-53`; demo
`before_digest:"h2"`) and the `{history,event}` return does not force append — Pass-1 R4 / Pass-2 R6;
`AwaitApproval`/`ApprovalRequest` lacks `stream_id`/`call_id` that the live flow uses
(`agent_loop_v2.ail:760-790` emits `tool_pending` with `stream_id`+`id` then blocks on `readLine`) —
Pass-1 R5 / Pass-2 R5; conformance-kit acceptance names no package/scenario/command
(`rg motoko_ext_conformance` empty) — Pass-1 R6 / Pass-2 R7; ABI v3 "constructor-only" is false for
compactors because `Compacted(msgs, note)` gains a field (`types.ail:124-127`;
`compaction_ai.ail:145-148`) — Pass-1 R7 / Pass-2 R8; and "no registry hydration" conflates the
core-L0/L1 gate with the registry-wide conformance gate — Pass-1 R8 / Pass-2 R9.

### What is accurate

The design thesis and its harder-to-check claims survive independent attack. Every ADR-body
`file:line` citation I checked is correct: the ten-effect row at `agent_loop_v2.ail:1125`;
persist-nudge marker scanning at `:1062-1063`; the system message built into the init list at
`rpc.ail:230-232` and forwarded unfiltered to `dispatch_pre_step` at `:1154`; the mid-dispatch
approval `readLine` at `:769` (preceded by the `tool_pending` emit at `:760-766`); scratchpad
hard-coded dispatch at `:868`; ephemerality-by-dataflow-accident (recurses on `msgs ++
[assistant_msg]` at `:1250`); `conversation_loop_v2` history preservation via `run_v2_from_messages`
(`:1518-1523`). The ABI substrate claims are exactly right: `on_describe_tools`,
`on_build_system_prompt`, `on_tool_policy` are already pure and `on_budget_plan` is `{Env, FS}` in
2.2.0, only the four "real work" hooks carry the 9-effect row (`types.ail:128-142`) — so D6's "no
row changes" justification is well-grounded. All substrate proofs reproduce on v0.26.0: sketch
`check`/`run`/`test` pass; forge/name probes fail `IMP010` while `probe_sealed_thread`,
`probe_opacity_forge`, `probe_rec_structural` behave as documented; `smoke_ports_record.ail` runs its
fake entry under `--caps IO` while `main_live` fails with `effect 'Clock' requires capability` —
confirming the caps-at-performance-time result (R7-killer) that the whole L1 story rests on. The
functional-core/imperative-shell direction, ports-as-values, ledger-as-trace, and
compaction-ephemerality-and-system-hiding-by-construction are sound and substrate-proven; the two
`compaction_ai` v0.2.0 live bugs are real and correctly characterized.

### Recommended pre-implementation actions (additive to prior passes)

1. Add a v1 transcript-validity gate on `checkpoint` output and a scenario that fails the current
   system-prefix-dropping sketch shape; stop citing "runs end-to-end" as invariant evidence (R1).
2. State which wire contract `to_schema_v1` targets, fix the `ProviderResult → thinking` mis-map, and
   make the Phase B gate assert `subset-of` the generated production inventory (R2).
3. Prove decision re-derivation in the sketch (or add the typed state fields it needs) before rejecting
   a `continuation` field; retire `pending_decision_seed` (R3).
4. Reconcile the ADR's "resolves DST R5" claim and the `actual_tokens_*` scenarios with the current
   single-tier `compaction.ail` — the actual/estimate split is gone from source (R4).
5. Replace the "~30 emit sites" figure with the measured 48 (R5).

---

## Author Response & Disposition Log

_Author: Claude Fable 5 (authoring session), 2026-07-03. Every finding was re-verified
empirically before disposition — greps re-run, all sketch/probe artifacts re-executed, and one
NEW probe written where the reviews' shared assumption needed testing. Dispositions: ACCEPTED
(defect real, fix applied), PARTIALLY ACCEPTED (real defect, but the finding's conclusion or
remedy needed correction), REFUTED (with evidence). Converged findings are dispositioned once,
citing all passes._

### Converged findings

**Sealed-type co-location (P1-R1, P2-R3) — PARTIALLY ACCEPTED; conclusion REFUTED by new
probe.** The contradiction both passes identified was real: the ADR's "`ProviderPayload` is the
only type `model_phase` accepts" required naming an unimportable type. But both passes'
conclusion — that `step_machine.ail`/`model_phase.ail` cannot be separate modules — rested on
an untested assumption: neither pass (nor the original probes) tested whether a separate module
can consume **exported wrapper types** that embed/carry sealed types. New probes
`sketch/vocab_probe.ail` + `sketch/probe_consumer_decide.ail` (2026-07-03) settle it: a
separate module imports `StateP { hist: SealedH }` and `DecisionP = CallModelP(SealedP)`,
defines `decide` over them, constructs and pattern-matches decision variants — runs clean;
sealing holds transitively (payloads obtainable only via ops). **Fix applied**: co-location
scope corrected to definers-only (Decision detail 4); `ModelRequest` wrapper introduced for the
model phase; the module table stands.

**Event inventory 28 → 29, `reasoning_delta` omitted (P1-R2, P2-R2, sharpened by P3-R2) —
ACCEPTED.** Re-verified: `reasoning_delta` at `agent_loop_v2.ail:265`, 27 `emit_event` names.
**Fix applied**: sketch inventory corrected to 29 with the regeneration command inline;
`StreamDelta` constructor + projection added (covers both delta kinds); Phase B gate now
compares against the mechanically generated inventory.

**Streaming timing vs. single-point emission (P1-R3, P2-R4) — ACCEPTED.** The finding is
correct that post-call batching cannot reproduce mid-call delta timing. **Fix applied**: the
ADR now specifies the driver-issued **ledger append handle** (a port scoped to stream-delta
events, arrival-order writes, driver-constructed so single logical authority holds) and a Phase
B streaming byte-parity test.

**Checkpoint enforcement gaps (P1-R4, P2-R6) — ACCEPTED.** The `{history, event}` return
indeed does not force the append, and the sketch digest is a placeholder. **Fix applied**:
normative mechanics added (content-hash digest; previous-digest chaining in `CheckpointTaken`;
atomic `apply_checkpoint` as the driver's only rewrite path — shape now proven in the sketch;
seed-time chain validation in `history_from_seed`).

**`AwaitApproval` protocol underspecified (P1-R5, P2-R5) — ACCEPTED.** **Fix applied**:
`ApprovalRequest` extended (`default_allow`, `stream_id`, suspended `remaining` plan tail) in
sketch and ADR; event-before-read ordering, default resolution, and RunTools-reissue semantics
specified; scripted TUI approval scenario added to Phase C deliverables.

**Conformance gate names no targets (P1-R6, P2-R7) — ACCEPTED.** **Fix applied**: package
path, four scenario ids, commands, and the registry probe named in Decision detail 6 as future
deliverables, mirroring the remedy DST ADR-001 R12 demanded.

**ABI "constructor-only / zero code changes" too broad (P1-R7, P2-R8) — ACCEPTED.** The
`Compacted` field addition is a source break for compactor packages. **Fix applied**: claim
narrowed to non-compactor packages; compactor constructor update explicitly listed with
`compaction_ai.ail:146-148` as the affected site.

**No-hydration conflated with registry gate (P1-R8, P2-R9) — ACCEPTED.** **Fix applied**:
gate-separation paragraph added (core DST gates vs. registry/conformance gates, distinct CI
target classes); acceptance criteria 3 and 4 now name their gate class.

### Pass-2/Pass-3 compaction finding

**Actual/estimate split gone from source (P2-R1, P3-R4) — ACCEPTED; highest-value finding of
the review.** Re-verified 2026-07-03: single 70/85/95 ladder at `compaction.ail:134-141`; no
`OUTPUT_HEADROOM`, no `75000`, no `last_input_tokens` anywhere in `src/core`. The ADR had
inherited DST ADR-001 R5's constants from its 2026-06-27 grounding without re-verifying against
moved source — exactly the staleness class this project's own discipline should have caught.
**Fix applied**: Phase A constants re-grounded (single table); `OUTPUT_HEADROOM`/60-75-85
struck; `actual_tokens_*` scenarios deferred with reinstatement condition; new Open Question 4
(reintroduce-or-amend, with git-history read); relates-to note amends the "resolves R5" claim;
sketch `CompactionPolicy` re-grounded; research doc corrected.

### Pass-3 findings

**P3-R1 (sketch checkpoint destroys system prefix) — ACCEPTED; the sharpest catch of the
review.** The original sketch's checkpoint reproduced the exact bug class (system-prefix loss)
the architecture exists to prevent, and no stated v1 gate would have caught it. **Fix
applied**: sketch checkpoint now pins and preserves the system prefix (demo re-run:
`len=2 (system prefix retained)`); transcript-validity of checkpoint output promoted to a v1
obligation with scenario `checkpoint_output_is_valid_transcript` (Phase C list + Decision
detail 4e); `sketch/README.md` wording corrected ("runs" ≠ "preserves invariants").

**P3-R2 (projection emits non-production names; `ProviderResult → thinking` mis-map) —
PARTIALLY ACCEPTED.** The direction error was real: the ADR claimed the projection "preserves
the existing production wire contract" while the artifact injected four new names. **Fix
applied**: two name classes made normative ([prod] = byte-compatible subset; [NEW] = additive,
tolerance-gated), constructors annotated in the sketch, Phase B gate asserts subset for [prod].
On the "mis-map": REFUTED as a routing error — production's `thinking` event *is* the
provider-result event (there is no production `provider_result`), so `ProviderResult →
"thinking"` is the correct [prod] projection; the defect was the sketch comment implying
canonical names appear on the wire. Comment rewritten to state the two-layer naming explicitly.

**P3-R3 (continuation rejection not proven; `pending_decision_seed` smuggles it) —
ACCEPTED.** Fair hit: the claimed proof never exercised the load-bearing transitions. **Fix
applied**: `pending_decision_seed` retired; typed re-derivation fields added
(`pending_tool_calls`, `last_finish_reason`, `last_response_text`); `decide` extended and the
demo now drives `CallModel → RunTools → Finalize` purely from applied state (re-run output:
`d0=CallModel d1=RunTools(1) d2=Finalize(model_stop)`). The ADR claim is retained in its
proven form: continuation is state, not a result field.

**P3-R5 (~30 emit sites → 48) — ACCEPTED.** Re-measured: 39 + 7 + 2 (+4 `emit_json`).
**Fix applied**: Context states 48 with the measurement method.

### Artifacts re-verified after all fixes (2026-07-03)

`sketch_vocabulary.ail`: check ✓, run ✓ (new demo output above), test ✓.
`vocab_probe.ail`/`probe_consumer_decide.ail`: run ✓. All prior probes unchanged and behaving
as documented. `scripts/smoke_ports_record.ail`: unchanged, previously verified by all three
reviewers.

---

## Plan-Authoring Findings & Dispositions (2026-07-03)

_Author: Claude Fable 5 (Phase-A plan-authoring session). These findings are the output of
the fresh-session ADR-completeness test prescribed by `NOTE-plan-authoring-session-choice.md`:
a session with no ADR-authoring context wrote `PLAN-phase-a-pure-foundations.md` from the
committed documents alone, re-verifying every citation against HEAD (`8227053`) and re-running
every artifact. Discrepancies became findings G1–G7 (full evidence in the plan's "ADR gaps
found"); dispositioned here with operator sign-off; body fixes applied same day. No finding
re-opens D1–D9._

- **G1 (`transcript.ail` does not exist at HEAD) — ACCEPTED, doc fix.** The ADR called the
  vocabulary module "`transcript.ail`'s successor" and Open Question 1 offered "expanding
  `transcript.ail`"; no such file exists — the helpers live in `agent_loop_v2.ail:361-501`.
  **Fix applied**: Decision detail 4 reworded; Open Question 1 closed with the plan's
  decision (`src/core/phase_vocab.ail`, transcript builders included); module table updated;
  research doc §7.1 case 7 corrected.
- **G2 (measurement-primitive naming imprecision) — ACCEPTED, doc fix.** "`estimate_tokens`,
  `usage_percent` … in `compaction.ail`" named the wrong symbols: `compaction.ail` exports
  `estimate_tokens_messages` / `usage_percent` / `usage_percent_with_limit`;
  `estimate_tokens` is a different, `[Msg]`-typed function in `context_usage.ail:12`.
  **Fix applied**: names corrected in Decision detail 4, Phase A, and research §7.5; the D9
  shared measurement surface is stated as the limit-parameterized variants (see G3).
- **G3 (model-name-keyed pure compaction path is dead at HEAD) — ACCEPTED; the load-bearing
  finding.** `context_limit_for` returns 0 for every model — intentional: commit `a7589b8`
  ("Moved context usage into model catalog", 2026-06-24) moved limits into the catalog
  (`catalog_context_limit_for`, `{Env, FS}`); production compaction takes the limit
  explicitly (`agent_loop_v2.ail:1149→1171`). Consequences dispositioned: (a) fact recorded
  (research §11 fact 19); (b) `scripts/smoke_v2_compaction_tiers.ail` — red at HEAD by its
  own pass criterion while exiting 0 — **fixed same day**: explicit-limit calls
  (`compact_step_with_limit`, hermetic, `--caps IO`), `exit(1)` on failure; the fix also
  exposed that the old tier-3 expectation (Err at 97% tool-heavy load) was itself wrong —
  emergency elision recovers; the smoke now tests both emergency-recovers and
  exhausted-errs; (c) wrapper retirement (`compact_step`, `usage_percent`,
  `try_emergency_compaction`, `context_limit_for`) added to Phase B deliverables, riding the
  D9 ladder relocation.
- **G4 (no-diff gate nondeterminism unspecified) — ACCEPTED, doc fix.** The event stream
  contains volatile fields (`duration_ms`; a `now()`-derived session-id fallback), so
  "no event-stream diff" was not executable as stated. **Fix applied**: Phase A gate restated
  as byte-identical modulo declared volatile fields (session id pinned via
  `MOTOKO_SESSION_ID`, `duration_ms` normalized — empirically the complete volatile set at
  HEAD, proven by pinned-session double-runs in the plan); Phase B's byte-compatible-subset
  gate inherits the definition.
- **G5 (constants enumeration incomplete) — ACCEPTED, doc fix.** The ladder's inline
  literals include the emergency keep-lasts 3/1 (`compaction.ail:111,:116`) and emergency
  re-checks (`:113,:118`) beyond the cited `:134-141` table. **Fix applied**: Phase A
  enumerates the full seven-export set.
- **G6 ("existing smokes" has no canonical runner) — ACCEPTED.** No Make/CI target runs
  `scripts/smoke_v2_*.ail`; some smokes need a live model; one was silently red (G3b) — as a
  gate, "existing smokes green" was unexecutable. **Fix applied**: the Phase A gate now names
  its executable artifacts (`scripts/phase_a_event_parity.sh` + `make smoke_parity`,
  to-be-created in plan WI-0 — future deliverables named now, mirroring Decision detail 6's
  no-phantom-gates remedy).
- **G7 (two extracted paths not e2e-coverable) — ACCEPTED, deferred deliverable.**
  `envelope_to_tool_message` and the `Handled`-path literals need an extension fixture
  (`ContinueWithFeedback` / `Handled`) no deterministic smoke can supply today. Disposition:
  Phase A pins them with golden-value pure tests (plan WI-3); a minimal in-repo test
  extension is added to Phase B deliverables so e2e parity coverage exists before emission
  rewires.

- **G8 (post-disposition, plan self-review 2026-07-03: 13 of 32 `scripts/*.ail` fail
  `ailang check` at HEAD) — ACCEPTED, with one sub-claim retracted.** The class: stale
  `ExtensionHooks` record literals predating the ABI 2.1/2.2 field additions
  (`on_describe_tools`, `on_pre_step`) — G3's staleness family, fleet-wide. Invisible
  because no CI target checks or runs `scripts/` (G6); each file fails loudly the moment
  anything executes it. **Retraction (same day):** the review initially also reported an
  AILANG substrate defect — "`ailang run` exits 0 on type errors" — refuted by a minimal
  repro (check and run both exit 1); the rc=0 readings were the review's own `$?`-through-
  a-pipeline measurement artifact. No upstream filing warranted. Post-mortem:
  `NOTE-ailang-run-exit-code-false-alarm.md`. Disposition: the plan's parity harness
  check-gates its own smoke list, runs under `set -euo pipefail` (the actual lesson), and
  fails on zero-event full-loop output; its two broken members
  (`smoke_v2_pending_full_loop`, `smoke_v2_handle`) are repaired in WI-0; the remaining 11
  broken scripts and a `check_scripts` CI target are flagged as repo hygiene outside
  Phase A (full list in the plan's G8 entry).

Cross-repo amendment applied the same day: DST ADR-001 R5/R15 (and its "What is accurate"
tier-facts line) carry dated notes that the actual/estimate split they were grounded on was
removed from source (P2-R1/P3-R4 here), with the export remedy redirected to the current
single-table reality.

---

## Phase-B Plan-Authoring Findings & Dispositions (2026-07-03)

_Author: Claude Fable 5 (Phase-B plan-authoring session). Second application of the
fresh-session ADR-completeness test: a session with no prior project context wrote
`PLAN-phase-b-phase-results.md` from the committed documents plus the Phase A commits,
re-verifying every citation against post-Phase-A HEAD (`d0d5b7e`) and re-running the
instruments. Discrepancies became findings G-B1–G-B7 (full evidence in the plan's "ADR gaps
found"); dispositioned here with operator sign-off ("I will follow your recommendations",
2026-07-03); body fixes applied same day. No finding re-opens D1–D9._

- **G-B1 ("each stage ledger-recorded" collides with the closed [NEW] whitelist) —
  ACCEPTED, doc fix.** D9's chain text promised per-stage records, but no admitted [NEW]
  name can carry a `PassThrough` stage and Phase B has no in-memory ledger. **Fix applied**:
  Decision detail 4 and research §7.5 now scope wire recording to applied/rejected stages
  (`compaction_extension` / `ext_compaction_rejected`); full stage records arrive with
  Phase C's in-memory ledger (or a future admitted name).
- **G-B2 (as-built `to_schema_v1` [prod] arms not byte-compatible) — ACCEPTED, no doc
  change.** Expected for a sketch-seeded scaffold; the mismatch list lives in the plan's
  grounding and defines WI-1's work. Recorded so no reader mistakes the scaffold for the
  contract.
- **G-B3 ("behavior-preserving relocation" is result-level, not byte-level) — ACCEPTED,
  doc fix.** Three residues: exhaustion-reason wording changes; genuinely-applied elision
  gains `compaction_extension` occurrences (type-set subset holds); compactors measure the
  segment under an effective-limit compensation (tier `t` fires at total usage `t + s(1−t)`
  for pinned-prefix share `s`; exact at `s = 0`). **Fix applied**: Phase B wording amended;
  the plan's expected-diff tables are the normative enumeration.
- **G-B4 (G7's fixture wording under-covers the envelope path) — ACCEPTED, doc fix.**
  `envelope_to_tool_message`'s only call site is the response-intercept path, so the
  fixture needs an `InterceptHandled` arm. **Fix applied**: Phase B G7 wording amended.
- **G-B5 (system messages remain visible via `ExtCtx.history_slice`) — ACCEPTED, deferred
  to the ABI v3 design.** Deliverable 4 closes the compaction *input* path (and WI-5's
  re-pin makes prefix corruption impossible regardless of compactor output); read-only
  visibility through `history_slice` is an ABI-surface question for the v3 `ExtCtx` work.
  No body fix; recorded here as ABI-track input.
- **G-B6 (emission-surface accounting: sites vs. grep hits; `rpc.ail` `v2_mode` and
  `ai_compat` outside the inventory) — ACCEPTED, doc fix.** **Fix applied**: Decision
  detail 3 states the inventory's scope (`agent_loop_v2`'s stream). The 48-figure stands
  as measured (grep hits incl. definitions; the plan records the call-site truth 38+6+1+3).
- **G-B7 (`motoko_core` path-dependency shape unproven for bundled extensions) — RESOLVED
  by probe, same session, positive.** Three substrate facts established (throwaway probe
  package, deleted after): the path target must be the `.packages/motoko_core` sync mirror
  (the resolver roots module lookup at the path target); `[exports] modules` gates
  cross-package imports; transitively imported modules must also be exported. The
  in-package-duplication fallback is retired. Residual for the ABI track: publishing
  `motoko_ext_compaction_structural` to the registry will need a published `motoko_core`
  (or vendored primitives) — a committed manifest cannot depend on a gitignored mirror
  outside this repo.
