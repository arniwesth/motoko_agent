# M-MOTOKO-DST-FRAMEWORK — Deterministic Simulation Testing, as built

**Status**: Implemented (as-built reference; refreshed 2026-07-24 for the seeded axis and the
naming amendment; **name adopted 2026-08-06** at the WI-D5 conformance gate)
**Naming**: **The unqualified "DST" / "simulation" label is ADOPTED for the generated axis as of
2026-08-06**, under D10 of
`.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`: the
acceptance test passes eleven of eleven rows for the documented baseline profile **`driver_only/10`**
(under execution manifest `driver_only/3`; the profile is **`driver_only/11`** from WI-D6, which
changed no claim the table rests on — see the superseded-clause note below), and project-007's definition/taxonomy ADR is
`Accepted 2026-07-26`. **Every report naming the axis must name the profile.**

> **This statement was superseded on 2026-08-06 and is kept because it was true when written.**
> From 2026-07-24 until the WI-D5 gate, this document read: *"The word 'DST' in this document's
> title, in every `dst*` make target, and in every `*_dst.ail` script name is grandfathered
> historical usage. Per 007's ADR, what is built here does not yet meet that ADR's conformance bar."*
> **The grandfathering clause still stands** — 007's ADR grandfathers every existing `dst` identifier
> and that exception is unchanged, so **adoption renamed nothing**. What changed is the second half:
> the conformance bar is now met for one profile.

> **THE CAVEAT BELOW WAS AMENDED ON 2026-08-07 (WI-D14) AND IS KEPT AS WRITTEN, because it was
> true from 2026-07-24 until that date and re-dating it in place would make it a false claim about
> history.** A SECOND profile now exists — `driver_plus_no_ops/1` — which installs four extensions
> and covers 32 hooks, so *"the axis's extension-model coverage is ZERO"* is no longer true of the
> axis as a whole. It remains true of `driver_only`, which still installs nothing, and every clause
> below still describes that profile exactly.
>
> **The honest successor, which the second profile's own result computes rather than asserts:**
> *extension-model coverage is NON-ZERO and ENTIRELY OF NO-OPS — 32 hooks across 4 installed
> extensions, of which the 16 resting on D5 criterion 2 satisfy its port and origin-tag clauses
> VACUOUSLY, over an empty set of performed effects. ZERO covered hooks mediate the world
> substantively, so the coverage exercises NONE of the world-mediation machinery.* That is a weaker
> claim than the number implies and a stronger one than zero, and no number alone separates it from
> real coverage. `make driver_plus_no_ops` prints it, and
> `tools/profile_definition/check_no_op_profile.py` fails if a non-zero coverage is stated without
> it. **What has NOT changed: no profile in this tree covers a hook that performs an effect, so the
> world-mediation machinery is still uncovered by any profile.**

**What the label does NOT assert — mandatory in every report:** **the axis's extension-model
coverage is ZERO.** `driver_only` installs no extension. Four of the eleven acceptance rows lean on
that emptiness in a named clause — the boundary row passes **vacuously** in every
installed-extension clause; the fault row's `extension_effect_fault` waiver and the oracle row's
`ScratchpadResult` exemption are both bought by it; and the virtual-time row's pass, while real,
does not transfer. **Per D10, additional profiles earn coverage separately and inherit none of these
four.** Full row-by-row evidence:
`.agent/projects/009_motoko_dst_execution/NOTE-d5-acceptance-table-rerun-and-name-decision.md`.

