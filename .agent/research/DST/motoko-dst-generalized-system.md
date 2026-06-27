# Generalized Deterministic Simulation Testing for Motoko

Date: 2026-06-27
Status: Research draft
Related:
- `.agent/plans/DST_v1_Motoko_Core.md`
- `.agent/research/DST/deterministic-simulation-testing-for-agent-loop-compaction.md`
- PR #75: actual-token compaction and system-message pinning
- PR #76: out-of-workspace `SYSTEM_MD` materialization

## Thesis

Motoko needs a generalized Deterministic Simulation Testing (DST) system, not one-off smokes for each bug. The recurring failures have the same shape: behavior depends on multi-step state transitions across process boundaries, environment setup, sandbox rules, provider telemetry, extension hooks, tool dispatch, and conversation history.

PR #75 and PR #76 should become two scenario families in a larger simulation framework:

- **Loop-state scenario:** provider token telemetry from one step affects compaction before the next step.
- **Harness-boundary scenario:** parent process materializes a readable system prompt before spawning the sandboxed AILANG runtime.

The generalized system should let us add these as data-driven scenarios with shared fixtures, fakes, recorders, and invariant checkers.

## What DST Means Here

DST is not "mock everything and assert a string." For Motoko, DST means:

1. Build a deterministic model of the external contracts around the agent.
2. Drive the real production transition code where possible.
3. Record all boundary observations.
4. Assert invariants over traces, not over final model prose.
5. Print a seed or scenario id that exactly reproduces any failure.

The test oracle should be structural:

- Was the system prompt non-empty and stable?
- Did provider-call messages preserve required protocol fields?
- Did the loop terminate within budget?
- Did tool calls flow through policy and handlers in the expected order?
- Did sandboxed paths become readable by the child?
- Did extension hooks receive the right slice of state?
- Did cost/context counters advance monotonically and drive the next decision?

## Layers

A useful Motoko DST system has four layers. Each layer can be tested independently, and some scenarios intentionally cross layers.

### Layer 0: Pure Policy DST

Scope:

- pure helpers
- threshold policies
- message rewrites
- parsers
- estimators

Examples:

- `compact_step_actual`
- `estimate_tokens_messages`
- tool-result elision
- command parsing
- cost arithmetic

Simulator shape:

```text
input data -> pure function -> invariant checks
```

This layer is cheap and should run on every PR.

### Layer 1: Loop-State DST

Scope:

- `loop_v2` state transitions
- scripted provider responses
- scripted extension runtime
- scripted tool policy and tool handling
- captured provider-call messages

Simulator shape:

```text
initial loop state
  + provider script
  + extension script
  + tool script
  -> loop transition trace
  -> invariant checks
```

This is where PR #75 belongs.

### Layer 2: Harness-Boundary DST

Scope:

- TypeScript runtime harness
- profile/env loading
- child process env allowlist
- sandbox path materialization
- profile mirroring
- child spawn arguments

Simulator shape:

```text
parent env + temp filesystem + profile
  -> harness preparation
  -> child env/spawn record
  -> sandbox readability checks
```

This is where PR #76 belongs.

### Layer 3: End-to-End Deterministic Harness DST

Scope:

- TypeScript harness starts a test child or AILANG runtime in stub mode
- no real provider
- no external network
- deterministic filesystem
- deterministic env server behavior

Simulator shape:

```text
workspace fixture
  -> RuntimeProcess/test child
  -> scripted loop
  -> JSONL event trace
  -> invariant checks
```

This layer is slower but gives confidence that Layers 1 and 2 compose.

## Core Components

### Scenario Schema

Each scenario should be a structured fixture with a stable id:

```json
{
  "id": "compaction.actual_tokens_drive_next_step",
  "layer": "loop-state",
  "seed": 0,
  "workspace": {},
  "env": {},
  "initialMessages": [],
  "providerScript": [],
  "extensionScript": [],
  "toolScript": [],
  "expectedInvariants": []
}
```

Not every field applies to every layer. The goal is consistent naming and reporting, not one universal mega-schema.

### Trace Recorder

The recorder should capture boundary observations in a normalized trace:

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

The trace is the object under test. Assertions should read from the trace.

