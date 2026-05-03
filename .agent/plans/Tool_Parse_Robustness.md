# Tool Parse Robustness

Fix two bugs in `core/parse.ail` that cause native tool calls to silently fail
for reasoning models and for `WriteFile` with multi-line content.

## Expected file changes

- Modify: `core/parse.ail`
- Modify: `core/parse_test.ail`
- Add: none

---

## Bug 1 — Think-block interference (Nemotron, any reasoning model)

### Symptom

Models that use `<think>...</think>` tags (Nemotron, DeepSeek-R1, QwQ, etc.)
produce responses like:

```
<think>
I need to read README.md first.
</think>
{"tool_calls":[{"id":"t1","tool":"ReadFile","path":"README.md","start":1,"end":200}]}
```

`parse_tool_calls` calls `extract_tool_json`, which tries `extract_fence` first.
If the model did not use a ` ```json ``` ` fence, the fallback fires:

```ailang
if contains(text, "\"tool_calls\"")
then Some(text)   -- entire response, including <think> block
else None
```

`decode(text)` receives a string starting with `<think>` -> fails with
`invalid character '<' looking for beginning of value` -> `ToolParseError` is
fed back to the model -> the model spins trying different formats, never
succeeding.

Secondary effect: when a model puts a ` ```json ``` ` fence *inside* its
`<think>` block as reasoning scratch-pad, `extract_fence` finds that block and
executes those calls, instead of the actual response payload.

### Decision

Do **not** globally strip `<think>...</think>` from the whole response.

Reason: global stripping can corrupt valid JSON payload bytes, especially
`WriteFile.content` that intentionally contains literal `<think>` text.
Tool parsing must preserve tool argument payloads exactly.

### Fix

Add a payload-safe extraction pipeline:

1. Compute `<think>...</think>` spans as index ranges in the raw response.
2. Build JSON candidates in true source order (by start index), including:
   - fenced ` ```json ` bodies,
   - unfenced JSON-start candidates.
3. Drop any candidate whose start index is inside a think span.
4. Try to decode each candidate exactly as-is.
5. Accept the **first** candidate that decodes to either:
   - root object with `tool_calls` array, or
   - root array (direct tool call list).
6. If none decode to a valid tool payload, return `ToolParseError`.

Think-span rules (explicit):

- Unclosed `<think>`: span runs from opener to end-of-response.
- Stray `</think>` with no open span: ignored as plain text.
- Nested `<think>` inside an open span: treated as span content (no new nesting
  depth tracking). A span ends at the first subsequent `</think>`.
- Candidate filtering is by candidate start index only; candidate body bytes are
  never rewritten.

Practical helper shape:

```ailang
type Span = { start: int, end: int }   -- [start, end), end-exclusive
type JsonCandidate = { start: int, body: string }

-- Find think spans in source text.
func think_spans(text: string) -> [Span]

-- True iff pos falls in any span.
func in_any_span(pos: int, spans: [Span]) -> bool

-- Returns candidates sorted by `start` (true source order), not by type.
func tool_json_candidates(text: string) -> [JsonCandidate]

-- Decode candidates in order (after think-span filtering);
-- return first candidate body that is a valid tool-call root.
func first_valid_tool_json(candidates: [JsonCandidate], spans: [Span]) -> Option[string]
```

No preprocessing pass should mutate bytes inside candidate JSON strings.

### Scope

Apply this only in `parse_tool_calls` (hybrid tool path).

Legacy `extract_bash` behavior remains unchanged in this plan.

---

## Bug 2 — Backtick splitting breaks `WriteFile` with code-block content

### Symptom

`extract_fence` currently uses `split(rest, "```")` and takes the first segment
as the fenced payload:

```ailang
cmd :: _ :: _ => Some(trim(cmd))
```

When JSON includes literal code fences in `WriteFile.content`, this truncates
the JSON before the true closing fence and `decode` fails.

Example:

~~~
```json
{"tool_calls":[{"id":"t2","tool":"WriteFile","path":"AGENTS.md","content":"# Title\n\n```bash\necho hi\n```\n"}]}
```
~~~

### Decision

Prioritize correctness for **first valid JSON tool block**, not "last fence
wins". "Last fence" introduces regressions when models append extra fenced prose
after the real tool JSON.

### Fix

Replace naive fence extraction for JSON fences with a quote-aware fenced scanner
for ` ```json ` blocks:

1. Locate `fence` start.
2. Scan forward for closing ````` while tracking JSON string state:
   - `in_string` (inside double-quoted JSON string)
   - `escaped` (previous char was backslash)
3. Treat ````` as a closing fence only when `in_string == false`.
4. Return trimmed body between the opener and the matched closer.

Then, in `parse_tool_calls`, attempt candidates in source order (excluding
think-span candidates) and accept the first decoded valid tool payload.