> **One clause of that caveat was superseded on 2026-08-06 and is kept because it was true when
> written.** From the ABI's first version until WI-D6, the sentence above continued: *"and that is
> structural rather than incidental … the empty install list is **forced**: while
> `ExtensionHooks.on_budget_plan` declares the ABI's closed row `! {Env, FS}` and returns a
> `BudgetPatch` with no successor field, no extension in the tree is installable in a conformant
> profile."*
>
> **WI-D6 narrowed that row**, after measuring all fifteen `on_budget_plan` bindings in the tree
> against two producers independent of the declaration — the runtime capability trap out of process
> (7 of 15 directly witnessed) and the effect checker over all 15, total over inputs. Not one
> performs `Env` or `FS`.
>
> **CORRECTION, same day: an extension is NOT yet installable, and an earlier revision of this
> paragraph said it was.** `on_budget_plan` was one of **four** barriers, not the only one. Three
> remain, and all three are **unconditionally dispatched** (`dst_profile_coverage.hook_dispatch`:
> `OnPreStep`, `OnResponseIntercept`, `OnSolverCandidate` are `Unconditional`; only `OnToolHandle` is
> `Gated`), so under D5 an extension cannot be installed with any of them excluded and none of the
> three is coverable: `on_pre_step` declares `IO`, `FS`, `Net` and `Process`, which are not
> world-mediated ports, and `on_response_intercept` and `on_solver_candidate` declare nine effects
> each while returning constants. **`src/core/dst_driver_only.ail`'s own omission reason says exactly
> this** — *"The three other former barriers stand and are unaffected"* — so the two artifacts
> disagreed and the profile was right. **What WI-D6 delivered is one barrier removed of four, and the
> argument that could remove the other three.**
>
> **The zero-coverage claim itself is UNCHANGED and stays mandatory.** What changed is only its
> reason: the empty install list is now **chosen** rather than **forced**, which is a *weaker*
> statement, not a stronger one — a chosen emptiness covers exactly as much as a forced one, which
> is nothing. **All four leaning rows still lean, to exactly the same extent**, because
> `driver_only` still installs nothing; per plan rule S21 their reasons **concentrated** rather than
> closed, each now resting on the profile's own emptiness where two of them used to rest on the ABI
> as well. Coverage moves when a profile installs something, which is WI-C5's `compose`-bearing
> profile and is not an ABI edit.

**Role**: The durable, navigable spine for the DST topic — what the framework *is* at HEAD, where
every piece lives, and how to extend it. Decision history stays in the ADRs linked at the bottom;
this doc describes the result. (Convention per
`.agent/issues/docs-split-across-agent-and-design-docs.md`: `design_docs/` = durable design of
shipped behavior; `.agent/projects/` = the working record.)
**Diagram**: `.agent/projects/007_dst_consolidation/mmd/dst-as-built.svg`

---

## What DST means in Motoko

Motoko failures cluster at boundaries — provider telemetry from step N shaping step N+1,
compaction applied to the send payload but not the loop history, extension hooks seeing the wrong
conversation slice, harness env/sandbox setup silently disabling behavior. Real-provider tests
can't be the regression oracle for these (slow, model- and network-dependent, unreproducible), and
unit tests can't see multi-step state. DST is the layered answer, decided in
`ADR-001-deterministic-simulation-testing-architecture.md` (project `001_DST`):

1. Deterministically model the external contracts around Motoko (provider, tools, clock, env).
2. Drive the **real production transition code**, not reimplementations.
3. Record boundary observations into a normalized trace.
4. Assert reusable structural invariants over that trace — never final model prose.
5. On failure, report scenario id, seed, and trace.

Live-provider runs (the `live_*` Makefile targets) are supplemental calibration smokes,
explicitly **outside** the deterministic oracle.

### Amendment: what this framework is *not* (2026-07-24)

`.agent/projects/007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md` **amends the
definition and naming threshold above** while preserving all five decisions — exercise production
code, use explicit fakes, record normalized traces, assert structural invariants, report id/seed/
trace. It also supersedes ADR-001's clock-normalization rule as a permanent answer.

That ADR reserves the unqualified words **"DST" / "simulation"** for a bar the framework had not yet
met when this section was written: a seed must generate the *ordering* of environment events, inject
logical faults, and advance a virtual clock, with invariants over a complete returned `LedgerTrace`.

**That bar is now MET for the baseline profile `driver_only/10`, as of 2026-08-06** — project 009
built the deterministic test world, and the WI-D5 gate ran the eleven-row acceptance table and found
eleven of eleven. The interim name is retired.

