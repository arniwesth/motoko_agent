---
doc_type: short
full_text: sources/AILANG_Agent.md
---

# AILANG SWE-Agent Summary

This document presents a detailed implementation plan for a software engineering agent written in [[concepts/AILANG]] with a TypeScript terminal UI ([[concepts/pi-tui]]) and a no-confirmation "yolo" execution mode. Model selection at runtime is handled by Option D: a new `call_with(model, prompt)` builtin, deferred to an optional final phase.

## Key Decisions
- **Yolo Mode**: Every proposed command is executed immediately without user approval, simplifying the brain and frontend. See [[concepts/Yolo Mode]].
- **Option D Model Selection**: A `call_with` builtin reads the current model from SharedMem, allowing `/model` commands in the TUI to switch providers mid-session. See [[concepts/Option D Model Selection]].
- **Environment Server**: Embedded in the TypeScript process, replaces the Python server from the original plan. Exposes `/exec`, `/snapshot`, `/restore` endpoints. See [[concepts/Environment Server]].
- **JSONL Protocol**: Minimal, newline-delimited JSON over stdin/stdout between the TypeScript frontend and the AILANG brain. See [[concepts/JSONL Protocol]].

## Architecture
Three processes: TypeScript process (pi-tui UI + environment server), AILANG brain process (always yolo), and a SharedMem cache layer. The brain emits JSONL events; the TUI renders Markdown, status bar, and model picker.

## Phase Plan
- **Phase 0–1**: TypeScript scaffold, environment server.
- **Phase 2**: AILANG brain modules (`types`, `parse`, `prompts`, `env_client`, `cache`), yolo brain (`swe/rpc.ail`), and pi-tui frontend.
- **Phase 3**: [[concepts/SharedMem Cache]] layer for trajectory hints.
- **Phase 4**: Test harness and SWE-bench benchmark.
- **Phase 5 (optional)**: Implement `call_with` for live model switching; streaming variant.
- **Phase 6 (optional)**: MCP upgrade if needed.

## Build Order
1. Add `_io_poll_stdin` builtin (non-blocking stdin peek).
2. Build and test environment server.
3. Write and test each AILANG module.
4. Wire TypeScript brain pipe and UI.
5. Smoke test on a repo issue.
6. Run SWE-bench sample (target >50% pass).
7. Optional: `call_with` and streaming.

## Notable Components
- **swe/rpc.ail**: The yolo brain loop—emit, execute, observe, recurse. Uses `_io_poll_stdin` to check for abort/model change between steps.
- **tui/**: TypeScript frontend with pi-tui Editor, Markdown rendering, slash-command registry (`/model`, `/abort`) and SelectList overlay.
- **env-server.ts**: Express wrapper around `child_process.execSync` with timeout, snapshot/restore via `git stash`.

## Future Work
- Full call_with runtime model switching (Phase 5).
- Streaming token deltas to the TUI.
- Optional MCP upgrade for richer tool semantics.

The plan yields a functional SWE agent in 7–10 days (phases 0–4), with optional enhancements to follow.

## Related Concepts
- [[concepts/yolo-execution-mode]]
- [[concepts/ailang-brain-communicating-processes]]
- [[concepts/jsonl-protocol-for-agent-communication]]
- [[concepts/sharedmem-cache-layer]]
- [[concepts/terminal-ui-testing]]
- [[concepts/tool-selection-bias]]
- [[concepts/constraint-graph]]
- [[concepts/session-state-management]]
