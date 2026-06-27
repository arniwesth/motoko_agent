# Deterministic Simulation Testing for Motoko Agent Loop Compaction

Date: 2026-06-27
Status: Research draft
Related: `.agent/plans/DST_v1_Motoko_Core.md`, PR #75 compaction branch

<!-- REVIEW BANNER — 2026-06-27, by Claude Opus 4.8, verified against source + AILANG MCP (v0.24.2 local / 0.25.0 docs).
Review comments are inline below, tagged 🔴 Critical / 🟡 Major / 🔵 Minor. Summary:
- 🔴 Emergency/exhaustion is gated on the chars/7 ESTIMATE, not actual tokens → Scenario 5 tests a near-dead path (see §Actual Tokens Drive Compaction, §Scenario 5).
- 🔴 Compaction output is EPHEMERAL — never persisted to history; the loop recurses on full uncompacted msgs. Scenario assertions must target the provider-call payload, not stored state (see §Scenario 1).
- 🟡 "Package resolution blocked" appears STALE — `ailang check` on stub_step passes and a full-loop stub smoke already runs (see §Current Repo Observations).
- 🟡 Two live tier tables exist (60/75/85 actual vs 70/85 estimate-fallback); doc only documents one (see §Headroom Policy).
- 🟡 Existing test infra (integration_tests.ail, ~15 smoke_v2_* scripts) not inventoried (see §Current Repo Observations).
-->

## Summary

Deterministic Simulation Testing (DST) is a strong fit for Motoko behaviors that are hard to test with ordinary unit tests and expensive or flaky to test against real providers. The current compaction branch is a good example: the correctness claim depends on a sequence of loop states, provider token telemetry, extension hooks, system-message handling, tool-call preservation, and compaction policy.

The recommended approach is to build a deterministic loop simulator around `loop_v2` with scripted providers and inspectable call records. The simulator should not try to imitate a full LLM. It should model the narrow external contracts that drive agent-loop state transitions:

- provider responses, including `input_tokens`, `output_tokens`, `finish_reason`, message content, and tool calls
- extension hook decisions, especially `on_pre_step`
- tool policy and tool handling outcomes
- generated tool results and their message shape
- emitted events, if practical
- final provider-call message arrays

For PR #75, the highest-value DST target is proving that actual provider `input_tokens` from step N drive compaction before step N+1, while system messages stay pinned outside both extension and structural compaction.

## Problem

The behavior under test is not one pure function. It is a state transition across several loop iterations.

PR #75 changes three important surfaces:

- `src/core/compaction.ail`
  - counts serialized `tool_calls` size in `estimate_tokens_messages`
  - uses `context_limit - 75000` as effective input budget
  - adds `compact_step_actual(msgs, model, actual_input)`
  - drives compaction tiers from provider-reported input tokens when available
- `src/core/agent_loop_v2.ail`
  - tracks `last_input_tokens` in `LoopTotals`
  - partitions system messages away from mutable conversation history
  - invokes extension compaction and structural compaction only on conversation messages
  - prepends system messages back before provider calls
- `.motoko/config/ollama/compaction_ai.json`
  - changes local AI compaction defaults

Ordinary tests can cover the pure compaction helpers, but they do not prove the loop-level claim:

1. Step N provider call returns an actual `input_tokens` count.
2. The loop stores that exact value.
3. Step N+1 pre-step compaction uses that value instead of a character estimate.
4. The right compaction tier fires.
5. System prompts are not exposed to compaction extensions or structural elision.
6. Provider calls still receive the system prefix.
7. Tool-call and tool-result correlation fields survive elision.

Real-provider tests can exercise this, but they are poor primary regression tests. They depend on provider availability, auth, model-specific token accounting, network behavior, model behavior, and expensive long-context prompts.

DST gives us exact, repeatable pressure on the state machine.

## Testing Model

The simulator should treat the agent loop as a deterministic state machine:

```text
State_n =
  messages
  totals
  step_idx
  provider_script
  extension_runtime
  tool_runtime

State_n --pre_step/compact/provider/tool_dispatch--> State_n+1
```

The simulator does not need realistic prose. It needs realistic protocol shape.

### Inputs Controlled by the Simulator

- initial messages, including one or more system messages
- model name, so `context_limit_for(model)` is deterministic
- scripted provider results
- scripted extension `on_pre_step` behavior
- scripted tool handling behavior
- step budget
- cost rates and cost cap

### Outputs Captured by the Simulator

- every provider-call message list
- every extension `on_pre_step` input message list
- compaction events, if observable
- final messages
- final `LoopTotals`
- termination status

