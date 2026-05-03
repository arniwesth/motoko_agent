# Plan: Runtime Continuation Intent Guard

## Context

Motoko currently treats an assistant response with no parseable tool call or
command as terminal:

- Legacy mode: `extract_bash(response) == None` plus extension `NoDecision`
  emits `done`.
- Hybrid mode: `parse_tool_calls(response) == NoToolCalls` plus extension
  `NoDecision` emits `done`.

This is correct for genuine final answers, but it fails when the model says it
intends to continue, e.g. "I will now use `Search`..." or "I will issue the
next tool call in a separate turn." The model believes it can produce another
assistant-only turn later, while Motoko interprets the prose-only response as
completion.

`SYSTEM.md` now clarifies that prose-only responses are stop signals, but this
should also be enforced by the runtime. Prompt-only fixes are not reliable
enough for protocol mistakes.

## Goal

Before emitting `done` for a no-tool/no-command assistant response, detect
obvious continuation intent. If detected, inject corrective feedback into the
conversation and continue the runtime loop instead of stopping.

The feedback should tell the model:

- It said it intends to continue.
- In Motoko, prose-only responses end the run.
- It must either emit the next JSON `tool_calls` block now, or provide a final
  answer if the task is actually complete.

## Desired Behavior

- Genuine final prose answers still emit `done`.
- Prose that promises future tool use does not emit `done`.
- The next model call receives corrective feedback and can emit the missing tool
  call.
- Current-step parsing stays unchanged: valid tool calls and bash commands are
  still executed normally.
- The guard applies to both hybrid and legacy no-tool completion paths.
- The guard uses sanitized visible assistant output, not raw thinking traces.

## Implementation

### 1. Add continuation-intent helpers

File: `src/core/parse.ail`

Add exported pure helpers near the response sanitization helpers:

```ailang
export func indicates_continuation_intent(text: string) -> bool
```

Recommended approach:

- Lowercase and trim the sanitized visible output.
- Match conservative phrases that strongly indicate future tool use or runtime
  action, not generic future work.
- Avoid broad matches like `will`, `next step`, or `we now transition` alone.
- Prefer exact anti-patterns from observed logs: "tool call in a separate turn",
  "I will now use `Search`", "I will search the repository", etc.

Suggested phrase checks:

```ailang
contains(t, "i will issue the next tool call")
contains(t, "tool call in a separate")
contains(t, "next tool call")
contains(t, "json tool_calls block")
contains(t, "in a separate json turn")
contains(t, "in a dedicated json turn")
contains(t, "separate, compliant json turn")
contains(t, "dedicated json turn")
```

Include task-oriented variants seen in logs:

```ailang
contains(t, "i will now use `search`")
contains(t, "i will now use search")
contains(t, "i will use `search`")
contains(t, "i will use search")
contains(t, "i will now search")
contains(t, "i will search")
contains(t, "proceeding to search the repository")
contains(t, "proceeding to search the codebase")
contains(t, "i will now inspect the repository")
contains(t, "i will inspect the repository")
contains(t, "i will now inspect the codebase")
contains(t, "i will inspect the codebase")
contains(t, "i will now readfile")
contains(t, "i will use readfile")
contains(t, "i will now read the file")
contains(t, "i will now read files")
contains(t, "i will now read src")
contains(t, "i will now read the repository")
contains(t, "i will now read the code")
contains(t, "i will now run a command")
contains(t, "i will run a command")
contains(t, "i will now execute")
contains(t, "i will execute")
```

Include tool-name variants to catch extension-specific continuations:

```ailang
contains(t, "i will now use ctx")
contains(t, "i will use ctx")
contains(t, "i will now use exa")
contains(t, "i will use exa")
contains(t, "i will now use omnigraph")
contains(t, "i will use omnigraph")
contains(t, "i will now call ctx")
contains(t, "i will call ctx")
contains(t, "i will now call exa")
contains(t, "i will call exa")
contains(t, "i will now call omnigraph")
contains(t, "i will call omnigraph")
```

Keep the function deliberately conservative. False negatives are acceptable;
false positives can annoy users by preventing valid final explanations.

Do not match generic transition language by itself:

