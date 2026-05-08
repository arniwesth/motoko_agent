---
doc_type: short
full_text: sources/AILANG_Composition_Language.md
---

# AILANG as Agent Composition Language

This plan introduces **AILANG composition** as a first-class execution mode for the Motoko agent, replacing sequential tool calls with a single programmatic snippet that orchestrates multiple operations. The LLM writes an AILANG program inside a ` ```ailang ``` ` fence, which is type‑checked and executed in a sandboxed AILANG runtime, reducing step count and token usage.

## Why AILANG Instead of Python (Monty)

AILANG offers structural advantages over a Python sandbox:
- **Zero new dependencies** – the runtime is already the host process.
- **Algebraic effect sandbox** – capabilities (`IO`, `FS`, `Process`, `Net`) are granted per‑run via `--caps`, enforced at [[concepts/type-checking|type‑check time]], not at runtime.
- **Pre‑execution type checking** (`ailang check`) catches errors before side effects occur, allowing self‑correction without burning a step.
- **Z3 verification** – pure helper functions can be formally verified before execution.
- **Proven LLM fluency** – the entire `src/core/` codebase was written by LLMs, confirming practical instruction‑following.
- **Ecosystem coherence** – one language, one type system, no impedance mismatch.

## Gains for the LLM

A multi‑step sequence (e.g., `ls`, `grep`, `wc`, `git blame`) can be replaced by a single AILANG snippet that reads files, filters, and aggregates results. Intermediate data never enters the context window, reducing token consumption and step budget.

## Architectural Design

### Execution Flow
1. Extract AILANG snippet from response → write to temp file → `ailang check` → on error retry → `ailang run --caps <granted>` → observe result.
2. The brain’s step handler tries JSON tools first, then AILANG, then legacy bash.

### Capability Control
- Capability level is chosen per task (read‑only, read‑write, network, full). The LLM declares effects; the brain grants a subset; if the snippet exceeds caps, type‑check rejects it.
- [[concepts/sandboxing|FS sandbox]] via `AILANG_FS_SANDBOX` jails all file operations to a workspace, including a `.motoko-store/` for persistent intermediate results across snippets.

### Integration with Existing Tools
AILANG composition is a peer execution mode, not a tool call. It coexists with JSON tool calls and legacy bash, with clear priority and collision rules.

## Implementation Phases

- **Phase 0** – Fence extraction (`extract_ailang` in `src/core/parse.ail`).
- **Phase 1** – Snippet execution endpoint (`POST /exec-ailang`) in the env‑server, with temp file management, sandboxing, and result store.
- **Phase 2** – Brain integration: separate code path in `rpc.ail`, type‑check retry loop, and emission of `proposed_ailang` events.
- **Phase 3** – Prompt engineering: mode selection guidance, a ~2K‑token compressed reference card, and few‑shot examples.
- **Phase 4** – Type‑check feedback loop with targeted error backtracking (line & category → relevant doc section).
- **Phase 5** – Optional Z3 verification for pure functions with contracts.

## Prompt & Doc Injection Strategy

A compressed **AILANG reference card** (~2K tokens) is always injected. On type‑check failure, **progressive document disclosure** adds only the relevant error‑category docs. Cached snippets from the trajectory store can be added as few‑shot examples later. This avoids the 22K‑token full docs.

## Security Model

- Effect‑based capability enforcement at type‑check time.
- `AILANG_FS_SANDBOX` prevents path traversal.
- No access to brain’s SharedMem or AI capabilities.
- Timeout enforcement by the env‑server.

## Key Influences

- **Pydantic Monty** – the idea of replacing tool menus with sandboxed code execution.
- **LLMVM** – adopted targeted error backtracking and session‑scoped result persistence (`.motoko-store/`).

## Related Concepts

- [[concepts/effect_system|Effect System]] – Used for sandboxing and capability grants.
- [[concepts/type-checking|Type‑checking]] – Pre‑execution safety gate.
- [[concepts/sandboxing|Sandboxing]] – FS jail and capability control.
- [[concepts/agent_composition|Agent Composition]] – Programmatic multi‑step orchestration.
- [[concepts/prompt_engineering|Prompt Engineering]] – Compressed reference cards and progressive disclosure.
- [[concepts/zero_dependency_integration|Zero‑Dependency Integration]] – Using existing runtime instead of external sidecars.
