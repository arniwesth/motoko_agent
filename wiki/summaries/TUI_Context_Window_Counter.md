---
doc_type: short
full_text: sources/TUI_Context_Window_Counter.md
---

# TUI Context Window Counter Plan Summary

**Date:** 2026-04-24 | **Status:** Proposed

## Overview

This plan proposes a local, lightweight context‑window usage display in the TUI status bar, showing `ctx: 12.3k/200k (6%)`. The estimate uses `(total chars ÷ 4)` across system prompt and message history, avoiding any dependency on provider tokenisation or the vendored `ailang` fork. Accuracy is ±20%, sufficient for a quick “am I running out?” answer.

## Key Design Decisions

- **Local estimate, not provider usage**  
  A pure function `estimate_tokens` in `context_usage.ail` computes tokens from total character length. A companion `context_limit_for` maps model names to known context limits, with OpenRouter prefix‑stripping. Unknown models return `0` → the TUI hides the ratio.

- **Runtime emits JSONL event**  
  A new `context_usage` line is printed to stdout once per step, carrying `step`, `tokens_est`, and `limit`. This keeps the TUI stateless and avoids touching `src/tui/src/models.ts`; the runtime is the single source of truth.

- **TUI rendering and color thresholds**  
  The status bar appends the counter after the model name, using `formatCount` (e.g., `12.3k`, `1.0M`). Yellow at ≥75%, red at ≥90%. When `limit === 0`, only the absolute count is shown. Chalk handling ensures no colour nesting bugs.

- **Minimal changes, no external dependencies**  
  Chars ÷ 4 is dependency‑free. Real tokeniser accuracy or provider‑reported usage is explicitly deferred.

## Implementation Phases

1. **AILANG side** – new `context_usage.ail` module with `estimate_tokens` and `context_limit_for`, inline tests, and companion test file for non‑empty message lists.  
2. **Wiring** – one (or few) call sites in `rpc.ail` emit the JSONL event each step.  
3. **TUI plumbing** – parse the event in `runtime-process.ts`, store latest values in `ui.ts`, extend `updateStatus()` with the counter segment.  
4. **Tests and docs** – unit tests for formatting, rendering, threshold colours; README one‑line addition.

## Concepts for Cross‑Reference

- [[concepts/context window estimation]] – local char‑based token approximation  
- [[concepts/runtime communication]] – JSONL events between core and TUI  
- [[concepts/model limits]] – mapping model names to context limits  
- [[concepts/tui status bar rendering]] – how the status bar composes and styles segments  

## Non‑Goals

- Real provider token counts, tokeniser‑accurate estimates, cached‑prompt savings, per‑step delta, or dynamic limit lookup for unknown OpenRouter models.