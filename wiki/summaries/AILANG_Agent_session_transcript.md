---
doc_type: short
full_text: sources/AILANG_Agent_session_transcript.md
---

# AILANG Agent Session Transcript Summary

This transcript explores how the **[[AILANG]]** language can be used to build a coding agent, particularly by reimplementing **[mini-swe-agent](/summary/mini-swe-agent)**. The conversation analyzes AILANG's design, evaluates three architectural paths, and settles on a **[[Path 3 brain-exec separation]]** architecture with a TypeScript environment server and a `pi-tui` frontend.

## AILANG's Design Principles
- No loops (only map, fold, filter, recursion) → guaranteed termination.
- Algebraic effects (`IO`, `FS`, `Net`, `AI`, `Shell`) enforce capability constraints before execution.
- Hindley-Milner type inference with structured JSON errors helps LLMs self-correct.
- Deterministic evaluator, replayable traces.
- Built-in **SharedMem** and **SharedIndex** for semantic memory, deduplication, and embedding search.

These properties make AILANG a safer, more auditable substrate for agent loops than general-purpose languages.

## Tool Calls as Code Snippets
Inspired by smolagents, the agent expresses actions as code snippets rather than JSON tool-call schemas. AILANG's type system validates snippets statically, and capabilities are enforced by effect annotations. The agent palette composes multiple tool calls in a single expression (e.g., `fetch_page(search(...))`).

## `_ailang_eval` as a Runtime Builtin
The transcript estimates the effort for a `_ailang_eval` builtin (from 1–3 days for a fresh-environment string-in/string-out design to weeks for full caller-scope inheritance). The planned immediate implementation returns a string, deferring deeper integration to later phases.

## Three Paths for Implementing mini-swe-agent
Three approaches to port the ~100-line bash-only mini-swe-agent to AILANG are evaluated:

1. **Path 1 — Shell Effect**: Add a `Shell` effect to AILANG, port the loop with explicit message history and capability flags. Compatible with existing SWE-bench scores; ~1–3 days.
2. **Path 2 — Pure AILANG**: Replace all bash operations with AILANG stdlib functions; only subprocess calls remain a gap. Yields a safe, cache-accumulating agent but loses reproduce-and-verify loop, likely reducing accuracy significantly.
3. **Path 3 — Brain-Exec Separation**: AILANG handles reasoning (LLM calls, message history, caching) via `! {Net, AI, SharedMem, IO}`, while a separate environment server (TypeScript) sandboxes execution via HTTP. This is the chosen path for its clean capability separation, parallel environment support, and future extensibility.

## Chosen Architecture (Path 3 + Yolo Mode)
- **Always-yolo mode** eliminates manual confirm/reject/human logic, simplifying the brain. The `rpc_loop` is a pure recursive function that extracts bash commands from LLM responses and executes them via `exec_in(env_url, cmd)`.
- **All file operations** (list, read, edit, test) go through bash commands on the environment server. The brain's `FS` effect is dropped entirely — only `Net` is needed for HTTP calls.
- **Model selection** uses **Option D**: a `call_with` builtin reads the active model from **SharedMem** (`config:current_model`). Phases 0–4 fix the model at startup; phase 5 adds true mid-session switching. This preserves the `AI` effect in types and traces, and keeps `--ai-stub` testing intact.
- The **LLM tool-calling API** (OpenAI/Anthropic function‑calling) is not used; the LLM outputs plain bash blocks, matching mini-swe-agent’s approach.

## Frontend and Environment Server
- **pi-tui** provides a TypeScript terminal UI with differential rendering, Markdown support, and proper Ctrl+C handling. Communication with the AILANG brain uses a **JSONL protocol** over stdin/stdout.
- The environment server (`env-server.ts`) replaces the original Python server; it runs `execSync` inside Docker or locally, accepting commands via `POST /exec`.

## Additional AILANG Details
- **Memory management**: AILANG values are garbage‑collected via Go's GC; recursion depth is bounded explicitly; SharedMem persists across runs.
- **Arrays**: O(1) access via `#[T]` but immutable (set is O(n) copy); lists are the default.
- **Dictionaries**: No built-in map type; records offer fixed-key compile-time dictionaries, JSON module uses linear‑scan on key‑value pairs, and SharedMem serves as persistent key‑value store.
- **OpenRouter**: Not supported in AILANG's current provider set (Anthropic, OpenAI, Google). Addition would require a `baseURL` override in the OpenAI client, deferred to phase 5.

## Key Decisions Summary
| Decision | Approach |
|----------|----------|
| Architecture | Path 3: AILANG brain + TypeScript env server |
| Execution mode | Always yolo |
| File access | All via bash, not `std/fs` |
| Model selection | Option D: `call_with` + SharedMem |
| Tool calling | LLM writes bash blocks, no API schema |
| Frontend | pi-tui (TypeScript) |
| Env server | TypeScript (express) |
| OpenRouter | Not in phases 0–4; possible later |

## Plan and Build Order
Phases 0–4 cover the scaffold, env server, AILANG brain modules, `swe/rpc.ail` yolo loop, pi-tui frontend, and SharedMem cache – total 7–10 days. Phase 5 adds `call_with` and streaming; phase 6 upgrades the protocol to MCP.

See also: [[AILANG tool calling]], [[AILANG memory management]], [[SharedMem for model switching]], [[pi-tui frontend]]