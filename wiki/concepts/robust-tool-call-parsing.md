---
sources: [summaries/Tool_Parse_Robustness.md]
brief: A parsing strategy that safely extracts tool call JSON from model outputs by filtering reasoning blocks and handling embedded code fences.
---

# Robust Tool Call Parsing

Robust tool call parsing is a technique for reliably extracting structured tool invocations from language model responses, even when the raw output contains artifacts such as reasoning blocks (``) or conflicting code fences. It addresses two deep-seated failure modes that previously caused native tool calls to be silently dropped, particularly with reasoning‑enabled models and complex `WriteFile` payloads.

## The Core Problems

As documented in [[summaries/Tool_Parse_Robustness]], two bugs plagued the original parsing logic:

1. **Think‑block interference** – Models like Nemotron, DeepSeek‑R1, and QwQ may wrap their reasoning in `{ "tool_calls": ... }`. The fallback extractor would feed the whole string (including the `` spans. These spans are then used to filter any JSON candidate that **starts** inside a think block, without altering the candidate’s bytes. The span rules are carefully defined:

- An unclosed `` without an opener is ignored.
- Nested `` closes the span.

### 2. Source‑Order Candidate Selection

All potential JSON containers are collected in true source order: fenced ````json` blocks and unfenced objects starting with `{` or `[` (if they contain `"tool_calls"`). Candidates that survive think‑span filtering are decoded sequentially; the **first** one that yields a valid tool‑call root (an object with `"tool_calls"` or a direct array of calls) is accepted. This "first‑valid" strategy prevents later prose or code fences from hijacking the parse, which is particularly important when models append extra fenced examples after the real tool JSON.

### 3. Quote‑Aware Fence Scanning

For ````json` fences specifically, the extraction no longer splits on all backticks. Instead, a stateful scanner locates the opener and advances until it finds a closing ````` that is not inside a JSON string (tracking double‑quote state and backslash escapes). This ensures that ````` characters embedded in string literals – as in `WriteFile.content` – do not prematurely close the fence, while still correctly terminating the block at the model’s intended endpoint.

## Key Design Principles

- **No byte mutation**: Candidate JSON strings are never rewritten; only their placement relative to think spans is used for filtering.
- **Hybrid‑tool path only**: The changes apply inside `parse_tool_calls`; legacy `extract_bash` remains unchanged.
- **Backward compatibility**: Root‑array payloads and standard fenced/unfenced JSON continue to work exactly as before, but now coexist safely with reasoning artifacts and embedded backticks.

## Related Concepts

- [[concepts/think-block-handling]] – the precise handling of reasoning block semantics without payload corruption.
- [[concepts/payload-integrity]] – a broader principle of never rewriting JSON content during extraction.
- [[concepts/parse-candidate-pipeline]] – the ordered, multi‑stage extraction and filtering design.
- [[concepts/quote-aware-scanning]] – stateful scanning that respects string context when matching delimiters.

This robustness layer is essential for any agentic system that relies on tool‑calling with reasoning‑enabled models, and it serves as a reference pattern for future parsing improvements as discussed in the document’s [[summaries/Tool_Parse_Robustness#Future options|future compatibility options]].