# ADR-001: Deterministic Simulation Testing Architecture for Motoko

Date: 2026-06-27
Status: Proposed

## Context

Motoko failures increasingly occur across boundaries rather than inside single pure functions. Recent compaction and harness regressions showed the same pattern:

- provider telemetry from one step influences the next loop decision
- compaction is applied to the provider-call payload but not persisted to loop history
- extension hooks can observe or rewrite the wrong slice of conversation state
- child process sandboxing can make configured files unreadable
- environment forwarding can silently disable runtime behavior

Real-provider tests are insufficient as the primary regression mechanism. They are expensive, slow, model-dependent, network-dependent, and difficult to reproduce. Unit tests are also insufficient when correctness depends on multi-step state transitions and process-boundary setup.

We need a deterministic test system that drives production transition code where practical, records boundary traces, and asserts structural invariants rather than final model prose.

The AILANG docs used for this ADR come from the MCP configured in `.mcp.json`. The local repo targets AILANG `>=0.24.2`, and the local binary observed during research was `v0.24.2`; the MCP docs expose `latest = 0.25.0` but no `0.24.x` snapshot. Therefore AILANG test syntax, stdlib helpers, and any property-test APIs are design inputs only until validated with the local `ailang check` or `ailang test`.

This ADR is based on:

- `.agent/research/DST/motoko-dst-generalized-system.md`
- `.agent/research/DST/deterministic-simulation-testing-for-agent-loop-compaction.md`
- `.agent/plans/DST_v1_Motoko_Core.md`

## Decision

Build Motoko DST as a layered scenario-and-invariant system.

DST will mean:

1. Deterministically model external contracts around Motoko.
2. Drive real production transition code where feasible.
3. Record boundary observations into normalized traces.
4. Assert reusable structural invariants over those traces.
5. Report scenario id, seed, and trace on failure.

The system will use explicit scripted fakes and recorders rather than assuming mature AILANG effect-handler mocking. AILANG latest docs describe effect mocking as planned, while the local repo currently uses explicit stubs such as `run_v2_with_stub`.

## Decision Drivers

- Deterministic replay must work without Ollama, OpenRouter, or live network.
- Tests must observe boundary payloads, not infer correctness from final model prose.
- The first implementation should use existing Motoko test seams before introducing a new framework tree.
- CI must not hide failures behind missing AILANG package-cache state.
- Seeded generation should extend fixed scenario tests, not replace them.
- Time, random, filesystem, and env observations must be normalized or explicitly controlled.

## Constraints

- Layer 1 and Layer 3 tests that import `agent_loop_v2` also import `src/core/ext/registry_generated.ail`; dependency hydration is a hard precondition, not a best-effort setup step.
- `ailang lock` is not accepted as sufficient by itself unless a follow-up check proves all generated-registry imports resolve.
- AILANG `std/clock` latest-doc metadata does not show how to enable virtual time. DST traces must normalize clock-derived fields until a local deterministic clock control is identified.
- Real-provider and live-network calls are outside the DST oracle and remain supplemental smokes only.

## Layers

### Layer 0: Pure Policy DST

Tests pure helpers and policies:

- compaction thresholds
- token estimates
- message elision
- parser helpers
- cost arithmetic
- path/config normalization

This layer can run through `ailang test` or `ailang run` smokes.

### Layer 1: Loop-State DST

Tests `loop_v2` state transitions with scripted provider, extension, and tool behavior.

The first load-bearing seam is provider-call recording in the existing scripted provider path. Compaction is ephemeral: compacted messages are sent to the provider, while the loop recurses on full uncompacted history. Therefore tests must inspect provider-call payloads, not just returned messages.

### Layer 2: Harness-Boundary DST

Tests TypeScript harness behavior before AILANG starts:

- child env preparation
- sandbox-readable path materialization
- profile mirroring
- env allowlist/forwarding
- spawn arguments

This layer catches bugs like external `SYSTEM_MD` being unreadable under `AILANG_FS_SANDBOX`.

### Layer 3: End-to-End Deterministic Harness DST

