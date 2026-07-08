# PLAN: Runtime Status Tool for Live Step/Compaction Introspection

Date: 2026-07-08
Status: Draft implementation plan
Audience: implementation agent working in `/workspaces/motoko_agent`

## Problem

In the live Qwen compaction calibration run, Motoko executed 78 provider calls and recorded the exact
count in JSONL:

- `provider_call_prepared.step` appeared for each provider call.
- `run_summary.steps_executed` reported `78`.
- compaction began at step `41`.
- `system_prefix_digest` remained stable after compaction.

However, when the user asked the model "Do you know how many steps were run?", Qwen did not answer
with the actual step number. The runtime knew the answer, but that control-plane state was only
available in logs and not exposed to the model during the session.

## Goal

Add a model-callable runtime status tool so the assistant can answer questions about exact runtime
state during a session, especially:

- current provider step / steps executed so far
- configured step budget
- compaction counts
- system-prefix digest, count, and character length
- cumulative token/cost totals already tracked by the v2 loop

The tool must not destabilize the system prompt digest and must not require reading JSONL logs from
inside the model path.

## Non-Goals

- Do not make live OpenRouter/Qwen calls part of `make compaction_dst`.
- Do not mutate or append per-step runtime status into the system prompt.
- Do not rely on the model's memory or summarized conversation state for exact counters.
- Do not expose full provider payloads or message contents through the status tool.
- Do not replace JSONL logging or `run_summary`; the tool is a live introspection surface, not the
  durable audit log.

## Plan-Level Decisions

### D1. Implement as a native runtime tool

Add a native tool named `MotokoRuntimeStatus`.

This should be advertised in `src/core/tool_catalog.ail` alongside existing native tools, with a
small schema accepting an optional `include` array or no arguments. The first implementation can
ignore arguments and return the stable status object.

### D2. Handle inside the v2 session/tool loop, not as an extension

The extension `on_tool_handle` path receives `ExtCtx`, but `ExtCtx` currently does not carry
everything needed for exact answers, especially:

- cumulative runtime totals from `C2LoopState.totals`
- active `step_budget`
- in-memory trace-derived compaction counts
- current system-prefix digest computed from the pinned prefix

Handling the tool in or just below `src/core/session.ail` keeps the implementation close to
`C2LoopState`, where the authoritative state already exists.

Preferred shape:

- Add a `RuntimeStatusSnapshot` record type in `src/core/session.ail` or a small new helper module.
- Build the snapshot in the `RunTools(plan)` arm before dispatching tool entries.
- Teach the tool-dispatch path to intercept `MotokoRuntimeStatus` and return a tool message directly.

Avoid threading hidden mutable state through `Ported(Ports)`.

### D3. Keep system-prefix digest stable

Do not inject per-step status into the system prompt or pinned prefix.

The status JSON may include:

- `system_prefix_digest`
- `system_prefix_count`
- `system_prefix_chars`

These values should be computed with the same functions already used by `ProviderCallPrepared`.

### D4. Count compaction from in-memory stage records

For consistency with ADR-004, count compaction from in-memory trace/state, not from wire log text.

The runtime status should distinguish at least:

- `compaction_ai_applied`
- `compaction_stage_applied_total`
- `compaction_stage_rejected_total`

The exact field names can be simpler if the first implementation only needs total applied/rejected,
but tests should cover the `compaction_ai` case because it is the live calibration target.

### D5. Tool answer is exact at the moment it is called

If the model calls `MotokoRuntimeStatus` during tool execution for provider step `N`, the tool should
return an unambiguous convention:

- `current_step`: `N`
- `provider_calls_started`: number of provider calls prepared so far
- `steps_executed_so_far`: provider calls completed before the current tool batch, or the same as
  `provider_calls_started` if that is easier to explain and test

Pick one convention and document it in the tool description and tests. Prefer including both
`current_step` and `provider_calls_started` to avoid off-by-one ambiguity.

## Proposed Tool Result Shape

Return a JSON object in the tool-role message content:

```json
{
  "tool": "MotokoRuntimeStatus",
  "current_step": 77,
  "provider_calls_started": 78,
  "step_budget": 100,
  "finish_reason_so_far": "tool_calls",
  "compaction": {
    "stage_applied_total": 69,
    "stage_rejected_total": 0,
    "compaction_ai_applied": 69
  },
  "system_prefix": {
    "count": 1,
    "chars": 16229,
    "digest": "sha256:eb0c8862e9aa17c4eac194cd0add8de352a1766bf645fbbe737479bf438fcec3"
  },
  "usage": {
    "input_tokens": 6717677,
    "output_tokens": 29853,
    "cache_read_input_tokens": 0,
    "cache_creation_input_tokens": 0,
    "total_cost_millicents": 0
  }
}
```

The live values above are examples from `session_2026-07-08T18-14-15-761Z.jsonl`, not hard-coded
expectations.

## Work Items

### WI-0: Re-ground current tool and session contracts

Read these anchors before editing:

- `src/core/session.ail`
  - `C2LoopState`
  - `RunTools(plan)` arm
  - `CallModel(_)` arm
  - `ProviderCallPrepared` emission
  - `emit_run_summary`
- `src/core/tool_phase.ail`
  - `dispatch_tool_entries`
  - `execute_allowed_tool_call`
- `src/core/tool_catalog.ail`
  - `tools()`
  - `tools_with_extensions`
- `src/core/phase_vocab.ail`
  - `CompactionStageRecord`
  - `TraceStageApplied`
  - `TraceStageRejected`
  - `ProviderCallPrepared`
  - `system_prefix_digest_for`
- `scripts/long_qwen_compaction_dst.ail`
  - deterministic trace projection
  - compaction counting helpers

Expected current facts:

- `C2LoopState.step_idx` is authoritative loop state.
- `RunSummary.steps_executed` receives `step_idx`.
- `ProviderCallPrepared.step` is emitted before provider dispatch.
- Native tools are advertised by `src/core/tool_catalog.ail`.
- Extension tool handling does not currently have enough state for exact runtime status.

Stop and amend this plan if any of those contracts have drifted.

### WI-1: Add the native tool schema

Edit `src/core/tool_catalog.ail`:

- Add `motoko_runtime_status_schema()`.
- Add it to `tools()`.
- Update `test_base_tools_count`.
- Add a focused test asserting:
  - the tool name is `MotokoRuntimeStatus`
  - the schema has no required fields
  - the description tells the model to call it for step count/runtime status questions

Suggested description:

> Get exact Motoko runtime status for the current session, including current step, step budget,
> compaction counts, system-prefix digest, and cumulative usage. Use this when asked about how many
> steps have run, whether compaction happened, or whether the system prefix stayed stable.

Keep the schema read-only and argument-light:

```json
{"type":"object","properties":{},"required":[]}
```

### WI-2: Add status snapshot helpers

Add a small pure helper surface near `C2LoopState` in `src/core/session.ail`, or in a new module if
that keeps tests cleaner.

Minimum helper responsibilities:

- Build JSON for `MotokoRuntimeStatus`.
- Count applied/rejected compaction records from `C2LoopState.trace`.
- Count `compaction_ai` applied records separately.
- Include cumulative totals from `RuntimeLoopTotals`.
- Include:
  - `current_step`
  - `provider_calls_started`
  - `step_budget`
  - `last_finish_reason`
  - `system_prefix` status

Important implementation detail:

- In the `RunTools(plan)` arm, `tool_step_idx = c2_done_step(st.step_idx)` is the completed provider
  step that produced tool calls.
- Use a documented convention:
  - `current_step = tool_step_idx`
  - `provider_calls_started = tool_step_idx + 1`
  - `steps_executed_so_far = tool_step_idx + 1`

If this convention is wrong after source re-grounding, update both the implementation and tool
description together.

### WI-3: Intercept `MotokoRuntimeStatus` before generic tool dispatch

Preferred implementation:

- In the `RunTools(plan)` arm, split `plan.entries` into runtime-status calls and all other calls.
- For each runtime-status call, append a direct tool-role message with the JSON status payload and
  matching `tool_call_id`.
- Continue dispatching any remaining calls through `dispatch_tool_entries`.

This keeps the special tool close to the `C2LoopState` snapshot and avoids expanding every extension
or native dispatch function with runtime-state parameters.