The most important missing capability in the current stub path is provider-call inspection. `src/core/test/stub_step.ail` can script returned `StepResult`s, but `dispatch_step` does not currently record the `msgs` passed into the provider. DST for compaction should add an inspectable provider seam or a test-only recorder.

## Core Invariants

These invariants should be checked over deterministic scenarios and later over seeded generated scenarios.

### System Message Pinning

System messages are constants, not mutable conversation history.

Invariants:

- `on_pre_step` receives no message with `role == "system"`.
- structural compaction receives no message with `role == "system"`.
- every provider call receives the original system prefix before conversation messages.
- provider-call system-message order is stable.
- system-message content is byte-identical to the initial system content.

This directly targets `partition_system_msgs` and the re-prepend at the provider call.

### Actual Tokens Drive Compaction

When `last_input_tokens > 0`, compaction tier selection should be driven by that value, not by local estimate.

For `ollama/qwen3...`, `context_limit_for` returns `262144`; with 75k output headroom, effective input budget is:

```text
262144 - 75000 = 187144
```

Approximate actual-token thresholds:

```text
60% = 112286
75% = 140358
85% = 159072
```

Invariants:

- `actual_input <= 0` falls back to estimate-based `compact_step`.
- `actual_input < 60% effective` does not elide old tool results.
- `actual_input >= 60% effective` keeps the last 10 tool results.
- `actual_input >= 75% effective` keeps the last 5 tool results.
- `actual_input >= 85% effective` enters emergency compaction.

<!-- 🔴 REVIEW (Critical) — actual/estimate MIXING inside the emergency branch.
`compact_step_actual` ENTERS emergency at actual pct>=85 (compaction.ail:164), but
`try_emergency_compaction` then decides success/failure via `usage_percent` — the
chars/7 ESTIMATE (compaction.ail:123-138), which is deliberately built to under-count.
So the >=95% exhaustion gate is on a metric engineered to stay low: emergency will
almost always return Ok(keep-3) and `ContextExhausted` is nearly unreachable through
the actual-token path. The invariant list should add: "emergency exhaustion is gated on
the ESTIMATE, not actual_input" and test that explicitly. This actual-vs-estimate split
is exactly the bug class DST should catch — it must be named, not glossed. -->

The critical DST scenario is a message list whose estimated size is small but whose previous `input_tokens` is above threshold. That proves the actual-token path is load-bearing.

### Tool Shape Preservation

Compaction may shorten old tool-result content, but it must not corrupt protocol correlation.

Invariants:

- list length is preserved by structural elision
- message order is preserved
- each tool message keeps its `tool_call_id`
- assistant `tool_calls` keep `id`, `name`, and `arguments`
- non-tool messages are not elided by `elide_old_tool_results`
- recent tool-result content is preserved according to the tier

### Headroom Policy

Usage percentage should be calculated against effective input budget, not the full provider context window.

Invariants:

- unknown model returns 0% usage
- models with `context_limit <= 75000` return 0% usage
- known large-context models calculate usage against `limit - 75000`
- `tool_calls.arguments` contributes to token estimate even when message `content` is small

<!-- 🟡 REVIEW (Major) — there are TWO live tier tables; this doc documents only one.
  • compact_step_actual (actual-token path):   60% keep-10, 75% keep-5, 85% emergency  (compaction.ail:159-167)
  • compact_step      (estimate/step-0 path):   70% keep-10, 85% keep-5, 95% emergency  (compaction.ail:144-150)
The DST suite must pin BOTH, since the estimate path is what runs at step 0 / whenever
last_input_tokens==0. The "Actual Tokens Drive Compaction" section silently assumes only the
first table exists. -->


## Scenario Tests for PR #75

### Scenario 1: Carry Forward Actual Tokens

Purpose: prove step N token telemetry controls step N+1 compaction.

Initial state:

```text
messages:
  system: "AILANG reference"
  user: "task"
  old tool results: 12 long tool messages

provider script:
  step 1: finish_reason = "tool_calls", input_tokens = 140359
  step 2: finish_reason = "stop", input_tokens = 100
```

Expected:

- step 1 provider call has no actual-token compaction yet if `last_input_tokens == 0`
- loop stores `last_input_tokens = 140359`
- before step 2 provider call, `compact_step_actual` uses the 75% tier
- first 7 of 12 old tool messages are elided, last 5 are preserved
- system message still appears at the beginning of step 2 provider call

