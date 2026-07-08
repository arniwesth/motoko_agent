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
- **`harness.ail`** — test-only library. Synthetic `ExtCtx` + pure fake ports; drives one package's
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

- `harness.ail` is a library with **no `main`**: it exports `run_conformance(hooks: ExtensionHooks)
  -> int ! {IO,...}` (failure count; prints per-scenario verdicts) + `run_scenario` + scenario
  constructors, and imports **only** ABI + `invariants`. It must not import fixtures or any compactor
  package, or those would ride into every consumer's build.
- **Extension CI** writes a 3-line entry in its *own* repo importing the kit + its own `register`:
  `main() = exit_nonzero_if(run_conformance(register_with_config(cfg)))`. No `registry_generated`,
  no other package — hydration-free, matching §6.1.
- **The registry probe** (`scripts/conformance_registry_probe.ail`, core CI) is the *only* place
  `registry_generated` appears; it resolves names → hooks via the **exported**
  `parse_core_ext_order(csv, cfg) -> ExtRegistry` (registry_generated.ail:63 — note `resolve` at :26
  is *not* exported, so it cannot be imported directly) and folds `run_conformance` over
  `registry.hooks`. Hydration is expected here (its gate class).
- **The kit's own self-acceptance `main`** lives in a **root script `scripts/conformance_selftest.ail`**
  (§4.4), *not* in `harness.ail` — it imports the in-kit reject fixtures + `compaction_ai`'s and
  `compaction_structural`'s `register` directly (fixed import set, no arg) and asserts fail-then-pass.
  **This amends ADR §6's command**, which names `--entry main …/harness.ail` "pointed at the package
  under test": the self-test entry is `scripts/conformance_selftest.ail`; `harness.ail` is a
  `main`-less library only `ailang check`ed.

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
| `conformance.compactor.deterministic_replay` | two runs with identical ctx+segment+`ai_step` fake produce equal output | (accept-only check; a non-deterministic compactor would differ) |
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
> hydration-class registry probe. `harness.ail` is a `main`-less library (imports only ABI +
> invariants); the fail-then-pass self-test entry is a root script `scripts/conformance_selftest.ail`
> (so the ADR §6 command `--entry main …/harness.ail` becomes `scripts/conformance_selftest.ail`).

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
packages/motoko_ext_conformance/          # ABI-ONLY package (no src/core dep) — safe for extension CI
  ailang.toml                 # version 3.x; dep motoko_ext_abi only; exports invariants+harness+fixtures
  invariants.ail              # module .../invariants  (pure, zero-cap; core imports this)
  harness.ail                 # module .../harness     (test-only LIBRARY; no main; imports only ABI+invariants)
  fixtures/
    reject_fixtures.ail       # module .../fixtures/reject_fixtures  (in-kit ABI-3.0 bad hooks; EXPORTED, not in [extensions])
scripts/                                   # ROOT-project scripts (resolve against root ailang.toml)
  conformance_selftest.ail         # has main; fail-then-pass; imports harness + fixtures + accept registers
  conformance_registry_probe.ail   # core-CI probe; imports registry_generated + harness
```

Naming: the ADR uses `motoko_ext_conformance` (underscores) for the package dir, unlike the
hyphenated `motoko-ext-*` sibling dirs. **Keep the ADR's exact spelling** (`packages/
motoko_ext_conformance/`) — it is the path named in the executable gate command (§6 line 289, §6
line 294). Module namespace follows the `sunholo/…` convention of the other packages.

**`ailang.toml`** (modeled on `motoko-ext-compaction-ai/ailang.toml`):

```toml
[package]
name = "sunholo/motoko_ext_conformance"
version = "3.0.0"                        # lockstep major with ABI 3.0 (G4 / §6.1 versioning)
edition = "1"
ailang = ">=0.26.0"
[dependencies]
"sunholo/motoko_ext_abi" = { path = "../motoko-ext-abi" }
[exports]
modules = ["sunholo/motoko_ext_conformance/invariants",
           "sunholo/motoko_ext_conformance/harness",
           "sunholo/motoko_ext_conformance/fixtures/reject_fixtures"]  # fixtures EXPORTED (importable) but NOT in root [extensions]
