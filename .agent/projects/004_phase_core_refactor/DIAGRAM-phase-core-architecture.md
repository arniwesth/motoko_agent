# Diagram: the phase-oriented core (as decided in ADR-001, D1–D9)

Companion to [ADR-001-phase-oriented-core.md](./ADR-001-phase-oriented-core.md) and
[RESEARCH-phase-core-dst-design.md](./RESEARCH-phase-core-dst-design.md). These diagrams show
the **target** architecture (post Phase C + ABI v3), annotated with which migration phase
lands each piece and which DST layer tests it.

Conventions: boxes are modules/functions; **PURE** boxes have no effect row (L0-testable with
zero caps); **SEALED** types are unexported single-constructor variants (constructor
unreachable outside the vocabulary module); dashed edges are data returned as values; solid
edges are calls. `[prod]`/`[NEW]` on events per ADR Decision detail 3.

---

## 1. The main loop — functional core, imperative shell (D1, D5)

The step machine is pure and returns decisions-as-data; the driver owns the only real effect
row, executes decisions through phases, and is the single authority for state application and
ledger emission.

```mermaid
flowchart TD
  subgraph SHELL["session.ail — driver / imperative shell · owns the real effect row · L3"]
    Init["session init<br/>resolve config+env ONCE into StepPolicy<br/>build live Ports: ai_step, tools, clock, env, approval io<br/>history_from_seed: head-prefix + digest-chain validation"]
    Exec["execute decision"]
    Apply["apply_state_delta — the ONE state path<br/>history_append through transcript gate<br/>ledger append — the ONE emission point"]
    ApplyCP["apply_checkpoint — atomic:<br/>rebuilt history + CheckpointTaken event together"]
  end

  subgraph CORE["step_machine.ail — PURE · L0/L1, zero caps"]
    Decide["decide StepState x StepPolicy -> StepDecision<br/>all loop policy lives here:<br/>budget caps, cost caps, stream-retry,<br/>persist-nudge, finalize gating"]
  end

  subgraph PHASES["phases — effectful via Ports only · return PhaseResult · L1 with scripted ports"]
    MP["model_phase.ail<br/>calls ports.ai_step with ModelRequest<br/>stream deltas -> ledger append handle"]
    TP["tool_phase.ail<br/>planner -> executor registry"]
    HP["hook_phase.ail<br/>extension dispatch via ExtCtx ports"]
  end

  Init --> Decide
  Decide -->|"CallModel ModelRequest"| Exec
  Decide -->|"RunTools ToolPlan"| Exec
  Decide -->|"AwaitApproval ApprovalRequest"| Exec
  Decide -->|"InjectUserMessage"| Exec
  Decide -->|"TakeCheckpoint — v1: never emitted"| ApplyCP
  Decide -->|"Finalize / Fail"| Done["run summary -> done event<br/>summary BEFORE done ordering preserved"]

  Exec --> MP
  Exec --> TP
  Exec --> HP
  MP -.->|"PhaseResult: delta, transcript_append,<br/>events, cost_delta"| Apply
  TP -.->|"PhaseResult"| Apply
  HP -.->|"PhaseResult"| Apply
  ApplyCP --> Apply
  Apply --> Decide
```

Continuation is state, not a field: `decide` re-derives `RunTools`/`Finalize`/`CallModel` from
typed `StepState` fields (`pending_tool_calls`, `last_finish_reason`, `last_response_text`) —
proven in `sketch/sketch_vocabulary.ail`. Lands: types Phase A, PhaseResult wiring Phase B,
inversion Phase C.

---

## 2. The vocabulary module — sealed types and who may name what (D3, D7; sketch Q1)

Opacity on v0.26.0: unexported variant constructors are sealed (`IMP010`), unexported type
names are unimportable, exported records are forgeable. So the vocabulary module co-locates
every type that NAMES a sealed type; consumers import exported wrappers only.

```mermaid
flowchart LR
  subgraph VOCAB["phase_vocab.ail — the ONE definer module · PURE · L0 + Z3 candidates"]
    H["SEALED History<br/>MkHistory unexported"]
    SEG["SEALED CompactableSegment<br/>cannot contain system messages"]
    PP["SEALED ProviderPayload<br/>only project() constructs one"]
    W1["exported wrapper: StepState<br/>embeds History"]
    W2["exported wrapper: StepDecision<br/>CallModel carries ModelRequest"]
    W3["exported wrapper: ModelRequest<br/>carries ProviderPayload"]
    OPS["exported ops:<br/>history_from_seed / history_append<br/>project / checkpoint / apply_state_delta<br/>transcript invariants (the gate)"]
    H --- OPS
    SEG --- OPS
    PP --- OPS
  end

  SM["step_machine.ail<br/>imports StepState, StepDecision"]
  MPH["model_phase.ail<br/>imports ModelRequest"]
  DRV["session.ail driver<br/>imports ops + wrappers"]

  W1 -.-> SM
  W2 -.-> SM
  W3 -.-> MPH
  OPS -.-> DRV
```

