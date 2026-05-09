---
doc_type: short
full_text: sources/Runtime_Continuation_Intent_Guard.md
---

# Runtime Continuation Intent Guard Summary

## Overview

Motoko's runtime treats an assistant's prose-only response (with no parsable tool call) as a terminal signal, emitting `done` and ending the agent loop. This is correct for final answers but fails when the model says it intends to continue (e.g., "I will now use `Search`..."). The **Runtime Continuation Intent Guard** intercepts such responses, detects overt continuation intent, injects corrective feedback, and continues the loop instead of stopping prematurely.

## Key Mechanism

- **Detection**: A new helper `indicates_continuation_intent()` in `parse.ail` scans the sanitized visible assistant output for conservative phrase patterns (e.g., "I will now use search", "tool call in a separate turn") that strongly imply the model plans further tool use. Generic transition language ("next step", "we now proceed") is deliberately avoided to prevent false positives.
- **Corrective Feedback**: If intent is detected, the runtime appends a user message (containing a unique marker) that instructs the model to either emit the next tool call now or provide a final answer. This feedback is added once per recent context window.
- **Repair Cap**: A recent-marker check (`has_recent_continuation_intent_repair`) limits repairs to one per local failure window, preventing infinite loops if the model repeats the mistake immediately after feedback.
- **Coverage**: The guard is applied in both the legacy (no-command) and hybrid (no-tool) completion paths, preserving normal completion for genuine final prose.

## Implementation Components

- **Parser helpers** in `parse.ail`:
  - `assistant_visible_output()` – extracts visible output (sans thinking traces).
  - `indicates_continuation_intent()` – phrase-based detection.
- **Runtime helpers** in `rpc.ail`:
  - `continuation_intent_feedback()` – constructs the corrective user message.
  - `has_recent_continuation_intent_repair()` – scans recent history for the marker.
- **Guard insertion** in `run_legacy_step()` and `run_hybrid_step()`: before emitting `done`, check for intent; if present and no recent marker, inject feedback and loop.
- **Tests**: Parser tests cover positive/negative cases; runtime tests validate feedback marker behavior.

## Risks and Mitigations

- **False positives**: Conservative pattern set reduces risk; only tool/action intent triggers guard, not generic future mentions.
- **Budget consumption**: The guard adds an extra model step, but preventing premature completion is deemed worthwhile.
- **Stubborn loops**: The recent marker cap limits repairs to one turn; after that, normal `done` ensues.
- **Extensions bypass**: Extensions that `Accept(output)` avoid this guard, so misbehaving extensions need separate fixes.

## Related Concepts

- [[concepts/continuation_intent_detection]] – How the phrase matching identifies future tool use.
- [[concepts/runtime_loop_guard]] – Design pattern for injecting feedback mid-loop to correct protocol errors.
- [[concepts/assistant_output_sanitization]] – Separating visible output from thinking traces to guard analysis.
- [[concepts/recent_message_marker_cap]] – Preventing repair loops with a sliding window marker check.

## Acceptance

- Prose-only responses with clear continuation intent no longer terminate the run.
- Corrective feedback is given, leading to a tool-call in a subsequent step.
- Repeated intent after feedback does not loop indefinitely.
- Both hybrid and legacy completion paths are covered.
- Genuine final answers still emit `done` normally.
- All specified tests pass and the TUI build succeeds.