# Plan: Filter Thinking Traces From Runtime Context

## Context

Motoko currently streams and renders LLM thinking traces in the TUI, but the full raw assistant response is also appended to runtime conversation history:

```ailang
let msgs1 = state2.msgs ++ [{ role: "assistant", content: response }];
let think_split = split_think_answer(response);
```

Because subsequent model calls use `fmt_msgs(state2.msgs)`, prior `<thinking>` / `<think>` content is replayed into the context window. This is uncommon for agent harnesses and can waste context, reinforce earlier mistakes, expose prompt details back to the model, and confuse parsing when reasoning contains example tags or JSON-like text.

Goal: keep thinking traces available for TUI display and logs, but store only non-thinking assistant content in conversation history.

## Desired Behavior

- Live thinking traces still stream via `thinking_delta` and render in the TUI.
- The final `thinking` event still includes:
  - `text`: full raw model response for display/debugging
  - `think`: extracted thinking text
  - `answer`: non-thinking assistant answer
- Runtime conversation history stores a sanitized assistant message, not raw thinking.
- Tool parsing and response interception still operate on the full raw response for the current step.
- Later model calls receive only the sanitized assistant content plus tool observations/user feedback.
- Context usage estimates drop because thinking traces are excluded from `state.msgs`.

## Implementation

### 1. Add testable sanitization helpers

File: `src/core/parse.ail`

Add helpers near `split_think_answer()` and export them:

```ailang
export func assistant_history_content(response: string) -> string {
  let split = split_think_answer(response);
  if split.think == "" then response
  else if trim(split.answer) == "" then "[assistant produced thinking with no answer]"
  else split.answer
}

export func assistant_visible_output(response: string) -> string {
  let split = split_think_answer(response);
  if split.think == "" then response
  else if trim(split.answer) == "" then "[assistant produced thinking with no answer]"
  else split.answer
}
```

Rationale:
- Normal history case: store `split.answer`.
- No tags detected: preserve exact current behavior.
- Thinking-only malformed response: do not replay raw thinking. Store a short placeholder in conversation history so message role order remains coherent.
- Final visible output should not show raw thinking. If there is no answer, emit the same placeholder rather than producing a silent empty successful completion.

### 2. Build both raw and sanitized assistant histories

File: `src/core/rpc.ail`

Update imports:

```ailang
import src/core/parse (
  extract_bash,
  is_done,
  parse_cwd,
  parse_tool_calls,
  split_think_answer,
  assistant_history_content,
  assistant_visible_output
)
```

In `rpc_loop`, change:

```ailang
let msgs1 = state2.msgs ++ [{ role: "assistant", content: response }];
let think_split = split_think_answer(response);
```

to:

```ailang
let think_split = split_think_answer(response);
let history_content = assistant_history_content(response);
let msgs1 = state2.msgs ++ [{ role: "assistant", content: history_content }];
```

Keep the emitted TUI event unchanged:

```ailang
kv("text",   js(response)),
kv("think",  js(think_split.think)),
kv("answer", js(think_split.answer))
```

### 3. Keep current-step parsing on raw response

Do not change the current calls:

```ailang
run_hybrid_step(state2, model2, response, msgs1, ...)
run_legacy_step(state2, model2, response, msgs1, ...)
```

Rationale:
- `run_hybrid_step()` uses `response` for `dispatch_response_intercept()` and `parse_tool_calls()`.
- `run_legacy_step()` uses `response` for `extract_bash()`.
- This preserves current-step behavior while ensuring the persisted history is sanitized.

### 4. Sanitize done output and trajectory cache

Current `done` events and trajectory cache use raw `response` in no-tool final-answer cases:

```ailang
kv("output", js(response))
put_trajectory(task_from_msgs(state.msgs), response)
```

These paths must be sanitized in the same patch. Otherwise raw thinking can still be shown to users and injected into future runs as a trajectory hint.

In both `run_legacy_step()` and `run_hybrid_step()`, update the `NoDecision` branch:

```ailang
let visible = assistant_visible_output(response);
let _ = emit(encode(jo([
  kv("type",   js("done")),
  kv("step",   jnum(_int_to_float(state.step))),
  kv("output", js(visible))])));
let _ = if trim(visible) == "" then () else put_trajectory(task_from_msgs(state.msgs), visible);
```

The skip-empty guard protects against future helper changes and prevents caching empty successful trajectories.

Do not change `Accept(output)` branches. Extension-provided `Accept` output is already a deliberate final output and may be independently sanitized by the extension if needed.

Do not change tool-result completion branches such as `is_done(result.stdout)`, because those use command/tool output rather than LLM thinking.

### 5. Add tests

Add AILANG tests:

- `split_think_answer()` already has coverage in `src/core/parse_test.ail`.
- Add wrapper tests for `assistant_history_content()` and `assistant_visible_output()` in `src/core/parse_test.ail`.

Suggested test cases:

```ailang
assistant_history_content("<thinking>x</thinking>answer") == "answer"
assistant_history_content("<think>x</think>{\"tool_calls\":[]}") == "{\"tool_calls\":[]}"
assistant_history_content("plain answer") == "plain answer"
assistant_history_content("<thinking>x</thinking>") == "[assistant produced thinking with no answer]"

assistant_visible_output("<thinking>x</thinking>answer") == "answer"
assistant_visible_output("plain answer") == "plain answer"
assistant_visible_output("<thinking>x</thinking>") == "[assistant produced thinking with no answer]"
```

### 6. Verify

Run:

```bash
ailang check src/core/rpc.ail
ailang test src/core/parse.ail
ailang test src/core/parse_test.ail
ailang test src/core/agents_md.ail
```

TUI build should still pass because event shape is unchanged:

```bash
cd src/tui
bun run build
```

Manual verification:

1. Run Motoko with a model that emits `<thinking>...</thinking>`.
2. Ask a multi-step question.
3. Confirm TUI still shows live thinking and collapsed `[think]`.
4. Ask a follow-up.
5. Confirm context counter grows less than before.
6. Compare the `ctx` estimate after a known large thinking response before and after the patch; the post-patch estimate should be materially lower.
7. Inspect the next model request input/prompt in `trace.jsonl` or runtime logs and confirm prior thinking text is absent from the request context. Raw thinking may still appear elsewhere in trace/debug events from the original response; that is acceptable.
8. Confirm final `done.output` and trajectory cache hints use the sanitized answer or placeholder, not raw thinking.

## Risks

- If a provider emits tool calls only inside thinking tags, sanitizing history removes that payload from future context. Current-step parsing remains raw, so immediate tool execution should still work, but later prompts will not contain the original raw tool intent.
- If the model emits no answer after thinking, history and final visible output store a placeholder. This avoids context leakage and makes malformed model behavior visible without silently succeeding with an empty response.
- `Accept(output)` from extensions is not sanitized by this plan. If an extension passes through raw thinking, that extension should be fixed separately.

## Acceptance Criteria

- Thinking traces are not replayed in subsequent model prompts.
- TUI thinking display behavior remains unchanged.
- Current-step tool parsing behavior remains unchanged.
- `done.output` excludes thinking traces when an answer exists.
- Thinking-only final responses produce a visible placeholder, not an empty successful response.
- Trajectory cache stores sanitized final output/hints rather than raw thinking.
- Context usage estimate decreases for thinking-heavy responses.
- Build/check/test commands above pass or have documented pre-existing failures.