<!-- 🔴 REVIEW (Critical) — compaction output is EPHEMERAL; assert on the provider-call payload, not stored state.
agent_loop_v2.ail sends `compacted_msgs = sys_prefix ++ conv_compacted` to the provider (line 1141)
but recurses on `msgs ++ [assistant_msg]` — the FULL, uncompacted history (line 1192). So:
  • "first 7 elided, last 5 preserved" is true ONLY in the step-2 provider call, NEVER in returned/persisted msgs.
    Any test asserting on run_v2_with_stub's returned message list will fail. The recorder must capture the
    provider-call payload (this reinforces the doc's call for a provider-call seam — but the prose conflates
    "sent" with "stored").
  • Subtle: last_input_tokens=140359 is the provider's count of the COMPACTED payload sent at step 1, yet at
    step 2 that count selects a tier applied to the LARGER full history. Pressure is measured on the trimmed
    list but elision runs on the untrimmed one (under-pressures). Add this as an explicit invariant to test.

🟡 REVIEW (Major) — "no actual-token compaction yet" at step 1 is misleading.
With last_input_tokens==0, compact_step_actual falls back to the ESTIMATE path compact_step (compaction.ail:160),
which fires at estimate>=70%. With 12 *long* tool messages the chars/7 estimate may already elide at step 1.
Reword to "no actual-token-DRIVEN compaction; estimate-fallback (compact_step, 70/85 tiers) may still fire." -->


### Scenario 2: Actual Tokens Beat Estimate

Purpose: catch regressions where code accidentally returns to `usage_percent(msgs, model)`.

Initial state:

```text
messages:
  system: "stable system"
  user: "small"
  12 tool messages with short content

totals.last_input_tokens:
  140359
```

Expected:

- compaction fires even though local estimate is below threshold
- provider sees tier-2 compacted conversation

This requires either direct test access to `compact_step_actual` or a one-step loop harness that can seed `LoopTotals`.

### Scenario 3: System Hidden From Malicious Extension

Purpose: prove extension compaction cannot drop or rewrite system instructions.

Fake extension:

```text
on_pre_step(msgs):
  assert no system messages are present
  return Compacted([], "drop everything")
```

Expected:

- extension input has no system messages
- provider still receives original system messages
- provider receives no conversation messages except any later loop-added ones

This tests the stronger property: even an aggressive compaction extension cannot remove the system prefix.

### Scenario 4: Tool Call Arguments Counted

Purpose: cover the original undercount class for write/edit operations.

Messages:

```text
assistant:
  content = ""
  tool_calls = [
    {
      name = "WriteFile",
      arguments = huge JSON payload
    }
  ]
```

Expected:

- `estimate_tokens_messages` increases according to `name + arguments`
- a content-only estimator would remain near zero; the new estimator does not

This can remain a pure helper test, but it belongs in the same DST suite as a regression guard.

### Scenario 5: Emergency Refusal

Purpose: verify the loop terminates with `ContextExhausted` only when emergency elision cannot recover.

Initial state:

```text
actual_input >= 85% effective
messages include large non-tool content that cannot be elided
```

<!-- 🔴 REVIEW (Critical) — this scenario likely tests an unreachable path as written.
The ">=95% after elision" check uses usage_percent (chars/7 ESTIMATE), not actual_input
(see compaction.ail:123-138, 164). Because the estimate is engineered to under-count, a
realistic message set that is at 85%+ of ACTUAL tokens will usually estimate well under 95%,
so try_emergency_compaction returns Ok and ContextExhausted never fires. To actually reach
the Err branch the fixture must contain large NON-tool content (system/user/assistant prose)
whose chars/7 estimate alone exceeds 95% of effective — tool elision can't help there. Either
rewrite the fixture to force that, or change the production code to gate emergency on actual
tokens too. Flag which behavior is intended before writing the test. -->

Expected:

- emergency compaction tries keep-last-3 and keep-last-1
- if usage remains >=95% after elision (measured by the chars/7 ESTIMATE, not actual_input), loop returns `ContextExhausted`
- run summary reason includes `compaction_exhausted`

## Follow-up PR #76: Harness Prompt Materialization

PR #76 fixed a related but different failure mode: `SYSTEM_MD` could point outside the task workspace, while the AILANG runtime was FS-sandboxed to `WORKDIR` through `AILANG_FS_SANDBOX`. In that case `rpc.ail` could preserve and pin the system message correctly, but the prompt content was empty from the start because the runtime could not read the external file. The observed symptom was `system_prompt_built` reporting `chars=0`.

This bug is catchable by DST, but not by a `loop_v2`-only simulator. It lives one boundary earlier: the TypeScript harness must materialize runtime inputs into the sandbox before spawning AILANG.

The useful abstraction is "sandbox materialization DST":

