---
doc_type: short
full_text: sources/Thinking_Traces.md
---

# Thinking Traces: Surface OpenRouter Reasoning Field

## Problem
- **Symptom:** Thinking traces from Qwen3 (and other reasoning models) via OpenRouter are not visible in the frontend, though the `thinking` event is emitted.
- **Root cause:** OpenRouter returns the reasoning content in a separate `message.reasoning` field alongside `message.content`; the AILANG Go struct `chatMessage` only maps `Content`, causing JSON unmarshaling to silently discard `reasoning`.

## Fix
Two minimal changes in the AILANG runtime:
1. **`ailang/internal/ai/openai/types.go`** – Add `Reasoning string` field (with `json:"reasoning,omitempty"`) to the `chatMessage` struct.
2. **`ailang/internal/ai/openai/chat.go`** – After extracting `Content`, prepend a ` thinking` block containing the `Reasoning` text, followed by ` response\n\n`. This re‑wraps the reasoning into a consistent format that the downstream AILANG brain already understands, regardless of whether the model used inline tags or a separate field.

## Why ` thinking` Tags?
- The `rpc.ail` script emits the full `response` string as the `thinking` event (no changes needed).
- The TUI (`ui.ts`) already knows how to parse ` thinking` blocks and style reasoning separately. The unified format avoids special‑casing different model outputs.

## UI Enhancement
In `tui/src/ui.ts`, the `handleEvent("thinking")` logic is updated to:
- Detect ` thinking ... <\/think>` at the start of the event text.
- Render the reasoning block dimmed (using `chalk.dim`) and pass the remainder as normal Markdown.
- Gracefully fall back to plain Markdown for models that do not produce ` thinking` blocks.

## Impact
- No modifications required in `swe/rpc.ail`, `tui/src/brain.ts`, or the existing `thinking` event plumbing.
- The `Message` structure now transparently carries reasoning content.
- Rebuild steps: `cd ailang && make quick-install`, then `cd tui && npm run build`.

## Cross‑document Connections
This fix touches the broader topic of [[concepts/thinking-trace-integration]] – how reasoning traces from different model providers (OpenRouter, Anthropic, etc.) are normalized and presented in the AILANG UI.

## Related Concepts
- [[concepts/jsonl-protocol-for-agent-communication]]