Composes the TypeScript harness with a deterministic child/runtime probe or scripted AILANG loop. It must not use real providers or live network as its oracle.

## Core Components

DST will use:

- Scenario fixtures with stable ids.
- A normalized trace recorder.
- Reusable invariant functions.
- Scripted provider fakes returning `std/ai.StepResult`-shaped values.
- Extension hook fakes that can record inputs and return `PassThrough` or `Compacted`.
- Tool fakes for deterministic stdout/stderr/exit-code behavior.
- Harness-boundary fixtures for temp workspaces, external files, and env layouts.
- Seeded generators for fuzzing scenario parameters after fixed scenarios are stable.

Scenario ids are the stable public contract. Fixture representation can vary by layer in v1, but each scenario must report the same id in failures and traces.

Canonical trace events should include:

```text
scenario_start
harness_env_prepared
child_spawn_prepared
system_prompt_built
extension_pre_step_called
provider_call_prepared
provider_result
tool_policy_decision
tool_result_appended
loop_totals_updated
scenario_end
```

### Provider-Call Recording Contract

The first required Layer 1 seam is a recorder around the scripted provider path. For every provider call, the trace should record at least:

- scenario id and loop step index
- normalized message payload passed to `dispatch_step`
- pinned system-prefix projection
- tool schema names or ids, if present
- previous `last_input_tokens`
- provider result `input_tokens`, `output_tokens`, `finish_reason`, and tool-call ids
- selected compaction tier or enough input facts to recompute the tier
- whether persisted loop history remains uncompacted after the call

The recorder must not change production provider behavior. If full messages are too large for default output, the failure trace can include a bounded projection plus hashes, while the in-memory invariant checks can still inspect the complete payload.

## Initial Scenario Families

### Compaction

The compaction scenarios prove actual-token behavior and system-message pinning.

Canonical ids:

- `compaction.actual_tokens_drive_next_step`
- `compaction.system_messages_hidden_from_compactors`
- `compaction.emergency_exhaustion_estimate_gated`
- `compaction.actual_tokens_small_context_fail_open`
- `compaction.provider_payload_vs_uncompacted_history_pressure`

Important invariants:

- provider-call payload contains the pinned system prefix
- extension `on_pre_step` never receives system messages
- `last_input_tokens` carries forward from provider result
- actual-token path uses 60/75/85 tiers only when effective context is positive
- estimate fallback uses 70/85/95 tiers when `last_input_tokens <= 0`
- emergency entry is actual-token-gated, but exhaustion is estimate-gated
- tool-call IDs and tool-result IDs survive elision

### Harness Prompt Materialization

The harness scenarios prove runtime inputs are readable inside the sandbox.

Canonical ids:

- `harness.external_system_md_materialized`
- `harness.workspace_system_md_not_rewritten`
- `harness.missing_system_md_fails_loudly`
- `harness.system_md_forwarded_to_child_env`

Important invariants:

- child env `SYSTEM_MD` points to a sandbox-readable path
- materialized prompt content equals the original external file
- child env includes `AILANG_FS_SANDBOX=WORKDIR`
- non-empty configured system prompts produce non-empty runtime prompt observations

## Preconditions

Do not add generalized DST on top of known-red tests.

Before Layer 1 or Layer 3 DST is enabled:

1. Hydrate AILANG registry dependencies in CI and local setup.
2. Ensure every package imported by `src/core/ext/registry_generated.ail` is available.
3. Fix or retire stale compaction tests that still assume no output headroom, especially tests using `test/tiny`.
4. Update compaction source comments to document both tier tables.
5. Validate any AILANG test/property-test syntax against the local binary, not only MCP latest docs.

## Implementation Plan

### Phase 0: Restore Test Preconditions

- Add dependency hydration to the test workflow.
- Add a concrete import-resolution check for the full-loop path, for example `ailang check` on a script or test that imports `agent_loop_v2`.
- Repair stale compaction tests around `context_limit - 75000`.
- Keep current pure compaction checks green.

### Phase 1: Make Existing Boundaries Inspectable

Start from existing infrastructure:

- `src/core/test/stub_step.ail`
- `src/core/agent_loop_v2.ail#run_v2_with_stub`
- existing `scripts/smoke_v2_*.ail`
- existing TypeScript runtime-process tests

Add provider-call recording to the scripted provider path. This is the first required seam.

### Phase 2: Add Scenario Runners

Initial files should stay small:

```text
scripts/smoke_v2_compaction_actual_dst.ail
src/tui/src/harness-dst.test.ts
src/tui/src/runtime-process-env.test.ts
```

Only introduce `src/core/test/dst/` after the smaller seams prove useful.

### Phase 3: Add Reusable Invariants

Implement common invariant helpers, including:

- `system_prompt_non_empty`
- `system_prompt_stable`
- `provider_calls_have_system_prefix`
- `system_messages_not_sent_to_pre_step`
- `tool_call_ids_preserved`
- `actual_tokens_select_compaction_tier`
- `provider_payload_compacted_but_history_uncompacted`
- `emergency_compaction_exhaustion_uses_estimate`
- `small_effective_context_fails_open`
- `sandbox_paths_readable_by_child`

### Phase 4: Add Seeded Fuzzing

Add seeded generators around fixed scenarios:

- message history sizes
- tool output sizes
- tool-call argument sizes
- token counts near thresholds
- extension decisions
- `SYSTEM_MD` path layouts
- profile mirror layouts

Every failure must print scenario id, seed, first failed invariant, and normalized trace.

## CI Shape

Fast PR gate:

```bash
ailang lock
make test_core
ailang check scripts/smoke_v2_compaction_actual_dst.ail
ailang run --caps IO --entry main scripts/smoke_v2_compaction_actual_dst.ail
cd src/tui && bun test src/harness-dst.test.ts
```

If `ailang lock` does not hydrate every registry dependency, CI must explicitly install missing packages before full-loop DST. The lock/install step is only successful when the full-loop import-resolution check passes.

Expanded gate:

```bash
ailang lock
make test_dst
```

Nightly:

```bash
DST_SEEDS=500 make test_dst_seeded
```

Provider smokes remain optional and supplemental.

## Acceptance Criteria

The first DST implementation is acceptable when:

- package hydration plus import-resolution checks pass in CI
- known stale compaction tests are fixed or retired rather than ignored
- a compaction DST scenario can prove that the provider payload was compacted while persisted loop history stayed uncompacted
- the external `SYSTEM_MD` harness scenario fails against the buggy behavior from PR #76 and passes after materialization
- every DST failure prints scenario id, seed when applicable, first failed invariant, and a normalized trace
- no DST gate requires Ollama, OpenRouter, or live network

## Consequences

Positive:

- Regressions become reproducible without Ollama/OpenRouter.
- Known bug classes become reusable scenario families.
- The provider-call payload becomes observable, closing the main loop-state test gap.
- Harness-boundary failures become testable without a full agent run.
- Fuzzing can explore scenario parameters without losing deterministic replay.

Negative:

- Some production-safe seams must be added for observability.
- CI must reliably hydrate AILANG registry dependencies.
- Tests will need care to avoid duplicating policy constants that should be exported from source.
- Layer 1 and Layer 3 DST can be blocked by unrelated generated-registry imports until package hydration is fixed.

## Rejected Alternatives

### Real-provider E2E as the primary gate

Rejected because it is flaky, slow, expensive, and not deterministic.

### Pure helper tests only

Rejected because they cannot catch loop-state and harness-boundary failures.

### Extract a pure pre-provider helper first

Deferred. Extension `on_pre_step` carries broad effects, and the most important observation is the actual payload consumed by `dispatch_step`. Provider-call recording is the better first seam.

### Arbitrary black-box fuzzing

Rejected for v1. Fuzzing should be seeded, scenario-shaped, and invariant-driven.

## Open Questions

- Should compaction thresholds and output headroom be exported constants?
- Should scenario fixtures be AILANG records, JSON files, TypeScript objects, or layer-specific?
- Should traces be normalized JSONL everywhere, or should AILANG `std/trace` be used for Layer 1?
- How should virtual time be enabled for `std/clock`, if needed?