Proven by `sketch/vocab_probe.ail` + `sketch/probe_consumer_decide.ail`: wrappers cross module
boundaries with **transitive sealing** — a consumer can construct `CallModel(payload)` only
with a payload obtained from `project()`. Bare sealed-type parameters in foreign signatures are
impossible. Lands: Phase A.

---

## 3. Compaction — core scaffold + extension-resident policy chain (D3 amended by D9)

Core owns what polices compactors; ALL policy (ladders, tiers, AI summarization) lives in
extensions, composed as a fold-through chain in registry order.

```mermaid
flowchart TD
  HIST["SEALED History — append-only<br/>rewritten ONLY by checkpoint, ledger-recorded"]
  PIN["pin head system prefix<br/>invariant at session entry:<br/>system messages form a head prefix"]
  SEGB["SEALED CompactableSegment"]
  NORM["normalize: tool-output caps -> estimate<br/>core exports estimate_tokens / usage_percent"]

  subgraph CHAIN["compactor chain — registry order = pipeline order · every stage ledger-recorded"]
    C1["motoko_ext_compaction_ai v0.3.0<br/>ports.ai_step summarizer<br/>artifact cache via ExtCtx.artifacts"]
    C2["...any other compactor extension...<br/>e.g. actual-token-gated policy<br/>reading ExtCtx.telemetry"]
    C3["motoko_ext_compaction_structural — bundled default, registered LAST<br/>the pure 70/85/95 elide ladder relocated from core"]
  end

  GATE["transcript gate validates EVERY stage<br/>pairing, ids, no system msgs<br/>invalid stage: ext_compaction_rejected event,<br/>stage SKIPPED, chain continues"]

  PAY["SEALED ProviderPayload<br/>the only thing model_phase accepts, via ModelRequest"]
  EXH["exhaustion: nothing fits<br/>-> Fail ContextExhausted<br/>(later: TakeCheckpoint)"]
  CP["checkpoint seam D7<br/>content-hash digest chain, prev digest in event<br/>output passes the SAME gate:<br/>checkpoint_output_is_valid_transcript"]

  HIST --> PIN --> SEGB --> NORM --> C1 --> C2 --> C3 --> GATE
  GATE -->|"valid"| PAY
  GATE -->|"nothing fits"| EXH
  HIST -.->|"v1: never; the one legal rewrite"| CP
  CP -.->|"atomic rebuilt history + event"| HIST
  PAY -.->|"NEVER written back — ephemeral by construction"| HIST
```

With zero compactors installed, core behavior is honest exhaustion. Lands: chain conversion +
ladder extraction Phase B; checkpoint types Phase A (never emitted in v1).

---

## 4. Tool phase — executor registry and the approval decision (D4)

No hard-coded extension knowledge in core: the planner assigns each call an executor strategy;
the scratchpad special-case becomes a registered `WsLoopback` executor; approval becomes a
decision the driver performs, preserving the live protocol's ordering.

```mermaid
flowchart TD
  PLAN["tool execution planner — PURE<br/>per call: policy decision + executor kind"]
  POL["policy preflight via hook_phase<br/>Allow / Deny / NoOpinion / Pending"]

  subgraph EXECS["executor registry — looked up, not if-chained"]
    EN["ExecNative<br/>dispatch_one via proc/fs ports"]
    ED["ExecDelegated<br/>deferred to host"]
    EH["ExecHandledByExt<br/>extension on_tool_handle"]
    EW["ExecWsLoopback<br/>scratchpad registers this"]
    ES["ExecStreamIsland<br/>contained selectEvents island"]
  end

  APR["AwaitApproval decision -> driver:<br/>1. emit tool_pending (stream_id, call_id)<br/>2. THEN block on approval input<br/>3. EOF/garbage -> carried PolicyDefault<br/>4. re-issue RunTools with remaining entries"]

  RES["ToolResultEnvelope per call"]
  TGATE["transcript gate:<br/>exactly one result per call, ids echoed,<br/>tool_use/tool_result correlation<br/>(the Bedrock rule, enforced not commented)"]

  PLAN --> POL
  POL -->|"Pending"| APR
  APR -->|"approved remainder"| PLAN
  POL -->|"Allow"| EXECS
  EN --> RES
  ED --> RES
  EH --> RES
  EW --> RES
  ES --> RES
  RES --> TGATE
  TGATE -.->|"tool messages into PhaseResult.transcript_append"| OUT["driver applies"]
```

