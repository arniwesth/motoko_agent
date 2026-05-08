# Thinking Traces: Surface OpenRouter Reasoning Field

## Problem

Thinking traces from Qwen3 (and other reasoning models via OpenRouter) are not visible in the frontend. The `thinking` event IS emitted and rendered correctly — the issue is that the reasoning content is silently dropped before it ever reaches AILANG.

**Root cause:** OpenRouter returns reasoning/thinking content in a separate `message.reasoning` field alongside `message.content`. The Go `chatMessage` struct in `ailang/internal/ai/openai/types.go` only maps `content`, so Go's JSON unmarshaler discards `reasoning` silently. The `thinking` event ends up containing only the bare answer.

```json
// What OpenRouter actually returns for Qwen3:
{
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "The answer is...",
      "reasoning": "Let me think step by step..."   ← silently dropped
    }
  }]
}
```

This is unrelated to Anthropic's "extended thinking" (separate content blocks via betas header). It is a missing struct field.

## Fix

Two small changes in the AILANG runtime:

### 1. `ailang/internal/ai/openai/types.go` — add `Reasoning` field

```go
// chatMessage represents a message in the Chat Completions API.
type chatMessage struct {
    Role      string `json:"role"`
    Content   string `json:"content"`
    Reasoning string `json:"reasoning,omitempty"`   // ← add this
}
```

### 2. `ailang/internal/ai/openai/chat.go` — prepend reasoning to text

After line 130 (`text := result.Choices[0].Message.Content`):

```go
text := result.Choices[0].Message.Content
reasoning := result.Choices[0].Message.Reasoning
if reasoning != "" {
    text = "<think>\n" + reasoning + "\n</think>\n\n" + text
}
```

This re-wraps the reasoning in `<think>` tags so the downstream AILANG brain receives a consistent format regardless of whether the model used inline tags or a separate field.

## Why `<think>` tags in the merged text?

- `rpc.ail` emits the full `response` string as the `thinking` event — no changes needed there
- `ui.ts` renders `thinking` events as Markdown — `<think>` tags are parsed out and the reasoning is styled separately (see UI change below)
- This format is consistent whether the model used inline tags or a separate API field

## Files to change

| File | Change |
|---|---|
| `ailang/internal/ai/openai/types.go` | Add `Reasoning string` to `chatMessage` |
| `ailang/internal/ai/openai/chat.go` | Prepend reasoning block when non-empty |
| `tui/src/ui.ts` | Parse `<think>` blocks and render with `chalk.dim` |

No changes needed in:
- `swe/rpc.ail` — already emits full response as `thinking`
- `tui/src/brain.ts` — `AgentEvent` type already has `text: string`

## UI change: style thinking traces in `tui/src/ui.ts`

In `handleEvent("thinking")`, split the text on `<think>` tags and render the reasoning block dimmed, separate from the final answer:

```typescript
case "thinking":
  this.step = event.step;
  const thinkMatch = event.text.match(/^<think>([\s\S]*?)<\/think>\s*/);
  if (thinkMatch) {
    this.history.addChild(styledText(thinkMatch[1].trim(), chalk.dim));
    const answer = event.text.slice(thinkMatch[0].length);
    if (answer.trim()) {
      this.history.addChild(new Markdown(answer, 0, 0, MINIMAL_THEME));
    }
  } else {
    this.history.addChild(new Markdown(event.text, 0, 0, MINIMAL_THEME));
  }
  break;
```

This visually separates reasoning (dim) from the final answer (normal Markdown), and gracefully falls back to plain Markdown for models that don't produce `<think>` blocks.

## Rebuild step

After changing Go source, reinstall the runtime:

```bash
cd ailang && make quick-install
```

Then rebuild the TypeScript frontend:

```bash
cd tui && npm run build
```
