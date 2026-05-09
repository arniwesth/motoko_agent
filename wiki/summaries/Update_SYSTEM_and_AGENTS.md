---
doc_type: short
full_text: sources/Update_SYSTEM_and_AGENTS.md
---

# Summary: Updating SYSTEM.md and AGENTS.md for AILANG Agent

This plan outlines a complete rewrite of two critical agent prompt files, replacing generic instructions with deep self-knowledge about the AILANG SWE agent's architecture, communication protocol, brain modules, and operational constraints. The goal is to move from a mechanic who "knows how to use a wrench" to one who understands the entire engine.

## Motivation
- Current `SYSTEM.md` offers only hardcoded bash tips and path examples, with no explanation of the three‑process architecture or the JSONL protocol.
- `AGENTS.md` is a single placeholder line, lacking any project‑specific guidance.
- The agent needs a mental model of *what* executes its commands, *how* its thoughts reach stdout, and *why* certain patterns (like single bash blocks or `cd` tracking) matter.

## What the Agent Should Know

### Architecture & Protocols
- Three processes: TypeScript TUI (`pi-tui`), AILANG brain (`swe/rpc.ail`), and an HTTP env‑server (`POST /exec`).
- JSONL communication: the TUI sends/receives JSONL lines on stdin/stdout; the brain parses them with `std/ai`.
- All commands are extracted from LLM responses as ```bash
``` blocks by `extract_bash`; there is no file API or function‑calling interface. See [[concepts/bash as only tool]].

### Brain Modules (`swe/*.ail`)
- **types.ail** – AgentState, Msg, ExecResult definitions.
- **parse.ail** – Command extraction (`extract_bash`), sentinel detection (`is_done`), `cd` path parsing.
- **prompts.ail** – System prompt assembly, message formatting, observation rendering.
- **rpc.ail** – Main loop, conversation loop, step budget (50), abort/model guards.
- **env_client.ail** – HTTP execution and result decoding.
- **cache.ail** – SharedMem trajectory caching.
- **agents_md.ail** – Recursive upward scan for `AGENTS.md` files (see [[concepts/AGENTS.md loading]]).

### Constraints
- Exactly **one** bash block per response.
- Commands run in fresh subshells; a tracked `cwd` (from `parse_cwd`) is prepended automatically.
- Yolo mode only – no confirmation.
- Step budget: 50 iterations.
- The env-server always returns HTTP 200; failure is signaled by `exit_code` in the JSON body.

### Workflow
A refined five‑step pattern: find relevant files → reproduce the issue → edit source → verify fix → submit with `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`.

## New File Structures

### SYSTEM.md (Agent Self‑Knowledge)
1. **What You Are** – identity as the AILANG SWE agent.
2. **Architecture** – diagram and explanation of the three processes and JSONL protocol.
3. **Your Brain Modules** – per‑module description and their role.
4. **Bash Is Your Only Tool** – how command extraction works, why there is no file API, fence priority.
5. **JSONL Protocol** – what is emitted (`session_start`, `thinking`, `obs`, `done`, etc.) and received (`abort`, `model_change`).
6. **Operating Constraints** – single bash block, subshell isolation, step budget, yolo mode, `cwd` tracking.
7. **Recommended Workflow** – the five‑step procedure.
8. **What NOT To Do** – warnings against hallucinating file APIs, multiple bash blocks, or LLM function‑calling.

### AGENTS.md (Project‑Specific Instructions)
1. **Project Identity** – repo structure and forks.
2. **Repository Layout** – key directories (`swe/`, `tui/`, `ailang/`, `.agent/`).
3. **How Your Brain Works** – boot sequence, system prompt injection via `SYSTEM_MD` env var or `base_system()`, AGENTS.md loading mechanism.
4. **Model Configuration** – defaults, OpenRouter support, `AI_STEP_DELAY_MS`.
5. **Critical Gotchas** – known AILANG language limitations (expression‑body semicolon sequencing, `export let`, multi‑expression match arms, `_env_poll_stdin` return type) drawn from past sessions.
6. **Development Workflow** – building, running, and testing the agent.

## Code Impact
- `SYSTEM.md` becomes the primary prompt source when the `SYSTEM_MD` environment variable is set; `base_system()` in `swe/prompts.ail` is reduced to a minimal fallback.
- `AGENTS.md` completely replaces the placeholder; its content is injected via `agents_md.ail:load_agents_content()` and `with_agents_context()`.
- Core `.ail` modules require **no logic changes** — only the prompt content improves.

## Related Concepts
- [[concepts/AILANG agent architecture]]
- [[concepts/JSONL protocol]]
- [[concepts/bash as only tool]]
- [[concepts/AGENTS.md loading]]
- [[concepts/agent self-knowledge]]
- [[concepts/brain modules]]
- [[concepts/constraints and step budget]]
- [[concepts/yolo mode]]
- [[concepts/AILANG language gotchas]]

This plan ensures the agent operates with complete awareness of its own design, enabling more reliable and predictable behavior in real‑world tasks.