[effects]
max = ["AI","IO","Process","FS","Env","Net","SharedMem","Clock","Stream"]   # the on_pre_step row the harness drives
```

Note the dep path is `../motoko-ext-abi` (ABI's dir is hyphenated); `invariants.ail` imports
`pkg/sunholo/motoko_ext_abi/types`. The package depends on **ABI only** — it does **not** depend on
`src/core` or on any compactor package, which keeps it acyclic and extension-CI hydration-free.

**Why `selftest` and the probe are ROOT scripts, not package modules.** The self-test must import the
*accept* packages' registers, but `compaction_ai` imports `src/core/compaction` (compaction_ai.ail:14)
and `compaction_structural` imports `src/core/ext/ctx_defaults` (:14). If the self-test lived *inside*
the conformance package, that package's `ailang.toml` would need to depend on the compactors (hence
on `src/core`), making it no longer ABI-only and coupling it to core. Putting the self-test and probe
under `scripts/` resolves their imports against the **root** `ailang.toml` — which already declares
`compaction_ai`, `compaction_structural`, `motoko_ext_conformance`, and `src/core` — so the package
stays clean and there is no back-edge into it. `fixtures/reject_fixtures` is exported so the root
`scripts/conformance_selftest.ail` can import it by path, while its absence from root `[extensions]`
keeps it off the registry-probe path (Decision C-i).

### 4.1 `invariants.ail` — the extracted law (Decisions A + B)

Move from `phase_vocab.ail` and **re-type on ABI `Msg`**:

- `has_assistant_call`, `has_assistant_call_id`, `has_tool_result_id` (phase_vocab.ail:233-256) →
  helpers.
- `validate_output_calls`, `validate_compactor_output_rec` (:258-290) → internal recursion.
- **Decompose** into three exported pure predicates (Decision B), each returning `bool`:
  - `no_system_in_output(out: [Msg]) -> bool` — no `role == "system"` message in output
    (phase_vocab law :273). **This is the only Err assigned here** (mapping re-verified at HEAD).
  - `pairing_preserved(input: [Msg], out: [Msg]) -> bool` — **quantified over `out`, not over
    `input`** (this is critical — see below): for each assistant tool_call `c` appearing **in an
    output message**, `has_tool_result_id(input, c.id) == has_tool_result_id(out, c.id)` (:264,
    "severed tool_result pair"); and for each tool message **in output**,
    `has_assistant_call_id(input, id) == has_assistant_call_id(out, id)` (:282-283, "severed
    assistant tool_call pair"). The two severed-pair Errs.
  - `ids_preserved(input: [Msg], out: [Msg]) -> bool` — **also quantified over `out`**: no empty
    assistant tool_call id (:262), no invented assistant-call id — `c.id` must trace to input as
    call-or-result (:263), **no empty tool-message `tool_call_id` (:274)**, no invented tool_result
    id — a tool message's id must trace to input (:280-281). The four id-shape/provenance Errs.
    (:274 is an *id-shape* check on tool messages, not a system check — do not fold it into
    `no_system_in_output`.)

  **⚠ Quantification is over the OUTPUT, never over the input.** The wrapper's recursion iterates
  *output* messages (`validate_compactor_output_rec(input, output, output)`, phase_vocab.ail:293) and
  each output message's `tool_calls` (`validate_output_calls`, :258). Consequence: a compactor that
  **drops a complete tool pair** (both the assistant call *and* its result) is **accepted** — nothing
  in output references that id, so no check fires. This is not incidental — it is exactly what
  `compaction_ai` 0.3.0 does when it summarizes old turns into one message (`compact_with_ai`:175
  replaces `old_turns` wholesale). A boolean written as "for every id *in input*, presence must agree
  in output" would be **stricter than the law** and would reject 0.3.0's own legitimate
  summarization — making 0.3.0 fail its own cert. The severed-pair Errs fire only when output
  *keeps one side and drops the other*.
- **Composed wrapper** (core keeps this exact call site & message):
  ```
  export pure func validate_compactor_output(input: [Msg], output: [Msg]) -> Result[(), string]
  ```
  It must reproduce the **exact Err strings and first-failure order** of the current
  `validate_compactor_output_rec` so `runtime.ail:170` is byte-for-byte behavior-preserving. The Err
  messages embed specific ids (e.g. `"severed tool_result pair ${c.id}"`), which a `bool` predicate
  discards — so the wrapper **must keep the id-aware recursion** (it cannot be reconstructed from the
  booleans). Two encodings therefore coexist: the recursive wrapper (source of truth for core's
  message) and the three total-scan booleans (for per-invariant harness naming). Keep them from
  drifting by (a) sharing the same helpers (`has_assistant_call_id`, `has_tool_result_id`) and
  (b) the equivalence test below.
- Port the three tests (phase_vocab.ail:943-966) into `invariants.ail` as `tests [((), true)]`
  blocks, retyped on ABI `Msg`; add three per-predicate boolean tests; **add an equivalence test**
  over a battery of inputs asserting `is_ok(validate_compactor_output(i, o)) == (no_system_in_output(o)
  && pairing_preserved(i, o) && ids_preserved(i, o))`. This pins the two encodings together and is
  well-formed because every Err in the recursion is assigned to exactly one predicate (the mapping
  above), so the conjunction partitions the wrapper's failure set. **The battery must include a
  dropped-complete-pair case** (input has an assistant call + its tool result; output drops *both*)
  asserting **`Ok` / all three booleans true** — this is the case that catches a predicate wrongly
  quantified over input, and it is 0.3.0's own summarization shape. Reuse the existing
  `accepts_orphan_identity` (phase_vocab.ail:950) and extend with drop-both and keep-one-side cases.
- `export pure func conformance_abi_version() -> string { "3.0" }` (G4).

**Blast radius (Decision A), enumerate & execute in WI-1:**

- Delete the moved cluster from `phase_vocab.ail` (:233-294) *and* its three tests (:943-966); leave
  the rest of `phase_vocab` intact (checkpoint/ledger vocab untouched).
- `src/core/ext/runtime.ail:27` — change `import src/core/phase_vocab (validate_compactor_output)`
  → `import pkg/sunholo/motoko_ext_conformance/invariants (validate_compactor_output)`. Call site
  :170 `validate_compactor_output(msgs, compacted_msgs)` unchanged **in text**, but note the type
  direction shifts: after the move the param is **ABI `Msg`**, so `compacted_msgs` (already ABI `Msg`
  from the `Compacted` destructure) fits directly, while `msgs` is core `Msg` (`types.ail:16`, whose
  `tool_calls` is `[std/ai.ToolCall]` vs ABI's `[motoko_ext_abi.ToolCall]` — both structurally
  `{id,name,arguments}`). The current code already compiles the *forward* mix at this site, so AILANG
  unifies these records structurally; the reverse should hold symmetrically. **WI-1 must confirm with
  `ailang check src/core/ext/runtime.ail`** — if it does not, the fallback is a one-line wrap of
  `msgs` through the existing `messages_to_msgs`/`msgs_to_messages` round-trip (session.ail:746 /
  phase_vocab.ail:683), which is conversion but not new machinery. This is the one place Decision A's
  "conversion-free" claim is empirically load-bearing.
- `scripts/phase_c_l1_scenarios.ail` — repoint the same import (verify at WI-1; grep for
  `validate_compactor_output`).
- Add to the **root `ailang.toml` `[dependencies]`** (alongside the other path deps):
  `"sunholo/motoko_ext_conformance" = { path = "packages/motoko_ext_conformance" }`, then
  `ailang lock`. The package resolves under `pkg/sunholo/motoko_ext_conformance/…` exactly as ABI
  does (root `ailang.toml` maps `"sunholo/motoko_ext_abi" = { path = "packages/motoko-ext-abi" }`).
  **Do NOT** add it to `[extensions] packages` — it is a library dep like ABI, not a registered
  extension, so it must not appear in `registry_generated.ail`. **Accepted cost:** core's build now
  depends on the conformance package (this *is* §6.1's shared-single-law coupling). Keep import
  granularity so `harness.ail`/`fixtures/` (test-only) never enter core's build — core imports
  `invariants` only, and `invariants.ail` imports **only ABI** (no core import), keeping the package
  graph acyclic and hydration-free for extension CI.
- Zero-cap check: `ailang test packages/motoko_ext_conformance/invariants.ail` passes with no caps.

### 4.2 `harness.ail` — the test rig (library, package-agnostic)

- Imports ABI types + `invariants` (for the two predicate-wrapping scenarios) + a pure `same_msgs`
  comparator (copy the shape from compaction_structural.ail:100 or ext_fixture; keep it local).
- **Does NOT import `registry_generated`** (G1) — stays hydration-free for extension CI.
- **ExtCtx fixture builder** `mk_conformance_ctx(segment: [Msg], artifacts: Json, ai_step_fake)`
  producing the 14-field ABI `ExtCtx` (types.ail:74-96), modeled on `mk_v2_ext_ctx`
  (session.ail:706) and the literal in compaction_structural.ail:199-217. `context_limit` set very
  low so `usage_percent` clears every tier — the compaction-forcing technique in §5.
- **Fake ports** (pattern: `scripts/smoke_ports_record.ail`, ext_fixture). **Key constraint:**
  `ExtPorts.ai_step` is `(string, [Msg]) -> Result[string, string]` — **stateless**; it cannot
  count calls or thread a script (a pure function of its args only). And `compact_with_ai` calls it
  **at most once** per compaction (`summarize_with_ai`, compaction_ai.ail:64, invoked once on
  cache-miss at :173). So a fake is a **constant per-run** port, not a cross-call script:
  - **canned fake** — `ai_step = \_model _msgs. Ok("CANNED SUMMARY")` (deterministic; may key its
    answer off `_msgs` content if a scenario needs input-sensitivity, still a pure function).
  - **poison fake** — `ai_step = \_model _msgs. Ok("POISON")` (or `Err("no summarizer")`, which
    `summarize_with_ai` maps to `"[summarizer unavailable: …]"`). Used for the cache scenario's
    second run: any compactor that re-calls the port instead of hitting the cache emits the poison
    string into its output, which the assertion detects.
  `proc_exec`, `clock_now`, `env_get` are noops (as in `ctx_defaults.noop_ext_ports`). Because the
  fakes never *perform* `AI`/`Clock`/`Env`/`Process`/`FS` (their bodies are pure despite declaring
  the rows), the harness drives at `--caps IO` (Decision D; `sha256Hex` used by 0.3.0's digest is
  pure — verified, no cap).
- **Report shape** — **adapt** the cousin's types (`scripts/phase_c2_wiring_scenarios.ail:55-101`):
  `ScenarioFailure = {failed_invariant: string, trace: [string]}` (verbatim); `Scenario = {id:
  string, run: (ExtensionHooks) -> Result[(), ScenarioFailure] ! {IO, Process, FS, AI, Env, Net,
  SharedMem, Clock, Stream}}` — **`run` takes the hooks under test** (the cousin's `run` is nullary
  because it closes over a fixed scenario; the kit parameterizes on hooks). Note the row is
  on_pre_step's (ABI types.ail:149) — **no `Trace`** (the cousin adds `Trace` because it drives full
  sessions; the kit does not). Reuse `ok_or_failure`; a `run_all`-style fold prints `scenario=<id>
  invariant=<name>`. Add a `trace` emitter that serializes the offending `(segment, output)` as one
  JSONL object per failure via `std/json` `jo/kv/js`. **Minimum:** a stable self-describing line
  (`scenario`, `invariant`, `segment`, `output`). §6.1's "same JSONL shape as the core ledger" is
  the aspiration; full `to_schema_v1` (phase_vocab.ail) parity is a WI-4 nicety, not a blocker.
- **Public entry points:**
  - `export func run_scenario(hooks: ExtensionHooks, s: Scenario) -> Result[(), ScenarioFailure] ! {IO, ...}`
    — drives one scenario; the `Err` names the exact `failed_invariant` (e.g. `"pairing_preserved"`).
  - `export func run_conformance(hooks: ExtensionHooks) -> int ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}`
    — folds `run_scenario` over all four, prints `scenario=<id> invariant=<name>` per failure, returns
    the failure count (the probe's summable API). Declares the full `on_pre_step` row; performs only
    `IO` under fake ports.
- **`harness.ail` has NO `main` and imports only ABI + `invariants`** (+ a local `same_msgs`). It
  must **not** import the fixtures or any compactor package — otherwise every extension that imports
  `harness` for `run_conformance` would transitively compile `compaction_ai`, `compaction_structural`,
  and the reject fixtures, breaking the hydration-free / package-agnostic promise (G1). The
  fail-then-pass `main` lives in a **root script**, `scripts/conformance_selftest.ail` (§4.4).

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
  (poison `ai_step` fake) it emits the poison string in its output. Fails `artifact_cache_effective`.

Each fixture is a full 9-field `ExtensionHooks` (the 8 non-`on_pre_step` hooks are the trivial
pass-throughs from ext_fixture.ail:54-104). The fixtures must construct valid *segments* (system
already stripped by the harness) so that the ONLY violation is the intended one — e.g.
`reject_pair_hooks` must otherwise return well-formed output.

**Fixture must not be registry-resolvable** (Decision C-i / rejected C-ii): it lives under
`packages/motoko_ext_conformance/fixtures/` and is `[exports]`-listed so `scripts/conformance_selftest.ail`
can import it by path, but it is **never** added to root `[extensions]` / `registry_generated`, so the
registry probe never resolves it.

### 4.4 `scripts/conformance_selftest.ail` — the kit's own fail-then-pass gate

A **root-project script** (has `main`), not a package module — see "Why … ROOT scripts" in §4.1
(keeps the conformance package ABI-only). Imports `harness` + `fixtures/reject_fixtures` (both
exported by the package) + `compaction_ai`'s and `compaction_structural`'s `register_with_config`
(root deps). Asserts **per scenario, by name** (not by count — R3), via `run_scenario`:

- `reject_prefix` → `system_prefix_preserved` returns `Err` with `failed_invariant ==
  "no_system_in_output"`, and the other three scenarios return `Ok`.
- `reject_pair` → `tool_pairing_preserved` returns `Err` with `failed_invariant ==
  "pairing_preserved"`, others `Ok`.
- `reject_nocache` → `artifact_cache_effective` returns `Err`, others `Ok`.
- `compaction_ai` 0.3.0 and `compaction_structural` 1.1.0 → **all four `Ok`** *and* the liveness
  assertion (returns `Compacted`, not `PassThrough`, on the engineered segment — §5 vacuity guard).

Prints `conformance self-test PASS` or `exit(1)`. This is the fail-then-pass proof (ADR Acceptance
criterion 3).

Caps: `register_with_config` for both accept packages performs `{Env, FS}` (reads profile config,
compaction-ai/register.ail:30-66, compaction-structural/register.ail:19-40 declared row), so the
self-test needs `--caps IO,Env,FS`. The *pure hook-driving* is still `IO`; the extra caps construct
the real hooks, not the scenarios (§7).

---

## 5. The four scenarios (exact ids, mechanics)

All scenarios hand the compactor a **system-stripped segment** and a ctx engineered to **force
compaction** for any threshold-based compactor. The harness controls `ctx.context_limit`, and
`usage_percent = estimate_tokens * 100 / context_limit` (compaction_ai.ail:27-29,
compaction_structural.ail:39-42), so **setting `context_limit` very low drives pct ≫ every tier**
(0.3.0's `threshold_pct=75`; structural's 70/85/95). The segment must also (a) contain **long tool
content** so structural's `elide_old_tool_results` actually shortens (else `same_msgs` ⇒
`PassThrough`, compaction_structural.ail:132-138), and (b) have **enough non-system turns** that
0.3.0's `split_body` yields non-empty `old` (compaction_ai.ail:99-119). Each scenario runs
`hooks.on_pre_step(ctx, segment)`, destructures `PreStepDecision`, and asserts.

**Vacuity guard (self-test only).** A `PassThrough` trivially satisfies all four invariant checks
(identity preserves everything) — which is *correct* for a non-compactor and is why the **registry
probe** stays green on the ~11 non-compactor packages (they make no compaction claim). But it would
let the accept packages pass **vacuously**. So the kit's self-test `main` additionally asserts that
`compaction_ai` 0.3.0 and `compaction_structural` 1.1.0 each return **`Compacted(...)` (not
`PassThrough`)** on the engineered segment — a liveness assertion (report invariant
`compaction_occurred` on failure). This keeps the four scenarios reusable/probe-safe while making the
accept cert non-vacuous.

1. **`conformance.compactor.system_prefix_preserved`** — build a segment with tool pairs and prose;
   run once; assert `no_system_in_output(out)`. (A `PassThrough` also passes — nothing emitted.)
2. **`conformance.compactor.tool_pairing_preserved`** — segment contains ≥1 assistant tool_use +
   matching tool_result far enough apart to be split; assert `pairing_preserved(seg, out) &&
   ids_preserved(seg, out)`.
3. **`conformance.compactor.deterministic_replay`** — run `on_pre_step` **twice** with two
   *identically-constructed* ctx values (same `artifacts = empty`, the same **canned** `ai_step`
   fake, same segment); assert `same_msgs(out1, out2)`. Fails a compactor whose output depends on
   anything outside its declared inputs. (Both runs get a fresh identical ctx — nothing is threaded
   between them.)
4. **`conformance.compactor.artifact_cache_effective`** — run one with the **canned** `ai_step` fake
   and `artifacts = empty`; capture `out1` and the `artifacts1` carried by the run-one
   `Compacted(_, _, artifacts1)`. Run two with `ctx.artifacts = artifacts1` and the **poison**
   `ai_step` fake; assert `same_msgs(out2, out1)`. A cache-effective compactor (0.3.0:
   `cached_summary` hits on the identical segment digest) never calls the port, so poison never
   appears and `out2 == out1`. A no-cache compactor re-calls the poison port → poison string in
   `out2` ≠ `out1` → fail. (Mirrors §6.1's worked example; note `same_msgs` compares
   role/content/tool_call_id — the poison surfaces in `content`, so it is detected.)

`compaction_ai` 0.3.0 passes all four: prefix-safe (emits no system message), pairing-aware
(drops complete pairs / keeps pairs together via `split_body`+`has_tool_result_for`; never severs),
deterministic given a fixed canned fake, artifact-cached (`cached_summary`/`cache_artifact`).
`compaction_structural` 1.1.0 passes all four: at the forced-high pct it returns `Compacted` (emergency
elision) on **both** runs and, being pure and port-free, elides identically each time — so
`deterministic_replay` holds and `artifact_cache_effective` holds trivially (it never calls
`ai_step`, so the poison fake is never reached; its emitted `artifacts` are `jo([])`,
compaction_structural.ail:123). See R4.

---

## 6. Registry probe — `scripts/conformance_registry_probe.ail`

Core-CI, **hydration-required** class. Imports `src/core/ext/registry_generated
(parse_core_ext_order)` + `harness (run_conformance)`. Build a CSV of the **short** ext names (the
tokens `resolve` switches on, registry_generated.ail:27-39), call `parse_core_ext_order(csv, cfg) ->
ExtRegistry`, then fold `run_conformance` over `registry.hooks`, summing failures; `exit(1)` if any
package fails. This reuses the exported entry (no dependence on the unexported `resolve`) and
inherits its `name#idx` id tagging. This is the "certified against conformance vN as a
registry-inclusion condition" gate (§6.1 "Who runs it").

