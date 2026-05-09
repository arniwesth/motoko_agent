# Tool Parse Robustness — 2026-04-06

Branch: `Tool_Parse_Robustness`

## What was done

Implemented the plan in `.agent/plans/Tool_Parse_Robustness.md`, fixing two parser bugs and making two architectural improvements to thinking trace handling.

---

## Bug 1 — Think-block interference (`core/parse.ail`)

Reasoning models (DeepSeek-R1, Nemotron) prepend `<think>…</think>` to responses. The old `extract_tool_json` passed the full response to `decode()`, which failed on the `<think>` prefix.

**Fix:** Collect `[start, end)` span positions for all `<think>…</think>` blocks using `think_spans` / `think_spans_loop`. Any JSON candidate whose `start` index falls inside a span is excluded from the first-valid selection pipeline. Unclosed `<think>` tags extend their span to `length(text)`.

New helpers: `find_from`, `think_spans`, `think_spans_loop`, `in_any_span`, `Span` type.

---

## Bug 2 — Backtick splitting breaks WriteFile (`core/parse.ail`, `tui/src/ui.ts`)

`extract_fence` split on the literal string ` ``` `, so a `WriteFile` payload containing a code block (e.g. `` "content": "```bash\necho hi\n```" ``) would truncate at the first backtick triplet inside the JSON string.

**Fix:** Quote-aware char-by-char scanner `find_json_fence_close(hay, pos, in_str, escaped)` tracks whether the scanner is inside a JSON double-quoted string and only recognises a closing fence when `in_str == false`. Used in `extract_fence` (when `fence == "```json"`), `collect_fenced_candidates`, and the TypeScript `findJsonFenceClose`/`jsonFenceBlocks` equivalents in `ui.ts`.

New helpers: `JsonCandidate` type, `collect_fenced_candidates`, `last_open_brace_before`, `collect_obj_candidates`, `collect_arr_candidate`, `collect_unfenced_candidates`, `first_valid_tool_json`, `extract_tool_json` (rewritten), `is_valid_tool_root`, `find_tool_calls_array`.

---

## Architecture — Native tool events

The TUI previously re-parsed `thinking` event text with a regex to discover native tool calls (`renderNativeToolCallsFromThinking`). This was fragile and duplicated logic from the runtime.

**Fix:** The runtime now emits `native_tool_calls` and `native_tool_results` JSONL events around `run_native_batch`. The TUI handles these directly. `renderNativeToolCallsFromThinking` and `syntheticToolBatches` are deleted.

New runtime helpers: `tool_result_item_to_display`, `tool_result_items_to_display_json`.
New TypeScript: `NativeToolResult` interface, two new `AgentEvent` union members.

---

## Architecture — Think/answer pre-split

The TUI `thinking` handler used `event.text.match(/<think>([\s\S]*?)<\/think>/)` (naive lazy regex) to visually separate reasoning from answer. This mishandled unclosed tags and stray closers.

**Fix:** `split_think_answer(text)` exported from `core/parse.ail` uses the existing `think_spans` infrastructure to extract think-block content and non-think remainder separately. Called in `rpc.ail` before emitting the `thinking` event; `think` and `answer` fields added to the event payload alongside the existing `text` field (backward-compatible optional fields).

The TUI uses `event.think` / `event.answer` directly when present and falls back to rendering `event.text` for older runtimes.

New helpers: `collect_think_text`, `remove_spans`, `remove_spans_loop`, `split_think_answer`.

---

## Think trace UX — Collapsible blocks with cycling

Thinking traces are often very long. New behaviour:

- Each `thinking` event renders a single collapsed dim header: `[think] step N · K chars ▸ ^t`
- A mutable `bodyRow` (initially empty) sits below it in the history box
- `ctrl+t` cycles backward through all think blocks (most recent → oldest → wraps), expanding the newly selected one and collapsing the previous. Works at any point — during a run or after task completion.
- `collapseThinkBlock` / `expandThinkBlock` / `selectThinkBlock` replace the earlier `toggleThinkBlock`.
- `thinkStepOrder: number[]` tracks insertion order; `selectedThinkIdx` tracks cycle position.

---

## Tests

- `core/parse_test.ail`: 8 new inline tests covering both bugs and the new `split_think_answer` export. 42 tests total, all passing.
- `tui/`: 18 existing tests, all passing. No new tests added for cycling logic (tracked as open issue).

---

## Open issues written to `.agent/issues/`

- `think-block-blank-line.md` — empty `bodyRow` renders as a blank line per collapsed block
- `think-block-timestamp-on-toggle.md` — header timestamp changes on every `ctrl+t` press
- `think-block-cycle-position-indicator.md` — no `(N/M)` cycle counter in header
- `think-block-selectedidx-not-reset.md` — `selectedThinkIdx`/`thinkStepOrder` not cleared on `session_start`
- `think-block-cycling-tests.md` — no tests for expand/collapse/cycle logic