This keeps embedded ````` inside JSON string literals intact while still
stopping at the real fence.

---

## Files to change

| File | Change |
|---|---|
| `core/parse.ail` | Replace `extract_tool_json` with ordered candidate extraction + first-valid decode selection |
| `core/parse.ail` | Add JSON-fence-specific quote-aware closing-fence scan (do not change non-JSON fence behavior used by `extract_bash`) |
| `core/parse_test.ail` | Add tests for think-preface handling, fenced JSON with embedded backticks, and first-valid selection |

No changes to `rpc.ail`, `tool_runtime.ail`, or TypeScript files.

---

## Test cases to add

**Bug 1 — think/preamble handling (in `core/parse_test.ail`):**

```ailang
-- Preface think block before valid unfenced tool JSON
func ptc_think_preface_unfenced() -> bool
  tests [((), true)]
  {
    let text = "<think>plan</think>\n{\"tool_calls\":[{\"id\":\"t1\",\"tool\":\"ReadFile\",\"path\":\"x.ail\",\"start\":1,\"end\":10}]}";
    match parse_tool_calls(text) {
      ParsedToolCalls(res) =>
        match res.calls {
          ReadFile(c) :: _ => c.id == "t1" and c.path == "x.ail",
          _ => false
        },
      _ => false
    }
  }
```

```ailang
-- Ensure parser does NOT execute fenced JSON inside think when later real block exists
func ptc_ignore_think_fenced_json() -> bool
  tests [((), true)]
  {
    let text = "<think>```json\n{\"tool_calls\":[{\"id\":\"bad\",\"tool\":\"ReadFile\",\"path\":\"bad\"}]}\n```</think>\n```json\n{\"tool_calls\":[{\"id\":\"good\",\"tool\":\"ReadFile\",\"path\":\"good\"}]}\n```";
    match parse_tool_calls(text) {
      ParsedToolCalls(res) =>
        match res.calls {
          ReadFile(c) :: _ => c.id == "good" and c.path == "good",
          _ => false
        },
      _ => false
    }
  }
```

```ailang
-- Unclosed <think> should suppress all later candidates in that unterminated span
func ptc_unclosed_think_suppresses_candidates() -> bool
  tests [((), true)]
  {
    let text = "prefix<think>```json\n{\"tool_calls\":[{\"id\":\"bad\",\"tool\":\"ReadFile\",\"path\":\"bad\"}]}\n```";
    match parse_tool_calls(text) {
      NoToolCalls => true,
      ToolParseError(_) => true,
      _ => false
    }
  }
```

```ailang
-- Payload integrity: literal <think> text inside JSON string must be preserved
func ptc_writefile_literal_think_content_preserved() -> bool
  tests [((), true)]
  {
    let text = "{\"tool_calls\":[{\"id\":\"w1\",\"tool\":\"WriteFile\",\"path\":\"x.md\",\"content\":\"before <think>literal</think> after\"}]}";
    match parse_tool_calls(text) {
      ParsedToolCalls(res) =>
        match res.calls {
          WriteFile(c) :: _ => c.id == "w1" and c.path == "x.md" and c.content == "before <think>literal</think> after",
          _ => false
        },
      _ => false
    }
  }
```

**Bug 2 — fenced JSON with embedded backticks (in `core/parse_test.ail`):**

```ailang
func ef_json_backticks_in_string() -> bool
  tests [((), true)]
  {
    let text = "```json\n{\"content\":\"```bash\\necho hi\\n```\"}\n```";
    match extract_fence(text, "```json") {
      Some(s) => s == "{\"content\":\"```bash\\necho hi\\n```\"}",
      None => false
    }
  }
```

```ailang
-- Regression guard: appended fenced prose after tool JSON should not break parse
func ptc_first_valid_over_appended_fence() -> bool
  tests [((), true)]
  {
    let text = "```json\n{\"tool_calls\":[{\"id\":\"t1\",\"tool\":\"ReadFile\",\"path\":\"a\"}]}\n```\nSee also:\n```bash\necho hello\n```";
    match parse_tool_calls(text) {
      ParsedToolCalls(res) =>
        match res.calls {
          ReadFile(c) :: _ => c.id == "t1" and c.path == "a",
          _ => false
        },
      _ => false
    }
  }
```

```ailang
-- Legacy extraction guard: bash fence behavior remains unchanged
func eb_bash_fence_unchanged() -> bool
  tests [((), true)]
  {
    match extract_bash("```bash\necho hello\n```") {
      Some(cmd) => cmd == "echo hello",
      None => false
    }
  }
```

```ailang
-- Root-array payload support remains valid under candidate pipeline
func ptc_root_array_payload() -> bool
  tests [((), true)]
  {
    let text = "[{\"id\":\"t1\",\"tool\":\"ReadFile\",\"path\":\"a\",\"start\":1,\"end\":2}]";
    match parse_tool_calls(text) {
      ParsedToolCalls(res) =>
        match res.calls {
          ReadFile(c) :: _ => c.id == "t1" and c.path == "a" and c.start == 1 and c.end == 2,
          _ => false
        },
      _ => false
    }
  }
```

---

## Implementation order

1. Implement ordered candidate extraction + first-valid decode in `parse_tool_calls`.
2. Replace JSON fence parsing with quote-aware closing-fence scan.
3. Add/adjust tests in `core/parse_test.ail` (and `core/parse.ail` inline tests if needed).
4. Run:
   - `ailang test core/parse.ail`
   - `ailang test core/parse_test.ail`
   - `ailang check core/rpc.ail`

---

## Future options

- `HYBRID_TOOLS=0` compatibility: if reasoning models must run in legacy mode,
  add equivalent think/preamble-safe handling to `extract_bash` path.