```ailang
-- Too broad; avoid these by themselves:
contains(t, "next step")
contains(t, "we now transition")
contains(t, "we now proceed")
contains(t, "i am now proceeding")
contains(t, "i will read")
contains(t, "i will use")
contains(t, "i will now inspect")
contains(t, "i will now read")
```

### 2. Add corrective feedback text helper and marker

File: `src/core/rpc.ail`

Add small helpers near other feedback helpers:

```ailang
func continuation_intent_marker() -> string =
  "MOTOKO_CONTINUATION_INTENT_REPAIR"

func continuation_intent_feedback() -> string =
  "${continuation_intent_marker()}: You said you intend to continue, but emitted no tool call or command. In Motoko, a prose-only response ends the run. If you intend to continue, emit the next JSON tool_calls block now. If the task is complete, provide a final answer without promising future tool use."
```

Keep it short and operational. Do not mention implementation details like
`NoDecision`.

### 2.1 Add one-shot repair cap

File: `src/core/rpc.ail`

Use the marker from `continuation_intent_feedback()` so the guard does not
consume many steps if the model keeps repeating prose-only continuation text.
Add a helper that scans recent message history for the marker:

```ailang
func has_recent_continuation_intent_repair(msgs: [Msg]) -> bool
```

Implementation can mirror existing retry-marker scans if one already exists in
`rpc.ail`. Otherwise, reverse the messages and scan only the most recent 6
messages using `contains(m.content, continuation_intent_marker())`.

Rationale for recent-only scanning:

- A marker from an unrelated earlier phase should not disable future repairs for
  the rest of a long session.
- A short recent window still prevents tight loops where the model repeats the
  same prose-only continuation mistake immediately after feedback.

Suggested helper shape:

```ailang
func has_recent_continuation_intent_repair(msgs: [Msg]) -> bool =
  has_recent_continuation_intent_repair_loop(reverse(msgs), 6)

func has_recent_continuation_intent_repair_loop(msgs: [Msg], remaining: int) -> bool =
  if remaining <= 0 then false
  else match msgs {
    [] => false,
    m :: rest =>
      if contains(m.content, continuation_intent_marker()) then true
      else has_recent_continuation_intent_repair_loop(rest, remaining - 1)
  }
```

Guard behavior:

- If continuation intent is detected and no marker is present, inject corrective
  feedback and continue.
- If continuation intent is detected but the marker is present in recent
  history, fall through to the normal sanitized `done` path. This prevents
  repeated repair loops while still preserving the final visible output.

### 3. Guard legacy no-command completion

File: `src/core/rpc.ail`

Update imports:

```ailang
import src/core/parse (..., assistant_visible_output, indicates_continuation_intent)
```

In `run_legacy_step()`, in the `extract_bash(response) == None` and
`NoDecision` branch, replace direct `done` emission with:

```ailang
let visible = assistant_visible_output(response);
if indicates_continuation_intent(visible) then
  if not has_recent_continuation_intent_repair(state.msgs) then {
    let msgs2 = msgs1 ++ [{ role: "user", content: continuation_intent_feedback() }];
    rpc_loop({
      env_url: state.env_url,
      msgs: msgs2,
      cwd: state.cwd,
      step: state.step + 1,
      inbox: state.inbox
    }, model2, depth - 1, step_delay, hybrid_enabled, ext_runtime, budget)
  } else {
    -- existing sanitized done/cache behavior
  }
else {
  -- existing sanitized done/cache behavior
}
```

Rationale:

- `msgs1` already includes the sanitized assistant response, preserving what the
  model said.
- Feedback is appended as a user message, matching existing repair-loop style.
- Incrementing `step` and decrementing `depth` prevents infinite free retries.
- The recent marker cap prevents repeated continuation-intent repairs from
  burning the whole step budget while still allowing a later unrelated phase to
  be repaired once.

### 4. Guard hybrid no-tool completion

File: `src/core/rpc.ail`

Apply the same pattern in `run_hybrid_step()` under:

```ailang
NoIntercept =>
  match parse_tool_calls(response) {
    NoToolCalls => ...
```

Only change the `NoDecision` branch. Do not change:

- `Accept(output)` branches.
- `ContinueWithFeedback(feedback)` branches.
- `ToolParseError(err)` branches.
- Valid `ParsedToolCalls(...)` branches.
- `is_done(result.stdout)` command/tool-output completion branches.

