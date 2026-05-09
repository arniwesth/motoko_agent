---
doc_type: short
full_text: sources/2026-04-06-tool-parse-robustness.md
---

# Tool Parse Robustness — Summary

This branch addresses two critical parser bugs and two architecture changes to improve the stability and user experience of multi‑turn tool‑calling with reasoning models.

## Parser Bug Fixes

### Think‑block interference (`core/parse.ail`)

Reasoning models prepend `` blocks that prevented `extract_tool_json` from finding valid JSON. The fix introduces span‑based exclusion: any JSON candidate whose start falls inside a `think` span is ignored. Unclosed tags are safely handled by extending the span to end‑of‑text. New helpers (`find_from`, `think_spans`, `in_any_span`, `Span`) provide the building blocks for future think‑aware parsing.  
→ See [[concepts/think-block-handling]] for the broader challenge of reasoning‑model output processing.

### Backtick splitting in `WriteFile` payloads

Code blocks inside `WriteFile` tool arguments (e.g., a JSON string containing ```) caused `extract_fence` to split incorrectly on interior backtick triplets. The fix is a **quote‑aware JSON fence scanner**: it tracks when it is inside a double‑quoted string and only recognises a closing fence outside of a string. This change affects `extract_fence`, `collect_fenced_candidates`, and the TypeScript side in `ui.ts`.  
→ See [[concepts/backtick-splitting]] for details on JSON‑embedded code fences and the scanner approach.

## Architecture Enhancements

### Native tool events

Previously the TUI re‑parsed `thinking` event text with a fragile regex to discover tool calls (`renderNativeToolCallsFromThinking`). Now the runtime emits explicit `native_tool_calls` and `native_tool_results` JSONL events around `run_native_batch`. The TUI consumes them directly, deleting the old regex‑based logic and the `syntheticToolBatches` structure. This improves separation of concerns and eliminates duplicated parsing.  
→ See [[concepts/native-tool-events]] for the event‑driven protocol for native tools.

### Think/answer pre‑split

The TUI no longer does lazy `/