> **Two claims here were superseded on 2026-08-06 and are kept because they were true when written.**
>
> * From 2026-07-24: *"What is built here — fixed scenarios plus the seeded axis below — is
>   **property-based testing over agent-loop state**: strictly stronger than trace replay, strictly
>   weaker than DST. The interim name for the seeded axis is 'deterministic trajectory testing'."*
>   The generated axis is no longer weaker than the bar; **the fixed scenarios still are**, and they
>   are a different axis that the label does not cover (see D10 — the label is adopted for the
>   *generated* axis only).
> * From 2026-07-24: *"Concretely, at HEAD the framework has no test scheduler, no injected-fault
>   mechanism, and no virtual clock."* All three now exist: a seeded generator whose output is a
>   function of its seed alone (WI-D4), a fault catalogue reaching nine required classes and nine
>   named production recovery branches by search (WI-D1), and a single world clock with every
>   profile-reachable time-bearing read routed through it (WI-A12/D3).

**The scope of the adoption, restated because it is the available misreading:** the label is adopted
for the **generated axis under one profile**, whose **extension-model coverage is zero** — see the
Naming block at the top. It is not a claim about the fixed scenarios, and it is not a claim about any
profile that installs an extension, because none exists. (This sentence read *"zero and structurally
so"* until 2026-08-06. WI-D6 removed the structural part and left the zero: an extension is now
installable, and no profile installs one. **The final clause — "because none exists" — became FALSE
on 2026-08-07**, when WI-D14 added `driver_plus_no_ops/1`, and it is kept rather than rewritten for
the same reason as the rest of this paragraph. The adoption's scope is unchanged: the label was
earned for `driver_only`, and the second profile earns its own rows from scratch per D10 — it has
re-earned four of the eleven and claims none of the other seven.)

The route was a cross-cutting change to effect routing and the terminal-trace contract, **not** a
`ScriptedStep` extension (`ScriptedStep` was a success-only record; approvals, native tools, and
session time bypassed the ports boundary; and `run_v2_from_messages` returns messages, not a trace).

## Architecture

One sentence: *swap the ports, keep the code, read the ledger.*

- **Injected nondeterminism — ports.** Production runs with live adapters (`live_ports`, live
  AI); DST runs the same driver with fakes: `src/core/test/stub_step.ail` (scripted provider
  steps: `Scripted`/`ScriptedStep`, `prose_step`, `tool_step`, …) and
  `src/core/test/scripted_ports.ail` (`ScriptedPortsState`: model, approvals, clock).
  `src/core/test/ext_fixture.ail` provides extension-hook fakes. Because fakes are pure, each gate
  runs under the **narrowest caps that pass** (from `--caps IO` up to the full row for the
  `--ai-stub` gates), so an unmodeled effect *class* fails at perform time — capability flags
  double as a conformance check ("caps-as-conformance"). Note the limit: caps reject a new effect
  class, not a new unmodeled operation *within* an already-granted class (a granted `IO` still
  admits `readLine()`, `Env` still admits new reads), so caps alone do not prove hermeticity.
- **Production transition code.** `src/core/step_machine.ail` (`decide`: pure
  `StepState → StepDecision`), the model/tool/hook phases (ports-only, returning
  `PhaseResult` + `StateDelta`), and `src/core/session.ail` (the driver that executes decisions
  and is the **sole emitter** of ledger events). L1/L3 scenarios drive this exact code.
- **Ledger = trace.** The typed `LedgerTrace`/`LedgerRecord` vocabulary in
  `src/core/phase_vocab.ail`, projected to schema-v1 JSONL on the wire. Scenarios assert over the
  typed in-memory ledger; deterministic replay compares normalized records (payload digests,
  stage records, `extension_diagnostic` events).
- **Invariants.** Pure predicates, usable by any layer and provable where they reduce to pure
  functions: `history_valid_transcript`, `validate_compactor_output` (package
  `motoko_ext_conformance/invariants.ail`), `validate_checkpoint_chain`, and friends.