### 5. Add parser tests

File: `src/core/parse_test.ail`

Import `indicates_continuation_intent` and add wrapper tests:

```ailang
func continuation_intent_detected(text: string) -> bool
  tests [
    ("I will now use `Search` to locate core files.", true),
    ("I will issue the next tool call in a dedicated JSON turn.", true),
    ("I will issue the Search tool call in a separate, compliant JSON turn.", true),
    ("I will now use Search to locate the core implementation files in src.", true),
    ("I am now proceeding to search the repository with Search.", true),
    ("I will now inspect the repository before editing.", true),
    ("I will now read the file before editing.", true),
    ("The task is complete. Summary: all checks passed.", false),
    ("I can help explain the code if needed.", false),
    ("Final answer: no further action is required.", false),
    ("Next step: review the diff manually if desired.", false),
    ("We now transition from analysis to final recommendations.", false),
    ("I will read this as a request for a concise explanation.", false),
    ("I will now read this as a request for a concise explanation.", false),
    ("I will now inspect the tradeoffs conceptually.", false)
  ]
  { indicates_continuation_intent(text) }
```

If the AILANG test runner has trouble with backticks or punctuation in expected
strings, simplify the strings while preserving coverage.

### 6. Optional runtime tests

If there is an existing pure test target for `rpc.ail` helper functions, add
tests for:

- `continuation_intent_feedback()` includes the marker.
- `has_recent_continuation_intent_repair()` returns true when the marker appears
  in the last 6 messages.
- `has_recent_continuation_intent_repair()` returns false when the marker is
  older than the recent window.

If such tests are impractical because `rpc.ail` is effectful and not currently
unit-tested, rely on parser tests plus `ailang check src/core/rpc.ail`, and
cover the recent-marker behavior in manual verification.

Do not add heavy integration tests in this patch unless the existing test
harness already supports deterministic no-tool LLM responses.

## Verification

Run:

```bash
ailang check src/core/rpc.ail
ailang test src/core/parse_test.ail
ailang test src/core/agents_md.ail
cd src/tui && bun run build
```

Also run, but document current behavior if unchanged:

```bash
ailang test src/core/parse.ail
```

At the time this plan was written, `src/core/parse.ail` had no inline `tests`
blocks and the runner reported `No tests found` as a nonzero result. That should
not block this implementation unless new inline tests are added there.

## Manual Verification

Use a model/session prompt likely to produce the bad pattern:

```text
Run a multi-step demo. Summarize each phase and then continue with tools.
```

Confirm:

1. If the assistant says it will continue but emits no tool call, Motoko does
   not emit `done`.
2. The next model prompt includes the corrective feedback.
3. The model emits a valid JSON `tool_calls` block on the next step.
4. If the model repeats continuation prose immediately after the feedback,
   Motoko does not inject the same repair indefinitely.
5. A later unrelated phase can still receive one continuation-intent repair.
6. Genuine final answers still emit `done`.
7. `done.output` remains sanitized and does not include thinking traces.

## Risks

- False positives could prevent valid final responses that mention possible
  future work. Keep phrase detection conservative, require tool/action intent,
  and avoid generic transition matches.
- The guard can add one extra model step. This is preferable to premature
  completion, but it consumes budget.
- A stubborn model may repeat prose-only continuation text. The recent marker
  cap should limit this to one repair turn before normal completion behavior
  resumes for that local failure.
- Extensions that return `Accept(output)` bypass this guard by design. If an
  extension accepts continuation prose as final output, fix that extension
  separately.

## Acceptance Criteria

- Runtime no longer stops on obvious "I will now call/use/search..." prose.
- Corrective feedback causes a repair turn instead of `done`.
- Repeated continuation-intent prose after a recent repair marker does not loop
  indefinitely.
- Hybrid and legacy no-tool/no-command completion paths are both covered.
- Final prose answers still complete normally.
- Parser tests cover positive and negative continuation-intent cases.
- `ailang check src/core/rpc.ail`, `ailang test src/core/parse_test.ail`,
  `ailang test src/core/agents_md.ail`, and TUI build pass, or failures are
  documented as pre-existing/unrelated.
