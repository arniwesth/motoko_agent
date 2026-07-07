# Plan 1 · Conformance kit (`motoko_ext_conformance`)

Status: ready to implement. Authored fresh, grounded at HEAD `44a4c6e` per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md` and
`re-ground-inherited-anchors-before-building.md`.
Provenance: written from `HANDOFF-write-conformance-kit-plan.md` (which carries Decisions A/C/D
closed with the operator, B scoped). Spec: ADR-001 **§6 / §6.1**. Depends on Plan 2 (ABI 3.0),
shipped — its surface is frozen and re-verified below.

## TL;DR

Build `packages/motoko_ext_conformance/` — the **executable contract law** that turns "this
compactor behaves the way core is entitled to assume" from prose into a gate. Two modules plus a
fixtures dir plus one core-CI probe:

- **`invariants.ail`** — pure, zero-cap, `ailang test`-able predicates over hook inputs/outputs
  (`no_system_in_output`, `pairing_preserved`, `ids_preserved`) + a composed
  `validate_compactor_output` wrapper. **This file is the single source of the compactor-output
  law**: it is *extracted from* `src/core/phase_vocab.ail` and **core imports it back** (Decision
  A/B). Typed on **ABI `Msg`**, not core `Msg`, to keep the module graph acyclic.
- **`harness.ail`** — test-only library. Scripted `ExtCtx` + fake ports; drives one package's
  `ExtensionHooks` through the four scenarios; on failure prints `scenario=<id>
  invariant=<name>` + a normalized JSONL trace, the same shape as the cousin harness
  `scripts/phase_c2_wiring_scenarios.ail`. **Package-agnostic** (never imports
  `registry_generated`); the package-under-test is supplied *by import*, not by name-string
  (gap G1 below).
- **`fixtures/`** — hand-written ABI-3.0 reject fixtures (Decision C-i), modeled on
  `src/core/test/ext_fixture.ail`, in per-bug variants so each scenario fails on its own
  invariant.
- **`scripts/conformance_registry_probe.ail`** — core-CI probe (hydration required) that folds
  the harness over `registry_generated`'s package list.

**Acceptance = fail-then-pass.** The kit's own gate rejects a 0.2.0-behavior reject fixture on
`system_prefix_preserved` + `tool_pairing_preserved` (+ `artifact_cache_effective`) and accepts
`compaction_ai` 0.3.0 and `compaction_structural` 1.1.0 on all four scenarios.

**Caps:** hook-driving harness runs at `--caps IO` (Decision D, measured). The registry probe adds
`Env,FS` because it hydrates the registry.

**Gate class:** registry/conformance (hydration required for the probe) — kept distinct from
core-DST gates (ADR §6 "Gate separation").

---

## 0. Grounding note (what re-grounding at HEAD `44a4c6e` confirmed / corrected)

Every `file:line` in the handoff was re-run. HEAD advanced past the handoff's cited `e650b56`
(two doc commits: `a50b906`, `44a4c6e`); all Plan 2 code artifacts are present and unchanged.

**Confirmed:**

- **ABI 3.0** at `packages/motoko-ext-abi/types.ail` (`version = "3.0"`). `ExtPorts` = **4 fields**
  `{ ai_step, proc_exec, clock_now, env_get }` (types.ail:62-67); `ExtCtx += {ports, artifacts,
  telemetry}` (:93-95); `Compacted(msgs, note, artifacts: Json)` (:141); `TokenTelemetry`
  input/output-only (:69-72). `ai_step: (string, [Msg]) -> Result[string, string] ! {AI, IO,
  Process, FS, Env, Net, SharedMem, Clock, Stream}`.
- **The law in core** — `phase_vocab.ail`: `validate_compactor_output` (:292-294) →
  `validate_compactor_output_rec` (:269-290); helpers `validate_output_calls` (:258-267),
  `has_assistant_call` (:233-238), `has_assistant_call_id` (:240-247), `has_tool_result_id`
  (:249-256). **Typed on `src/core/types.Msg`** (import at phase_vocab.ail:19) — confirms the
  Decision-A retype-to-ABI-`Msg` move is needed to avoid a cycle. Tests at :943-966
  (`accepts_identity`, `accepts_orphan_identity`, `rejects_bad_shapes`).
- **The importer** — `src/core/ext/runtime.ail`: imports `validate_compactor_output` (:27), calls
  it at :170 inside `fold_pre_step_chain_rec` (the D9 chain fold), passing core-`Msg` `msgs` and
  ABI-`Msg` `compacted_msgs` (from the `Compacted` destructure) into the same function — **the
  structural ABI/core `Msg` compat is already exercised in shipping code and compiles**, so the
  retype is conversion-free. Second importer of the cluster to update:
  `scripts/phase_c_l1_scenarios.ail` (per handoff — verify at WI time).
- **Accept fixtures** — `compaction_ai` 0.3.0 (`compact_with_ai` at compaction_ai.ail:159; ports
  via `ctx.ports.ai_step` :64; `split_prefix` :72; `split_body`/`has_tool_result_for` :90-113;
  `cached_summary` :136 / `cache_artifact` :150). `compaction_structural` 1.1.0 (pure
  `compact_for_pre_step` at compaction_structural.ail:119). Both link ABI via
  `{ path = "../motoko-ext-abi" }`.
- **C-i model** — `src/core/test/ext_fixture.ail` is an in-repo test extension (not a package):
  builds a full 9-field `ExtensionHooks`, `pre_step` returns `Compacted(msgs, note,
  empty_ext_artifacts())` (:89). Exactly the reject-fixture template.
- **Fake ports** — `scripts/smoke_ports_record.ail` still demonstrates pure-fake ports green under
  `--caps IO` even with `Clock`/`Env` in declared rows (caps checked on *perform*, not declare).
- **Registry probe surface** — `src/core/ext/registry_generated.ail`: `resolve(name, cfg) ->
  Option[ExtensionHooks]` (:26-41) imports all 13 `register_*` modules; `parse_core_ext_order(raw,
  cfg) -> ExtRegistry ! {Env, FS}` (:63).
- **Harness cousin** — `scripts/phase_c2_wiring_scenarios.ail`: `ScenarioFailure =
  {failed_invariant, trace: [string]}`, `Scenario = {id, run}`, `run_all` folds counting failures
  and prints `scenario=<id> invariant=<name>`, `ok_or_failure(ok, name, trace)`. Reuse this shape.
- **`getArgs() : () -> [string] ! {Env}`** exists in `std/env` — decisive for the probe boundary
  (G1).
- **`--caps IO`** floor for hook-driving: re-confirmable against the frozen 0.3.0 (Decision D).
- No `motoko_ext_conformance` / `conformance_registry_probe` / `conformance_abi_version` exists
  yet — clean slate.

**Corrected / newly surfaced** (see §1 ADR gaps): the system-prefix responsibility split; the
`ExtPorts` field count vs ADR §6 prose; the invariant-vs-scenario naming mismatch; the harness
boundary convention; the ABI-version guard mechanism.

---

## 1. ADR gaps found (§6.1 is a decision *and* nearly a plan — but not complete)

Recorded per the handoff's instruction (*"record it, don't invent a convention silently"*). Each
gap is closed **inside this plan** with a proposed resolution derivable from source; the
resolutions are amended back into ADR-001 §6.1 on landing (the D9 / D-B5 pattern).

### G1 — the "package-under-test arg convention" is under-specified *and*, read literally, breaks the two-gate-class split

ADR §6 names the command `ailang run --caps IO --entry main
packages/motoko_ext_conformance/harness.ail` *"pointed at the package under test (exact arg
convention frozen with the kit)"*. The convention is not given. The obvious reading — a CLI name
argument via `getArgs()` resolved to hooks — is **not viable for extension CI**: name→hooks
resolution only exists in `registry_generated.resolve` (registry_generated.ail:26), and importing
that module pulls in **all 13** `register_*` packages, i.e. full registry hydration. That
contradicts §6.1's own promise that *extension CI runs "fast, deterministic, no network, **no
registry hydration**."*

**Resolution (freeze this):** `harness.ail` is a **package-agnostic library**. The
package-under-test is supplied **by import**, not by name-string:

- `harness.ail` exports `run_conformance(hooks: ExtensionHooks) -> int ! {IO,...}` (returns the
  failure count; prints per-scenario verdicts) plus the scenario constructors.
- **Extension CI** writes a 3-line entry in its *own* repo importing the kit + its own `register`:
  `main() = exit_nonzero_if(run_conformance(register_with_config(cfg)))`. No `registry_generated`,
  no other package — hydration-free, matching §6.1.
- **The registry probe** (`scripts/conformance_registry_probe.ail`, core CI) is the *only* place
  `getArgs()`/`registry_generated` appear; it resolves names → hooks via `resolve` and folds
  `run_conformance` over the package list. Hydration is expected here (its gate class).
- **The kit's own self-acceptance `main`** imports the in-kit reject fixtures + `compaction_ai`'s
  and `compaction_structural`'s `register` directly (fixed import set, no arg) and asserts
  fail-then-pass.

So the frozen "arg convention" is: **hooks in by import; name-string selection exists only in the
hydration-class probe.** This is the minimal reading consistent with both gate classes.

### G2 — ADR §6 prose lists a stale `ExtPorts` field set

ADR §6 (line 264) says `ExtPorts` = `(ai_step, http, proc_exec, kv, clock_now, env_get)` — 6
fields. The **frozen** ABI has **4** (`ai_step, proc_exec, clock_now, env_get`; Open Q3 Option B,
closed in Plan 2 with `http`/`kv` deferred). The kit types against the *actual* ABI. **Amendment:**
strike `http`/`kv` from §6's `ExtPorts` line (already reflected in PLAN-abi-v3 §2 Open Q3).

### G3 — the four named predicates in §6.1 ≠ the four scenario ids; `envelope_well_formed` is out of scope

§6.1 names predicates `pairing_preserved`, `ids_preserved`, `no_system_in_output`,
**`envelope_well_formed(call, result_env)`**. But the four *scenario ids* are
`system_prefix_preserved`, `tool_pairing_preserved`, `deterministic_replay`,
`artifact_cache_effective`. Two mismatches, both resolved by source:

1. **`envelope_well_formed` is a tool-handle obligation, not a compactor-output one.** It concerns
   `on_tool_handle`'s `ToolResultEnvelope`, which §6.1's own exclusions assign to *core's transcript
   gate* ("provider acceptance of final payloads — core's transcript gate"). The current core law
   (`validate_compactor_output`) does **not** implement it, and no compactor scenario exercises it.
   **Decision B is therefore scoped to the three compactor-output predicates** the core gate
   actually enforces (`no_system_in_output`, `pairing_preserved`, `ids_preserved`). Certifying
   tool-handle envelopes is a *future obligation family*, not this plan. **Amendment:** note in
   §6.1 that `envelope_well_formed` is deferred (no core-law referent at HEAD).
2. **`deterministic_replay` and `artifact_cache_effective` are behavioral scenarios, not single-shot
   pure predicates.** They compare outputs across *two runs*; they cannot be `Result[(), string]`
   over one `(input, output)` and so are **not** part of the transcript gate. They live in
   `harness.ail` as scenario logic (using a pure `same_msgs` comparator), not in `invariants.ail`'s
   gate-shared law. This is the clean split: `invariants.ail` = the 3 predicates core shares;
   `harness.ail` = all four scenarios, two of which wrap the predicates and two of which are
   multi-run behavioral checks.

**Scenario → invariant map (frozen):**

| scenario id | asserts | fails on reject fixture because |
|---|---|---|
| `conformance.compactor.system_prefix_preserved` | `no_system_in_output(out)` | fixture emits a `system`-role message in output (phase_vocab law :273) |
| `conformance.compactor.tool_pairing_preserved` | `pairing_preserved(seg, out)` ∧ `ids_preserved(seg, out)` | fixture severs a tool_use/tool_result pair (positional split) |
| `conformance.compactor.deterministic_replay` | two runs with identical ctx+segment+`ai_step` script produce equal output | (accept-only check; a non-deterministic compactor would differ) |
| `conformance.compactor.artifact_cache_effective` | re-run with run-one artifacts + poison/empty `ai_step` equals run-one output | no-cache fixture re-calls the port → poison sentinel in output ≠ run-one |

**Naming note (record, don't rename):** scenario `system_prefix_preserved` is certified via the
predicate `no_system_in_output`. These are two sides of the core/compactor responsibility split:
the live loop **strips the system prefix before the compactor** (`split_for_compaction` →
`segment_messages`, session.ail:1448-1449) and **re-prepends it after** (`seal_compacted_payload`,
:1456, prepends `split.pinned`). So the *prefix is preserved by core precisely because the
compactor is forbidden from emitting system messages* — the compactor-side obligation is
`no_system_in_output` (phase_vocab.ail:273). The kit therefore hands each compactor a
**system-stripped segment** (matching the live loop) and asserts the compactor injected no system
message. This is why 0.3.0's own `split_prefix` (compaction_ai.ail:72) is a harmless no-op in this
pipeline: handed a system-stripped segment, it returns `prefix: []`.

### G4 — the "harness refuses a mismatched ABI loudly" mechanism has no runtime referent

§6.1 requires the kit to export `conformance_abi_version()` and *"the harness refuses a mismatched
ABI loudly."* The frozen ABI (`motoko-ext-abi/types.ail`) exports **no version symbol** — nothing
to compare against at runtime. **Resolution (two layers, both derivable):**

1. **Compile-time (the real guard):** the kit *structurally depends* on 3.0-only shapes — it
   destructures `Compacted(msgs, note, artifacts)` (3-arg, ABI 3.0) and references
   `ctx.ports.ai_step` (ABI 3.0). Linking the kit against a non-3.0 ABI **fails to compile**. This
   is the loud refusal §6.1 wants, delivered by the type system.
2. **Declared + printed:** `invariants.ail` exports `conformance_abi_version() -> string = "3.0"`;
   the harness banner prints it at run start (`conformance kit 3.0 · ABI 3.0`). `ailang.toml` pins
   `motoko_ext_abi = { path = "../motoko-ext-abi" }` and kit `version = "3.x"` (lockstep major).

**Amendment:** note that the ABI-version guard is compile-time structural + a declared constant,
since the ABI exposes no runtime version symbol.

---

## 2. Decisions inherited (closed — carry the amendments, do not re-litigate)

Verbatim from the handoff; re-grounding **did not contradict** any of them.

- **Decision A → CLOSED (A1).** Contract-law predicates move **out of** `phase_vocab` **into**
  `invariants.ail`, **typed on ABI `Msg`** (`pkg/sunholo/motoko_ext_abi/types.Msg`), and **core
  imports them back** (`runtime.ail` imports `invariants`, never `harness`). Graph: `core →
  conformance/invariants → ABI` (acyclic; core already `→ ABI`). Retype is conversion-free
  (runtime.ail:170 already mixes ABI/core `Msg` and compiles).
- **Decision B → scoped (this plan, §5.1).** Decompose the monolithic validator into the **three**
  named compactor-output predicates (G3.1 scopes out `envelope_well_formed`); core's coarse wrapper
  composes them and keeps its single `Err` message so `runtime.ail:170` is behavior-unchanged.
- **Decision C → C-i.** Reject fixture is an **in-kit `fixtures/` module** (hand-written ABI-3.0
  `ExtensionHooks`, C-i), **not** registry-resolvable. Per-bug variants (§4). Published 0.2.0 stays
  as provenance only, not a loadable artifact (targets ABI 2.2.0, cannot link 3.0).
- **Decision D → `--caps IO`.** Hook-driving harness floor is bare `IO`. Re-measure once the harness
  adds its own scaffolding (§9 WI-5 measures the real harness; probe adds `Env,FS` for hydration).

**ADR-001 §6.1 amendment text (apply on landing):**

> The compactor-output law's canonical home is `packages/motoko_ext_conformance/invariants.ail`,
> typed on ABI `Msg`, extracted from `src/core/phase_vocab` and imported back by the core transcript
> gate (`runtime.ail`). It exposes three named predicates — `no_system_in_output`,
> `pairing_preserved`, `ids_preserved` — plus a composed `validate_compactor_output` wrapper
> preserving the single Err message. `envelope_well_formed` is deferred (no core-law referent; a
> tool-handle obligation owned by core's transcript gate). `deterministic_replay` and
> `artifact_cache_effective` are harness-only behavioral scenarios, not gate predicates. `ExtPorts`
> is the four-field Option-B set. The ABI-version guard is compile-time structural dependence on
> 3.0 shapes plus a declared `conformance_abi_version()` constant (the ABI exposes no runtime
> version symbol). Extension CI supplies hooks by import; name-string selection exists only in the
> hydration-class registry probe.

---

## 3. The frozen surface the kit types against (reference)

| symbol | location (HEAD) | kit use |
|---|---|---|
| `Msg = {role, content, tool_calls, tool_call_id}` | motoko-ext-abi/types.ail:39 | predicate & fixture element type |
| `ToolCall = {id, name, arguments}` | :20 | pairing/id predicates |
| `ExtCtx {…, ports, artifacts, telemetry}` | :74-96 | harness ctx fixture |
| `ExtPorts {ai_step, proc_exec, clock_now, env_get}` | :62-67 | fake ports |
| `TokenTelemetry {last_input_tokens, last_output_tokens}` | :69-72 | ctx fixture |
| `PreStepDecision = PassThrough \| Compacted(msgs, note, artifacts: Json)` | :139-142 | hook output destructure |
| `ExtensionHooks` (9 fields) | :143-157 | the thing under test |
| `empty_ext_artifacts()`, `noop_ext_ports()`, `zero_token_telemetry()` | src/core/ext/ctx_defaults.ail:23-38 | fixture defaults (or kit-local copies — see WI-2 note) |

---

## 4. Package layout

```
packages/motoko_ext_conformance/
  ailang.toml                 # version 3.x; dep motoko_ext_abi = { path = "../motoko-ext-abi" }
  invariants.ail              # module sunholo/motoko_ext_conformance/invariants  (pure, zero-cap)
  harness.ail                 # module sunholo/motoko_ext_conformance/harness     (test-only lib)
  fixtures/
    reject_fixtures.ail       # module .../fixtures/reject_fixtures  (in-kit ABI-3.0 bad hooks)
