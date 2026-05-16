# Reasoning models exhaust output budget on thinking tokens

**Date**: 2026-05-16
**Status**: POC workaround implemented (local); upstream fix needed
**Affected models**: tencent/hy3-preview (and likely any reasoning model not in AILANG's models.yml)

## Symptom

When running Motoko against `openrouter/tencent/hy3-preview`, the agent loop stalls at step 0 indefinitely. The TUI shows "Runtime is reasoning..." but never progresses. User-sent "continue" messages spawn new sessions that also stall.

## Root cause

Two compounding issues:

### 1. AILANG hardcodes max_tokens: 4096 for unknown models

The AILANG runtime's AI handler defaults to `max_tokens: 4096` when a model is not found in the embedded `models.yml` (`internal/ai/handler.go:95`). Reasoning models like `tencent/hy3-preview` use output tokens for chain-of-thought thinking. With only 4096 tokens available, the model spends them ALL on reasoning and never produces content or tool calls.

Evidence from session logs:
```
finish_reason: "length"
output_tokens: 4096
tool_calls: 0
content: ""
```

Path through AILANG:
1. `setupAIHandler("openrouter/tencent/hy3-preview")` called
2. Model not in embedded `models.yml` → falls to `setupAIHandlerDirect`
3. `GuessProvider` → ProviderOpenRouter (correct)
4. Handler created with NO `WithMaxTokens()` → defaults to 4096
5. All output tokens consumed by reasoning → `finish_reason: "length"`

### 2. Motoko treats finish_reason="length" as terminal

At `agent_loop_v2.ail:994` (pre-fix), the condition `if result.finish_reason != "tool_calls"` catches "length" alongside "stop", causing the loop to terminate at step 0 with no output.

### 3. Model uses text-format tool calls instead of API tool_calls

Even after solving issues 1 & 2, `tencent/hy3-preview` emits tool calls in free-text XML rather than the structured API mechanism:
```
<tool_call>BashExec<tool_sep>
<arg_key>cmd</arg_key>
<arg_value>ailang prompt</arg_value>
</tool_call>
```

This produces `tool_calls: 0` in the API response, so Motoko's standard dispatch path never fires.

## Local workaround (POC)

Two changes in `src/core/agent_loop_v2.ail`:

### A. Length-limit retry

When `finish_reason == "length"` AND `tool_calls == 0` AND `content == ""`:
- Emit `length_retry` telemetry event
- Append the empty assistant message + a user continuation prompt instructing the model to be concise
- Recurse (consuming one step from the budget)

The step budget naturally caps retry attempts.

### B. Text-format tool call extraction

New functions:
- `extract_text_tool_call(text) -> Option[ToolCall]` — parses `<tool_call>...<tool_sep>...<arg_key>...<arg_value>...</tool_call>` XML
- `extract_arg_pairs(text, acc)` — recursively extracts key-value pairs into JSON
- `find_from(hay, needle, offset)` — substring search with offset

Wired into the dispatch path after hybrid bash extraction fails, before solver_candidate. Dispatches extracted calls through the same M3-M6 pipeline.

## Upstream fix needed (AILANG)

The local workaround is fragile. The real fix requires AILANG changes:

| Fix | Impact |
|-----|--------|
| Add `--max-tokens <N>` CLI flag to `ailang run` | Motoko can pass model-appropriate limits |
| Add model to embedded `models.yml` with `max_output_tokens: 16384+` | Per-model config |
| Raise default from 4096 to 16384 for OpenRouter models | Broader fix |
| Wire Motoko's `ai_options_json` config field through to handler setup | Project-level override |

## Validation

Session `session_2026-05-16T11-38-35-108Z.jsonl` confirms the POC works:
- Step 0: `finish_reason: "length"` → `length_retry` fires → continuation sent
- Step 1: Model responds within budget (3223 tokens), emits `<tool_call>` in prose → `text_tool_extracted` would dispatch it (done event fired before extraction was wired — this was the second POC)