- Package list source: a CSV of the short names — `"test_dummy,omnigraph,context_mode,mcp,exa_search,
  ailang_docs,compose,a2a,decision_framework,microrag,compaction_ai,scratchpad,compaction_structural"`
  at HEAD. Since `registry_generated.ail` is `GENERATED by ailang generate-extension-registry`,
  prefer regenerating a companion `[string]` of names rather than hand-maintaining this literal
  (note for the extension-registry generator; out of scope to *build* the generator here — the probe
  starts from the literal above with a WI-note to fold it into the generator).
- **Only compactor packages implement `on_pre_step` meaningfully;** non-compactor hooks return
  `PassThrough`, which passes all four scenarios vacuously (correct — they make no compaction claim).
  The probe thus certifies the whole registry cheaply and specifically catches a regressed
  compactor. An extension whose `on_pre_step` performs a **gated effect outside `ctx.ports`** (e.g.
  a direct `std/ai.step`) faults under `--caps IO,Env,FS` — that is caps-as-conformance working
  (§6.1); such an extension needs a per-extension **caps allowance** declaring its residual raw
  effects, or the probe run for it is scoped accordingly. (WI-6 assumption: at HEAD only the two
  compactors implement `on_pre_step` non-trivially — WI-6 verifies by running the probe.)