### Invariant Library

Common invariants should be reusable functions:

- `system_prompt_non_empty`
- `system_prompt_stable`
- `system_messages_not_sent_to_pre_step`
- `provider_calls_have_system_prefix`
- `tool_call_ids_preserved`
- `message_order_preserved`
- `last_input_tokens_carried_forward`
- `actual_tokens_select_compaction_tier`
- `sandbox_paths_readable_by_child`
- `config_env_vars_forwarded_to_child`
- `loop_terminates_within_budget`
- `no_unexpected_provider_call_after_terminal_stop`

Scenario tests should mostly compose invariants instead of implementing bespoke assertions.

### Fakes and Scripts

Provider fake:

- returns scripted `StepResult`s
- records each input message list
- supports explicit `input_tokens`, `output_tokens`, `finish_reason`, `tool_calls`

Extension fake:

- records hook inputs
- can return `PassThrough`
- can return `Compacted`
- can deny or delegate tools
- can maliciously try to drop messages

Tool fake:

- returns scripted stdout/stderr/exit code
- can generate large outputs
- can fail deterministically
- can simulate truncation

Harness fake child:

- records env
- validates sandbox-readable paths
- optionally emits minimal JSONL events such as `system_prompt_built`

Filesystem fixture:

- creates temp workspaces
- creates external files outside the workspace
- creates profile mirrors
- records materialized files

## PR #75 as Two Scenario Tests

### Scenario: `compaction.actual_tokens_drive_next_step`

Layer: Loop-state DST

Purpose: provider telemetry from step N must drive compaction before step N+1.

Fixture:

```text
model = "ollama/qwen3.6:35b-a3b-mxfp8"
effective_context = 262144 - 75000

initial messages:
  system "AILANG reference sentinel"
  user "task"
  12 old tool messages

provider script:
  step 1:
    finish_reason = "tool_calls"
    input_tokens = 140359
    tool_calls = [BashExec true]
  step 2:
    finish_reason = "stop"
    input_tokens = 100
```

Invariants:

- step 1 provider call includes the system prefix
- after step 1, `last_input_tokens == 140359`
- step 2 provider call used the 75% compaction tier
- old tool messages outside the last 5 were elided
- last 5 tool messages remain unelided
- tool message `tool_call_id`s are preserved

### Scenario: `compaction.system_messages_hidden_from_compactors`

Layer: Loop-state DST

Purpose: no compaction layer can drop or mutate the system prompt.

Fixture:

```text
initial messages:
  system "AILANG reference sentinel"
  user "task"
  tool "large output"

extension script:
  on_pre_step:
    record received messages
    return Compacted([], "drop conversation")

provider script:
  step 1 stop
```

Invariants:

- extension received no `system` messages
- provider call still begins with the original system message
- system content is byte-identical to the initial content

## PR #76 as Two Scenario Tests

### Scenario: `harness.external_system_md_materialized`

Layer: Harness-boundary DST

Purpose: external `SYSTEM_MD` paths are materialized into the workspace before AILANG spawn.

Fixture:

```text
WORKDIR = /tmp/motoko-dst/workdir
SYSTEM_MD = /tmp/motoko-dst/external/SYSTEM.md
external SYSTEM.md content = "AILANG reference sentinel"
```

Invariants:

- child env `SYSTEM_MD` points inside `WORKDIR`
- materialized file exists
- materialized file content equals the external file content
- child env includes `AILANG_FS_SANDBOX=WORKDIR`
- a sandboxed child read of `SYSTEM_MD` succeeds

### Scenario: `harness.workspace_system_md_not_rewritten`

Layer: Harness-boundary DST

Purpose: local workspace prompt paths remain valid and are not broken by materialization.

Fixture:

```text
WORKDIR = /tmp/motoko-dst/workdir
SYSTEM_MD = /tmp/motoko-dst/workdir/SYSTEM.md
workspace SYSTEM.md content = "AILANG reference sentinel"
```

Invariants:

- child env `SYSTEM_MD` points to a readable path under `WORKDIR`
- content equals the original workspace prompt
- no empty prompt is observed

## Cross-Layer Scenario

### Scenario: `system_prompt_read_then_pinned_through_compaction`

