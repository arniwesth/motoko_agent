---
doc_type: short
full_text: sources/Hybrid_Tool_Execution.md
---

# Hybrid Tool Execution Summary

This document proposes a **hybrid architecture** for the tool execution system of an AI agent (the brain) that integrates two backends: **native execution** within the AILANG runtime and **delegated execution** via the Terminal UI (TUI). The design preserves the brain as the semantic owner of tool calls, tool parsing, batching, and observation shaping, while using the TUI only as a capability extension for execution modes not yet supported by AILANG.

## Core Idea
- The brain owns the entire tool lifecycle: parsing, schema, IDs, warnings, batch control, and observation formatting.
- A single typed tool system is split at the execution layer into [[concepts/backend-selection|backend selection]] (native vs delegated).
- The TUI is not a co-equal tool runtime; it is a **delegation layer** invoked only when the native runtime cannot handle a call (e.g. streaming stderr, per-call cwd, hard cancellation).

## Responsibilities
- **Brain-owned**: JSON parsing, correlation IDs, schema construction, unsupported-tool warnings, batching rules, observation formatting, message history, conversational cwd state.
- **Native execution**: Semantic file tools (`ReadFile`, `Search`, `WriteFile`) and synchronous process execution via `std/process.exec`.
- **Delegated execution** (via TUI): Streaming subprocesses with stderr, per-call cwd, hard-cancelable processes, advanced interactive subprocesses.

## Key Architectural Choices
### Backend Selection
A deterministic function (`backend_for`) chooses the backend per tool call based on capabilities (streaming, stderr, cwd, cancellation). No shell metacharacters are allowed in native execution; shell-dependent commands are delegated. See [[concepts/backend-selection]] for details.

### Unified Tool Model
A typed ADT family (`ToolCallReq`, `ProcessExecReq`) expresses semantic tool intent without exposing backend details. The model reasons about tools, not about brain vs TUI. [[concepts/tool-call-adt|Tool Call ADT]]

### Result Normalization
All results, whether native or delegated, are normalized into a single `ToolResultItem` ADT (e.g., `BashExecResult`, `RunTestsResult`, `ReadFileResult`) with metadata like truncation, byte counts, and hashes. The LLM sees one consistent observation surface. [[concepts/result-normalization]]

### Batching
Native and delegated calls can coexist in one batch. The brain may split a model-proposed batch internally if backend constraints force it, maintaining the invariant that independent calls execute in one step. [[concepts/batching-semantics]]

### Streaming
- Native: stdout-only streaming via `std/stream.asyncExecProcess`.
- Delegated: richer streaming (stderr, cancellation) when needed.
- The brain retains ownership of IDs, event meaning, truncation, and result shaping.

### Cancellation
Hybrid: synchronous native calls cancel at the next loop boundary; native streaming calls close streams on abort; delegated calls are aborted immediately via the TUI. The brain defines abort semantics and result shaping. [[concepts/cancellation-model]]

### CWD Model
Conversational cwd is brain-owned. Native process execution uses runtime cwd; for per-call cwd requirements, delegation is used. This avoids masking native limitations. [[concepts/cwd-model]]

### Delegation Protocol
A strict message contract over stdin/stdout handles `tool_calls`, `tool_results`, `tool_stream`, and `tool_cancel_ack` with request/call correlation IDs. Inboxes queue unknown messages, and timeouts are enforced. [[concepts/delegation-protocol]]

## Phased Implementation
1. **Runtime readiness**: feature flags, capabilities.
2. **Unified tool ADTs**: typed model, IDs, schemas.
3. **Native runtime**: file tools + `std/process.exec`.
4. **Delegation protocol**: TUI integration, normalization.
5. **Mixed-batch orchestration**: seamless native+delegated batches.
6. **Streaming support**.
7. **Prompt & schema refinement**.

## Success Criteria
The brain remains the semantic owner; native execution is used where AILANG is strong; delegation is limited to unsupported modes; results are normalized; unsupported tool warnings remain visible; correlation IDs span both backends; delegated surface is explicit; no stdin message loss; deterministic backend selection.

## Migration & Research Trajectory
Near term: native semantic tools + synchronous exec, with delegated advanced subprocesses. Medium term: shrink delegated surface as AILANG improves. Long term: aim for rare or zero delegation.

This hybrid plan is recommended as the strongest current design given AILANG constraints, balancing research value with practical execution capabilities.