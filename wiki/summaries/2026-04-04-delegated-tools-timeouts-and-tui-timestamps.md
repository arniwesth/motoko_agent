---
doc_type: short
full_text: sources/2026-04-04-delegated-tools-timeouts-and-tui-timestamps.md
---

# Summary: Delegated Tool Timeout Fixes + TUI Timestamps

## Overview
This document details fixes for regressions introduced by [[Tool Dispatch to TUI]]. It addresses three symptoms: false delegated timeouts, missing per‑message timestamps in the terminal UI, and a frozen elapsed timer during delegated waits. The changes also restore bounded attempts on the wait loop, as flagged in review.

## Key Changes
1. **Reliable token consumption** – `wait_for_tool_results` now parses stdin line‑by‑line looking for `tool_results` messages by request ID, eliminating missed lines that caused premature “timed out” errors.
2. **Bounded attempts** – Recursive branches (decode error, `model_change`, unrelated messages) decrement the attempt counter, preventing the loop from waiting forever while stdin is open.
3. **TUI timestamps** – All history entries (reasoning, tool batches, user echoes, errors, rendered markdown) gain a millisecond‑precision timestamp (`HH:MM:SS.mmm`).
4. **Footer timestamp** – Status line 1 now shows both relative age (“last update: Xs ago”) and absolute time.
5. **Async delegated execution** – Switched from `spawnSync` to `spawn` inside `handleToolCalls`, freeing the Node event loop so the footer’s elapsed timer updates during delegated tool runs.

## Impact
- False “timed out waiting for tool_results” messages are eliminated.
- Every TUI message now carries a precise timestamp, aiding debugging.
- The footer shows an up‑to‑date absolute timestamp and live age.
- Delegated tool calls no longer freeze the UI timer.
- The wait loop respects a bounded number of non‑matching messages.

## Concepts
- [[Delegated Execution]] – offloading tool invocations to a subprocess while the brain waits for results.
- [[Async Tool Execution]] – moving from synchronous blocking calls to non‑blocking async IO to keep the UI alive.
- [[TUI Timestamping]] – adding per‑message and footer timestamps for observability.
- [[Bounded Attempts]] – ensuring recursive wait loops have a finite limit on unsuccessful reads.

## Validation
All AILANG checks (`swe/rpc.ail`, `swe/types.ail`, `swe/parse.ail`, etc.) passed, and the TUI’s test suite (4/4 suites) passed after the changes.