- **Failure contract.** `scenario=<id> seed=<seed> invariant=<failed_invariant>` + `trace <line>`
  lines, via the shared harness (below). Scenario ids are the stable public contract.

## Layers, as built

| Layer | Tests | Lives in | Runner |
|---|---|---|---|
| **L0 — pure policy** | thresholds, token estimates, elision, invariant predicates; Z3 contracts where provable | `scripts/dst/compaction_policy_dst.ail`, package invariants, `ailang test` modules | `ailang run/test`; `make verify_core` (Z3, advisory) |
| **L1 — loop state** | real `session`/`step_machine` with scripted ports; compaction chains, checkpoints, guards, approval protocol, runtime-status tool | `scripts/dst/phase_c_l1_scenarios.ail`, `phase_c2_wiring_scenarios.ail`, `phase_c_approval_protocol.ail`, `long_qwen_compaction_dst.ail`, `runtime_status_tool_dst.ail` | `make phase_c_l1`, `make compaction_dst` |
| **L2 — harness boundary** | TypeScript harness before AILANG starts: system-prompt materialization, env/spawn prep | `src/tui/src/harness-dst.test.ts` (+ extracted `system-prompt.ts`) | `make dst_l2` (bun-native; see landmine below) |
| **L3 — end-to-end deterministic** | real driver + fully scripted ports (`run_v2_with_scripted_ports`); event parity between phase paths | `scripts/dst/phase_a_event_parity.sh` two-capture `diff -r` | `make smoke_parity` |

**The bun landmine (L2):** run `bun test <explicit path>` from `src/tui/`. The npm `test` script
(jest-under-bun) is broken repo-wide, and bare `bun test` doesn't discover the `src/*.test.ts`
family. Gate on the DST file, not the whole TUI suite.

## The shared scenario harness

`src/core/test/dst_harness.ail` is the single in-repo runner (consolidated 2026-07-12, project
`007_dst_consolidation`):

```ailang
export type ScenarioFailure = { failed_invariant: string, trace: [string] }

export type Scenario = {
  id: string,
  seed: string,
  run: () -> Result[(), ScenarioFailure]
    ! {AI, FS, Process, IO, Env, Net, SharedMem, Clock, Stream, Trace}
}
```

plus `run_one`, `run_all`, `failure`, `ok_or_failure`, `report_failure`, `print_trace`. The
`Scenario` type carries the **maximal** effect row; IO-only gate scripts still run under
`--caps IO` because unused effect rows don't demand capabilities — only performed effects do.

Fixed scenarios (`seed="fixed"`) remain the bulk of the suite. **Seeded generation is built** (the
ADR-001 extension point, landed 2026-07-18/23) and lives outside `dst_harness.ail`: the seeded
scripts own their own seed loops and report `family=`/`scenario=` lines directly. See *The seeded
axis* below.

**The one deliberate exception:** `packages/motoko_ext_conformance` keeps its own package-owned
`Scenario`/`run_scenario`/reporter. Sharing the in-repo type caused an AILANG transitive
name-resolution collision with the ABI package's distinct `Scenario`, and the kit's surface is
ABI-versioned — consolidating it would have forced a kit major for zero behavior change. The
package harness is the only `run_all` outside `dst_harness.ail` (`rg '^func run_all' scripts`
must stay empty).

## The seeded axis

Five generated families plus a PRNG canary, in two scripts run by `make dst_seeded` under
`--caps IO,Env,Rand`:

| Family | Script | Drives |
|---|---|---|
| `compaction.gen.tool_heavy` | `compaction_seeded_dst` | `compact_for_pre_step` (pure) |
| `phase_c.gen.seal_boundary` | `phase_c_seeded_dst` | seal/exhaustion boundary |
| `phase_c.gen.checkpoint_pressure` | `phase_c_seeded_dst` | `decide → apply_checkpoint → decide` |
| `phase_c.gen.split_prefix` | `phase_c_seeded_dst` | system-prefix split |
| `phase_c.gen.stage_records` | `phase_c_seeded_dst` | stage-record projection |