Lands: Phase B (phases + envelopes), Phase C (AwaitApproval inversion, gated by the scripted
TUI approval scenario).

---

## 5. Events — one ledger, two wire-name classes, streaming handle (D5; review R2/R3-family)

```mermaid
flowchart TD
  subgraph PRODUCERS["event producers"]
    PH["phases -> PhaseResult.events<br/>(batched, post-call)"]
    SH["model_phase streaming:<br/>driver-issued ledger APPEND HANDLE<br/>writes thinking_delta / reasoning_delta<br/>in arrival order DURING the call"]
  end

  LED["ledger.append — single logical authority<br/>typed LedgerEvent variants (DST-canonical names)"]

  PROJ["to_schema_v1 projection"]
  PRODW["[prod] names — byte-compatible subset of the<br/>mechanically generated 29-name inventory<br/>(27 emit_event + thinking_delta + reasoning_delta)"]
  NEWW["[NEW] names — additive:<br/>provider_call_prepared, loop_totals_updated,<br/>history_checkpoint, ext_compaction_rejected<br/>gated by TUI unknown-type tolerance check"]

  TUI["TUI + eval harnesses<br/>(existing schema-v1 consumers)"]
  DST["DST invariants consume TYPED events in memory<br/>failure reports print the JSONL projection<br/>ledger IS the trace — replay-ready"]

  PH --> LED
  SH --> LED
  LED --> PROJ
  PROJ --> PRODW --> TUI
  PROJ --> NEWW --> TUI
  LED -.-> DST
```

Lands: Phase B (all emission through the ledger; 48 scattered emit sites retired).

---

## 6. Extension boundary — ABI v3 and the conformance kit (D6, D8, D9)

```mermaid
flowchart LR
  subgraph CORE2["core"]
    CTX["ExtCtx v3:<br/>+ ports (ai_step, http, proc_exec, kv, clock_now, env_get)<br/>+ artifacts (compaction cache channel)<br/>+ telemetry (per-step usage, D9)"]
    GATE2["transcript gate<br/>imports conformance INVARIANTS —<br/>one source of contract law"]
    REC["recorder-wrapped live ports:<br/>every extension effect call -><br/>extension_effect ledger event"]
  end

  subgraph EXT["extension packages (12 registered)"]
    EA["compaction_ai v0.3.0<br/>ports-native, artifact-cached"]
    EST["compaction_structural 1.0<br/>pure ladder, bundled default"]
    EO["others: context_mode, scratchpad,<br/>exa_search, mcp, ..."]
  end

  subgraph KIT["motoko_ext_conformance — lockstep majors with ABI"]
    INV["invariants module — PURE contract law<br/>pairing, ids, no-system, determinism"]
    HAR["harness module — test-only<br/>scripted ExtCtx + fake ports<br/>caps-as-conformance: minimal caps make<br/>raw effect bypasses FAIL at performance time"]
  end

  CTX --> EA
  CTX --> EST
  CTX --> EO
  REC -.-> CTX
  INV -.->|"imported by"| GATE2
  HAR -->|"runs in each extension's CI +<br/>registry probe in core CI (hydration required)"| EXT
  INV --- HAR
```

Fault isolation: obligations are composition-closed, so any composition failure decomposes into
"an extension broke its contract" (kit's job) or "core's chain/arbitration is wrong" (core L1
scenario) — and if neither, the contract was too weak and gains an obligation.

---

## Migration overlay

| Piece | Lands |
|---|---|
| Vocabulary module, sealed types, tier-constant exports, transcript builder extraction | **Phase A** (zero behavior change) |
| PhaseResult wiring, ledger + projection, streaming handle, segment fix, compactor chain, structural extension extraction, provider-call seam | **Phase B** |
| Pure `decide`, decision execution, AwaitApproval inversion, L1 scenario families | **Phase C** |
| ExtCtx ports/artifacts/telemetry, conformance kit, compaction_ai 0.3.0, structural 1.0, registry probe | **ABI v3 track** (parallel to B/C; hydration-required gate class) |