- Caps: `--caps IO,Env,FS` (registry parse performs `{Env, FS}` — parse_core_ext_order,
  registry_generated.ail:63; `register_with_config` performs `{Env, FS}`).

---

## 7. Gate / acceptance criteria (checkable commands)

**Registry / conformance gate class (hydration required, `ailang lock` first):**

```
# 1. static check
ailang check packages/motoko_ext_conformance/invariants.ail
ailang check packages/motoko_ext_conformance/harness.ail
ailang check scripts/conformance_selftest.ail

# 2. pure law, zero caps
ailang test packages/motoko_ext_conformance/invariants.ail

# 3. self-acceptance (fail-then-pass) — the kit's own gate
ailang run --caps IO,Env,FS --entry main scripts/conformance_selftest.ail
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
- **WI-2 — Harness library (§4.2).** `harness.ail` (**no `main`**, imports only ABI + `invariants`):
  ctx builder, canned/poison fake ports, report shape (adapt cousin — `run` takes hooks, no `Trace`),
  `run_scenario`/`run_conformance`, the four scenario constructors, JSONL trace emitter, local
  `same_msgs`. Fixture-defaults source: **copy** the three `ctx_defaults` constructors locally rather
  than importing `src/core/ext/ctx_defaults` (keeps the kit core-free / extension-CI hydration-free;
  ~15 lines). Gate: `ailang check harness.ail`.
- **WI-3 — Reject fixtures (§4.3).** `fixtures/reject_fixtures.ail` with the three per-bug variants;
  ensure each fails **exactly one** invariant (assert the specific `failed_invariant` name — R3).
  Confirm none is registry-resolvable.
- **WI-4 — Scenarios + `scripts/conformance_selftest.ail` (§5, §4.4).** Implement the four scenario
  bodies in `harness`; write the root script `scripts/conformance_selftest.ail` (`main`) asserting
  fail-then-pass **by invariant name** over the reject fixtures + the two accept packages, plus the
  liveness (`Compacted`) guard. Gate: command 3 (entry `scripts/conformance_selftest.ail`).
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

- **R1 — Err-string parity + two-encoding drift (WI-1).** The composed `validate_compactor_output`
  must reproduce the exact first-failure and message of the current recursive body, or `runtime.ail`
  stage-rejection strings drift. Because the id-bearing messages can't be rebuilt from booleans, the
  wrapper keeps the recursion while the 3 booleans are separate total scans (§4.1) — two encodings
  that could diverge. Mitigation: both share the same helpers, and the **equivalence test** (§4.1)
  pins `is_ok(wrapper) == (no_system ∧ pairing ∧ ids)` over a battery incl. the dropped-complete-pair
  case. Verify with the ported `rejects_bad_shapes` test (phase_vocab.ail:957).
- **R2 — Core now build-depends on the conformance package (Decision A cost).** If the package path
  dep is misconfigured, core stops building. Land WI-1 as a single atomic change (move + repoint +
  dep) and gate on `make check_core`.
- **R3 — Fixture over-failing.** A reject fixture that trips more than its target invariant makes
  the scenario→invariant map (G3) a lie. Each fixture must be otherwise-valid; assert the *specific*
  `failed_invariant` name in the self-test, not merely `failures > 0`.
- **R4 — Cache scenario false green for pure compactors.** `compaction_structural` never calls
  `ai_step`, so the poison fake can't poison it; `same_msgs(out2, out1)` holds trivially. That is
  *correct* (a compactor that makes no port call is trivially cache-effective) — document it so it
  isn't mistaken for the scenario not exercising anything.
- **R5 — `deterministic_replay` has limited teeth in AILANG.** With ctx + fake ports fixed and the
  effect system controlling all nondeterminism, a well-typed compactor is deterministic almost by
  construction; the scenario mainly catches gross misuse and is retained for ADR scenario-id
  completeness. It is *not* a substitute for the cache/pairing checks, which carry the real signal.
- **R6 — AILANG workspace resolution assumptions (WI-1/WI-2/WI-4).** The plan assumes: (a) core can
  `import pkg/sunholo/motoko_ext_conformance/invariants` given a root path dep (mirrors the ABI dep);
  (b) a package can export a module (`fixtures/reject_fixtures`) that a root script imports by path
  while that module stays out of `[extensions]`; (c) root scripts resolve compactor + `src/core`
  imports against the root `ailang.toml`. All three match existing patterns (ABI dep; packages
  importing `src/core`; `scripts/*` importing both), but each is an inference — WI-1/WI-2 confirm with
  `ailang check` before building further.