**Configuration.** `DST_SEEDS` (default 5) and `DST_BASE_SEED` (default 1); each family runs seeds
`base … base+n-1`. Reproduce a failure with
`DST_BASE_SEED=<failing seed> DST_SEEDS=1 make dst_seeded`.

**The RNG canary** (`compaction.gen.rng_canary`, always `seed=fixed`) pins `rand_seed(12345)` to
golden integers. If the AILANG stdlib PRNG ever changes, this fails loudly instead of silently
re-mapping every seed recorded in every past bug report. It is the reason a seed is a usable
reproduction key at all.

**Anti-silent-drop.** Each script's PASS line derives `families=N` from the summed family results,
not a literal, so removing a family moves the count (and a dangling reference fails to compile).
This mirrors the fixed gates' `PASS count=N` oracle.

**What the seeded axis is not.** The seed draws *input parameters* (and, in `stage_records`, an
input list of stage outcomes) — never the driver's environment-event ordering. There is no fault
injection and no clock. Two consequences for anyone extending it:

1. **Invariants only; do not tighten into decision assertions.** Short-content draws legitimately
   produce `PassThrough`; a generated family that asserts a specific decision will flake or go
   vacuous. Permitted decision assertions must be **one-sided** (e.g. *below threshold ⇒ never
   compacted*, with no converse), respecting the `checkpoint_would_relieve` veto.
2. **Import policy constants; never hardcode tiers.** Duplicated thresholds make a generated family
   keep certifying the old policy forever after a config change.

## Scenario ID namespace

Dotted, layer/topic-prefixed; the id is the stable contract, the script is an implementation
detail:

| Namespace | Count | Gate script |
|---|---:|---|
| `compaction.*` (policy) | 3 | `compaction_policy_dst` |
| `compaction.catalog_limit_qwen` | 1 | `compaction_catalog_dst` |
| `compaction.*` (long-session AI/structural, incl. all four `compaction_ai` terminal-diagnostic codes) | 8 | `long_qwen_compaction_dst` |
| `runtime_status.*` | 2 | `runtime_status_tool_dst` |
| `phase_c.l1.*` | 15 | `phase_c_l1_scenarios` |
| `phase_c.approval.*` | 7 | `phase_c_approval_protocol` |
| `phase_c.c2.*` | 18 | `phase_c2_wiring_scenarios` |
| `conformance.compactor.*` | 4 | package kit (× 5 hook cases in selftest = 20; × 13 registry hooks in probe = 52) |
| `harness.*` | 7 | `harness-dst.test.ts` (bun) |
| `compaction.gen.*` (seeded: `tool_heavy` + `rng_canary`) | 1 family + 1 fixed canary | `compaction_seeded_dst` |
| `phase_c.gen.*` (seeded: `seal_boundary`, `checkpoint_pressure`, `split_prefix`, `stage_records`) | 4 families | `phase_c_seeded_dst` |

Seeded families report per-seed `scenario=<id> seed=<n>` lines plus a per-family
`family=<id> seeds=<n> ok` line, so a `.gen.` id is a *family* contract, not a single case.

Renaming or dropping an id is a contract change: gate output lines are parsed by humans and
scripts (`rg "scenario="`), so treat id changes like wire-schema changes — deliberate and
reviewed.

## Gates and CI

```text
make dst                      # the umbrella: everything deterministic
├── compaction_dst            # policy + catalog + runtime_status + long_qwen (--ai-stub)
├── conformance               # kit checks/tests + selftest + registry probe
├── phase_c_l1                # depends on compaction_dst; + approval + c2 wiring
├── smoke_parity              # L3 event-parity (scripts/dst/phase_a_event_parity.sh)
├── dst_l2                    # bun test src/tui/src/harness-dst.test.ts
└── dst_seeded                # seeded families + RNG canary (--caps IO,Env,Rand)
```

