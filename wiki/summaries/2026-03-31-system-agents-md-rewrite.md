---
doc_type: short
full_text: sources/2026-03-31-system-agents-md-rewrite.md
---

## Summary

On 2026-03-31, the AILANG agent&#39;s self-knowledge was dramatically improved by rewriting `SYSTEM.md` and `AGENTS.md`, and a critical infinite‑loop bug in the bash block protocol was fixed. Prior to these changes, the agent lacked an understanding of its own architecture and operational constraints, leading to erratic behavior on conversational prompts.

### Key Problems

- **Empty AGENTS.md** – only a placeholder; no project-specific instructions loaded despite `agents_md.ail` scanning for them at startup.
- **Generic SYSTEM.md** – contained basic SWE‑agent examples but no self‑knowledge of the agent’s architecture, brain modules, or constraints.
- **Infinite loop from bash block mandate** – both SYSTEM.md and `base_system()` insisted on exactly ONE bash block per response, but the code treats *no bash block* as `done`. This forced the LLM into an endless loop whenever the task was conversational (e.g., “Who are you?”).

### Fixes

**SYSTEM.md (complete rewrite)**
- Added a “What You Are” section describing the three‑process architecture, JSONL protocol, and environment server.
- Included an ASCII architecture diagram and a table of all 7 brain modules (`swe/*.ail`) with responsibilities.
- Clarified the bash extraction protocol: *no bash block* signals completion (matching the code’s `extract_bash` → `None` → `done` path).
- Documented JSONL protocol events and commands, state management, and rate limiting.
- Changed the constraint from “exactly ONE bash block” to “at most ONE; omit when answering.”

**base_system() in `swe/prompts.ail`**
- Reduced from 46 lines to 13, now serving only as a fallback when `SYSTEM_MD` is unset.
- The new fallback text explicitly teaches: “When you are ready to give a final answer, respond with text only — NO bash block.”

**AGENTS.md (complete rewrite)**
- Project identity, repository layout, brain boot sequence, model configuration (OpenRouter), trajectory cache mechanism, known AILANG runtime gotchas, and development workflow.

### Key Concept: [[concepts/bash-protocol]]

The fundamental improvement is aligning prompt instructions with the actual code behavior. The agent now understands that **omitting a bash block is the signal for task completion**. This prevents infinite loops and matches the `rpc_loop` logic.

### Cross‑Cutting Ideas
- [[concepts/agent-architecture]] – the three‑process model (TUI ↔ brain ↔ env‑server) now documented for the agent itself.
- [[concepts/ailang-brain-modules]] – the 7 `swe/*.ail` files form a modular brain; SYSTEM.md teaches the agent about each module’s role.
- [[concepts/task-completion-signal]] – the “no bash block = done” protocol is a critical design choice for LLM‑driven agents.
- [[concepts/infinite-loop-bug]] – a case study of how a prompt‑code mismatch can cause uncontrolled exploration.
- [[concepts/prompt-engineering]] – demonstrates the importance of precise, self‑referential prompts in autonomous agents.