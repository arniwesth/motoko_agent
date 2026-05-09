---
doc_type: short
full_text: sources/Tool_Parse_Robustness.md
---

# Tool Parse Robustness Summary

This document outlines precise fixes for two critical bugs in `core/parse.ail` that silently break native tool calls for reasoning models and for `WriteFile` payloads with multi-line content. The solutions introduce a payload-safe extraction pipeline and a quote-aware fenced JSON scanner.

## Bug 1: Think-Block Interference

Models that emit `` tags (Nemotron, DeepSeek‑R1, QwQ) can produce responses where the tool call JSON is preceded or interspersed with reasoning text. The fallback in `extract_tool_json` blindly passes the entire response to `decode` if no ` ```json ` fence is found, causing a `ToolParseError` when the response starts with `` spans as index ranges, extract all JSON candidates (fenced and unfenced) in source order, filter out any candidate that starts inside a think span, and accept the **first** candidate that decodes to a valid tool‑call root (object with `tool_calls` array or a direct array).

This approach is implemented only in the hybrid tool path (`parse_tool_calls`); legacy `extract_bash` remains unchanged.

## Bug 2: Backtick Splitting Breaks `WriteFile`

The existing `extract_fence` uses `split(rest, "```")` and takes the first segment, which truncates JSON when the content itself contains a code fence. For example, a `WriteFile` with a ` ```bash ` snippet inside the JSON can cause the parser to stop at the inner fence.

**Fix:** Replace the JSON‑fence extraction with a quote‑aware scanner. It locates the ` ```json ` opener, then scans forward for the closing ` ``` `` while tracking whether the current position is inside a double‑quoted JSON string (accounting for backslash escapes). A ````` is treated as a closing fence only when not inside a string. This preserves any ````` that appear as literal text within JSON values.

## Implementation Highlights

- Ordered candidate extraction + first‑valid decode in `parse_tool_calls`.
- New helper functions: `think_spans`, `tool_json_candidates`, `first_valid_tool_json`.
- Quote‑aware fence scan for ` ```json ` blocks only (non‑JSON fence behavior untouched).
- Comprehensive tests covering think‑preface handling, fenced JSON with embedded backticks, payload integrity of literal `

## Related Concepts
- [[concepts/robust-tool-call-parsing]]