CI (`.github/workflows/verify-extensions.yml`) blocks every PR on the full set: the main job runs
`check_core`, `smoke_no_delegated_storm`, `make --keep-going compaction_dst conformance
phase_c_l1`, `make smoke_parity`, and `make verify_core` as advisory (`continue-on-error`); a
separate 5-minute `dst_l2` job (needs bun, not AILANG) runs the L2 gate.

The **DST seeded gate** step is seed-rotating: on `schedule` (nightly `0 6 * * *`) it runs
`DST_SEEDS=500 DST_BASE_SEED=$(date +%Y%m%d)`; on PR/push it runs the fixed
`DST_SEEDS=5 DST_BASE_SEED=1`. So PR runs are a fast constant 25 cases, and the *search* happens
nightly against a date-derived base. A nightly-only failure is reproduced locally by passing that
day's base seed. There is no automatic promotion of a failing seed into the fixed suite — doing
that by hand is the current regression practice.

Two standing rules:

1. **CI references make targets only, never script paths** — file moves are absorbed by the
   Makefile (this is what let the `scripts/dst/` migration land without touching the workflow).
2. **No live/network targets in CI** — `live_*` calibration stays manual.

`scripts/phase_b_projection_gate.sh` remains a manual gate by recorded disposition (Track 1
plan); `scripts/smoke_v2_*` are legacy smokes outside the DST oracle, pending the deferred
subsumption audit.

## The conformance kit and ABI lockstep

`packages/motoko_ext_conformance` certifies pre-step compactor extensions against the ABI
(`packages/motoko-ext-abi`), versioned in **lockstep majors** (both 4.0 at this writing). The
four compactor scenarios — `system_prefix_preserved`, `tool_pairing_preserved`,
`deterministic_replay`, `artifact_cache_effective` — run in-repo two ways: the selftest (bundled
hook cases) and the registry probe (every hook in the generated registry, guarding against a
mixed-ABI hydration). ABI 4.0 added observable pass-through
(`PassThroughObserved(code, fields)` → `extension_diagnostic` ledger events), so a silent
over-threshold compaction outcome is now either below-threshold by design or a bug; the kit
certifies identity, normalization bounds, ordering, replay stability, and counter neutrality for
it. History and acceptance:
`.agent/projects/004_phase_core_refactor/NOTE-abi-pre-step-observability{,-closeout}.md`.

## How to add a scenario

1. Pick the layer (usually L1) and the owning gate script in `scripts/dst/`.
2. Write `func scenario_<name>() -> Result[(), ScenarioFailure] ! {…maximal row…}` using
   `ok_or_failure`/`failure` from `src/core/test/dst_harness`; drive real core code through
   `stub_step`/`scripted_ports` fakes; assert over the typed ledger, not prose.
3. Register it with a **dotted id** in the script's scenario list (`seed: "fixed"`).
4. Run the owning make target; the pass count must increase by exactly your additions — counts
   are the anti-silent-drop oracle (recorded per-gate in the Track 2 plan).
5. `make dst` before pushing; CI enforces the same set.

**Adding a seeded family** instead: write `run_<name>(seed) -> bool` in the owning
`*_seeded_dst.ail`, draw params with the script's `pick_int`-style helpers *after* `rand_seed(seed)`,
add a `run_<name>_seeds` loop, and append its result to the family list so `families=N` and the
failure total stay derived from one source. Print `scenario=<dotted.gen.id> seed=<n>` per seed and
`family=<dotted.gen.id> seeds=<n> ok` per family. Assert **invariants only** — see the two rules
under *The seeded axis*; a family that asserts a specific decision will flake or go vacuous. Verify
boundary reach at a high seed count locally (e.g. `DST_SEEDS=200`) before committing the default 5.

Adding a whole new gate script: put it in `scripts/dst/`, give it a make target with the
**narrowest caps that pass**, chain it into `dst` (and CI if blocking), and record its baseline
count. Adding an ABI constructor? Expect exhaustive-match updates across
runtime/vocab/session/scripts — grep `PassThrough|StageApplied|TraceStageApplied` and rely on
the conformance registry probe to catch mixed hydration.

