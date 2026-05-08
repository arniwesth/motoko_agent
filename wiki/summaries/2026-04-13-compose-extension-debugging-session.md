---
doc_type: short
full_text: sources/2026-04-13-compose-extension-debugging-session.md
---

# 2026-04-13 Compose Extension Debugging Session

## Overview
This session transformed the Compose tool from an unstable, partially wired component into a robust extension within the core architecture. The work spanned implementation of a first‑class extension hook model, TUI streaming corrections, diagnostic noise reduction, and fixes for two critical retry failures. The result is a significantly more reliable Compose path that passes dedicated regression tests in the core suite.

## Key Implementations

### Extension Architecture & Hooks
Established an extension‑first hook chain (`on_tool_policy`, `on_tool_handle`, `on_response_intercept`) and refactored runtime routing so Compose runs as a full extension rather than ad‑hoc special casing. This involved cross‑module changes in `src/core/ext/compose/*`, `src/core/ext/*`, and `src/core/rpc.ail`. See [[concepts/compose-extension-architecture]].

### TUI Streaming Rendering
Fixed two regressions: internal Compose streams leaking into the main transcript, and missing incremental updates. Implemented internal stream ID parsing (`compose-author-*`, `compose-summary-*`, `compose-claimcheck-*`) and routed delta events into the compose card state. For details, see [[concepts/tui-compose-streaming]].

### Diagnostic Noise Reduction
Ailang check diagnostics were extremely verbose in TUI sessions. Compacted emission logic in Compose to strip `Suggestion`, `Hint`, and workaround blocks, preserving actionable errors while reducing clutter. See [[concepts/ailang-check-noise]].

### Retry Failure #1 – Invalid Module Header
Compose wrapper injected a syntactically invalid header (`module .motoko-store/snippets/<name>`) causing deterministic parse failures across retries. Fix removed the invalid header and added a sanitizer `compose_file_body` that strips user‑provided module declarations. Regression test added. See [[concepts/retry-failure-invalid-module]].

### Claimcheck Boilerplate Handling
Claimcheck evaluation was corrupted by runtime boilerplate (`→ Type checking...`, etc.). Added normalization to strip those lines before comparison. If normalized output becomes empty, the check is marked as vacuous and a corrective hint is emitted. Tests verify stripping and empty‑output handling. See [[concepts/claimcheck-runtime-noise]].

### Retry Failure #2 – Vacuous Output Loop
After stripping, many attempts still produced only boilerplate. Root cause was snippet execution with incorrect module paths (e.g., absolute path with mismatched module name). Fixed by writing snippets to relative `tmp/<name>.ail`, injecting a matching `module tmp/<name>` header, and invoking `ailang check/run` with the same relative path. This ensures actual user output is produced, ending the vacuous retry loop. See [[concepts/compose-snippet-execution]].

## Activation & Environment
Updated `Makefile` to set `CORE_EXT_ORDER=compose` and `HYBRID_TOOLS=1` for local tests; disabled legacy compose HTTP endpoints in `env-server.ts`. These changes guarantee Compose is always activated in the intended test path.

## Testing
All fixes are backed by dedicated regression tests in `compose_test.ail` and `claimcheck_test.ail`, now part of `make test_core`. TUI tests (`npm test`) confirmed 14 suites, 81 tests passing.

## Relevance
This session’s work is foundational for reliable cross‑document synthesis and agentic retry logic. It directly impacts the behavior of Compose as a first‑class tool, and the fixes for streaming, diagnostics, and claimcheck robustness improve the overall developer experience of the personal knowledge base.
