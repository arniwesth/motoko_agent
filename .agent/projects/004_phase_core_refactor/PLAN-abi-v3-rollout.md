# Plan 2 · Extension ABI v3 rollout (2.2.0 → 3.0)

Date: 2026-07-07
Status: Plan — implementation not started. Two operator sign-offs required (Open Q2, Open Q3;
§2 below). Amendments to ADR-001 Open Questions log drafted here, to be applied on sign-off.
Author session: fresh, grounded at HEAD `8923993`
(`arniwesth/mot-29-implement-remaining-refactor-adrs`), toolchain `AILANG v0.26.0`.
Spec: ADR-001-phase-oriented-core §6 / §6.1; framed by
NOTE-remaining-dst-work-scope-and-sequence.md as **Plan 2, the dependency root**.

## TL;DR

Take the extension ABI **2.2.0 → 3.0** and produce the frozen surface the other two DST plans sit
on. Three type edits (`ExtCtx += {ports, artifacts, telemetry}`, `Compacted += artifacts`, new
`ExtPorts`/`TokenTelemetry`), migrate `compaction_ai` → **0.3.0** (ports-native, artifact-cached,
core-primitive-based — the accept fixture Plan 1 will certify), re-cert bundled
`compaction_structural` → **1.1.0**, and fold in the one core-side DST completion (assert an L1
scenario over a `LedgerTrace` captured from a driven run).

**Closes two ADR-001 open questions (operator sign-off required, §2):**
- **Q2 · artifacts** → stay raw `Json` (one self-owned producer/consumer; no speculative typing).
- **Q3 · `ExtPorts`** → freeze **{ `ai_step`, `proc_exec`, `clock_now`, `env_get` }** (one exercised
  port + three zero-invention projections of live core `Ports` seams); **defer `http` + `kv`** (no
  consumer — addable later as a host-only constructor break, *not* a major bump).

**Five ADR gaps / re-ground corrections the plan carries (§1), the load-bearing ones:**
- **Blast radius is wider than ADR §6 says** — `Compacted` breaks **17 sites across 7 files**
  (construct *and* pattern-match), incl. **live core** `runtime.ail:159,168`; `ExtCtx` breaks ~9
  construction sites incl. two ADR-unnamed `rpc.ail` builders (§4).
- **The threading is real state plumbing, not "expose existing fields"** — `C2LoopState` carries
  *neither* `ext_artifacts` nor `telemetry` across steps; without adding them the artifact cache is
  dead (§5.1).
- **The driven-trace mechanism already exists** (`phase_c2_wiring_scenarios.ail`, ungated) — reuse +
  gate it, don't rebuild (§5.4).
- `ai_step` returns `Result[string, string]`, not `Result[StepResult, AIError]`, to keep the ABI
  free of `std/ai` imports (§2).

**Gates (two classes, do not conflate, §8):** ABI/compaction packages → **hydration-required**
(`ailang lock` first); the ledger scenario → **core-DST** but empirically needs
`--caps IO,Env,Clock,FS,Trace` (no provider/network). **Out of scope:** the conformance kit itself
(Plan 1) and the checkpoint trigger (Plan 3).

## 0. Grounding note (read first)

Every `file:line` below was re-observed at HEAD `8923993` on 2026-07-07 per
`re-ground-inherited-anchors-before-building.md`. The handoff's anchors were mostly accurate; the
material corrections found during re-grounding are called out inline as **[re-ground]** and
collected in §1 (ADR gaps) where they change what the ADR implies. Anchors are starting points,
not guarantees — re-verify again before editing, since this is a moving branch and a registry
cache.

Confirmed at HEAD:
- ABI pin is `sunholo/motoko_ext_abi = 2.2.0` (`ailang.lock:73-75`). ✔ still the pin.
- `compaction_ai = 0.2.0` (`ailang.lock:138-140`); only `0.2.0` in the registry cache. ✔
- `compaction_structural = 1.0.0` (`ailang.lock:160-163`); `ailang.toml` deps
  `motoko_ext_abi = 2.2.0`. ✔
- No `2.3.0`/`3.0` ABI and no `0.3.0` compactor exist yet — this plan produces them.

---

## 1. ADR gaps found (ADR-001 §6 is a decision, not a plan)

ADR-001 §6 is thinner than ADR-002 was, exactly as the handoff warned. Five facts a sequencing
plan needs are not derivable from §6 + prose and were only visible in source. None re-opens a
decision; each is a scoping fact the plan must carry.

- **G-A1 — the `ExtCtx` blast radius is ~9 construction sites, not "core `mk_v2_ext_ctx` +
  extension test fixtures."** ADR §6 names only `mk_v2_ext_ctx`. At HEAD, record-literal `ExtCtx`
  construction sites are: `src/core/session.ail:682` (`mk_v2_ext_ctx`), **`src/core/rpc.ail:118`
  and `:224`** (two legacy-path ctx builders the ADR does not mention), `src/core/ext/runtime.ail:341`
  (test), five DST/smoke scripts (`scripts/smoke_v2_pending.ail:128`,
  `smoke_v2_policy_denial.ail:84`, `smoke_v2_handle.ail:108`, `smoke_v2_compaction_chain.ail:57`,
  `compaction_policy_dst.ail:105`), and `packages/motoko-ext-compaction-structural/compaction_structural.ail:209`
  (its inline test). All are *constructor-only* (add the new fields, no logic), but the count and
  the two `rpc.ail` sites belong in the blast-radius table (§4).