## Relationship to Z3 contracts

Complementary, not competing (ADR-001 §"Relationship To Z3 Contracts"): Z3 (`make verify_core`,
advisory in CI) proves local universal properties of pure helpers; DST owns anything requiring
execution traces across time or process boundaries. Z3-proved helpers keep scenario invariants
from re-deriving policy arithmetic.

## Decision history and cross-links

The ADR chain (two projects, independent numbering — this doc is the disambiguating spine):

| Doc | Decides |
|---|---|
| `.agent/projects/001_DST/ADR-001-deterministic-simulation-testing-architecture.md` | The layered scenario-and-invariant system itself |
| `.agent/projects/001_DST/ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md` | Compaction DST on the phase-core scaffold |
| `.agent/projects/001_DST/ADR-003-harness-boundary-dst-…-materialization.md` | Layer 2 scope: system-prompt materialization contract |
| `.agent/projects/001_DST/ADR-004-long-qwen-compaction-session-dst.md` | Long-session compaction DST design |
| `.agent/projects/004_phase_core_refactor/ADR-001-phase-oriented-core.md` | The phase-oriented core DST drives (D7 checkpoints, D9 policy residency, §6/§6.1 ABI + kit) |
| `.agent/projects/004_phase_core_refactor/ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` | Send-gate + project-vs-seal emission |
| `.agent/projects/007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md` | **Amends** the definition, naming threshold, and clock rule: what "DST" is entitled to mean, the conformance profile, the single-actor / logical-fault scope, and the revisit tripwires |
| `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` | The deterministic test world required to meet that bar (effect boundary, execution program, trace completion, replay) |

Execution record: `001_DST` and `004_phase_core_refactor` PLAN/HANDOFF/NOTE files (per-feature),
`.agent/projects/007_dst_consolidation/` (this consolidation: scope note, plans, as-built
handoff with the full migration commit list and baseline table).

**Delivered 2026-08-06** (was "known deferred work" from 2026-07-24 until then, and the entry read:
*"the deterministic test world that would earn the DST name (project 009 — generated event
orderings, logical faults, virtual time, complete returned traces, exact-program replay; currently
blocked on an upstream AILANG recorded-stream API)"*). **Two halves of that entry expired at
different times and both are recorded rather than deleted:** the upstream recorded-stream API landed
in a released AILANG and was repinned at WI-B1 and adopted at WI-C1/C2, so the *blocked-on* clause
had already been false for some time; and the world itself was completed and gated at WI-D5, which
is what earned the name — **for the baseline profile `driver_only/10`, whose extension-model coverage
is zero.** (The profile is `driver_only/11` from WI-D6; the sentence names v10 because that is the
version the name was earned on, and v11 changed no claim it rests on.)

Known deferred work — **the `on_budget_plan` entry was DONE at WI-D6, 2026-08-06, and is kept here
restated rather than deleted (S15).** It read: *"the `on_budget_plan` ABI widening — the one change
that would let any profile install an extension, and so the one that would make the four
extension-dependent acceptance clauses non-vacuous"*. **The first half happened and the second half
did not follow from it**: the row was narrowed rather than widened, any profile may now install an
extension — and **not one of the four clauses became non-vacuous**, because `driver_only` still
installs nothing. Making them non-vacuous needs the profile, not the ABI. Still deferred: a second
(`compose`-bearing) profile; shrinking and automatic
promotion of failing seeds, the `smoke_v2_*` subsumption audit
(operator-deferred 2026-07-12), in-flight extension diagnostics (`ExtPorts.emit_diagnostic`),
and the gated AILANG env-manifest Layer-2 scenarios (ADR-003; blocked on the WI-1/WI-2 track in
`.agent/projects/004_phase_core_refactor/NOTE-env-manifest-single-source-and-drift-guard.md`).
