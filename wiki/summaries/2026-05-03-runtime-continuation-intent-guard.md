---
doc_type: short
full_text: sources/2026-05-03-runtime-continuation-intent-guard.md
---

# Runtime Continuation Intent Guard

## Overview
This session implemented a runtime guard to prevent early termination of agent sessions when the assistant's response is prose-only but clearly expresses an intent to continue working (e.g., promising a future tool call). Previously, such responses were treated as terminal `done` events, causing the agent to stop prematurely. The fix detects continuation intent and injects corrective feedback to nudge the model toward either emitting an actual JSON tool call block or providing a final answer.

## Key Changes
- **Detection Logic**: Added `indicates_continuation_intent(text)` in the parser module, using conservative phrase matching on sanitized visible assistant output.
- **Repair Mechanism**: Introduced helper functions to produce a continuation intent marker and feedback message, with a loop guard to cap immediate repair cycles (max recent marker check).
- **Runtime Integration**: Guarded both `run_legacy_step()` and `run_hybrid_step()` paths where a response lacks a parsed command or tool call block, but the text indicates more work to come.
- **Testing**: 43 new parser tests validate positive/negative intent detection, and integration with runtime steps confirmed via `rpc` and `agents_md` tests.

## Detection Logic
The function `indicates_continuation_intent` only inspects the visible assistant output (not raw thinking traces). It lowercases and trims the input, then checks for specific phrases like:
- "i will issue the next tool call"
- "i will now use search"
- "proceeding to search the repository"
- ... among others.

Broad phrases such as "next step" or "i will read" alone are excluded to avoid false positives. This conservative approach ensures that only clear promises of imminent tool execution trigger the guard. See [[concepts/continuation intent detection]] for broader pattern design considerations.

## Repair and Loop Guard
When continuation intent is detected, the runtime appends a user message containing the `MOTOKO_CONTINUATION_INTENT_REPAIR` marker and a prompt instructing the model to output either the next JSON `tool_calls` block now or a final answer. The marker is checked over the most recent 6 messages to prevent repeated immediate repair loops if the model keeps producing prose-only continuation responses. This feedback loop ensures the assistant has one additional chance to correct its output before falling through to a terminal state. Related patterns are explored in [[concepts/agent feedback loop]] and [[concepts/prose-only response handling]].

## Runtime Integration
The guard is applied in two critical completion paths:
- **Legacy step**: When no bash command is extracted and the extension returns `NoDecision`, the runtime checks for continuation intent.
- **Hybrid step**: When no tool calls are parsed and the extension returns `NoDecision`, the same check runs.

In both cases, if intent is found and no recent repair marker exists, the runtime calls `rpc_loop` again with the appended feedback, consuming one additional step. Valid tool calls, bash commands, and extension accepts continue without interference. This integration is a prime example of [[concepts/runtime termination rules]] refinement.

## Testing and Verification
All modified files type-checked successfully (`parse.ail`, `rpc.ail`, `parse_test.ail`). Unit tests:
- `parse_test.ail`: 43 tests covering positive/negative continuation intent cases.
- `rpc.ail`: 26 tests passed, validating runtime behavior with repair steps.
- `agents_md.ail`: 11 tests passed, confirming no regressions.

The implementation note about `parse.ail` having no inline tests despite README claims is recorded but not a bug.

## Implementation Notes
- Only visible output is used for detection, preserving the separation of thinking traces.
- The corrective feedback is appended after the original assistant response, keeping history intact.
- Each intent repair consumes one runtime step and reduces remaining depth.
- The loop guard prevents infinite repair cycles.

## Cross-Document Concepts
This session connects to several recurring themes:
- [[concepts/continuation intent detection]]
- [[concepts/prose-only response handling]]
- [[concepts/runtime termination rules]]
- [[concepts/agent feedback loop]]
- [[concepts/tool-use orchestration]]

These concept pages may be expanded as more sessions cover intent guards, runtime state machines, and assistant correction strategies.