Acceptance details:

- Preserve ordering of tool results relative to tool calls.
- Preserve `tool_call_id`.
- Emit a normal handled-tool style ledger event if an existing event fits, or add a small event only
  if needed for tests/debugging.
- Do not require approval for this tool.
- Do not call `BashExec`, filesystem, network, or logs.

If preserving mixed-call ordering becomes awkward in `RunTools(plan)`, add a small helper that walks
entries left-to-right and delegates non-status runs in batches. Do not reorder model tool results.

### WI-4: Teach the model to use the tool without per-step prompt mutation

The tool schema description should carry most of the routing instruction.

If additional instruction is necessary, add a stable one-time system prompt line in the existing
base prompt/config path, not a changing runtime line:

> When the user asks about exact runtime state such as step count, compaction count, budget, or
> system-prefix hash, call `MotokoRuntimeStatus`.

Before adding prompt text, inspect where the base prompt is assembled and prefer the narrowest stable
location. Re-run the system-prefix digest live observability checks if prompt text changes because it
will intentionally change the baseline digest for future sessions.

### WI-5: Deterministic tests

Add focused offline tests. Suggested coverage:

1. `src/core/tool_catalog.ail`
   - updated native tool count
   - `MotokoRuntimeStatus` schema present

2. A small scripted v2 scenario, either new script or added to an existing smoke:
   - scripted provider first returns a `MotokoRuntimeStatus` tool call
   - runtime returns a tool result with:
     - `current_step`
     - `provider_calls_started`
     - `step_budget`
     - valid `system_prefix.digest`
   - scripted provider then answers using the tool result

3. A compaction-aware deterministic scenario, preferably extending
   `scripts/long_qwen_compaction_dst.ail`:
   - after at least one `compaction_ai` application, scripted provider calls `MotokoRuntimeStatus`
   - assert the returned JSON has `compaction.compaction_ai_applied >= 1`
   - assert `compaction.stage_rejected_total == 0`
   - assert `system_prefix.digest` matches the provider-call prepared digest projection

Do not use OpenRouter or live Qwen in deterministic tests.

### WI-6: Make/CI wiring

Keep `make compaction_dst` deterministic/offline.

If the runtime-status scenario is added to `scripts/long_qwen_compaction_dst.ail`, it can ride the
existing target. Otherwise wire a new deterministic script into `make compaction_dst` only if it does
not require live credentials or network.

Expected fast-gate commands:

```bash
ailang check src/core/tool_catalog.ail
ailang test src/core/tool_catalog.ail
ailang check src/core/session.ail
MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
  ailang check scripts/long_qwen_compaction_dst.ail
make compaction_dst
```

### WI-7: Optional live calibration check

After deterministic tests pass, optionally run manual live calibration:

```bash
make live_qwen36_compaction_calibration
```

Then ask the model during the run:

```text
Do you know how many steps have run? Use exact runtime status if available.
```

Expected behavior:

- model calls `MotokoRuntimeStatus`
- final answer reports exact step count
- JSONL still has stable `system_prefix_digest`
- no fast-gate target depends on the live call

## Acceptance Checklist

- `MotokoRuntimeStatus` is advertised as a native tool.
- The tool returns exact runtime state from `C2LoopState`, not from model memory.
- The tool result preserves `tool_call_id`.
- Tool handling does not mutate the system prompt or pinned prefix.
- The returned `system_prefix.digest` matches `ProviderCallPrepared.system_prefix_digest`.
- Deterministic tests prove the model can call the tool and receive exact step count.
- A compaction-aware deterministic test proves compaction counts are available after compaction.
- `make compaction_dst` remains deterministic/offline and green.
- Live calibration remains optional/manual.

## Risks and Review Traps

- Off-by-one step semantics: document and test the convention.
- Mixed tool-call ordering: do not reorder runtime-status results relative to other tool calls.
- Prompt digest churn: avoid per-step prompt mutation.
- Trace source of truth: count in-memory stage records, not JSONL text.
- Overexposure: return counters and digests, not full prompt/payload contents.
- Extension temptation: current extension hooks do not have enough state; do not force this into
  `ExtCtx` unless a broader runtime-state ABI change is intentionally planned.

