# Research: a phase-oriented core designed for Deterministic Simulation Testing

Date: 2026-07-02
Status: Research / design discussion record (pre-ADR)
Pinned toolchain: AILANG **v0.26.0** (commit `3b52a24`); `ailang.lock` → `ailang_version: "v0.26.0"`

Relates to:
- `../003_CSP_core_refactor/NOTE-why-not-csp-now.md` — the direction note this project executes:
  phase-oriented core instead of CSP-first, on v0.26.0
- `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` — DST is a first-class
  design constraint here, not a later add-on; this doc resolves several of its review comments
  (R4, R5, R7, R8, R11) by construction
- `scripts/smoke_ports_record.ail` — substrate smoke validating the Ports design (all green)

---

## TL;DR

The phase-oriented core (from the why-not-CSP note) and DST (from ADR-001) are the **same design
pressure seen from two sides**: a functional core with effects pushed to a thin driver at the rim.
Designed that way, DST is a property of the shape, not a bolt-on.

Decisions settled in this research (with the operator, 2026-07-02):

1. **Full inversion**: the step machine is pure and returns decisions-as-data; the driver executes
   them (Phase C of the migration).
2. **Ports record** for all nondeterminism sources — substrate-validated by
   `scripts/smoke_ports_record.ail` (no workarounds needed; see §4 for the two parser gotchas and
   the caps-at-performance-time result that resolves ADR-001 R7).
3. **Compaction**: pure projection pipeline `History -> ProviderPayload` owned by
   `transcript.ail`, ephemeral by construction, with an explicit ledger-recorded `Checkpoint`
   seam. Pressure-tested in §7; design settled, one verified live gap found (§7.0).
4. **`agent_loop_v2.ail` residual logic**: every squatter mapped to exactly one home (§5);
   nothing stays "in the loop" because there is no loop file anymore.

Later settled same day: **ABI v3 scope** (D6 — ports-in-ExtCtx + artifacts channel, no row
changes, conformance kit as separate package), the **`Checkpoint` seam** (D7, elaborated in
§7.4 — blessed in v1 types with a never-emit cage), and the **conformance kit details** (D8,
elaborated in §6.1 — two-module package, caps-as-conformance, fault-isolation split). No open
decisions remain; this research is ready to seed the ADR.

---

## 1. Context and thesis

`NOTE-why-not-csp-now.md` reverted the Phase-1 CSP implementation and prescribed a
phase-oriented core: deterministic step machine, explicit phase contracts, strict transcript
builder, append-only event ledger, normalized envelopes, stream islands only where the substrate
is strong. ADR-001 independently requires: deterministic modeling of external contracts, real
production transition code driven by scripted fakes, boundary observations recorded into
normalized traces, reusable invariants over those traces.

These converge. The note's `PhaseResult` **is** ADR-001's trace record; the note's ledger **is**
the normalized trace; the note's envelopes **are** the recordable boundary payloads; the note's
phase contracts **are** the DST seams. The organizing principle for both is
**functional core, imperative shell**:

- a **pure step machine** makes every decision as a data value;
- **phases** perform effects only through injected **ports** and return `PhaseResult` values;
- a thin **driver** owns the real effect row, executes decisions, appends the ledger.

### Evidence that the current shape is the problem

- `loop_v2`'s effect row is `{AI, FS, Process, IO, Env, Net, SharedMem, Clock, Stream, Trace}`
  (`agent_loop_v2.ail:1125`). Every test driving the real loop must satisfy all ten effects even
  when the provider is scripted — ADR-001 review comment R7 in one line.
- Event emission is scattered: ~30 inline `emit_event`/`emit_run_summary`/`emit_stream_chunk`
  call sites inside the loop. Replay and deterministic trace ordering are impossible to reason
  about.
- The existing DST seam (`StepProvider` with `Scripted`, `src/core/test/stub_step.ail:42`,
  used by `run_v2_with_stub` at `agent_loop_v2.ail:1693`) covers **only the model call**. Tools,
  extension hooks, clock (`now()` at `:1710`), and mid-loop env reads
  (`MOTOKO_RETRY_STREAM_ERROR` at `:1216`) are all live effects.
- The architecture punishes state so hard that features store state **steganographically in the
  transcript**: persist-nudge counts its own uses by scanning message history for a magic marker
  string, because there is "no new loop_v2 state to thread through its 16 recursive call sites"
  (comment at `agent_loop_v2.ail:1063`).

---

## 2. Design principles

### P1. The step machine is pure — decisions as data

`step_machine.ail` is a pure function `(StepState) -> StepDecision`, with decisions like
`CallModel(ModelEnvelope)`, `RunTools(ToolPlan)`, `AwaitApproval(call, default)`,
`InjectUserMessage(msg)`, `Compact(tier)`, `Checkpoint(..)` (see §7.4), `Finalize(reason)`,
`Fail(err)`. The driver executes decisions and feeds results back as data.

Consequences: Layer 1 DST drives the pure machine with scripted results and needs **zero**
effects — no caps, no sandbox, no registry hydration. Budget/cost/retry policy (currently inline
`if` chains at `loop_v2:1126-1147`) becomes Z3-addressable, connecting to ADR-001's
Z3-complementarity section.

**Settled: full inversion** (operator decision, 2026-07-02). A softer variant (phases return
`PhaseResult` but the driver keeps the current recursive control flow) is used only as the
intermediate migration state (§8 Phase B), not the end state.

### P2. The ledger IS the DST trace — one artifact, not two

Phases return `ledger_events` inside `PhaseResult`; exactly one place (the driver) appends and
emits. Consequences:

- **ADR-001 R8 dissolves** ("recorder must not change production behavior"): the ledger is
  always-on production telemetry with a single emission point; the DST recorder is a sink over
  it, not a test-only seam.
- **ADR-001 R4 resolves** (trace format blocks Phase 1): ledger events are typed AILANG records
  in memory (what invariants consume), with a JSONL projection at the driver boundary (what
  failure reports print).
