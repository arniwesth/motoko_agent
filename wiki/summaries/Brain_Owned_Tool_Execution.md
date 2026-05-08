---
doc_type: short
full_text: sources/Brain_Owned_Tool_Execution.md
---

# Brain-Owned Tool Execution Summary

## Overview

This plan moves all normal tool execution from the TUI's HTTP `/exec` endpoint into the AILANG brain itself, leveraging native `std/process` and `std/stream` primitives. The TUI becomes a pure presentation and control layer, while the brain owns reasoning, tool lifecycle, process state, truncation, and typed observations.

## Architectural Change

The current `rpc_loop` sends commands to `env-server` via `exec_in()`. The new design parses model JSON tool calls, dispatches them via `run_tool_batch()` directly within AILANG, and emits typed lifecycle events to the TUI. The brain's effect signature changes from `Net` to `Process` and `Stream`. This aligns with a stronger thesis: the entire agent runtime is inspectable, typed, and controllable inside AILANG. See [[concepts/brain_owned_execution]] and [[concepts/TUI_roles]].

## Key Design Principles

The plan adopts state-of-the-art patterns:
- **Correlation IDs** mandatory for every tool call ([[concepts/correlation_ids]])
- **Typed tool interfaces**: ADTs like `Bash`, `ReadFile`, `Search`, `WriteFile`, `RunTests` instead of raw shell commands ([[concepts/tool_adts]])
- **Machine-readable tool schema** in the system prompt ([[concepts/tool_schema]])
- **Incremental streaming** of stdout chunks for visibility ([[concepts/streaming]])
- **Bounded output** with explicit truncation metadata, hashes, and byte counts ([[concepts/truncation_policy]])
- **Brain‑owned cancellation** via closing stream sources and abort markers ([[concepts/cancellation]])

## Tool Model

Tool calls are parsed from JSON into a `ToolCallReq` ADT. Phase 1 keeps `Bash` only; later phases add semantic tools like `ReadFile`, `Search`, `WriteFile`, `RunTests`. Results carry typed metadata: exit codes, truncated flags, hashes, and byte totals. The model-facing observation formatter selects relevant fields, while the TUI receives richer events. See [[concepts/tool_results]].

## Streaming and Output Management

The brain emits `tool_call_start`, `tool_stdout_chunk`, `tool_call_finish` events. A per‑call cap on stdout (e.g., 16 KB) and stderr (8 KB) prevents context-window overflow. When clipping, prefix-only or prefix+suffix strategies are used, and full‑output hashes are always stored. Truncation metadata becomes part of the result ADT. [[concepts/output_limits]]

## Cancellation and Concurrency

`abort` from stdin is consumed by the brain. If tools are running, active stream sources are closed; for synchronous `exec`, abort is observed at the next loop boundary. The brain runs a batch of tool calls (one LLM step → N calls) with a simple concurrency policy: read-only tools may start immediately, most use synchronous `exec`, and streaming is used only for long‑running stdout commands. The scheduler tracks active tools by ID. [[concepts/concurrency_model]]

## TUI Simplification

The TUI no longer dispatches tools. It spawns the brain, renders events (chunks, finishes, warnings), and forwards `abort`/`model_change`/user messages. `env-server.ts` is removed from the normal path. This eliminates `tool_calls`/`tool_results` round‑trips and class‑of‑step‑mismatch bugs. [[concepts/thin_tui]]

## Implementation Phases
1. **Types** – Add ADTs for requests, results, statuses; remove `env_url`.
2. **Parser** – JSON tool parsing with `ParseToolCalls` ADT, warnings for unsupported tools.
3. **Tool runtime** – `swe/tool_runtime.ail` wrapping `std/process.exec` and `asyncExecProcess`, truncation, events, cancellation.
4. **rpc_loop rewrite** – Replace `exec_in()` with `run_tool_batch()`, emit events, append observations.
5. **Prompt rewrite** – Schema‑bearing instructions, ID/working‑directory rules, batching guidance.
6. **TUI simplification** – Remove tool dispatch, render streaming events.
7. **Named tools** – Add `ReadFile`, `Search`, `WriteFile`, `RunTests`.

[[concepts/implementation_phases]]

## Research Roadmap

Immediate work uses current AILANG capabilities (per‑runtime working directory, per‑call timeouts). The document proposes future runtime extensions:
- Per‑call `cwd` and timeout/output limits
- AILANG‑level process termination
- Stderr streaming
- Unified subprocess API
- Typed execution schemas and bounded‑stream collectors
These would further strengthen brain‑owned execution. [[concepts/runtime_extensions]]

## Success Criteria

The plan is satisfied when `env_client.ail` is deleted, the brain’s effect signature contains `Process`/`Stream`, long‑running commands stream progress, oversized outputs are clipped, every event is correlated by ID, and the TUI stops dispatching tools.

This summary captures the architectural shift, design principles, and implementation strategy of the brain‑owned tool execution plan.