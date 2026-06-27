# Generalized Deterministic Simulation Testing for Motoko

Date: 2026-06-27
Status: Research draft
Related:
- `.agent/plans/DST_v1_Motoko_Core.md`
- `.agent/research/DST/deterministic-simulation-testing-for-agent-loop-compaction.md`
- PR #75: actual-token compaction and system-message pinning
- PR #76: out-of-workspace `SYSTEM_MD` materialization
- AILANG docs MCP: `.mcp.json` -> `https://mcp.ailang.sunholo.com/mcp/`

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

## AILANG Docs Grounding

This draft was checked against the AILANG docs MCP configured in `.mcp.json`.

Important version note: the local repo declares `ailang = ">=0.24.2"` and the local binary reports `AILANG v0.24.2`, but the MCP docs server does not expose a `v0.24.2` snapshot. It reported `latest = 0.25.0`, so the grounding below uses the MCP `latest` docs and stdlib metadata. Anything used for implementation should be validated against the local `ailang check`/`ailang test` binary before landing.

Grounding points from MCP:

- AILANG has first-class unit and property tests in the docs (`test "name" = expr`, `property "name" (...) = expr`) and property tests generate random cases with shrinking.
- Property-test configuration is documented through environment variables: `ailang_test_runs`, `ailang_test_seed`, `ailang_test_max_size`, `ailang_test_min_int`, and `ailang_test_max_int`.
- AILANG's effect system is explicit and capability-based; side effects must appear in signatures and be granted at runtime through `--caps`.
- The docs explicitly call out testing benefits from explicit effects and describe mocking effects as planned, while pure function testing is current. That supports starting DST with pure policy tests and explicit fakes rather than assuming a mature effect-handler mocking layer.
- `std/fs` operations are sandboxed and respect `AILANG_FS_SANDBOX`, which directly grounds the PR #76 scenario.
- `std/env` exposes environment variables through snapshot semantics and allowlist enforcement; DST should test child-env preparation in TypeScript and not assume all parent env vars are visible inside AILANG.
- `std/rand` provides `rand_seed(seed)` and deterministic random generation via the `Rand` effect. This can support AILANG-native seeded fuzzing where the local version supports it.
- `std/trace` exposes `spanStart`, `spanEnd`, and `event` with the `Trace` effect. `std/trace_test` exposes trace-existence assertions. This supports an optional trace-backed oracle, though the first DST trace recorder can simply emit normalized JSONL from the harness.
- `std/ai` defines the multi-turn protocol shape used by Motoko: `Message`, `ToolCall`, `ToolSchema`, `StepResult`, `AIError`, `step`, `stepWithCache`, and streaming variants. Its docs state that tool results come back as `role="tool"` messages whose `tool_call_id` matches a prior `ToolCall.id`, which grounds the tool-shape invariants.

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

AILANG fit:

- Use regular `ailang test` for pure helpers when the syntax is supported locally.
- Use existing inline `tests [(...), ...]` style where it fits the current repo's code style.
- For scenario-like pure smokes that need richer reporting, `ailang run --caps IO --entry main ...` remains reasonable.

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

AILANG fit:

- Because the docs describe effect mocking as planned rather than complete, the first implementation should use explicit dependency injection and scripted providers rather than depending on language-level effect handlers.
- Provider fakes should return `std/ai.StepResult`-shaped values and record `std/ai.Message` arrays.

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

AILANG fit:

- `std/fs` sandbox behavior and `std/env` snapshot/allowlist behavior mean this layer belongs mostly in TypeScript harness tests, with a minimal child probe if needed.
- The child probe should not assume ambient env access; the harness must explicitly forward/allow the env vars under test.

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

AILANG fit:

- Use `--ai-stub` or scripted providers for deterministic AI behavior.
- Use `--caps` narrowly and deliberately. The relevant caps for Motoko loop tests are usually some subset of `AI,FS,Process,IO,Env,Net,SharedMem,Clock,Stream,Trace`.

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

Implementation note:

- AILANG's `std/trace` can emit `Trace` events, and `std/trace_test` can assert span existence. That is useful for AILANG-native trace assertions.
- For cross-layer Motoko DST, a normalized JSONL trace is still preferable as the portable boundary format because the TypeScript harness, AILANG runtime, and subprocess probes can all emit it.

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
- uses `std/ai` protocol types where possible

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