- ADR-001's canonical trace events (`provider_call_prepared`, `provider_result`,
  `tool_policy_decision`, ...) become the ledger event vocabulary — designed once, used by
  production and DST alike.
- Deterministic event ordering falls out of single-point emission; replay becomes possible.

```text
PhaseResult {
  state_delta,       -- e.g. totals, telemetry, ext compaction artifacts (§7.3)
  transcript_delta,  -- validated by transcript.ail only
  ledger_events,     -- the trace
  cost_delta,
  continuation       -- data consumed by the step machine
}
```

### P3. Ports for every nondeterminism source

Generalize the proven `StepProvider` pattern to a record of function values covering: model step,
tool executor, extension hooks, clock, env/config reads, approval input. The driver builds live
ports once at session init; DST injects fakes. Config/env reads happen **once** at session init
and become policy data (no more `getEnvOr` mid-loop). Clock values enter as `StepState` fields —
resolving ADR-001's "no virtual time in `std/clock`" constraint: only the driver touches `Clock`.

**Settled: Ports record** (operator decision, 2026-07-02), substrate-validated — see §4.
Scripted-state style: external threading (script state lives in `StepState`; ports stay stateless
values), not self-replacing recursive ports, although both are expressible (§4).

#### Definition: what a port is (and is not)

A **port** is a function passed in as a value, standing in the place where code would otherwise
name an effectful operation directly. The term is from ports-and-adapters (hexagonal
architecture): the *port* is the function signature the core needs fulfilled; an *adapter* is
whatever gets plugged in. No language feature is involved — it is a plain record field with a
function type. Precedents already in production: `ExtensionHooks` (a record of effectful
function fields) and `StepProvider`'s `Scripted` variant (a single-purpose port in variant
clothing).

The contrast, concretely. Hardwired (today, `compaction_ai.ail:89-91` — no seam; cannot be
tested without a provider, observed, or replayed):

```ailang
func summarize_with_ai(prompt: string, model: string) -> string ! {AI, ...} {
  match step(model, msgs, []) { ... }        -- std/ai.step, the real thing, always
}
```

Ported (the callee is identical in production and DST; only the record passed in differs):

```ailang
type ExtPorts = {
  ai_step:   (string, [Msg]) -> Result[StepResult, AIError] ! {AI},
  http_get:  (string) -> Result[string, NetError] ! {Net},
  clock_now: () -> int ! {Clock}
}

func summarize(ports: ExtPorts, prompt: string, model: string) -> string ! {AI} {
  match ports.ai_step(model, [user_msg(prompt)]) { ... }
}

-- production adapter (driver builds once at session init):
func live_ai_step(model: string, msgs: [Msg]) -> ... ! {AI} { step(model, msgs, []) }
-- DST adapter (scenario builds instead — pure, deterministic, no network):
func fake_ai_step(model: string, msgs: [Msg]) -> ... { Ok(canned_summary_result()) }
```

Three properties make this the right tool (all verified by `scripts/smoke_ports_record.ail`, §4):

1. **It is just a value.** No mocking framework, no effect-handler interception (which AILANG
   lacks and ADR-001 refuses to bet on).
2. **The effect row stays honest but costless when faked.** The callee still declares `! {AI}` —
   the type system tracks what *could* happen — but capabilities are charged when an effect is
   *performed* (§4 Q5), so a test wiring `fake_ai_step` needs no `AI` cap, network, or sandbox.
3. **Ports are stateless; scripts thread state.** A scripted port returning different answers on
   successive calls doesn't mutate — its script lives in `StepState` and advances by threading,
   like `Scripted(rest)` in `stub_step.ail` today.

Beyond testing: because every effect flows through a known function value, the driver can
**wrap** live adapters with a recorder — same signature, appends a ledger event, delegates.
That is how extension effect calls enter the DST trace
(`extension_effect{ext_id, port, args_digest}`) without the extension knowing or cooperating.

Fencing the concept — a port is **not**: a CSP channel or process (no concurrency; calls are
ordinary blocking calls); an effect handler (nothing intercepted — the callee cooperates by
accepting the argument); or a service locator (nothing global — the record is passed explicitly
down the call tree, which is exactly what makes replay deterministic). "Ports in `ExtCtx`" (§6)
means precisely: `ExtCtx` gains one field holding this record; the core fills it with live or
recorder-wrapped adapters; a DST harness fills it with fakes; extensions call
`ctx.ports.ai_step(...)` instead of `std/ai.step(...)`.

### P4. The transcript builder is a pure module and the only provider-message gate

`transcript.ail` is the single place provider-facing messages are built, enforcing: no empty tool
ids; exactly one tool result per tool call; original ids preserved; tool_use/tool_result
correlation (the Bedrock rule, see §5 hybrid-bash); no live chunks in the model transcript;
malformed state becomes a valid error result, not an invalid transcript. It also owns the
compaction projection (§7). Invariants are L0-testable and the best Z3 candidates in the refactor.

---

## 3. Module boundaries and DST layer mapping

| Module | Nature | DST layer |
|---|---|---|
| `step_machine.ail` | pure decisions | L0/L1, no effects |
| `transcript.ail` | pure builder + projection + invariants | L0, Z3 candidates |
| `ledger.ail` | pure event types + append | L0 |
| `model_phase.ail`, `tool_phase.ail`, `hook_phase.ail` | effectful via ports, return `PhaseResult` | L1 with scripted ports |
| `tool_stream_phase.ail` | the contained `selectEvents` island | L1 scripted + supplemental smokes |
| `session.ail` (driver) | owns the real effect row, executes decisions | L3 |
| `recovery.ail`, compaction policy | pure policy + phase | L0 + L1 |
| `cost_phase.ail` | pure arithmetic + thresholds | L0 |

ADR-001 R11 (the undefined L3 "runtime probe") sharpens under this design: Layer 3's probe is
**the driver wired with scripted ports** — no separate binary.

---

## 4. Substrate validation: the Ports smoke (all green)