Layer: End-to-end deterministic harness DST

Purpose: compose PR #76 and PR #75 invariants.

Fixture:

```text
WORKDIR outside prompt location
SYSTEM_MD external to WORKDIR
scripted provider returns high input_tokens on step 1
extension tries to compact/drop conversation before step 2
```

Invariants:

- harness materializes `SYSTEM_MD`
- runtime emits non-empty `system_prompt_built`
- extension never sees system messages
- provider calls receive non-empty system prefix
- step 2 compaction is driven by step 1 actual tokens
- system prefix is still present after compaction

This is the best high-level regression for the combined failure class: "the agent loses the AILANG reference during long runs."

## Implementation Strategy

### Phase 1: Make Boundaries Inspectable

Add test-only or production-safe seams:

- provider call recorder for scripted `StepProvider`
- extension hook recorder
- harness preparation function that can be invoked without launching the full UI
- child env/spawn recorder for `RuntimeProcess`

Avoid large refactors. The first goal is observability at boundaries.

### Phase 2: Add Scenario Runners

Two runners are enough initially:

```text
scripts/dst_loop_scenarios.ail
src/tui/src/runtime-process-env.test.ts or src/tui/src/harness-dst.test.ts
```

The AILANG runner covers Layers 0-1. The TypeScript runner covers Layer 2. Layer 3 can wait until the two lower layers stabilize.

### Phase 3: Add Reusable Invariants

Start with handwritten invariant functions. Do not introduce a heavy property-testing framework yet.

Recommended first invariants:

- system prompt non-empty
- provider system prefix
- no system messages in pre-step extension input
- tool IDs preserved after compaction
- actual-token tier selection
- sandbox path readability

### Phase 4: Add Seeded Generation

Once scenario tests are stable, add seeded generators around the same invariants:

- message histories around compaction thresholds
- tool-call argument sizes
- system prompt path locations
- profile path layouts
- extension hook decisions
- tool success/failure/truncation outcomes

Every failure must print:

- scenario id
- seed
- minimized input if available
- normalized trace

## Where This Should Live

Suggested structure:

```text
src/core/test/dst/
  scenarios.ail
  provider_recorder.ail
  extension_recorder.ail
  invariants.ail
  generators.ail

scripts/
  smoke_dst_loop.ail

src/tui/src/
  harness-dst.test.ts
  runtime-process-env.test.ts
```

If AILANG package-resolution remains unstable for full loop tests, start with:

- pure compaction DST in `scripts/smoke_v2_compaction_actual_dst.ail`
- TypeScript harness-boundary DST in `src/tui/src/harness-dst.test.ts`

Then connect the full loop once `pkg/...` import resolution is reliable.

## CI Shape

Fast PR gate:

```bash
make test_core
ailang run --caps IO --entry main scripts/smoke_v2_compaction_actual_dst.ail
cd src/tui && bun test src/harness-dst.test.ts
```

Expanded PR gate:

```bash
make test_dst
```

Nightly:

```bash
DST_SEEDS=500 make test_dst_seeded
```

Optional provider smoke:

```bash
OPENROUTER_API_KEY=... PROFILE=openrouter make run TASK='...'
```

The provider smoke should not be the primary regression gate.

## Design Rules

- Prefer invariant assertions over final-output assertions.
- Prefer scenario ids over vague test names.
- Keep fakes protocol-shaped, not model-shaped.
- Record boundary traces before asserting.
- Make all generated tests seed-reproducible.
- Test both "inside sandbox" and "outside sandbox" path cases.
- Treat empty system prompt as a failing invariant unless a scenario explicitly opts out.
- Keep real-provider tests optional.

## Open Questions

- Should scenario fixtures be JSON files, AILANG records, TypeScript objects, or all three by layer?
- Should `RuntimeProcess` expose a dry-run spawn-preparation API for harness DST?
- Should system prompt materialization become a standalone exported function instead of living inside `main()`?
- Should compaction thresholds and headroom be exported constants so tests do not duplicate policy values?
- Should event traces become the canonical DST output format across both AILANG and TypeScript layers?
- Can the existing `run_v2_with_stub` path be extended to record provider-call messages without invasive changes?