Random generator:

- for AILANG-native fuzzing, use `std/rand.rand_seed(seed)` plus `rand_int`, `rand_bool`, and `rand_float` where supported by the local binary
- for TypeScript harness-boundary fuzzing, use a deterministic seeded RNG in TS and persist the seed in the failure trace

## DST Plus Fuzzing

It makes sense to combine DST with fuzzing in Motoko, but the fuzzing should be structured and seed-reproducible. Plain random fuzzing over full agent runs would mostly produce noisy failures and hard-to-debug traces. The better model is:

```text
Deterministic simulator + seeded scenario generator + invariant library
```

In other words, DST supplies the controlled world and the trace oracle; fuzzing supplies many variations inside that world.

### Why The Combination Fits Motoko

Motoko has many bug-prone boundaries:

- provider message protocol shape
- tool-call and tool-result correlation
- context and cost counters across steps
- extension hook ordering
- sandbox path materialization
- environment-variable forwarding
- profile mirroring
- parser handling of model-generated text
- truncation and large tool outputs

Most of these are not well tested by either hand-written examples or black-box provider runs. Seeded fuzzing inside a deterministic harness can explore the cross-product:

```text
message history shape
  x provider token counts
  x extension hook decisions
  x tool result sizes
  x env/profile path layouts
  x termination reasons
```

The key is that every generated case must still be a valid Motoko protocol scenario, or an intentionally invalid scenario with a clearly expected failure mode.

### Fuzzing Levels

#### Level A: Pure Input Fuzzing

Applies to Layer 0.

Good targets:

- command/fence parsing
- JSON-ish tool argument parsing
- token estimation
- path normalization
- config coercion

Example generators:

- malformed markdown fences
- nested code blocks
- huge strings
- unicode and zero-width characters
- incomplete JSON
- paths with symlinks, `..`, absolute paths, spaces

Oracle:

- function is total
- output shape is valid
- round-trip properties where applicable
- no unexpected panic

#### Level B: Protocol-Shape Fuzzing

Applies to Layer 1.

Good targets:

- message sequences
- tool-call arrays
- assistant/tool correlation
- provider finish reasons
- token counters
- extension decisions

Example generators:

- 0-3 system messages
- 0-20 previous tool results
- assistant messages with 0-N tool calls
- matching and mismatching `tool_call_id`s
- provider `input_tokens` around compaction thresholds
- tool outputs just below and above elision thresholds
- extension `PassThrough` vs `Compacted`

Oracle:

- system messages are not lost
- provider-call shape remains valid
- tool IDs are preserved by compaction
- actual tokens drive compaction tiers
- loop terminates within step budget
- invalid protocol inputs fail loudly or are sanitized according to policy

#### Level C: Harness Layout Fuzzing

Applies to Layer 2.

Good targets:

- `WORKDIR`
- `SYSTEM_MD`
- `MOTOKO_CONFIG`
- `MOTOKO_REPO`
- profile directories
- sandbox-readable and sandbox-unreadable paths

Example generators:

- prompt inside workspace
- prompt outside workspace
- missing prompt
- relative prompt path
- absolute profile path
- repo path equal to workdir
- repo path different from workdir
- profile already mirrored
- basename collisions for absolute profiles

Oracle:

- child env contains required config vars
- sandbox-readable files are materialized
- external files are copied with identical content
- missing required files fail loudly
- no feature silently disappears because an env var was scrubbed

#### Level D: Stateful Sequence Fuzzing

Applies to Layers 1 and 3.

Good targets:

- multi-step loops
- repeated tool failures
- compaction after long histories
- cost cap exhaustion
- retry behavior
- terminal vs non-terminal finish reasons

Example generators:

- provider script of length 1-50
- stochastic but seeded finish reasons
- high token counts followed by low token counts
- repeated tool calls with growing outputs
- extension compaction at random steps
- tool denial at random steps

Oracle:

- no infinite loop
- budget exhaustion happens before unbounded recursion
- terminal stop prevents further provider calls
- summaries/events reflect the final termination reason
- all provider calls remain protocol-valid

### Seed Discipline

Fuzzing only belongs in DST if failures are reproducible.

Every fuzz test should report:

```text
scenario_id
seed
generator version
shrunk/minimized input if available
normalized trace
first failed invariant
```

Seeded generators should be deterministic across machines as much as possible. Avoid depending on wall time, filesystem listing order, live network, provider output, or platform-specific temp path names unless those values are explicitly normalized in the trace.

AILANG-specific seed controls:

```bash
ailang_test_runs=500 ailang_test_seed=42 ailang test path/to/test.ail
```

For scenario runners invoked with `ailang run`, pass the seed explicitly through args or env:

```bash
DST_SEED=42 ailang run --caps IO,Rand --entry main scripts/smoke_dst_loop.ail
```

If using `std/rand`, call `rand_seed(seed)` at the beginning of each generated scenario so the sequence is not affected by previous tests.

### Shrinking

Shrinking is useful but not required for v1. For Motoko, the first practical shrinker can be domain-specific:

- reduce number of messages
- reduce tool-output size
- reduce provider script length
- remove extension decisions one by one
- move token counts to the nearest threshold boundary
- simplify paths from complex absolute paths to minimal inside/outside workspace examples

This will be more useful than generic byte-level shrinking because the failures are usually protocol or state-machine failures.

### What Not To Fuzz Initially

Avoid fuzzing real providers. It will be expensive and mostly unreproducible.

Avoid fully arbitrary invalid message arrays as the main workload. They can be useful negative tests, but if most generated inputs are nonsense, the harness will spend its time testing defensive checks rather than Motoko behavior.

Avoid concurrent fuzzing until the single-threaded deterministic trace is stable. Concurrency can come later for env-server and process-lifecycle bugs.

### Recommended v1 Combination

Start with fixed scenarios for known regressions, then fuzz around their parameters:

```text
Fixed scenario:
  compaction.actual_tokens_drive_next_step

Fuzz dimensions:
  number of old tool messages
  tool output sizes
  exact token count around 60/75/85%
  assistant tool_call argument sizes
  extension PassThrough vs Compacted
```

```text
Fixed scenario:
  harness.external_system_md_materialized

Fuzz dimensions:
  SYSTEM_MD inside/outside workspace
  relative vs absolute path
  missing vs present file
  nested workspace paths
  profile mirror present vs absent
```

This gives the value of fuzzing without losing the clarity of scenario-based DST.

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

AILANG property-test variant:

```bash
ailang_test_runs=500 ailang_test_seed=42 ailang test src/core/test/dst
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
- Which AILANG testing syntax is safest for this repo's pinned local version: top-level `property` tests from the latest docs, or the existing inline `tests [(...)]` style already used in `src/core/*.ail`?
- Should AILANG-native DST use `std/trace`/`std/trace_test`, normalized JSONL, or both?

## MCP Sources Consulted

Queried through the configured AILANG MCP endpoint:

- `ailang_versions`: latest available docs snapshot is `0.25.0`; `v0.24.2` was not available.
- `docs_nav`: confirmed docs include `guides/testing`, `reference/effects`, `guides/evaluation/*`, `guides/traces`, and stdlib reference pages.
- `docs_search("Testing Guide")`: returned AILANG Testing Guide with unit tests, property tests, shrinking, and env-based configuration.
- `docs_search("Effect System")`: returned effect-system docs covering explicit effects, capability grants, FS sandbox, env/process effects, and testing with effects.
- `effects_catalog`: confirmed core effect/capability mapping for `IO`, `FS`, `Net`, `AI`, `Env`, `Clock`, `Process`, and `Stream`.
- `stdlib_modules`: confirmed availability and summaries for `std/ai`, `std/fs`, `std/env`, `std/process`, `std/rand`, `std/trace`, `std/trace_test`, `std/json`, and related modules.
- `stdlib_module(std/ai)`: confirmed protocol types and `step`/`stepWithCache` shape.
- `stdlib_module(std/fs)`: confirmed `readFile`, `readFileResult`, `writeFile`, `mkdirAll`, `fileExists`, and sandbox behavior.
- `stdlib_module(std/env)`: confirmed env snapshot and allowlist semantics.
- `stdlib_module(std/rand)`: confirmed `rand_seed` and deterministic random generation functions.
- `stdlib_module(std/trace)` and `std/trace_test`: confirmed trace event/span emission and trace-existence assertions.