`scripts/smoke_ports_record.ail`, verified on v0.26.0 (commit `3b52a24`). Precedent already in
production: `ExtensionHooks` is a record of effectful function fields; `deny_all_rt`
(`stub_step.ail:196`) builds pure-bodied fakes for it.

Verified results:

- **Q1–Q4 pass**: record types with effectful function fields; live closures, named funcs, and
  let-bound lambdas as field values; pure-bodied fakes; scripted-state threading via the
  `StepProvider` pattern.
- **Q5 — the R7 killer result**: capabilities are checked when an effect is **performed**, not
  when a row is declared. The fakes-only entry (declared rows include `{Clock, Env}`) runs under
  `--caps IO` alone. **Layer 1 DST with scripted ports needs only the caps it actually uses.**
- **Subsumption**: an *unannotated pure lambda* is accepted into a field typed with an effect row
  (pure ≤ `{Env}` holds). No annotation ceremony for fakes.
- **Recursive record types** through function fields work (self-replacing
  `Counter = { step: (int) -> {value, next: Counter} }` runs), so both scripted-state styles are
  available; we standardize on external threading for simplicity.

Parser gotchas to carry into design docs:

- `func() -> ...` as an *expression* does not parse — `()` lexes as the unit literal. Zero-arg
  ports must be named top-level funcs (or take an argument).
- Anonymous `func(...)` expressions are not valid directly as record-literal field values;
  let-bind them first (existing codebase convention).
- Known since v0.21: unused function-typed parameters get their effect row narrowed to `{}`;
  pin with `let _ = f in` (see `stub_step.ail:127`).

### 4.1 Vocabulary sketch (pre-ADR substrate validation, 2026-07-02)

`sketch/` in this project directory: `sketch_vocabulary.ail` (checks, runs, inline tests pass)
plus five opacity probes. Full answers in `sketch/README.md`; summary of the four questions it
was built to retire:

1. **D7's opacity assumption holds, with a co-location constraint.** `export type` exports
   constructors (forgeable); an *unexported* variant type with exported ops is truly sealed —
   constructor import fails `IMP010`, values still thread through consumers. But the unexported
   *type name* is not importable either, so **records embedding `History` (`StepState`) must be
   co-located in the defining module** — the phase core needs a single vocabulary module
   (working name `src/core/phase_vocab.ail`; final home an ADR detail). Exported record types
   are structurally forgeable, so sealed types must be single-constructor variants. The
   self-auditing `checkpoint -> {history, event}` shape runs end-to-end.
2. **One `LedgerEvent` type serves both event vocabularies.** Typed variant + `to_schema_v1`
   projection onto the existing production wire contract; the 28 production schema-v1 event
   types are inventoried in the sketch; representative 11-constructor subset proven, including
   payload-dependent legacy-name mapping. **Full 28-name projection coverage is a Phase B ship
   gate.** ADR-001 canonical names map 1:1 to constructors.
3. **`state_delta` is a patch record with one application point.** `Option` fields (absent =
   unchanged) applied only by `apply_state_delta` — the state mirror of single-point event
   emission and itself a DST invariant site. Full-state returns rejected: the delta IS the
   observation DST wants recorded.
4. **`StepDecision` variants carry named record payloads cleanly**, and the pure
   `decide(StepState, StepPolicy) -> StepDecision` skeleton composes with the sealed projection
   pipeline. `PhaseResult` drops the note's `continuation` field — the step machine re-derives
   the next decision from applied state.

---

## 5. Where `agent_loop_v2.ail`'s residual logic goes

The sorting rule is *what kind of thing each feature is* — not "hook vs. loop". Six squatters:

| Feature | What it really is | Home | DST consequence |
|---|---|---|---|
| Persist-nudge (`:1054-1105`, `:1389-1406`) | pure decision policy | step machine | L0 |
| Cost warnings/caps, stream-retry (`:1126-1147`, `:1216`, `:1262-1275`) | pure decision policy | step machine | L0 |
| DP7 verify gate (`:1020-1052`) | finalization decision + one effect | step machine decides, port executes | L1, scripted verifier |
| Hybrid-bash synthesis (`:1303-1343`) | response interpretation + a transcript invariant | interpreter + **transcript builder** | L0 property test |
| Scratchpad special-case (`dispatch_calls:868`) | an executor strategy | tool-phase planner | L1, scripted executor |
| Pending-approval `readLine` (`dispatch_calls:769`) | an interaction point | step machine yields `AwaitApproval`, driver performs I/O | L1, scripted approvals |

Notes on the three interesting ones:

- **Persist-nudge is the smoking gun for the refactor** (see §1, marker-scanning). Target design:
  `nudges_used` is a `StepState` field; env budget resolved once at session init; decision is
  `InjectUserMessage(nudge)`.
- **Hybrid-bash is secretly a transcript-builder concern.** The synthesis (prose → synthetic
  `BashExec` call) is response interpretation. But the Bedrock comment at `:1316-1333` — the
  assistant message must be rewritten to carry the synthetic `tool_use` or Bedrock 400s on the
  orphaned `tool_result` — is a tool_use/tool_result **correlation invariant**, i.e. the
  transcript builder's job. Moved there, it becomes an enforced, L0-testable property instead of
  a 20-line comment; this is exactly the provider-400 bug class ADR-001 exists to catch.
- **Scratchpad breaks the extension abstraction.** `dispatch_calls:868` hard-codes one
  extension's tool name, calls its WebSocket loopback directly (magic timeout 30), with a bespoke
  emitter (`emit_scratchpad_result_if_present`). Target: the tool-phase **planner** assigns each
  call an executor strategy (`Native | Delegated | Handled | WsLoopback | StreamIsland`);
  executors are looked up, not if-chained; scratchpad registers a `WsLoopback` executor and the
  core stops knowing it exists.

---

## 6. DST for extension packages: three test surfaces

The extension boundary is a two-sided contract; "DST for extensions" decomposes into:

**Surface A — core under test, extensions scripted.** Already works (`deny_all_rt`); hook
decisions (`PreStepDecision`, `ToolPolicyDecision`, ...) are plain data, so scripted hooks are
data scripts. The phase refactor keeps this trivially.

