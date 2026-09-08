# Phase-Oriented Core, Deterministic Test World, and the DST Framework

Base branch: `origin/main`

Integration branch `main_dst` at `303d8697`, **773 commits ahead of and 0 behind
`origin/main`** (`e48de909`). 65 merge commits — PRs #79 through #152, each already
reviewed individually. This merge integrates reviewed work; it introduces no new material.

**892 files changed, +217,701 / −3,061.** Roughly half the insertions (~120k lines) are the
`.agent/` working record — ADRs, handoffs, notes, session summaries — not runtime code.
Runtime and test code is ~60k lines, concentrated in `src/core/` and `scripts/dst/`.

## Summary

`main` still carries the pre-refactor agent loop: a single 1,727-line
`src/core/agent_loop_v2.ail` that owned decisions, effects, transcript construction, and
telemetry together. Nothing in that shape is deterministically testable — provider telemetry
from step N shapes step N+1, compaction applies to the send payload but not loop history, and
extension hooks see conversation slices no unit test can reach. Live-provider tests are slow,
model-dependent, and unrepeatable; unit tests cannot see multi-step state.

This branch replaces that shape with a **functional core with an imperative shell** — a pure
step machine returning decisions-as-data, phases that perform effects only through injected
**ports**, a single pure transcript builder, and a thin driver that owns the real effect row
and appends an **append-only event ledger that doubles as the DST trace**. DST is not a suite
added afterward; it is a property of this shape. The deterministic test world, the seeded
generated axis, and the conformance kit are then built on top.

## Changes

### Phase-oriented core (`.agent/projects/004_phase_core_refactor/ADR-001`)

- Reduces `src/core/agent_loop_v2.ail` from 1,727 lines to a 37-line compatibility facade.
- Adds `session.ail` (3,624) as the sole agent loop; `ports.ail` (2,573) as the injected
  effect boundary over provider, tools, clock, env, and FS; `phase_vocab.ail` (1,318) as the
  only producer of provider-facing messages; `step_machine.ail` (436) as the pure `decide`.
- Adds `ext_world.ail` (1,095) for extension-hook world mediation, plus `tool_phase.ail`,
  `model_phase.ail`, `cost_phase.ail`, `hook_phase.ail`, `tool_stream_phase.ail`,
  `fs_node.ail`, and `recovery.ail`.
- Reworks `ext/runtime.ail` (+435/−74) for the pre-step compactor chain and reduces
  `compaction.ail` (+77/−180) to a measurement surface; the structural elision ladder now
  lives in `packages/motoko-ext-compaction-structural`.
- Deletes `src/core/ext/types.ail`, superseded by `packages/motoko-ext-abi`.

### Deterministic test world (`.agent/projects/009_motoko_dst_execution/ADR-001`, Accepted 2026-08-02)

- Adds ~19 `src/core/dst_*.ail` modules (~17k lines) and 52 files / 25.5k lines under
  `scripts/dst/`.
- Seeded generation of environment-event *ordering* (`dst_generator.ail`, `dst_corpus.ail`),
  a logical-fault catalogue (`dst_fault_catalogue.ail`), a virtual clock, and exact-program
  strict replay (`dst_replay.ail`, `dst_program.ail`, `dst_persistence.ail`).
- Reusable structural invariants over the returned `LedgerTrace` in `dst_invariants.ail`
  (1,957 lines) — asserted over the trace, never over model prose.
- Three profiles — `dst_driver_only.ail`, `dst_driver_plus_no_ops.ail`,
  `dst_driver_plus_compose.ail` — with `dst_profile.ail` and `dst_profile_coverage.ail`
  *computing* coverage rather than asserting it.
- Reporting via `dst_run_report.ail`, `dst_attribution_table.ail`,
  `dst_event_vocabulary.ail`, and `dst_result.ail`.
- Documents the result as-built in
  `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`.

### Build targets

Adds ~40 `make` targets: `dst`, `dst_seeded`, `dst_l2`, `strict_replay`, `seeded_generator`,
`program_persistence`, `driver_only`, `driver_plus_no_ops`, `driver_plus_compose`,
`fault_catalogue`, `event_vocabulary`, `invariants`, `run_report`, `corpus_pr`,
`corpus_rotating`, `profile_coverage`, `profile_definition`, `execution_program`,
`discovery`, `world_state`, `terminal_trace`, `conformance`, the inventory family
(`effect_inventory`, `ext_call_inventory`, `ext_ambient_inventory`, `ext_hook_scope`,
`test_coverage`, `predicate_anchors`, `attribution_table`), and live calibration smokes
(`live_qwen36_*`, `live_hunyuan3_*`, `deepseekv4_flash_*`).

### CI

- Adds `.github/workflows/dst-corpora.yml` — ADR-001 D11's two corpora as two jobs: a
  blocking PR corpus of fixed seeds and promoted regression programs, and a scheduled
  rotating corpus whose seed window is the UTC day number. `dst_corpus.resolve_epoch` has no
  default, so a missing epoch fails the job rather than silently freezing the window; each
  job declares a minimum seed count and asserts that exact count completed, so a zero,
  truncated, or below-minimum window fails. `make corpus_rotating` proves both properties
  locally, including that the scheduled job does not select `MOTOKO_DST_SCALE: demo`.
- Extends `.github/workflows/verify-extensions.yml` (+51/−17).

### Extensions