- **G-A2 — core `runtime.ail` *pattern-matches* `Compacted`, so `Compacted += artifacts` is a
  source-level break inside core, not only in compactor packages.** ADR §6 frames Compacted
  breaks purely as *construction* sites ("`compaction_ai` is the first and currently only such
  package"). At HEAD, `Compacted` is also **deconstructed** at
  `src/core/ext/runtime.ail:159` (`Compacted(_, note)`) and `:168` (`Compacted(compacted_msgs,
  note)`) — the live chain fold. A positional constructor arity change breaks these patterns too.
  In-core *construction* sites also exist beyond compaction_ai:
  `src/core/test/ext_fixture.ail:88` and the three chain-test hooks
  `src/core/ext/runtime.ail:434/440/446`. So "only compaction_ai" is true only at *external
  registry package* granularity; §4 enumerates the full set.

- **G-A3 — `ExtCtx.telemetry` has no exercised consumer in this plan, and the existing typed
  telemetry type carries no cache tokens.** ADR §6/D9 wants telemetry = "`last_input_tokens`,
  output/**cache** tokens." The live typed carrier is `TokenTelemetry = { last_input_tokens,
  last_output_tokens }` (`src/core/phase_vocab.ail:154-157`) — **no cache fields**. Cache tokens
  exist only on `StepResult` and only surface in the JSONL projection
  `per_step_usage_kvs` (`src/core/session.ail:548-560`), not in the typed carrier. And the only
  compactor migrated here (`compaction_ai` 0.3.0) uses *estimate*-based usage
  (`estimate_tokens_messages`), not `ExtCtx.telemetry` — actual-token gating is the D9-deferred
  future compactor (Open Q4). So telemetry is **pure forward surface with zero first consumer**.
  This forces a shape decision the ADR does not make; resolved in §5.3 (reuse the input/output
  `TokenTelemetry`; defer cache-token fields to the first actual-token consumer, mirroring the
  Open-Q2 "no speculative surface" logic).

- **G-A4 — `compaction_ai` reaches core's measurement primitives as a `motoko_core` package
  dependency, and there is a `[Msg]` vs `[Message]` type gap at that seam.** ADR §6 says v0.3.0
  "consumes core's `estimate_tokens_messages`/`usage_percent_with_limit`." Those are
  `export pure func` in the **published** package
  `.packages/motoko_core/src/core/compaction.ail:17,25` (the structural compactor already deps on
  `motoko_core` by path — `packages/motoko-ext-compaction-structural/ailang.toml`). But both take
  `[Message]` (`std/ai`), while extension hooks receive `[Msg]` (ABI). v0.3.0 must convert
  `[Msg] → [Message]` at the call, or core must expose a `Msg`-typed helper. §6.2 picks
  Msg→Message conversion in the extension (no core change).

- **G-A5 — a *driven*-trace L1 scenario cannot run under AC4's literal "`--caps IO` or less."**
  ADR-001 Acceptance criterion 4 (lines 490-492) says "the compaction L1 family … runs with
  `--caps IO` or less, no Ollama/OpenRouter/network." That is exact for the **pure-invariant**
  scenarios, but the handoff's folded item explicitly wants a scenario that captures a
  `LedgerTrace` *from a real run* — and a real `run_v2_session_traced` run **empirically requires
  `--caps IO,Env,Clock,FS,Trace`** (measured at HEAD; §5.4), because the loop performs `now()`
  (Clock), `Trace` spans (`session.ail:1646-1648`), and FS/Env host effects even with scripted
  ports. It does **not** need `AI`/`Net`/`SharedMem`/`Stream` (never *performed*). Reconciliation:
  AC4's binding criterion is "**no provider / no network / no hydration**," which the driven-trace
  scenario satisfies; "`--caps IO` or less" describes the pure family only. Recommend a one-line
  ADR-001 AC4 clarification ("pure-invariant scenarios `--caps IO`; driven-trace scenarios
  `--caps IO,Env,Clock,FS,Trace`, still no provider/network/hydration"). Not blocking; no decision.

- **G-A6 — implementation correction: ABI/package sources must be workspace-durable, not created
  only in `~/.ailang/cache`.** The original plan described producing new package versions under the
  local registry cache, but that cache is disposable across dev-container rebuilds. The durable
  rollout therefore vendors/re-certs the active extension packages under `packages/` and points
  `ailang.toml`/`ailang.lock` at path dependencies. AILANG has no manifest-level override that
  reconciles exact transitive `motoko_ext_abi = 2.2.0` requirements with a root ABI 3.0 path
  dependency, so active registry extensions must be workspace re-certified or published together.
  Related source fact: importing `.packages/motoko_core` from the workspace `compaction_ai` package
  collides with the root `src/core/compaction.ail` module declaration (`module_prefix = "src"` in
  `.packages/motoko_core`); the monorepo fixture imports the live `src/core/compaction` primitive
  instead, preserving a single source inside this checkout.

**No new decision is implied by any of these.** They sharpen the blast radius (G-A1, G-A2, and the
17-site `Compacted` sweep in §4b), resolve a shape the ADR left implicit (G-A3), name an import
path (G-A4), reconcile a caps clause against an empirically measured run (G-A5), and correct the
package-source mechanics for durable implementation (G-A6).

---

## 2. Decisions this plan closes (ADR-001 Open Questions 2 and 3)

ADR-001 defers both into "the `compaction_ai` v0.3.0 migration, not before" (Open Q2 line 541-542,
Open Q3 line 543-544). This is that migration. Each is closed below with rationale grounded in the
0.3.0 design, an operator sign-off line, and the ADR-001 amendment text (D9 / D-B5 pattern).

### Open Q2 — `artifacts`: raw `Json` vs a typed record → **raw `Json`** (ADR lean confirmed)

**Resolution:** keep `artifacts: Json`. **Rationale:** the only artifact producer *and* consumer
in this plan is `compaction_ai` 0.3.0, which reads/writes a single self-owned shape (a cached
segment summary keyed by a digest — §6.1). One producer that is also its own only consumer is
exactly the "no second consumer yet" condition ADR-001 names for staying on `Json`. The core
plumbing is already `Json`: `StepState.ext_artifacts: Json` (`phase_vocab.ail:351`), seeded
`jo([])` at `session.ail:412` and threaded through `apply_delta`
(`phase_vocab.ail:379`). Typing the artifact now would add a record to the ABI's public surface
with exactly one reader — speculative surface the ADR's own discipline rejects. Revisit at the
second consumer.

> **Operator sign-off (Open Q2):** ____________________  (confirm: artifacts stay `Json` in ABI 3.0)

### Open Q3 — exact `ExtPorts` field list → **freeze the four consumer-/seam-justified ports; defer `http` + `kv`**

ADR §6 names six intended ports (`ai_step, http, proc_exec, kv, clock_now, env_get`). The handoff's
discipline is explicit: *"the port set is justified by its first real consumer, not invented ahead
of one."* Re-grounding against what `compaction_ai` 0.3.0 actually needs and against the **already
live** core port seams splits the six cleanly:

| ADR port | First-consumer / seam status at HEAD | Decision |
|---|---|---|
| `ai_step` | **Exercised** — 0.3.0 replaces its direct `std/ai.step(model, msgs, [])` call (`compaction_ai.ail:91`) with `ctx.ports.ai_step`. | **Freeze.** |
| `proc_exec` | Not exercised by 0.3.0, but **already a live core seam** `tool_exec` (`src/core/ports.ail:22`) — projecting it costs zero invention. | **Freeze** (project from `Ports.tool_exec`). |
| `clock_now` | Same — live core seam `clock_now` (`ports.ail:20`), verbatim signature. | **Freeze** (project from `Ports.clock_now`). |
| `env_get` | Same — live core seam `env_get` (`ports.ail:21`), verbatim signature. | **Freeze** (project from `Ports.env_get`). |
| `http` | **No consumer, no live core seam** (core `Ports` has no `Net` port). Would be invented ahead of use. | **Defer.** |
| `kv` | **No consumer** — 0.3.0's artifact cache uses the `artifacts` field (in-session, §6.1), *not* a persistent KV store. No live core seam. | **Defer.** |

**Resolution (recommended, Option B):** `ExtPorts` = **{ `ai_step`, `proc_exec`, `clock_now`,
`env_get` }** — the one exercised port plus three already-live core seams projected at zero
invention cost. **Defer `http` and `kv`** until a real consumer appears.

**Why deferring costs nothing later:** `ExtPorts` is constructed **only by the host** (core builds
it from its own `Ports` record at the `mk_v2_ext_ctx` seam — §5.2). Extensions *receive*
`ctx.ports` and read fields; a reader is unaffected by a record gaining fields. So adding `http`/`kv`
later is a **constructor-only break at a single core site — not an ABI major bump**. Freezing them
now would put two reader-less fields into the 3.0 public surface with no way to validate their
signatures against a consumer (violating the same discipline that produced this table).

**Alternative (Option A, ADR-literal):** freeze all six now. Rejected as recommended default
because it invents `http`/`kv` signatures with no consumer to pin them and no cheaper-later
argument against it. Recorded so the operator can choose it.

**Frozen signatures (Option B), grounded in `src/core/ports.ail` and the ABI's purity pattern:**

```ail
export type ExtPorts = {
  -- Exercised by compaction_ai 0.3.0, replacing its std/ai.step(model, msgs, []) call.
  -- Returns Result[string, string] (Ok = response content, Err = error message), NOT
  -- Result[StepResult, AIError]: (1) the ABI imports ONLY std/option + std/json and inlines
  -- every std/ai shape (Msg/ToolCall/ToolSchema) to stay effect-func-free — verified at HEAD,
  -- types.ail:11-12 — so importing std/ai StepResult/AIError would break that deliberate
  -- pattern; (2) the sole consumer reads only result.message.content and e.code/e.message
  -- (verified compaction_ai.ail:92-93), which a string result covers exactly. The host wraps
  -- core Ports.model_step and returns .message.content on Ok / the error string on Err.
  -- Row = on_pre_step's hook row (types.ail:134) so the extension can call it inside on_pre_step;
  -- note Trace is deliberately absent (on_pre_step's row has no Trace), so the host wrapper must
  -- NOT surface Trace from model_step (ports.ail:18 declares Trace) — discharge it host-side.
  ai_step:   (string, [Msg]) -> Result[string, string] ! {AI, IO, Process, FS, Env, Net, SharedMem, Clock, Stream},
  -- Projected verbatim from core Ports.tool_exec (ports.ail:22).
  proc_exec: (string, string) -> string ! {IO, Process, FS},
  -- Projected verbatim from core Ports.clock_now (ports.ail:20).
  clock_now: () -> int ! {Clock},
  -- Projected verbatim from core Ports.env_get (ports.ail:21).
  env_get:   (string, string) -> string ! {Env}
}
```

> **Operator sign-off (Open Q3):** ____________________  (choose Option B [recommended] or Option A)

### ADR-001 amendment text (apply to Open Questions log on sign-off)

> 2. ~~`artifacts` as raw `Json` vs. a typed artifact record~~ **Closed 2026-07-07 (Plan 2, ABI v3
>    rollout; operator sign-off).** Raw `Json`. Sole producer/consumer in the migration is
>    `compaction_ai` 0.3.0 reading its own cached-summary shape; core plumbing is already
>    `Json` (`StepState.ext_artifacts`). Revisit at a second consumer.
> 3. ~~Exact `ExtPorts` field list~~ **Closed 2026-07-07 (Plan 2; operator sign-off).**
>    `ExtPorts = { ai_step, proc_exec, clock_now, env_get }`. `ai_step` is justified by
>    `compaction_ai` 0.3.0; the other three are zero-invention projections of live core
>    `Ports` seams. `http` and `kv` are **deferred** (no consumer; no live seam) — addable later
>    as a constructor-only break at the single core construction site, *not* a major bump, since
>    only the host constructs `ExtPorts`.

---

## 3. What ABI 3.0 changes, exactly (the frozen surface)

Three type edits in `~/.ailang/cache/registry/sunholo/motoko_ext_abi/<3.0>/types.ail` (grounded in
2.2.0 at `types.ail:62,124-126,146`). This is the surface Plan 1 (conformance kit) will certify;
it must be frozen here.

**3a. `ExtCtx` gains three fields** (append after `context_limit`, `types.ail:80`):

```ail
export type ExtCtx = {
  ... existing 14 fields (task … context_limit) ...,
  ports: ExtPorts,        -- Open Q3 shape above
  artifacts: Json,        -- Open Q2: run-scoped artifacts in (prior-step cache); Json
  telemetry: TokenTelemetry  -- prior-step usage; input/output only (G-A3, §5.3)
}
```

**3b. `PreStepDecision.Compacted` gains an artifacts field** (`types.ail:126`) — **[re-ground:
the handoff called this `CompactionResult`; the type is `PreStepDecision`, constructor `Compacted`
at `types.ail:126`. There is no `CompactionResult` type.]**

```ail
export type PreStepDecision
  = PassThrough
  | Compacted(msgs: [Msg], note: string, artifacts: Json)   -- was Compacted(msgs, note)
  deriving (Eq)
```

**[re-ground, verified]** The `deriving (Eq)` at `types.ail:127` **survives** the `Json` field: a
minimal probe (`type D = A | C(note: string, artifacts: Json) deriving (Eq)` with `jo([]) == jo([])`)
type-checks and evaluates `true` under `AILANG v0.26.0`. `Json` is `Eq`-comparable (the ABI already
derives `Eq` on `ToolPolicyDecision`/`FinalizeDecision`, and `ToolCallEnvelope.arguments` is `Json`).
No `deriving`-clause change needed.

**3c. New ABI types `ExtPorts` and `TokenTelemetry`** added to `types.ail` (TokenTelemetry mirrors
`phase_vocab.ail:154-157` — see G-A3 / §5.3 for why input/output only). `ExtPorts` per §2.

**No effect-row changes** (ADR §6, confirmed: the four max-row hooks at `types.ail:134,137,139,141`
are already at full rows; the three pure hooks stay pure). Bump `motoko_ext_abi` **major → 3.0**,
publish, and update `ailang.lock`.

---

## 4. Blast-radius table (ADR-002 format; every site cited at HEAD `8923993`)

Two break classes, per ADR §6 — sharpened by G-A1/G-A2. **Constructor-only** = a record/`ExtCtx`
literal that must gain fields (mechanical, no logic). **Source-level** = a `Compacted` positional
constructor or pattern whose *arity* changes.

### 4a. Constructor-only breaks — `ExtCtx += {ports, artifacts, telemetry}`

| Site (HEAD) | What it is | Change |
|---|---|---|
| `src/core/session.ail:682` `mk_v2_ext_ctx` | live v2 ctx builder (the ADR-named one) | add 3 fields; **thread real values** (ports from provider, artifacts+telemetry from `StepState`) — §5.2 |
| `src/core/rpc.ail:118` | legacy budget-hook ctx **[G-A1, ADR-unnamed]** | add 3 fields; ports = a no-op/empty projection, artifacts `jo([])`, telemetry zero |
| `src/core/rpc.ail:224` | legacy system-prompt ctx **[G-A1, ADR-unnamed]** | same |
| `src/core/ext/runtime.ail:341` | in-repo test ctx | add 3 fields (test values) |
| `scripts/smoke_v2_pending.ail:128` | smoke fixture | add 3 fields |
| `scripts/smoke_v2_policy_denial.ail:84` | smoke fixture | add 3 fields |
| `scripts/smoke_v2_handle.ail:108` | smoke fixture | add 3 fields |
| `scripts/smoke_v2_compaction_chain.ail:57` | smoke fixture | add 3 fields |
| `scripts/compaction_policy_dst.ail:105` | DST fixture | add 3 fields |
| `packages/motoko-ext-compaction-structural/compaction_structural.ail:209` | inline test ctx | add 3 fields |

**Vestigial-mirror check [re-ground]:** `src/core/ext/types.ail` defines its own `ExtCtx` (:11) and
`PreStepDecision`/`Compacted` (:67-69), but **no live `.ail` source imports `src/core/ext/types`** —
`session.ail:47`, `runtime.ail:11-24`, and `ports.ail:12` all import these types from
`pkg/sunholo/motoko_ext_abi/types`. WI-1 must **verify** this (grep for live importers) and then
either delete the mirror or update it in lockstep. Do not silently leave a diverged second `ExtCtx`.

### 4b. Source-level breaks — `Compacted(msgs, note) → Compacted(msgs, note, artifacts)`

| Site (HEAD) | Construct / Match | Owner | Change |
|---|---|---|---|
| `~/.ailang/cache/.../compaction_ai/0.2.0/compaction_ai.ail:148` | **construct** | external registry pkg → **0.3.0** (§6) | real artifacts (cached summary) |
| `packages/.../compaction-structural/compaction_structural.ail:121,124,130,134` | **construct** ×4 | bundled pkg → **1.1.0 re-cert** (§7) | `jo([])` (structural produces no AI artifact) |
| `packages/.../compaction_structural.ail:215` | **match** `Compacted(_, _)` | bundled pkg test | add arity `_` |
| `src/core/test/ext_fixture.ail:88` | **construct** | in-repo test fixture | `jo([])` |
| `src/core/ext/runtime.ail:434,440,446` | **construct** ×3 (chain-test hooks) | in-repo test | `jo([])` |
| `scripts/phase_c2_wiring_scenarios.ail:253,254` | **construct** ×2 (stage_hook) | in-repo DST harness [re-ground] | `jo([])` |
| `scripts/smoke_v2_compaction_chain.ail:117,123,129` | **construct** ×3 | in-repo smoke [re-ground] | `jo([])` |
| `src/core/ext/runtime.ail:159` `Compacted(_, note)` | **match** | **live core chain fold** [G-A2] | add arity `_` |
| `src/core/ext/runtime.ail:168` `Compacted(compacted_msgs, note)` | **match** | **live core chain fold** [G-A2] | add arity binder; wire artifacts into stage (§5.2) |
| `scripts/compaction_policy_dst.ail:156,163,253,264` | **match** ×4 | in-repo DST [re-ground] | add arity `_` |

The only **external** package that breaks is `compaction_ai` — ADR §6's claim holds at that
granularity. But the in-repo edit set is the whole 4b table — **17 sites across 7 files** (initial
grep missed the five `scripts/` files; re-swept `grep -rn 'Compacted(' scripts/ packages/` at HEAD),
and two of them are **live core code** (`runtime.ail:159,168`), not tests. A mechanical
`Compacted(m, n) → Compacted(m, n, jo([]))` codemod covers every site except `compaction_ai`
(real artifacts, §6) and `runtime.ail:168` (wire artifacts into the stage result, §5.2).

---

## 5. Core-side wiring (the one DST completion + the ABI threading)

### 5.1 Where `artifacts` and `telemetry` live — and the cross-step gap (re-ground correction)

The `StepState` **type** carries both (`phase_vocab.ail:345-351`): `telemetry: TokenTelemetry` and
`ext_artifacts: Json`, with a `StateDelta`/`apply_delta` path (`:358-396`) and `model_phase.result_delta`
building telemetry from `StepResult` (`model_phase.ail:17`). **But these are transient *within* a
step, not persisted *across* steps** — and that gap is load-bearing:

- `c2_step_state` **rebuilds `StepState` fresh every iteration**, hard-resetting
  `telemetry: {0, 0}` and `ext_artifacts: jo([])` (`session.ail:409,412`).
- The cross-step carrier is **`C2LoopState`** (`session.ail:320-336`), which has
  `msgs, step_idx, totals, provider, pending_*, trace, …` but **neither `ext_artifacts` nor
  `telemetry`**. So a value computed in step N's `StepState` is dropped at the tail-recursion and
  step N+1 starts from zero/empty.

Consequence: exposing `StepState`'s fields into `ExtCtx` is **not** enough. `ExtCtx.artifacts` would
always be empty and `ExtCtx.telemetry` always `{0,0}` unless `C2LoopState` is extended to persist
them. The artifact cache (§6.1) — the whole point of which is reusing step N's summary at N+1 —
**cannot function** without this. So the threading *is* new state plumbing, contrary to a first read.

### 5.2 The threading (WI-2)

1. **Project `ExtPorts` from core `Ports`.** Add a pure `ext_ports_of(p: Ports) -> ExtPorts` that
   maps `tool_exec → proc_exec`, `clock_now`, `env_get` verbatim, and adapts `model_step` into
   `ai_step` (drop the streaming `on_chunk` param — a summary needs no stream — and map the result
   to `Result[string, string]`: `Ok(sr) → Ok(sr.message.content)`, `Err(e) → Err("${e.code}: ${e.message}")`,
   so the ABI stays free of `std/ai` types, §2). Core's `Ports` is available in `c2_loop` via the
   `Ported` provider (`session.ail:442-444`, `ports.ail:17`).
2. **Persist artifacts + telemetry across steps (the §5.1 gap).** Add `ext_artifacts: Json` and
   `telemetry: TokenTelemetry` to **`C2LoopState`** (`session.ail:320`); seed them
   (`jo([])` / `{0,0}`) in `c2_initial_state` (`:420`); stop `c2_step_state` from hard-resetting
   them (`:409,412`) — carry the `C2LoopState` values in instead; and when building each next
   `C2LoopState`, write back (a) the step's telemetry after the model phase and (b) the fold's
   artifacts after the pre-step chain.
3. **Extend `mk_v2_ext_ctx`** (`session.ail:670-697`) to take `ports: ExtPorts`, `artifacts: Json`,
   `telemetry: TokenTelemetry` and set the three new fields. Update its four call sites
   (`session.ail:1325,1352,1394,1472`) to pass `ext_ports_of(...)` and the **`C2LoopState`**
   artifacts + telemetry (per step 2), so the pre-step `ctx` (`:1394`) sees the prior step's cache.
4. **Return `Compacted`'s artifacts from the fold.** `fold_pre_step_chain` currently returns
   `{ msgs, stages }` (`runtime.ail:150-151`); add an `artifacts` field so the chain's final
   artifacts reach `c2_loop`, which writes them into the next `C2LoopState` (step 2b). This closes
   the artifact-cache loop end-to-end and is what makes the kit's future `artifact_cache_effective`
   scenario meaningful. **Chain-artifact merge semantics** (multiple compactors returning artifacts)
   are undefined by ADR §6 — with one artifact-producing compactor (`compaction_ai`) at HEAD,
   last-writer-wins is sufficient; flag a richer merge as follow-on if a second producer appears.

### 5.3 `TokenTelemetry` shape (resolves G-A3)

**Mirror** `TokenTelemetry = { last_input_tokens, last_output_tokens }` (`phase_vocab.ail:154-157`)
as a *new type defined in the ABI package* — the ABI cannot import `src/core/phase_vocab`, so it
declares its own structurally-identical `TokenTelemetry`, exactly as it inlines `Msg` today.
`mk_v2_ext_ctx` converts the core `TokenTelemetry` value into the ABI one at the seam (a trivial
field copy — like `messages_to_msgs`; distinct nominal types even when structurally identical).
**Do not** add cache-token fields yet:
no consumer exists (0.3.0 uses estimate-based usage), and the cache figures live only in the JSONL
projection `per_step_usage_kvs` (`session.ail:553-559`), never in the typed carrier. Adding cache
fields is deferred to the first actual-token-gated compactor (Open Q4 / D9 future) — the identical
"no speculative surface" logic as Open Q2. **Note in the ADR amendment** that ADR §6's "output/cache
tokens" phrasing is satisfied by input/output now, cache-on-first-consumer later.

### 5.4 Typed-ledger consumption wiring — closing the dst-status "partial" (WI-5)

**[re-ground — this section was rewritten after review; my first draft's premise was false.]** The
capture *mechanism already exists and is exercised.* Two distinct harness files must be
distinguished:

- `scripts/phase_c_l1_scenarios.ail` (**gated**, `--caps IO`, `Makefile:54`) — the compaction/
  checkpoint invariant family. Confirmed at HEAD to assert **only over pure functions / hand-built
  inputs** (`validate_compactor_output`, `history_valid_transcript`, `project`,
  `seal_compacted_payload`, `validate_checkpoint_chain`; scenarios at `:126,137,172,258,272`). It
  imports no `run_v2`/`Session.` (grep-verified). This is the "partial."
- `scripts/phase_c2_wiring_scenarios.ail` (**ungated** — no `Makefile`/CI reference, grep-verified)
  — **already drives real scripted runs and asserts over the captured `LedgerTrace`**:
  `run_scripted(rt, script)` calls `Session.run_v2_session_traced(..., Scripted(script))`
  (`:161-163`) and asserts over `traced.trace` — decision sequences via `assert_decisions`/
  `DecisionRecord` (`:153`) and stage outcomes via `has_stage_passed/applied/rejected` over
  `CompactionStageRecord` (`:328-378`).

So the loop threading is done (`c2_loop` builds the trace via `c2_append_decision`/
`c2_trace_stage_records`/`c2_trace_wire_events`, `session.ail:354-368`; every arm returns
`{result, trace}`, `TracedSessionResult`, `:134-137`) **and** a driven-trace harness exists. The
residual gap is therefore narrower and more specific than "build the mechanism":

1. **The gated L1 suite has no driven-trace scenario at all** — its compaction-content invariants
   (system-prefix / tool-pairing preserved *in a driven compacted payload*, summary-cache reuse,
   checkpoint-output validity) are proven only over synthetic inputs, never over a trace from a run.
2. **The one harness that drives runs (`phase_c2_wiring`) is ungated** and covers only decision/
   stage *wiring*, not compaction *content* invariants.

**Caps — corrected and empirically measured.** A driven scripted run is **not** `--caps IO`. Running
`phase_c2_wiring_scenarios.ail` at HEAD faults progressively (`Env` → `FS` → `Clock` → `Trace`) and
**passes only under `--caps IO,Env,Clock,FS,Trace`**. Crucially it does **not** need `AI`, `Net`,
`SharedMem`, or `Stream` (declared in the effect row, never *performed* under scripted ports —
caps-as-conformance, §6.1). So a driven-trace scenario is still squarely **core-DST gate class** by
AC4's substantive clause ("no Ollama/OpenRouter/network") — no provider, no network, no hydration —
but requires the deterministic-effect set, not bare `IO`. See G-A5 (§1) for the AC4 wording
reconciliation.

**Deliverable (scope: reuse existing mechanism + ≥1 compaction-content invariant over a driven
trace + gate it):**
1. **Reuse** `run_scripted` from `phase_c2_wiring_scenarios.ail` (do not rebuild a driver). Either
   add the compaction-content scenario there, or lift `run_scripted` into a shared helper the L1
   suite imports.
2. **Add one compaction-content invariant over a driven trace.** Recommended:
   `compactor_chain_order_is_registry_order` — drive a two-compactor scripted run (a `stage_rt()`
   analogue) and assert the **captured** `CompactionStageRecord` *order* equals registry order.
   `phase_c2_wiring` asserts stage *presence* (pass/apply/reject) but **not order**, and the gated
   L1 suite asserts neither over a real trace — so this is genuinely new coverage, exercising the
   live `fold_pre_step_chain` → `stage_record` → `ledger_append` path (`runtime.ail:150+`,
   `phase_vocab.ail:523`) end-to-end.
3. **Gate the driven-trace harness** in the `Makefile` under `--caps IO,Env,Clock,FS,Trace`
   (either `phase_c2_wiring_scenarios.ail` as-is, or a merged suite). An ungated harness is not a
   DST gate. *(Synergy: the ABI-v3 `Compacted += artifacts` change forces edits to
   `phase_c2_wiring:253,254` anyway (§4b), so touching this file already rides WI-2/WI-4.)*
4. **Follow-on (enumerated, not in this plan):** convert `history_rewrite_requires_checkpoint_event`,
   `checkpoint_output_is_valid_transcript`, `summary_cache_replay_stable` to driven-trace form once
   the shared helper is gated.

---

## 6. `compaction_ai` 0.3.0 (the fixture Plan 1 will certify — produced here, not tested here)

Target: `compaction_ai` **0.3.0**, ports-native + artifact-cached + core-primitive-based, that makes
the kit's four compactor scenarios resolvable (`system_prefix_preserved`, `tool_pairing_preserved`,
`deterministic_replay`, `artifact_cache_effective`). Baseline: `0.2.0`
(`compaction_ai.ail`, 152 lines).

### 6.1 The four changes

1. **Ports-native (`ai_step`).** Replace `import std/ai (Message, step)` + the direct
   `step(model, msgs, [])` in `summarize_with_ai` (`compaction_ai.ail:89-95`) with
   `ctx.ports.ai_step(cfg.model, prompt_msgs)`. The extension no longer holds the `AI` effect
   itself for summarization; it reaches the model only through the port (the property the kit's
   caps-as-conformance model polices). Keep the `Result` match — `ai_step` returns
   `Result[string, string]` (§2): `Ok(content)` replaces `result.message.content` (`:92`),
   `Err(msg)` replaces the `"[summarizer unavailable: ...]"` fallback (`:93`), same
   continue-on-failure behavior.
2. **Core measurement primitives (G-A4).** Delete the local `estimate_tokens`/`estimate_msgs_tokens`/
   `usage_percent` (`compaction_ai.ail:28-46`); depend on `motoko_core` (path dep, as
   `compaction-structural/ailang.toml` already does) and import
   `estimate_tokens_messages, usage_percent_with_limit` from
   `pkg/sunholo/motoko_core/src/core/compaction`. **Convert `[Msg] → [Message]`** at the call
   (G-A4: the primitives take `[Message]`; the extension holds `[Msg]`). This removes the
   `usage_percent` duplication ADR-001 flags as a structural defect.
3. **Prefix- and pairing-aware split (fixes the two live bugs).** The two bugs are in `split_msgs`
   (`compaction_ai.ail:101-110`), which splits purely by position:
   - *system_prefix_preserved:* a system message at the head can fall into `old` and be summarized
     away. 0.3.0 must **never** place the system prefix into `old` — keep it verbatim in the output
     head. (Core also helps here via the Phase-B "pass `CompactableSegment`, not the raw list"
     fix, but 0.3.0 must be correct on its own for the kit's synthetic fixture.)
   - *tool_pairing_preserved:* the `keep_recent` boundary can cut between a `tool_use` (→`old`) and
     its `tool_result` (→`recent`), severing the pair (422). 0.3.0 must **snap the split boundary**
     so no `tool_call_id` correlation crosses it (the ABI carries `tool_calls`/`tool_call_id` on
     `Msg`, `types.ail:39-44` — the data needed is present).
4. **Artifact cache (via the `artifacts` field, not a port).** Read `ctx.artifacts` for a cached
   summary keyed by the old-segment digest; on hit, reuse it and **do not call `ai_step`**; on
   miss, summarize and return the new cache in `Compacted(compacted, note, artifacts')`. Artifact
   shape (Open Q2 `Json`, self-owned): e.g. `{ "compaction_ai": { "segment_digest": <str>,
   "summary": <str> } }`. This is what makes a re-run with an **empty `ai_step` script** pass
   instead of hitting the poison sentinel (ADR §6.1 worked example) — and it is closed end-to-end
   only because §5.2 steps 2+4 persist `Compacted.artifacts` into `C2LoopState.ext_artifacts` across
   steps (without that cross-step plumbing, `ctx.artifacts` is empty every step and the cache is
   dead — the §5.1 gap).

### 6.2 The single source-level break in 0.3.0

`Compacted(compacted, note)` at `compaction_ai.ail:148` → `Compacted(compacted, note, artifacts')`.
Bump dep `motoko_ext_abi = 3.0`, publish `0.3.0`, update `ailang.lock`.

> **Boundary:** this plan *produces* 0.3.0 as the accept fixture. It does **not** write the harness,
> invariants, or scenarios that test it — that is Plan 1 (conformance kit). The fail-then-pass proof
> (`0.2.0` rejected / `0.3.0` accepted) is Plan 1's acceptance criterion; here we only guarantee
> 0.3.0 is *built to pass* it.

---

## 7. `motoko_ext_compaction_structural` re-cert on 3.0 (WI-4)

Bundled, **pure**, needs no ports (`compact_for_pre_step` is `export pure func`,
`compaction_structural.ail:117`; no `std/ai`/`Net`/`step`). Per ADR §6 it may ship early on 2.2.0
and re-cert on 3.0. **[re-ground: "re-cert" is not zero code change.]** The `Compacted += artifacts`
arity change forces mechanical edits at its four construction sites
(`compaction_structural.ail:121,124,130,134` → append `jo([])`, since structural produces no AI
artifact) and one match (`:215` → add `_`), plus the inline-test `ExtCtx` at `:209` (add 3 fields).

Work: version `1.0.0 → 1.1.0` (`ailang.toml`); dep `motoko_ext_abi 2.2.0 → 3.0`; the mechanical
Compacted/ctx edits above; republish; update `ailang.lock`. No logic change; no ports.

---

## 8. Gate / acceptance criteria (checkable commands)

Derived from ADR-001 §6 + Acceptance criteria 2-3, honoring the **gate-class split** (ADR §6
"Gate separation", lines 471-476). Two distinct classes — do not conflate.

### 8a. Registry / conformance gate class — **hydration required, `ailang lock` first**

These touch published packages and the registry; run in core CI against hydrated extensions.

```
# ABI 3.0 published, lock updated to the majors in lockstep:
ailang lock            # resolves motoko_ext_abi 3.0, compaction_ai 0.3.0, compaction_structural 1.1.0
ailang check ~/.ailang/cache/registry/sunholo/motoko_ext_abi/<3.0>/types.ail
ailang check <compaction_ai 0.3.0 source>          # ports-native, one Compacted site updated
ailang check packages/motoko-ext-compaction-structural/compaction_structural.ail
```

- **G1** `ailang lock` resolves `motoko_ext_abi = 3.0`, `compaction_ai = 0.3.0`,
  `compaction_structural = 1.1.0` with no 2.2.0 residue in `ailang.lock`.
- **G2** All three packages `ailang check`-clean against ABI 3.0.
- **G3** `ExtPorts`/`Compacted`/`ExtCtx` shapes match §2/§3 exactly (frozen surface Plan 1 depends
  on). *The fail-then-pass conformance proof (0.2.0 rejected / 0.3.0 accepted) is **Plan 1's**
  gate, not this plan's — this plan's obligation is only that 0.3.0 is built to pass it.*

### 8b. Core-DST gate class — **no provider, no network, no hydration** (the ledger item only)

Two cap tiers within this class (empirically measured at HEAD, §5.4 / G-A5): the **pure-invariant**
suite stays at `--caps IO`; the **driven-trace** scenario needs `--caps IO,Env,Clock,FS,Trace` (but
still no `AI`/`Net`/`SharedMem`/`Stream` — no provider, no network).

```
# pure-invariant family (unchanged, Makefile:54):
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
# driven-trace scenario (new gate — add to Makefile; verified passing set):
ailang run --caps IO,Env,Clock,FS,Trace --entry main scripts/phase_c2_wiring_scenarios.ail
```

- **G4** The new compaction-content driven-trace scenario (§5.4) passes under
  `--caps IO,Env,Clock,FS,Trace` with a `Scripted` provider — no provider/network/hydration — and
  on failure prints scenario id + first failed invariant + normalized trace (the harness reporting
  contract at `phase_c2_wiring_scenarios.ail:64-86`).
- **G4b** The driven-trace harness is **wired into the `Makefile`** (it is ungated at HEAD, §5.4) —
  an ungated harness is not a gate.
- **G5** All existing smokes + DST scripts touched by the ExtCtx constructor edits (§4a) and the
  `Compacted` codemod (§4b) stay green (`ailang check` + their `make` targets).

> **Verified at HEAD:** the `--caps IO,Env,Clock,FS,Trace` set is the measured minimal passing set
> for a driven `run_v2_session_traced` run (progressive faults `Env→FS→Clock→Trace` below it;
> `PASS count=6` at it). Re-measure after the ABI-v3 edits, since new host effects could shift it.

> **Gate discipline (memory `verify-before-claiming-substrate-defects`):** never read `$?` after a
> pipeline to judge an `ailang run`; assert on the run's own printed verdict.

---

## 9. Work items (sequence)

Frozen-surface-first, so Plan 1 and Plan 3 build on a stable ABI.

- **WI-1 — Freeze the surface.** Apply §3 type edits to a new `motoko_ext_abi` 3.0; resolve the
  vestigial-mirror question (§4a: verify no importer of `src/core/ext/types`; delete or lockstep).
  Get Open Q2/Q3 sign-off; apply the ADR-001 amendment (§2).
- **WI-2 — Core threading.** `ext_ports_of`; **persist `ext_artifacts` + `telemetry` on
  `C2LoopState` across steps** (the §5.1 cross-step gap — seed, stop the `c2_step_state` reset,
  write-back after model + fold); extend `mk_v2_ext_ctx` and update its 4 call sites to pass ports +
  persisted artifacts/telemetry; extend `fold_pre_step_chain` to return artifacts; update the two
  `rpc.ail` + test/smoke ctx sites (§4a). Fix the two live core `Compacted` matches
  (`runtime.ail:159,168`) and all in-repo construct/match sites (§4b codemod).
- **WI-3 — `compaction_ai` 0.3.0.** Ports-native, core primitives (+Msg→Message), prefix/pairing
  split, artifact cache, the one Compacted site (§6). Publish.
- **WI-4 — Structural 1.1.0 re-cert.** Version+dep bump + mechanical Compacted/ctx edits (§7).
  Publish.
- **WI-5 — Ledger consumption.** **Reuse** the existing `run_scripted` driver in
  `phase_c2_wiring_scenarios.ail` (do not rebuild); add ≥1 **compaction-content** invariant over a
  driven `LedgerTrace` (recommended: chain-order over the captured trace); and **gate** the
  driven-trace harness in the `Makefile` under `--caps IO,Env,Clock,FS,Trace` (it is ungated at
  HEAD). Enumerate follow-on conversions (§5.4). Re-measure the minimal cap set post-ABI-v3.
- **WI-6 — Lock + gates.** `ailang lock` to the three new majors; run §8a and §8b; update
  `ailang.lock`.

---

## 10. Out of scope (owned elsewhere — do not widen)

- **Conformance kit** (`packages/motoko_ext_conformance`, `invariants.ail`, `harness.ail`, the four
  scenarios, the registry probe) — **Plan 1**. This plan freezes the surface it certifies and
  produces the 0.3.0 accept fixture; it writes none of the kit.
- **Checkpoint trigger** — **Plan 3** (ADR-001 D7 + ADR-002).
- **Any core loop / send-gate change** — shipped in ADR-002.
- **`http`/`kv` ports, cache-token telemetry, typed artifacts** — deferred to first consumer (§2,
  §5.3); explicitly not built here.
