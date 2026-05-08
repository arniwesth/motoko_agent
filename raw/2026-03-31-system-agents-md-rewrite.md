# Optimized SYSTEM.md and AGENTS.md + Bash Block Loop Fix — 2026-03-31

## What was done

Created comprehensive SYSTEM.md and AGENTS.md documents that give the AILANG agent self-knowledge of its own architecture, brain modules, and operating constraints. Fixed the "exactly ONE bash block" instruction that caused infinite exploration loops on conversational prompts.

## Problems Identified

### 1. Empty AGENTS.md

AGENTS.md contained only a placeholder line. The agent had no project-specific operating instructions despite agents_md.ail scanning for and loading them at startup.

### 2. SYSTEM.md was generic

SYSTEM.md contained basic SWE-agent idioms (find, grep, sed examples) but no knowledge of the agent's own architecture, protocol, brain modules, or constraints. The agent didn't understand itself.

### 3. Bash block instruction contradiction (infinite loop bug)

SYSTEM.md and `base_system()` in `swe/prompts.ail` both said:

> "Each response MUST contain exactly ONE bash block"

But the code treats **no bash block** as task completion (`extract_bash` returns `None` → `done`). This created an infinite loop on conversational prompts like "Who are you?" — the LLM was forced to keep producing bash blocks even when answering, never reaching a terminal state. It would run exploratory commands indefinitely until hitting the 50-step limit.

## Fix

### SYSTEM.md (complete rewrite)
- Added "What You Are" section: describes the three-process architecture, JSONL protocol, environment server
- Added "Architecture" section: ASCII diagram of TUI ↔ brain ↔ env-server
- Added "Brain Modules" table: describes all 7 swe/*.ail files and their responsibilities
- Added "Bash Is Your Only Tool" section: explains the bash extraction protocol including the critical fact that **no bash block = `done`**
- Added JSONL protocol tables: events emitted (stdout) and commands received (stdin)
- Added State Management, Rate Limiting sections
- Fixed bash block constraint from "exactly ONE" to "at most ONE; omit when answering"

### base_system() (swe/prompts.ail)
Simplified from 46 lines to 13 lines of essential rules. SYSTEM.md is now the authoritative prompt; base_system() serves only as a fallback when SYSTEM_MD env var is unset:

```
BASH BLOCKS — HOW THEY WORK:
When you need to run a command, include a bash block.
When you are ready to give a final answer, respond with text only — NO bash block.
A response with no bash block signals task completion.

CRITICAL RULES:
- Include a bash block ONLY when you need to execute a command
- At most ONE bash block per response; only the first is executed
- Omit the bash block when answering or concluding
- Do not keep searching after you have enough information
- Every command runs in a fresh subshell — use `cd <WORKDIR> && cmd`
- All file and repo access goes through bash — there is no native file API
- When done, submit with: echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
```

### AGENTS.md (complete rewrite)
- Project identity and repository layout
- Brain boot sequence explained end-to-end
- AGENTS.md loading behavior
- Model configuration and OpenRouter support
- Trajectory cache mechanism
- Known AILANG runtime gotchas from six debugging sessions
- Development workflow (check, run, build, test)

## Files changed

| File | Change |
|---|---|
| `SYSTEM.md` | Complete rewrite: 330 → 157 lines of self-knowledge content |
| `AGENTS.md` | Complete rewrite: placeholder → 176 lines of project instructions |
| `swe/prompts.ail` | `base_system()` simplified: 46 → 13 lines |

## Bash block loop fix

The contradictory instruction ("MUST produce exactly one bash block" vs code treating none-as-done) caused the agent to loop indefinitely on conversational tasks. Now all prompt sources teach the LLM that **omitting the bash block signals completion**, which matches the actual code behavior:

```
LLM response with no bash block
  → extract_bash returns None
    → rpc_loop emits done event
      → TUI shows result, enters follow-up mode (TTY) or exits (PlainLogger)
```

This fix applies to both code paths:
- SYSTEM.md via `SYSTEM_MD` env var (primary)
- `base_system()` fallback via `swe/prompts.ail` (fallback)

## How it works at startup

1. `main()` in `swe/rpc.ail` reads env vars
2. If `SYSTEM_MD` set and file exists → read verbatim; else → `base_system(WORKDIR)`
3. `with_agents_context()` → scans upward for AGENTS.md files, injects them
4. `with_cache_hint()` → appends trajectory cache hits
5. System prompt → LLM → 50-step `rpc_loop` → `conversation_loop` for follow-ups

The agent's own AGENTS.md at repo root is loaded in every session, providing project-specific operating context to all sessions running in this workspace.