Adds 16 packages: `motoko-ext-abi` (the versioned hook ABI), `motoko-ext-compose`,
`motoko-ext-compaction-ai`, `motoko-ext-compaction-structural`, `motoko-ext-mcp`,
`motoko-ext-a2a`, `motoko-ext-omnigraph`, `motoko-ext-microrag`, `motoko-ext-exa-search`,
`motoko-ext-ailang-docs`, `motoko-ext-ai-compat`, `motoko-ext-decision-framework`,
`motoko-ext-empty-stop-guard`, `motoko-ext-progress-contract-guard`,
`motoko-ext-test-dummy`, and `motoko_ext_conformance` (the conformance kit).

### Tooling

Adds `tools/code-graph` (11.5k lines), `tools/effect-inventory`, `tools/ext_call_inventory`,
`tools/ext_ambient_inventory`, `tools/predicate-anchors`, `tools/profile_definition`,
`tools/test_coverage`, `tools/md2pdf`, and `tools/mmd2svg`. `profile_definition` includes
`check_no_op_profile.py`, which fails if a non-zero coverage number is stated without its
vacuity qualifier.

### Harness boundary (TUI)

- Reworks `src/tui/src/runtime-process.ts` (+103/−141), extracting child-process env
  construction into an exported `buildChildEnv()` with an explicit allowlist — provider keys,
  `AILANG_FS_SANDBOX`, `MOTOKO_*`, and OTEL passthrough — so the harness→runtime boundary is a
  testable function rather than inline setup.
- Moves `systemPromptForWorkspace` and `materializeSystemPromptArg` out of `index.ts` into
  `src/tui/src/system-prompt.ts`; behavior unchanged.
- Adds `harness-dst.test.ts` and `runtime-process.unknown-events.test.ts`.

### Toolchain

Repins `ailang.lock` from **v0.24.2 to v0.33.0** and updates `ailang.toml`. The architecture's
streaming-trace parity depends on the upstream recorded-stream API landing in a released
AILANG, which is what the repin carries.

### Documentation

- `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md` — the durable spine.
- 469 files under `.agent/`: 10 project working records, ADRs, handoffs, notes, 78 session
  summaries, and 5 meta-decisions.
- `papers/motoko-dst-report/` — an 8–12pp external technical report (SCOPE, DRAFT, PDF,
  review round 1, two SVG figures).

### Removals

- `src/core/ext/types.ail` — superseded by `packages/motoko-ext-abi`.
- `scripts/smoke_v2_compaction_ai.ail`, `scripts/smoke_v2_compaction_ai_registry.ail` —
  superseded by the DST compaction targets.

## Coverage claims

Per D10 of `009/ADR-001` and the spine doc's naming block, every use of the unqualified "DST"
label for the generated axis **must name the profile**, and coverage must be stated as the
profiles' own STATEMENT lines state it. At HEAD:

- **`driver_only` v22** — extension-model coverage is **zero**; it installs nothing. Four of
  the eleven acceptance rows lean on that emptiness: the boundary row passes vacuously in
  every installed-extension clause, the fault row's `extension_effect_fault` waiver and the
  oracle row's `ScratchpadResult` exemption are both bought by it, and the virtual-time row's
  pass, while real, does not transfer.
- **`driver_plus_no_ops` v9** — coverage is **non-zero and entirely of no-ops**: 32 hooks
  across 4 installed extensions, of which the 16 resting on D5 criterion 2 satisfy its port
  and origin-tag clauses **vacuously**, over an empty set of performed effects.
- **`driver_plus_compose` v1** — 7 covered + 1 excluded, of which **one** hook mediates the
  world substantively. Its registration gap is stated, not closed.
- Tree-wide honest form, as the computed vacuity register states it: **one of forty
  classification entries is measured and substantive.** Hermeticity is enforced per profile;
  `extension_effect_fault` is waived by every profile.

The label covers the **generated axis only** — fixed scenarios are property-based testing over
agent-loop state and must not be called DST unqualified. The `live_*` targets are calibration
smokes, explicitly outside the deterministic oracle. The name was earned at the WI-D5 gate on
2026-08-06 for `driver_only/10` (eleven of eleven acceptance rows), not for the framework in
general. Four deferred gate mechanisms from `009/ADR-001` remain open; each has a stated
acceptance criterion, and each blocks broader name adoption rather than this merge.

## Verification

```
make dst                  # generated axis, demo scale
make driver_only          # baseline profile — prints its own coverage statement
make driver_plus_no_ops   # prints the no-op vacuity qualifier
make driver_plus_compose
make strict_replay        # exact-program replay
make corpus_pr            # the blocking CI corpus, locally
make conformance          # extension conformance kit
bun test                  # TUI harness tests, incl. harness-dst + unknown-events
```

CI runs `dst-corpora.yml` (PR corpus, blocking) and `verify-extensions.yml` on this PR.

## Review notes

1. **Working files committed at the repo root.** `phase_log.md` (a compaction-calibration
   scratch log) and `scratchpad/verify_guard.ail` (129 lines) read as session artifacts rather
   than intended tree contents. Worth deciding whether they belong on `main`.
2. **New root config.** `package.json` and `bun.lock` carry a single devDependency
   (playwright); `.marimo.toml` raises the output cap for the DAG concept graph;
   `.gitattributes` sets `*.sh text eol=lf`.
3. **`.agent/` volume.** ~120k lines of working record. Deliberate under the repo's convention
   (`design_docs/` = durable design of shipped behavior, `.agent/projects/` = the working
   record, per `.agent/issues/docs-split-across-agent-and-design-docs.md`), but it dominates
   the diffstat and will dominate review attention unless reviewers filter it out.