scripts/
  conformance_registry_probe.ail   # core-CI probe (imports registry_generated)
```

Naming: the ADR uses `motoko_ext_conformance` (underscores) for the package dir, unlike the
hyphenated `motoko-ext-*` sibling dirs. **Keep the ADR's exact spelling** (`packages/
motoko_ext_conformance/`) — it is the path named in the executable gate command (§6 line 289, §6
line 294). Module namespace follows the `sunholo/…` convention of the other packages.

### 4.1 `invariants.ail` — the extracted law (Decisions A + B)

Move from `phase_vocab.ail` and **re-type on ABI `Msg`**:

- `has_assistant_call`, `has_assistant_call_id`, `has_tool_result_id` (phase_vocab.ail:233-256) →
  helpers.
- `validate_output_calls`, `validate_compactor_output_rec` (:258-290) → internal recursion.
- **Decompose** into three exported pure predicates (Decision B), each returning `bool`:
  - `no_system_in_output(out: [Msg]) -> bool` — no `role == "system"` message in output
    (phase_vocab law :273); also folds the empty-`tool_call_id` shape check (:274).
  - `pairing_preserved(input: [Msg], out: [Msg]) -> bool` — for every id, `has_tool_result_id`
    agrees input↔output and `has_assistant_call_id` agrees input↔output (the severed-pair checks at
    :264, :282, :283).
  - `ids_preserved(input: [Msg], out: [Msg]) -> bool` — no empty tool_call id (:262), no invented
    assistant-call id (:263), no invented tool_result id (:280-281).
- **Composed wrapper** (core keeps this exact call site & message):
  ```
  export pure func validate_compactor_output(input: [Msg], output: [Msg]) -> Result[(), string]
  ```
  It must reproduce the **exact Err strings and first-failure order** of the current
  `validate_compactor_output_rec` so `runtime.ail:170` is byte-for-byte behavior-preserving. Cleanest
  implementation: keep the existing recursive body as the wrapper's engine and have the three `bool`
  predicates *also* call the shared helpers — i.e. the predicates are boolean *views* of the same
  law, not a re-implementation. (Avoids two divergent encodings of the contract.)
- Port the three tests (phase_vocab.ail:943-966) into `invariants.ail` as `tests [((), true)]`
  blocks, retyped on ABI `Msg`; add three per-predicate boolean tests.
- `export pure func conformance_abi_version() -> string { "3.0" }` (G4).

**Blast radius (Decision A), enumerate & execute in WI-1:**

- Delete the moved cluster from `phase_vocab.ail` (:233-294) *and* its three tests (:943-966); leave
  the rest of `phase_vocab` intact (checkpoint/ledger vocab untouched).
- `src/core/ext/runtime.ail:27` — change `import src/core/phase_vocab (validate_compactor_output)`
  → `import pkg/sunholo/motoko_ext_conformance/invariants (validate_compactor_output)`. Call site
  :170 unchanged (structural `Msg` compat already holds).
- `scripts/phase_c_l1_scenarios.ail` — repoint the same import (verify at WI-1; grep for
  `validate_compactor_output`).
- Add `motoko_ext_conformance = { path = "../motoko_ext_conformance" }` (or relative) to the core
  build's dep set / lockfile so `runtime.ail` resolves it. **Accepted cost:** core's build now
  depends on the conformance package (this *is* §6.1's shared-single-law coupling). Keep import
  granularity so `harness.ail` (test-only) never enters core's build — core imports `invariants`
  only.
- Zero-cap check: `ailang test packages/motoko_ext_conformance/invariants.ail` passes with no caps.

### 4.2 `harness.ail` — the test rig (library, package-agnostic)

- Imports ABI types + `invariants` (for the two predicate-wrapping scenarios) + a pure `same_msgs`
  comparator (copy the shape from compaction_structural.ail:100 or ext_fixture; keep it local).
- **Does NOT import `registry_generated`** (G1) — stays hydration-free for extension CI.
- **ExtCtx fixture builder** `mk_conformance_ctx(segment: [Msg], artifacts: Json, ai_step_script)`
  producing the 14-field ABI `ExtCtx` (types.ail:74-96), modeled on `mk_v2_ext_ctx`
  (session.ail:706) and the literal in compaction_structural.ail:199-217. `context_limit` set low
  enough to force compaction (e.g. small limit vs a segment sized above threshold — see §4.3).
- **Fake ports** (pattern: `scripts/smoke_ports_record.ail`, ext_fixture): `ai_step` is a
  **scripted pure** port — threads a script of canned summaries `Script([...])` returning the next
  on each call and a **poison sentinel** when exhausted (for the cache scenario). `proc_exec`,
  `clock_now`, `env_get` are noops. Because the fakes never *perform* `AI`/`Clock`/`Env`, the
  harness runs at `--caps IO` (Decision D).
- **Report shape** — reuse the cousin's types (`scripts/phase_c2_wiring_scenarios.ail:55-101`):
  `ScenarioFailure = {failed_invariant: string, trace: [string]}`, `Scenario = {id, run}`,
  `ok_or_failure`, `run_all` printing `scenario=<id> invariant=<name>`. Add a `trace` emitter that
  serializes the offending `(segment, output)` as JSONL **in the same shape as the core ledger** so
  a conformance failure reads like a core DST failure (§6.1). Keep the JSONL builder small
  (`std/json` `jo/kv/js`); one line per scenario failure.
- **Public entry points:**
  - `export func run_conformance(hooks: ExtensionHooks) -> int ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}`
    — runs all four scenarios against `hooks.on_pre_step`, returns failure count, prints verdicts.
    (Declares the full `on_pre_step` row; performs only `IO` under fake ports.)
  - scenario constructors, for probes that want to name a subset.
- **The kit's own `main`** (self-acceptance): imports the reject fixtures + `compaction_ai`'s and
  `compaction_structural`'s `register_with_config`, and asserts:
  `run_conformance(reject_prefix) == 1 on system_prefix` (etc., >0), `run_conformance(reject_pair)`
  fails pairing, `run_conformance(reject_nocache)` fails cache, and
  `run_conformance(register_compaction_ai(cfg)) == 0` and
  `run_conformance(register_compaction_structural(cfg)) == 0`. Prints `conformance self-test PASS`
  or `exit(1)`. This is the fail-then-pass proof (ADR Acceptance criterion 3).

  Note: `register_with_config` for both accept packages performs `{Env, FS}` (reads profile config);
  the self-test `main` therefore needs `--caps IO,Env,FS`. The *pure hook-driving* is still `IO`;
  the extra caps are for constructing the real hooks, not for the scenarios. Record both floors in
  the gate (§7).

### 4.3 `fixtures/reject_fixtures.ail` — the C-i reject fixtures

Hand-written ABI-3.0 `ExtensionHooks` modeled on `src/core/test/ext_fixture.ail`. **Per-bug
variants** (handoff "plan must also carry"), so each scenario fails on *its own* invariant rather
than all tripping the first flaw:

- `reject_prefix_hooks` — `on_pre_step` returns `Compacted` whose output **injects a `system`-role
  message** (reproduces the class of bug where positional splitting mangles the prefix). Fails
  `no_system_in_output` → `system_prefix_preserved`.
- `reject_pair_hooks` — output **severs a tool pair**: keeps the assistant message bearing
  `tool_calls=[{id:"tc1",…}]` but drops the matching `role:"tool", tool_call_id:"tc1"` (or vice
  versa), reproducing 0.2.0's positional `split_msgs` (compaction_ai.ail split-by-position lineage).
  Fails `pairing_preserved` → `tool_pairing_preserved`.
- `reject_nocache_hooks` — a summarizing compactor that **always calls `ctx.ports.ai_step`** and
  **never reads `ctx.artifacts`** (no `cached_summary`), so on the cache scenario's second run
  (poison/empty `ai_step` script) it emits the poison sentinel. Fails `artifact_cache_effective`.

Each fixture is a full 9-field `ExtensionHooks` (the 8 non-`on_pre_step` hooks are the trivial
pass-throughs from ext_fixture.ail:54-104). The fixtures must construct valid *segments* (system
already stripped by the harness) so that the ONLY violation is the intended one — e.g.
`reject_pair_hooks` must otherwise return well-formed output.

**Fixture must not be registry-resolvable** (Decision C-i / rejected C-ii): it lives under
`packages/motoko_ext_conformance/fixtures/`, is imported only by the kit's `harness.ail` self-test,
and is **never** added to `registry_generated` or any `ailang.toml [extensions]` list.

---

## 5. The four scenarios (exact ids, mechanics)

All scenarios hand the compactor a **system-stripped segment** sized above the compaction threshold
(match the live loop: `context_limit` small, segment content large; for `compaction_ai` the default
`threshold_pct=75`, `keep_recent=6` from compaction_ai/types.ail). Each scenario runs
`hooks.on_pre_step(ctx, segment)`, destructures `PreStepDecision`, and asserts.

1. **`conformance.compactor.system_prefix_preserved`** — build a segment with tool pairs and prose;
   run once; assert `no_system_in_output(out)`. (A `PassThrough` also passes — nothing emitted.)
2. **`conformance.compactor.tool_pairing_preserved`** — segment contains ≥1 assistant tool_use +
   matching tool_result far enough apart to be split; assert `pairing_preserved(seg, out) &&
   ids_preserved(seg, out)`.
3. **`conformance.compactor.deterministic_replay`** — run `on_pre_step` **twice** with an
   *identical* ctx (same artifacts=`empty`, same `ai_step` script producing the same summary);
   assert `same_msgs(out1, out2)`. Fails a compactor whose output depends on unscripted
   nondeterminism.
4. **`conformance.compactor.artifact_cache_effective`** — run once with `ai_step` scripted to a
   canned summary and `artifacts = empty`; capture `out1` and the returned `Compacted` artifacts.
   Run again with `ctx.artifacts = <run-one artifacts>` and an **empty/poison `ai_step` script**;
   assert `same_msgs(out2, out1)` (cache hit, port not re-called). A no-cache compactor re-calls the
   (now poison) port → sentinel content in `out2` ≠ `out1` → fail. (Mirrors §6.1's worked example.)

`compaction_ai` 0.3.0 passes all four: prefix-safe (no system emitted), pairing-aware
(`has_tool_result_for`/`split_body`), deterministic given a fixed script, artifact-cached
(`cached_summary`/`cache_artifact`). `compaction_structural` 1.1.0 passes all four (pure, no ports:
on run-two it still `PassThrough`/elides identically — cache scenario is trivially satisfied since
it never calls `ai_step`).

---

## 6. Registry probe — `scripts/conformance_registry_probe.ail`

Core-CI, **hydration-required** class. Imports `src/core/ext/registry_generated (resolve)` (or the
generated package-name list) + `harness (run_conformance)`; for each package name, `resolve(name,
cfg)` → `Some(hooks)` → `run_conformance(hooks)`, summing failures; `exit(1)` if any package
fails. This is the "certified against conformance vN as a registry-inclusion condition" gate (§6.1
"Who runs it").

- Package list source: iterate the same names `resolve` switches on (registry_generated.ail:27-39),
  or a generated list beside it. Since `registry_generated` is `GENERATED by
  ailang generate-extension-registry`, prefer regenerating a companion `[string]` of names rather
  than hand-maintaining one (note for the extension-registry generator; out of scope to *build* the
  generator here — the probe can start from a literal list matching registry_generated at HEAD and
  a WI-note to fold it into the generator).
- **Only compactor packages implement `on_pre_step` meaningfully;** non-compactor hooks return
  `PassThrough`, which passes all four scenarios vacuously (correct — they make no compaction claim).
  The probe thus certifies the whole registry cheaply and specifically catches a regressed
  compactor.
- Caps: `--caps IO,Env,FS` (registry parse performs `{Env, FS}` — parse_core_ext_order,
  registry_generated.ail:63; `register_with_config` performs `{Env, FS}`).

---

## 7. Gate / acceptance criteria (checkable commands)

**Registry / conformance gate class (hydration required, `ailang lock` first):**

```
# 1. static check
ailang check packages/motoko_ext_conformance/invariants.ail
ailang check packages/motoko_ext_conformance/harness.ail