```text
Parent process state:
  WORKDIR = /tmp/workspace-A
  SYSTEM_MD = /tmp/external/system.md
  AILANG_FS_SANDBOX = /tmp/workspace-A

Harness transition:
  materialize readable runtime inputs into WORKDIR
  rewrite env vars to sandbox-readable paths
  spawn child process

Child observable:
  SYSTEM_MD points inside WORKDIR
  file exists
  file content equals original external prompt
  system_prompt_built chars > 0
```

### Scenario 6: External SYSTEM_MD Is Materialized

Purpose: catch the PR #76 bug class.

Simulator setup:

```text
workspace:
  /tmp/motoko-dst/workdir/

external prompt:
  /tmp/motoko-dst/prompts/SYSTEM.md
  content = "AILANG reference sentinel: dst-system-prompt"

env:
  WORKDIR=/tmp/motoko-dst/workdir
  SYSTEM_MD=/tmp/motoko-dst/prompts/SYSTEM.md
```

Expected after harness preparation:

- `process.env.SYSTEM_MD` is rewritten to a path under `WORKDIR`
- rewritten file exists
- rewritten file content exactly equals the external prompt
- child env includes `AILANG_FS_SANDBOX=WORKDIR`
- a sandboxed child read of `SYSTEM_MD` succeeds

This can be tested without a real model. A minimal child process can read `SYSTEM_MD` under the same environment contract and print `{system_md, chars, sentinel_found}`.

### Scenario 7: Workspace-local SYSTEM_MD Is Not Rewritten

Purpose: avoid over-materializing normal local paths.

Setup:

```text
WORKDIR=/tmp/motoko-dst/workdir
SYSTEM_MD=/tmp/motoko-dst/workdir/SYSTEM.md
```

Expected:

- `SYSTEM_MD` remains the original path or an equivalent path under `WORKDIR`
- content is unchanged
- child read succeeds

### Scenario 8: Missing External SYSTEM_MD Fails Loudly

Purpose: avoid returning to a silent empty prompt.

Setup:

```text
WORKDIR=/tmp/motoko-dst/workdir
SYSTEM_MD=/tmp/motoko-dst/missing/SYSTEM.md
```

Expected:

- harness emits a warning or the child emits `system_prompt_built chars=0`
- DST marks this as a failure unless the test explicitly expects a missing-prompt case

The invariant should be phrased positively for production profiles: if `SYSTEM_MD` is non-empty and intended to be read, the runtime must observe non-empty prompt content.

### Where This Fits

PR #75 DST is loop-state DST. PR #76 needs harness-boundary DST. They are related because both protect the same semantic invariant:

```text
Every provider call that requires the AILANG reference must receive a non-empty, stable system prompt.
```

The end-to-end invariant spans two layers:

1. TypeScript harness materializes and forwards a sandbox-readable prompt path.
2. AILANG runtime reads the prompt, builds the system message, and pins it outside compaction.

Testing only layer 2 would not catch PR #76. Testing only layer 1 would not catch PR #75. The DST suite should include both.

## Architecture Options

### Option A: Extend Existing Stub Provider

Current file: `src/core/test/stub_step.ail`

It already provides:

- `ScriptedStep`
- `StepProvider = LiveAI | Scripted([ScriptedStep])`
- `dispatch_step`
- `run_v2_with_stub` integration path through `agent_loop_v2`

Needed addition:

- record the `msgs` passed into each scripted provider call
- expose those recorded calls to tests

Possible implementation directions:

- add a `RecordingScripted` provider variant with an explicit call log carried in the provider state
- return `{ result, next_provider, observed_msgs }` from a test-only dispatch function
- introduce a pure `pre_provider_messages_for_step` helper that runs DP0a/DP0b compaction and returns the message list that would be sent to the provider

Pros:

- smallest conceptual change
- tests the real loop path
- reuses existing scripted `StepResult` constructors

Cons:

- AILANG effects and recursive provider state may make call-log threading awkward
- current package-resolution issues around `pkg/...` imports can block loop-level tests until fixed

### Option B: Extract Pre-Step Compaction Pipeline

Create a pure or mostly pure helper in `agent_loop_v2.ail`:

```ailang
prepare_provider_messages(
  rt,
  ctx,
  msgs,
  model,
  last_input_tokens
) -> Result[[Message], string]
```

The helper would:

1. partition system messages
2. call extension `on_pre_step`
3. call `compact_step_actual`
4. re-prepend system messages

Pros:

- directly testable
- narrower than full loop
- captures the critical PR #75 behavior

Cons:

- not fully pure if extension hooks have effects
- production refactor required
- still needs a fake extension runtime

### Option C: Pure Compaction State Machine Mirror

Build a test-only pure model of the pre-step compaction pipeline and compare production helper outputs against it.

