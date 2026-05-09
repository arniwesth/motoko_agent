---
doc_type: short
full_text: sources/2026-04-23-compose-streaming-teacher-prompt-phase6-followup.md
---

This follow-up session resolved five Compose/streaming regressions in the Motoko/AILANG integration and finalized Phase 6 documentation status.

## Core Regressions Addressed
- Compose no longer triggered after `Reason about core`.
- Single-object JSON tool calls caused a stall.
- Empty snippet errors from subagent (missing `ailang` fence or empty body).
- Composer streaming not working even when fallback execution succeeded.
- Composer system prompt was a minimal stub, not the full teacher prompt.

## Key Changes
1. **Routing & Runtime Recovery** – Restored Compose execution path via `exec_compose_stream` in `src/core/rpc.ail`, with proper call splitting and result construction.
2. **Env Server Endpoints** – Reinstated `/exec-ailang` and `/compose` endpoints in the environment server, reconnecting the compose loop (author/check/run/retry/result).
3. **Parse Robustness** – Extended parser in `src/core/parse.ail` to handle root-object tool-call payloads like `{"tool":"Compose",...}`; tests passed.
4. **Snippet Extraction Hardening** – Added multiple extraction strategies (beyond strict ```ailang fences) and early-stop logic for repeated empty snippets.
5. **Authoring Failure Visibility** – Introduced `compose_author_error` events and fallback to non-stream author calls on streaming failure, providing compact failure details.
6. **Streaming Fixes** – Fixed stream helper import (`callStreamResult`), string interpolation, and expanded delta parsing compatibility for `thinking_delta`, `assistant_delta`, `text_delta` deltas.
7. **Teacher Prompt Source-of-Truth** – Compose now loads the full teacher prompt from `v0.12.1.md` verbatim, replacing the earlier stub.
8. **Phase 6 Status** – Marked Phase 6 completed on 2026-04-21 in the rebase-forward plan.

## Architecture Highlights
- The [[concepts/compose]] component integrates with the [[concepts/env-server]] for streaming execution and with the parser for tool-call JSON.
- [[concepts/streaming]] involves NDJSON events and fallback mechanisms between streaming and non-streaming calls.
- [[concepts/teacher-prompt]] is now directly sourced from a versioned markdown file, avoiding derived or truncated prompts.
- [[concepts/ailang-parsing]] now supports both array and object-shaped tool calls, improving compatibility with various LLM output styles.

## Validation
All checks (`ailang check`, `ailang test`, `npm build`) passed after each patch, confirming system integrity.