---
sources: [summaries/Thinking_Traces.md]
brief: Unified normalization and presentation of AI reasoning traces across provider-specific formats.
---

# Thinking Trace Integration

## What It Is
Thinking trace integration is the mechanism in the AILANG system that collects reasoning content from various AI model providers, normalizes it into a standard format, and surfaces it in the user interface without disrupting the answer flow.

## The Challenge
Different providers deliver reasoning traces in incompatible ways:

| Provider | Delivery Method |
|---|---|
| Models with inline tags | Reasoning wrapped directly in ` thinking` XML-style tags inside the main `content` string |
| OpenRouter Qwen3, others | Reasoning placed in a separate `message.reasoning` JSON field; `message.content` contains only the final answer |
| Anthropic Extended Thinking | Reasoning delivered as separate content blocks that require a `betas` header to enable |

Without normalization, only the first case works correctly. The other cases either lose the reasoning entirely or require special handling at every layer of the stack.

## The Normalization Pattern
As described in [[summaries/Thinking_Traces]], the chosen approach is to perform normalization as early as possible — at the API response parsing layer in the AILANG runtime:

1. **Catch all formats** where the upstream API delivers reasoning.
2. **Re-wrap into ` thinking` tags** so that downstream components (rpc.ail script, UI event handler) see a single, uniform format.
3. **Preserve backward compatibility**: models that already use inline tags continue to work unchanged.

The unified format is:
```
 thinking
<reasoning text>
 response

<final answer>
```

## End-to-End Flow
1. `ailang/internal/ai/openai/chat.go` merges `Reasoning` into `Content` with ` thinking` wrappers.
2. The `rpc.ail` AILANG script emits the full merged string as a single `thinking` event.
3. `tui/src/ui.ts` parses the ` thinking` block, renders reasoning in dimmed style (`chalk.dim`), and renders the final answer as normal Markdown.

## Related Concepts
- [[summaries/Thinking_Traces]] – The specific fix that uncovered this integration pattern
- UI event handling for streaming model responses
- Provider abstraction vs. model-specific code paths

## Design Principle
Single normalization point, dumb downstream. By doing the work once in the API client layer, every other component (script engine, terminal UI, future web UIs) can rely on a consistent message format without knowing which provider or model produced the trace.