Pros:

- easy to generate many seeded cases
- no provider or extension effects

Cons:

- risks testing the mirror instead of production behavior
- less valuable unless paired with Option A or B

Recommendation: start with Option B if a clean helper extraction is possible; otherwise start with Option A and add provider-call recording.

## Seeded Simulation After Scenario Tests

After the fixed scenarios pass, add seeded generation. The generator should produce bounded message histories with controlled structure:

- 0-3 system messages
- 1-20 user messages
- 0-20 assistant messages
- 0-20 tool messages
- optional assistant tool calls with small, medium, or huge `arguments`
- tool outputs with small, elidable, and non-elidable sizes
- `actual_input` values around thresholds: `threshold - 1`, `threshold`, `threshold + 1`

Generated invariants should avoid asserting exact final prose. They should assert structural facts:

- no system message is lost
- system prefix remains byte-identical
- no `tool_call_id` is lost
- elision never increases list length
- recent tool messages remain unelided
- unknown models fail open
- repeated run with same seed returns identical call log

The seed must be printed on failure and accepted as a rerun input.

## CI Strategy

Suggested targets:

```make
test_dst_compaction:
	ailang run --caps IO --entry main scripts/smoke_v2_compaction_actual_dst.ail

test_dst: test_dst_compaction
```

Merge gate phases:

1. Pure helper checks only
2. Scenario DST with scripted provider
3. Seeded DST with 100 seeds
4. Seeded DST with 500 seeds once runtime is stable

Real-provider OpenRouter or Ollama tests should remain optional smoke tests, not the primary gate.

## Current Repo Observations

- `src/core/test/stub_step.ail` already has most of the scripted provider machinery.
- `scripts/smoke_v2_compaction_tiers.ail` encodes old threshold assumptions and currently needs revision for the new headroom and actual-token policy.
- Loop-level checks are currently blocked in this checkout by AILANG package-resolution errors for `pkg/sunholo/motoko_ext_abi/types`, despite `ailang.toml` and `ailang.lock` being present. DST work that depends on full `loop_v2` execution should first resolve that package-root/import issue.
- A narrow pure smoke can still be written immediately for `compact_step_actual`, `estimate_tokens_messages`, and tool-shape preservation.

<!-- 🟡 REVIEW (Major) — this section's "current state" is incomplete and partly STALE. Verified 2026-06-27:
  • STALE: `ailang check src/core/test/stub_step.ail` → "✓ No errors found!", and
    `scripts/smoke_v2_compaction_full_loop.ail` / `smoke_v2_cost_budget_full_loop.ail` already call
    `run_v2_with_stub` (agent_loop_v2.ail:1639) and run. The "package resolution blocked" blocker — the
    main argument for deferring Layer-1 DST — could not be reproduced. RE-VERIFY before relying on it.
  • MISSING infra that already exists and overlaps the proposal:
      - src/core/test/integration_tests.ail  (already documents run_v2_with_stub invariants)
      - ~15 scripts/smoke_v2_*.ail, incl. smoke_v2_compaction_full_loop.ail, smoke_compaction_tool_call_id.ail
      - stub_step.ail already exposes token_step / continuing_token_step (scripted input_tokens) —
        so only PROVIDER-CALL MESSAGE RECORDING is the genuine gap, not token scripting.
  Inventory these before adding scripts/smoke_v2_compaction_actual_dst.ail to avoid duplication. -->


## Proposed First Implementation Slice

Create `scripts/smoke_v2_compaction_actual_dst.ail` with pure deterministic checks:

1. `actual_tokens_low_no_elision`
2. `actual_tokens_60pct_keep_last_10`
3. `actual_tokens_75pct_keep_last_5`
4. `actual_tokens_85pct_emergency`
5. `tool_call_arguments_counted`
6. `tool_shape_preserved_by_elision`

Then add the loop-level DST once provider-call recording is available:

1. `last_input_tokens_carries_forward`
2. `system_hidden_from_extension`
3. `provider_receives_system_prefix_after_compaction`

This sequence gives immediate regression value without waiting for the deeper harness refactor.

## Open Questions

- Should `partition_system_msgs` be exported or kept private and tested only through a pre-step helper?
- Should compaction policy thresholds be constants exported from `compaction.ail` to avoid tests duplicating magic numbers?
- Should the 75k output headroom be model-specific rather than global?
- Can AILANG tests carry an inspectable provider call log without `SharedMem`, or is explicit state threading better?
- Should extension compaction be allowed to summarize assistant messages with tool calls, or should those be protected like system messages?
- What is the smallest loop-level seam that lets tests inspect provider inputs without weakening production encapsulation?