# 2. pure law, zero caps
ailang test packages/motoko_ext_conformance/invariants.ail

# 3. self-acceptance (fail-then-pass) — the kit's own gate
ailang run --caps IO,Env,FS --entry main packages/motoko_ext_conformance/harness.ail
#   expect: reject_prefix fails system_prefix_preserved,
#           reject_pair  fails tool_pairing_preserved,
#           reject_nocache fails artifact_cache_effective,
#           compaction_ai 0.3.0 and compaction_structural 1.1.0 pass all four
#           → prints "conformance self-test PASS", exit 0

# 4. registry probe — every package in registry_generated
ailang run --caps IO,Env,FS --entry main scripts/conformance_registry_probe.ail
```

**Hook-driving floor (Decision D, re-measure at WI-5):** the pure scenario driving is `--caps IO`;
`Env,FS` in commands 3–4 are only for constructing real hooks / registry parse, not for the
scenarios. Confirm empirically that `run_conformance` over a fixture with fake ports is green at
`--caps IO` and faults *only* on withheld caps if a fixture bypasses ports.

**Core-side regression (Decision A landed):** after the law move, core still builds and its gate is
unchanged:

```
ailang check src/core/ext/runtime.ail
ailang test src/core/phase_vocab.ail          # remaining vocab tests still green
make check_core                                # or the repo's core gate
```

**ADR-001 Acceptance criterion 3** is satisfied by command 3 (fail-then-pass), now with a concrete
package, scenario ids, fixtures, and commands (closing review R6/R7/R8 in the ADR — the gate names
verifiable targets).

**Gate separation (ADR §6):** commands 3–4 are the **registry/conformance** class (hydration); do
not fold them into the no-hydration core-DST Makefile targets. Add them under a distinct target
(e.g. `make conformance`).

---

## 8. Work items (sequence)

- **WI-1 — Extract & decompose the law (Decisions A+B, §4.1).** Create
  `packages/motoko_ext_conformance/{ailang.toml, invariants.ail}`; move the validator cluster from
  `phase_vocab.ail`, retype on ABI `Msg`, split into 3 predicates + composed wrapper, port + extend
  tests. Repoint importers (`runtime.ail:27`, `scripts/phase_c_l1_scenarios.ail`); add the core dep.
  Gate: `ailang test invariants.ail` (zero caps) + `ailang check runtime.ail` + core gate green
  (behavior-preserving; verify Err strings/order identical).
- **WI-2 — Harness library (§4.2).** `harness.ail`: ctx builder, scripted/poison fake ports, report
  shape (reuse cousin), `run_conformance`, JSONL trace emitter. Decide fixture-defaults source:
  reuse `src/core/ext/ctx_defaults` (pulls a core module into the kit — acceptable, it's ABI-typed
  and pure) **or** copy the three tiny constructors locally to keep the kit core-free for extension
  CI. **Recommend local copies** (keeps extension-CI hydration-free; the three fns are 15 lines).
  Gate: `ailang check harness.ail`.
- **WI-3 — Reject fixtures (§4.3).** `fixtures/reject_fixtures.ail` with the three per-bug variants;
  ensure each fails exactly one invariant. Confirm none is registry-resolvable.
- **WI-4 — Wire the four scenarios + self-test `main` (§5, §4.2).** Implement scenario logic; the
  `main` self-acceptance asserting fail-then-pass over the reject fixtures + the two accept packages.
  Gate: command 3.
- **WI-5 — Measure caps & finalize floors (Decision D).** Run command 3 at `--caps IO,Env,FS`, then
  probe the pure driving at `--caps IO` against a fixture; confirm a ports-bypassing fixture faults
  on the withheld cap. Record the confirmed floors in the plan/ADR amendment.
- **WI-6 — Registry probe (§6).** `scripts/conformance_registry_probe.ail`; run command 4 over the
  full registry; expect all green (compactors certified, non-compactors vacuous). Add the
  package-name-list generator note.
- **WI-7 — Gates + amendment.** Add the `make conformance` target (registry/conformance class,
  distinct from core-DST); apply the ADR-001 §6.1 amendment text (§2); `ailang lock`.

---

## 9. Out of scope (owned elsewhere — do not widen)

- Cross-extension composition / chain order / arbitration — core L1 (`runtime.ail:143-188`); the
  obligations are composition-closed by design.
- Provider payload acceptance — core's transcript gate (`seal_compacted_payload`).
- `envelope_well_formed` / tool-handle certification — deferred (G3.1); no core-law referent at HEAD.
- Cross-package `id` uniqueness — the registry. Resource/time budgets — v1 out of scope.
- The checkpoint trigger (Plan 3). Any ABI change (frozen). Any new compactor *behavior* — 0.3.0
  and structural 1.1.0 are built; the kit certifies, it does not re-open them.
- Building the `generate-extension-registry` companion name-list emitter — noted, not built here.

## 10. Risks / notes

- **R1 — Err-string parity after the law move (WI-1).** The composed `validate_compactor_output`
  must reproduce the exact first-failure and message of the current recursive body, or `runtime.ail`
  stage-rejection strings drift and any test asserting on them breaks. Mitigation: keep the existing
  recursion as the wrapper engine; the 3 predicates are boolean views over the same helpers, not a
  reimplementation. Verify with the ported `rejects_bad_shapes` test (phase_vocab.ail:957).
- **R2 — Core now build-depends on the conformance package (Decision A cost).** If the package path
  dep is misconfigured, core stops building. Land WI-1 as a single atomic change (move + repoint +
  dep) and gate on `make check_core`.
- **R3 — Fixture over-failing.** A reject fixture that trips more than its target invariant makes
  the scenario→invariant map (G3) a lie. Each fixture must be otherwise-valid; assert the *specific*
  `failed_invariant` name in the self-test, not merely `failures > 0`.
- **R4 — Cache scenario false green for pure compactors.** `compaction_structural` never calls
  `ai_step`, so the poison script can't poison it; `same_msgs(out2, out1)` holds trivially. That is
  *correct* (a compactor that makes no port call is trivially cache-effective) — document it so it
  isn't mistaken for the scenario not exercising anything.