**Surface B — extension under test, core scripted.** The gap. Synthetic `ExtCtx` + histories are
easy; the blocker is extensions performing their *own* effects (Net for exa_search, Process for
context-mode's exec, AI for a future summarizer) directly via stdlib inside hook bodies. There is
no seam: an extension package cannot deterministically test its own hook logic today.

**Surface C — the contract itself.** A conformance kit (shared invariants + scripted harness)
shipped *inside the ABI package*, versioned with the ABI. Each obligation has an owner: core
guarantees "on_pre_step never receives system messages" (currently FALSE — see §7.0); a compactor
extension guarantees "tool_call_id pairing survives my compaction". Extension CI runs the kit
against its hooks; core CI runs it against scripted extensions. Consumer-driven contract testing
for independently-shipped packages (`packages/motoko-ext-*`).

### The load-bearing fix for Surface B: ports through the ABI (ABI v3)

`ExtCtx` carries a ports record (model step, HTTP, process exec, clock). Extensions perform
effects through ports; the core builds live ports; DST harnesses inject fakes. Payoffs beyond
testability:

1. **Observability for free**: the core wraps live ports with recorders, so every extension
   effect call becomes a ledger event (`extension_effect{ext_id, port, args_digest}`). Extension
   internals enter the same DST trace as core behavior.
2. **The caps result compounds** (§4 Q5): an extension's DST harness with fake ports runs under
   minimal caps — no sandbox, no network.
3. **A path to honest effect rows** — CORRECTED (2026-07-02, after reading ABI 2.2.0 source):
   the ABI is already partially narrowed. `on_describe_tools`, `on_build_system_prompt`, and
   `on_tool_policy` are **already pure**; `on_budget_plan` is already `{Env, FS}`. Only four
   hooks carry the maximal 9-effect row: `on_pre_step`, `on_tool_handle`,
   `on_response_intercept`, `on_solver_candidate` — precisely the "extension does real work"
   hooks. Analysis in the O1 discussion: once ports exist, further row-narrowing buys little
   (calling an effectful port requires the effect in the caller's row anyway; DST fake-ability
   comes from ports + caps-at-performance-time, not from narrow rows).

Cost: an ABI major version bump. Migration is cheaper than it looks: with ports placed *inside
`ExtCtx`*, hook signatures do not change — extension packages that ignore ports need no code
changes (record readers don't break when a field is added; only constructors do, i.e. core's
`mk_v2_ext_ctx` and extension test fixtures). §7.3 adds one more item to the same bump: an
artifact channel for compaction caches (`Compacted` gains an artifacts field — touches only
compactor packages).

**Settled (D6, 2026-07-02)**: ABI v3 scope = ports-in-ExtCtx + artifact channel; no row changes
in v3; conformance kit as a separate lockstep package. See §9.

### 6.1 The conformance kit (D8, settled 2026-07-02)

#### Three deliverables in one package (`motoko_ext_conformance`)

1. **Contract law** — pure invariant functions over hook inputs/outputs
   (`pairing_preserved`, `ids_preserved`, `no_system_in_output`, `envelope_well_formed`, ...).
   Pure ⇒ L0: any extension runs them under `ailang test` with no caps.
2. **Harness** — a scenario runner driving one extension's `ExtensionHooks` with synthetic
   `ExtCtx` values, fixture histories, and fake `ExtPorts` builders (per the §4 smoke
   conventions: named funcs, let-bound lambdas, script state threaded). Surface B (§6) made
   concrete: the extension-side mirror of `run_v2_with_stub`.
3. **Reporting** — the ADR-001 failure contract verbatim (scenario id, seed where applicable,
   first failed invariant, normalized trace), emitted in the same JSONL shape as the core
   ledger projection, so extension conformance failures and core DST failures read identically.

#### Caps-as-conformance: ports discipline enforced by the runtime

Falls directly out of §4 Q5. "This extension is ports-native" sounds like it needs static
analysis AILANG cannot express; behaviorally it is free: **the harness runs hook scenarios with
fake ports under minimal caps** (e.g. `--caps IO`). An extension that bypasses ports and calls
`std/ai.step` or `Net.httpGet` raw fails the capability check at the moment of performance —
the scenario fails without any analysis. Extensions with legitimate raw-effect use
(pre-migration `SharedMem` frames in context-mode) get a **per-extension declared-caps
allowance** in their conformance config — an honest, machine-readable record of exactly which
effects they still perform outside ports; shrinking that list to empty IS the migration
progress metric.

#### Dependency inversion: one source of contract law

Naively, pairing/id invariants would exist twice (core's `transcript.ail` gate + the kit) and
drift. Instead the package splits into two modules with different audiences:

- `motoko_ext_conformance/invariants` — pure contract law, no test machinery, depends only on
  the ABI. **Core's `transcript.ail` imports this too**: the production gate validating a
  `Compacted` result (§7.1 case 2) and the kit scenario an extension runs in its own CI execute
  the *same function*. Disagreement is impossible by construction.
- `motoko_ext_conformance/harness` — runner, fixtures, fake ports, reporting. Test-only; core
  never imports it.

#### Per-hook obligations catalog (v1 scope)

| Hook | Extension-owned obligations |
|---|---|
| `register_with_config` | total for any `RuntimeConfig`; pure (ABI law); `id` non-empty; `provided_tools` consistent with `on_describe_tools` |
| `on_describe_tools` | schema names unique + non-empty; `parameters` parses as JSON |
| `on_build_system_prompt` | pure (ABI law); patch bounded; deterministic given ctx |
| `on_tool_policy` | pure (ABI law); total over arbitrary envelopes |
| `on_pre_step` / `Compacted` | pairing preserved; ids preserved; no system-role messages in output; deterministic given (segment, artifacts, ports script); artifacts round-trip stable |
| `on_tool_handle` / `on_response_intercept` | result envelope well-formed; `tool_call_id` echoes the call's id; exit_code/stdout/stderr semantics respected |
| `on_solver_candidate` | `ContinueWithFeedback` carries non-empty feedback; deterministic given (ctx, text, ports script) |

Core-owned obligations (tested core-side, *stated* in the kit so both parties read one
document): the segment never contains system messages; first-`Compacted`-wins order is
ledger-recorded; every hook output passes the transcript gate before touching a provider
payload.

#### First invariant set: hardened by the `compaction_ai` v0.3.0 migration

Per the D6 reference-migration plan, the catalog is not designed speculatively — the migration
needs exactly: `pairing_preserved`, `ids_preserved`, `no_system_in_output`,
`deterministic_replay` (same segment + artifacts + port script ⇒ identical decision), and
`artifact_cache_effective` — the caching assertion done behaviorally: run the scenario twice
with run-one's artifacts; run-two's fake `ai_step` port is an empty script returning a poison
sentinel, so any re-summarization surfaces in output and fails. **The kit's acceptance test:
it must reject `compaction_ai` v0.2.0 for its two live bugs (§7) — the kit is correct when it
rejects the shipped compactor for the right reasons.**

#### Versioning and CI mechanics

Lockstep majors (kit `3.x` certifies against ABI `3.x`); the kit exports
`conformance_abi_version()` and the harness refuses an ABI mismatch loudly. Extension CI runs
its own scenarios (fast, caps-minimal, no network — ADR-001-compatible by construction). Core
CI runs the harness against every extension in `registry_generated.ail`, turning "certified
against conformance v3" into a checkable registry-inclusion gate rather than a README claim.

#### What the kit deliberately cannot check — and why that is a design, not a gap

Out of scope: cross-extension composition (registry order, arbitration, hook interaction) —
core-side L1; provider acceptance of final payloads — core's transcript gate; cross-package
`id` uniqueness — the registry; resource/time budgets — v1 out of scope.

The composition exclusion is structural, for three reasons:

1. **The kit's vantage point is one package in an open world.** It runs in the extension's CI,
   where sibling extensions are not in the dependency closure and cannot be: the composition
   set is a *deployment* property (`registry_generated.ail` is generated per install from
   `RuntimeConfig`), not a package property. A test needing the composed set can only run where
   that set exists — the core side.
2. **The behavior under test in composition is core's fold, not the extension's.**
   First-`Compacted`-wins lives in `dispatch_pre_step`'s recursion (`ext/runtime.ail:143-164`);
   the ABI deliberately does not specify arbitration. A kit asserting arbitration would have to
   reimplement the fold — a mirror that drifts the day core changes arbitration, leaving two
   authorities on composition semantics. The correct subject of an arbitration test is the
   dispatcher driven by scripted hooks — core Surface A / L1, already in the design.
3. **Combinatorics close only at the deployment boundary.** A fake of a sibling extension is
   just a scripted hook; a kit test using one *is* a core L1 scenario wearing a kit costume,
   run from a worse place to debug.

**The fault-isolation principle that makes the split sound**: the obligations catalog is chosen
to be **composition-closed** — if every compactor preserves pairing, ids, and system-hiding,
then *whichever one wins arbitration*, the winning output is safe; the invariant survives the
fold without the kit ever seeing the fold. Every composition failure then decomposes:

- an extension violated its contract → kit's job; one identifiable party; reproducible in that
  extension's own CI; or
- all contracts met, composed result still wrong → core's arbitration bug → core L1 scenario.

If a bug ever fits neither branch — contracts met, fold correct, still broken — the contract
itself was too weak, and the fix is a new obligation in the kit's next version. The boundary is
the feedback loop that hardens the contract.

**Honest residual gap**: *real-pair* emergent interactions — two actual extensions coupling
through side channels the contract does not model (colliding `SharedMem` keys; two individually
bounded prompt patches that are jointly contradictory). The kit cannot see pairs (reason 1) and
core L1 uses scripted hooks, so real pairs are exercised only by the registry gate in core CI
(harness against hydrated extensions) and L3. Mitigations already in the design: the ports
migration shrinks side channels, recorder-wrapped ports make residual couplings *visible* in
the ledger even where not prevented, and declared-caps allowances make "which pairs could even
interact outside the contract" a queryable question rather than archaeology.

---

## 7. Compaction: pure projection pipeline, pressure-tested

Compaction is the one behavior living on *both* sides of the extension boundary: structural
compaction in core (`src/core/compaction.ail` — **entirely pure already**, including tiers and
emergency), and AI-summarization via `on_pre_step`/`Compacted` (ABI surface + dispatch at
`ext/runtime.ail:143`, "first Compacted wins").

CORRECTION (2026-07-02): an AI compactor **does exist** — `motoko_ext_compaction_ai` v0.2.0, a
registry package wired into `registry_generated.ail:17`. (No *in-repo* implementation; the
original "empty seat" claim conflated the two.) Reading its source made the pressure-test
concrete — it exhibits **every failure mode this design targets**:

1. **Live bug — destroys the system prefix**: `split_msgs` (`compaction_ai.ail:101`) splits by
   position only; the system message is the oldest, so above the threshold it always lands in
   `old_turns`, is summarized into `[CONTEXT SUMMARY]` prose, and the provider payload for that
   step **loses its system message** (violates ADR-001 `provider_calls_have_system_prefix`).
2. **Live bug class — can sever tool pairs**: `keep_recent` counts messages, not turn groups, so
   the cut can separate an assistant-with-tool_calls from its tool results → provider 422 (the
   exact class the ABI's own M-ABI-MSG-WIRE-PARITY comment warns about). §7.1 case 2's
   post-validation catches both bugs at the gate.
3. **No caching**: re-summarizes (one blocking AI call) on *every step* above threshold —
   §7.1 case 3's cost blow-up is live, not hypothetical.
4. **Untestable deterministically**: `summarize_with_ai` calls blocking `std/ai.step` directly
   (`compaction_ai.ail:89-91`) — no seam; needs the AI port.
5. **Duplicated policy**: reimplements `estimate_tokens`/`usage_percent` (chars/4 heuristic)
   locally — the constant-duplication ADR-001 R5 warns about.

`compaction_ai` v0.3.0 is therefore the designated **reference migration** for ABI v3 and the
first conformance-kit consumer. Note the system-prefix fix does NOT wait for v3: core-side
hiding (passing the segment, not the full list, to `dispatch_pre_step`) has zero ABI cost.

Compaction is already ephemeral *by accident of dataflow*: `loop_v2` sends `compacted_msgs` to
`dispatch_step` but recurses on `msgs ++ [assistant_msg]` from the **original** history
(`agent_loop_v2.ail:1250`). ADR-001's flagship invariant currently holds protected by nothing.

### 7.0 Finding (live gap, verified): extension compactors DO receive system messages

`rpc.ail:231` puts a system-role message **into the message list**; `loop_v2:1154` passes the
entire unfiltered list to `dispatch_pre_step`. ADR-001's
`compaction.system_messages_hidden_from_compactors` is aspirational, not descriptive. Nothing
exploits it yet only because no real `Compacted` implementation exists. Structural compaction is
safe by accident: `elide_walk` rewrites only tool-message content (`compaction.ail:99`).
The `CompactableSegment` type below **fixes a bug-in-waiting**, not a formality.

### 7.1 Pressure-test stress cases and design fixes

1. **Where is the pin cut?** If system messages could sit mid-list, the segment can't be a simple
   split and reassembly becomes positional. Verified: system messages are head-only in practice
   (rpc builds the head; dp7 retries, nudges, solver feedback all inject user-role). **Fix**:
   promote "system messages form a head prefix" to a transcript-builder invariant checked at
   session entry (`run_v2_from_messages` accepts arbitrary resumed histories — that's the
   enforcement point). Pin = head prefix; segment = tail; reassembly = concatenation.
2. **An extension compactor can 400 the provider.** `Compacted(msgs, note)` is unconstrained — a
   summarizer that severs a tool_use/tool_result pair reproduces the Bedrock correlation failure.
   **Fix**: projection output passes the same transcript-builder validation as everything else
   (that is what "single gate" means). Invalid `Compacted` ⇒ **rejected**: ledger event
   `ext_compaction_rejected`, fall back to structural tiers, run continues. Provider 400 becomes
   graceful degradation; the rejection path is L0-testable; the conformance-kit obligation for
   compactors falls out (pairing/ids/order preserved).
3. **Ephemeral AI summarization has a cost blow-up, and the obvious escape hatch is DST poison.**
   Re-projection every step ⇒ a summarizer re-summarizes the growing history every step. The
   natural extension-author fix is `SharedMem` caching — hidden mutable state, replay poison.
   **Fix**: the summary cache is **explicit state**: the hook returns its artifact in the phase
   result; it lands in `StepState` (keyed by a segment digest); the next projection hands it back
   via `ExtCtx`. History stays uncompacted; the cache is replayable data; cache hits/misses are
   ledger events. First mandatory client of `PhaseResult.state_delta`; adds the artifact channel
   to ABI v3 (§6).
4. **Ephemeral-only has a hard ceiling.** Once even the fully-elided projection exceeds the
   limit, every path ends `ContextExhausted`. Acceptable for bounded task runs; fatal for
   `conversation_loop_v2` long sessions. **Fix**: keep ephemerality but make its one exception
   explicit — *History is rewritten only by an explicit `Checkpoint` decision of the step
   machine, recorded in the ledger.* v1 never emits `Checkpoint`; the types just leave the driver
   a legal construction path. The DST invariant stays checkable (history rewrite without a
   matching ledger event = failure). **Settled (D7)** — full design in §7.4.
5. **Tier telemetry is a function input and measures the payload, not the history.**
   `last_input_tokens` is the actual token count of the previous **compacted payload** — correct
   (it measures what the provider sees) but subtle enough to be "fixed" wrongly someday.
   Signature makes it explicit:
   `project(History, TokenTelemetry, CompactionPolicy, model_limits) -> ProviderPayload`, with
   telemetry in `StepState` (also ADR-001's `last_input_tokens` carry-forward observation point).
   Guard scenario: `compaction.telemetry_reflects_payload_not_history`.
6. **First-`Compacted`-wins makes registry order load-bearing** (`ext/runtime.ail:143`). Not
   wrong, but must be visible: hook order is a DST scenario input; the ledger records which
   extension won; conformance obligation: compactor deterministic given (segment, cache, ports).
7. **Normalization ordering owned in one place**: cap tool output (`cap_tool_message_content`) →
   estimate → tiers, explicit inside `transcript.ail`'s projection, using exported constants
   (ADR-001 R5 — still a Phase 0 deliverable: `OUTPUT_HEADROOM=75000`, actual tiers 60/75/85,
   estimate tiers 70/85/95).
8. **The pure core earns property tests / Z3 obligations**: projection idempotence; monotone
   shrinkage (payload tokens ≤ raw tokens at every tier); elision preserves message count and all
   ids; emergency implies tiers were insufficient. `elide_preserves_length` already exists inline
   and graduates to the invariant library.

### 7.2 The pipeline (post-pressure-test)

```text
History (append-only; rewritten only by ledger-recorded Checkpoint — v1: never)
  │  invariant at entry: system messages are a head prefix
  ▼
pin head prefix ──────────────► pinned system prefix
  ▼
CompactableSegment (no system messages, by type)
  │  normalize (caps) → estimate
  │  ext compaction: f(segment, summary_cache, ports) → Compacted | PassThrough
  │       └─ output VALIDATED by transcript invariants; invalid ⇒ rejected + ledger event, fall back
  │  structural tiers (pure; actual-gated via TokenTelemetry from StepState)
  │  emergency (pure) ⇒ Err becomes step-machine Fail decision
  ▼
ProviderPayload (distinct type; the only thing model_phase accepts)
      summary artifacts ⇒ StepState via state_delta; every stage ⇒ ledger events
```

Two "unrepresentable bug" moves: **ephemeral by construction** (`ProviderPayload` is derived
from `History`; nothing in the step machine can write it back —
`compaction.provider_payload_vs_uncompacted_history_pressure` becomes a type error to violate)
and **system-message hiding by construction** (compactors receive `CompactableSegment`, which
cannot contain system messages).

### 7.3 DST scenario coverage

All five ADR-001 compaction scenarios land at **Layer 0** (pure projection in, payload out),
except `system_messages_hidden_from_compactors`, which becomes unrepresentable (one L1 check that
the wiring uses the segment type). New scenarios from the pressure test:

- `compaction.ext_compaction_invalid_rejected`
- `compaction.telemetry_reflects_payload_not_history`
- `compaction.summary_cache_replay_stable`
- `compaction.history_rewrite_requires_checkpoint_event`

### 7.4 The `Checkpoint` seam (D7, settled 2026-07-02)

#### The problem it exists for

Ephemeral compaction re-derives the provider payload from raw `History` every step, and
`History` only ever grows. Elision shrinks tool-result *content*, but message scaffolding,
user/assistant prose, and the summary-resistant recent turns accumulate — so the **minimum
achievable payload** (full elision, emergency tier) grows monotonically with history length.
When that floor crosses the context limit, every projection path returns `Err`, the step
machine's only legal move is `Fail(ContextExhausted)`, and the session is dead — not degraded,
dead, because the design deliberately gives nothing the power to make `History` smaller. Bounded
task runs usually hit the step budget first; `conversation_loop_v2` explicitly preserves
accumulated history across tasks (`agent_loop_v2.ail:1520-1523`), so long-lived sessions walk
toward the ceiling **by design**. The ceiling is reachable today, not hypothetical.

#### What the seam concretely is

Three small things; the second is the load-bearing one:

1. **A decision variant**: `Checkpoint(CheckpointPlan)` in `StepDecision`. Pure policy in the
   step machine decides when (e.g. "estimated fully-elided payload exceeds N% of the limit") —
   L0-testable like every other decision.
2. **One legal constructor, and it is self-auditing.** `History` is opaque in `transcript.ail`
   (unexported constructor), with exported ops `append`, `project`, and exactly one function
   that can produce a *rebuilt* history:

   ```ailang
   checkpoint : (History, CheckpointPlan) -> { history: History, event: LedgerEvent }
   ```

   Returning the rebuilt history **together with its ledger event** makes the invariant nearly
   hold by construction: you cannot obtain a rewritten `History` without being handed the event
   that must be appended. DST then only verifies the digest chain — each checkpoint event
   records `before_digest`/`after_digest`; any history whose digest doesn't chain back through
   recorded events is a failure.
3. **The invariant, restated.** "History is never rewritten" becomes "**History is rewritten
   only by `checkpoint`, and every rewrite has a matching ledger event.**" The v1 behavior —
   never rewritten — holds as a corollary, checkable as: *the v1 step machine never emits
   `Checkpoint`* (a one-line L0 scenario, and the cage that prevents scope creep).

#### Why decide now instead of retrofitting

The asymmetry is stark. Cost now: one variant, one opaque-type discipline, one invariant
phrasing, zero implementation. Cost later: by the time the ceiling bites, the invariant library,
the compaction scenario family, the Z3 contracts on `transcript.ail`, and every exhaustive
`match` on `StepDecision` will have "never rewritten" baked in as an *axiom* rather than a
corollary. Retrofitting means weakening a load-bearing assumption across tests specifically
designed to catch exactly this mutation — the DST suite would correctly fight the change,
turning its full strength into a penalty for not leaving a door. Provenance argument: every
long-lived agent system ends up with persistent summarization/compaction, so "never" was always
going to become "almost never, explicitly" — better the types say what is true long-term.

#### The synergy that makes v2 nearly free

The artifacts channel (D6) means ext compaction's summary cache already lives in `StepState` as
replayable data. When the ceiling approaches, `CheckpointPlan` can **promote the existing
summary artifact** into the rebuilt history — summarization work done for ephemeral projection
is ratified, not recomputed. Checkpoint output passes the same transcript-builder gate as ext
compaction (system prefix preserved, pairing preserved), so the validation machinery already
exists. Bonus: `checkpoint` + the ledger is most of a session persist/resume story.

#### Steelman against, and responses

- **"YAGNI — task runs never hit it."** True for task mode; conversation mode exists and
  accumulates. And the "it" is a seam, not a feature — YAGNI's cost argument assumes nontrivial
  cost.
- **"A blessed seam invites premature implementation."** The cage is explicit: v1 policy never
  emits it, enforced by scenario (`checkpoint_never_emitted_in_v1`), not convention.
- **"The weakened invariant is weaker."** Yes — and it is the *true* one. "Rewritten only with
  an audit event" is defensible forever; "never rewritten" was a v1-policy statement wearing an
  invariant's clothes. Separating invariant from policy corollary is more honest, not less safe.

#### DST scenarios

v1-active: `compaction.history_rewrite_requires_checkpoint_event` (digest-chain check),
`compaction.checkpoint_never_emitted_in_v1`. Reserved for v2: checkpoint output satisfies
transcript invariants; replay across a checkpoint is deterministic given plan + artifacts;
resume-from-checkpoint reproduces the digest chain.

---

## 8. Migration plan (strangler, not big-bang)

1. **Phase A — pure foundations, zero behavior change**: ledger event types, envelope types,
   transcript builder extracted from current helpers (`step_result_to_message`,
   `envelope_to_tool_message`, `tool_result_message`, ...); export compaction constants
   (ADR-001 R5); Ports substrate smoke (**done** — `scripts/smoke_ports_record.ail`);
   vocabulary sketch (**done** — `sketch/`, §4.1; seeds the real vocabulary module).
2. **Phase B — split `loop_v2` into phases returning `PhaseResult`**; driver keeps the current
   recursive shape. Scattered emission centralizes; ADR-001's required first seam (provider-call
   recording) lands naturally as ledger events around the model phase.
3. **Phase C — extract the pure step machine and invert control**: driver executes decisions.
   Layer 1 DST scenario families (compaction first) come alive here.

Each phase leaves the system shippable; DST coverage grows monotonically. ABI v3 (ports-in-ExtCtx
+ artifact channel) sequences alongside — the core needs ports anyway; threading them one level
further into `ExtCtx` is marginal cost against a paid ABI bump.

---

## 9. Decision log

Settled (operator + research, 2026-07-02):

| # | Decision | Outcome |
|---|---|---|
| D1 | Step machine purity | Full inversion in Phase C |
| D2 | Ports mechanism | Ports record; substrate-validated (§4); external state threading |
| D3 | Compaction design | Pure projection pipeline (§7.2); pressure-tested; types enforce ephemerality + system-hiding |
| D4 | `agent_loop_v2` residual logic | All six squatters mapped (§5); no successor loop file keeps any |
| D5 | Ledger/trace unification | One artifact; typed records in memory, JSONL projection at driver (resolves ADR-001 R4/R8) |
| D6 | ABI v3 scope (was O1; settled 2026-07-02) | Ports-in-ExtCtx + `artifacts` channel; **no row changes** (`on_tool_policy` is already pure in 2.2.0; narrowing the four max-row hooks buys ~nothing once ports exist). Conformance kit as a **separate package** (`motoko_ext_conformance`), lockstep-versioned with the ABI. Reference migration: `compaction_ai` v0.3.0 |
| D7 | `Checkpoint` seam in v1 types (was O2; settled 2026-07-02) | Yes — `Checkpoint(CheckpointPlan)` decision variant; `History` opaque with a single self-auditing rebuild op returning `{history, event}`; invariant "rewritten only with a matching ledger event"; v1 never emits it, enforced by scenario. Full design §7.4 |
| D8 | Conformance kit details (was O3; settled 2026-07-02) | Two-module package: `invariants` (pure contract law, imported by core's transcript gate — one source of law) + `harness` (test-only). Caps-as-conformance with per-extension declared-caps allowances. Per-hook obligations catalog per §6.1; invariant set frozen only after `compaction_ai` v0.3.0 passes; lockstep majors with loud version handshake; acceptance test: the kit must reject v0.2.0's two live bugs. Full design §6.1 |

No open decisions remain — all decisions raised by this research are settled. Next step: promote
this research into an ADR (the decision log is its skeleton).

## 10. ADR-001 review comments resolved by this design

- **R4** (trace format blocks Phase 1): typed ledger records in memory; JSONL projection at the
  driver boundary (§2 P2).
- **R5** (export compaction constants): Phase A deliverable (§7.1 case 7, §8).
- **R7** (per-layer effect satisfaction): pure step machine needs zero effects at L1; ports +
  caps-at-performance-time (§4 Q5) mean scripted tests declare rows but need only the caps they
  perform.
- **R8** (recorder vs. production behavior): dissolved — the ledger is always-on production
  telemetry with single-point emission; the DST recorder is a sink (§2 P2).
- **R11** (undefined L3 runtime probe): the probe is the driver wired with scripted ports (§3).

## 11. New facts established during this research (not in prior docs)

1. Capabilities are checked at effect **performance** time, not row declaration
   (`scripts/smoke_ports_record.ail` Q5).
2. Unannotated pure lambdas subsume into effect-row-typed record fields (probe, §4).
3. Recursive record types through function fields work on v0.26.0 (probe, §4).
4. `func()` zero-arg anonymous functions do not parse; anonymous `func` cannot sit directly in
   record literals (§4).
5. Extension compactors currently receive system messages — ADR-001's hiding invariant does not
   hold today (`rpc.ail:231` + `agent_loop_v2.ail:1154`; §7.0). **Exploitable now**: with
   `compaction_ai` active, above its threshold the provider payload loses its system message
   entirely (§7, correction block).
6. Compaction ephemerality currently holds only by dataflow accident (`agent_loop_v2.ail:1250`).
7. Structural compaction (`src/core/compaction.ail`) is already fully pure — L0-ready.
8. `motoko_ext_compaction_ai` v0.2.0 (registry package, wired in `registry_generated.ail:17`)
   implements `Compacted` pre-step; it has two live bug classes (system-prefix loss, tool-pair
   severing), no summary caching, a direct blocking `std/ai.step` call, and duplicated token
   policy (§7). No *in-repo* implementation exists.
9. Persist-nudge stores its state in transcript marker strings because `loop_v2`'s signature
   makes new state prohibitively expensive (`agent_loop_v2.ail:1063`).
10. ABI 2.2.0 already has differentiated hook effect rows: `on_describe_tools`,
    `on_build_system_prompt`, `on_tool_policy` are pure; `on_budget_plan` is `{Env, FS}`; only
    the four "real work" hooks (`on_pre_step`, `on_tool_handle`, `on_response_intercept`,
    `on_solver_candidate`) carry the maximal 9-effect row (registry cache
    `sunholo/motoko_ext_abi/2.2.0/types.ail:128-142`).
11. `ExtCtx` is pure data and is never serialized across a process boundary (no JSON encoding of
    ctx found in core or packages) — function-valued ports can live inside it safely.
12. The extension ecosystem is entirely external packages: 12 registered in
    `registry_generated.ail`; the `src/core/ext/*` subdirectories are empty placeholders.
13. Type opacity is enforceable on v0.26.0, but only for variants and only by *not exporting*
    the type: `export type` exports constructors; unexported variant + exported ops is sealed
    (`IMP010` on constructor import); the unexported type name is not importable either, so
    embedding records must be co-located; exported record types are structurally forgeable
    (sketch probes, §4.1).
14. Production emits 28 schema-v1 event types (inventoried in
    `sketch/sketch_vocabulary.ail`); the TUI and eval harnesses consume them, so the ledger's
    `to_schema_v1` projection must cover all 28 before Phase B ships.
15. Imports must lexically precede all declarations in an AILANG module (parse error
    otherwise).
