# M-MOTOKO-DST-FRAMEWORK — Deterministic Simulation Testing, as built

**Status**: Implemented (as-built reference, 2026-07-12)
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

## Architecture

One sentence: *swap the ports, keep the code, read the ledger.*

- **Injected nondeterminism — ports.** Production runs with live adapters (`live_ports`, live
  AI); DST runs the same driver with fakes: `src/core/test/stub_step.ail` (scripted provider
  steps: `Scripted`/`ScriptedStep`, `prose_step`, `tool_step`, …) and
  `src/core/test/scripted_ports.ail` (`ScriptedPortsState`: model, approvals, clock).
  `src/core/test/ext_fixture.ail` provides extension-hook fakes. Because fakes are pure, running
  a scenario under `--caps IO` makes any raw effect fail at perform time — capability flags double
  as a conformance check ("caps-as-conformance").
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
`--caps IO` because unused effect rows don't demand capabilities — only performed effects do. All
current scenarios are fixed (`seed="fixed"`); seeded generation remains the designed extension
point from ADR-001, not yet built.

**The one deliberate exception:** `packages/motoko_ext_conformance` keeps its own package-owned
`Scenario`/`run_scenario`/reporter. Sharing the in-repo type caused an AILANG transitive
name-resolution collision with the ABI package's distinct `Scenario`, and the kit's surface is
ABI-versioned — consolidating it would have forced a kit major for zero behavior change. The
package harness is the only `run_all` outside `dst_harness.ail` (`rg '^func run_all' scripts`
must stay empty).

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
└── dst_l2                    # bun test src/tui/src/harness-dst.test.ts
```

CI (`.github/workflows/verify-extensions.yml`) blocks every PR on the full set: the main job runs
`check_core`, `smoke_no_delegated_storm`, `make --keep-going compaction_dst conformance
phase_c_l1`, `make smoke_parity`, and `make verify_core` as advisory (`continue-on-error`); a
separate 5-minute `dst_l2` job (needs bun, not AILANG) runs the L2 gate. Two standing rules:

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

Execution record: `001_DST` and `004_phase_core_refactor` PLAN/HANDOFF/NOTE files (per-feature),
`.agent/projects/007_dst_consolidation/` (this consolidation: scope note, plans, as-built
handoff with the full migration commit list and baseline table).

Known deferred work: seeded scenario generation (ADR-001), the `smoke_v2_*` subsumption audit
(operator-deferred 2026-07-12), in-flight extension diagnostics (`ExtPorts.emit_diagnostic`),
and the gated AILANG env-manifest Layer-2 scenarios (ADR-003; blocked on the WI-1/WI-2 track in
`.agent/projects/004_phase_core_refactor/NOTE-env-manifest-single-source-and-drift-guard.md`).
