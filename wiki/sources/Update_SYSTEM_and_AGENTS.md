# Plan: Optimized SYSTEM.md and AGENTS.md for AILANG Agent

## Goal

Create SYSTEM.md and AGENTS.md that teach the AILANG Agent **what it actually is** — its architecture, brain modules, protocol, tool palette, and constraints — so it operates with complete self-knowledge instead of generic SWE-agent instructions.

## Problem

Current files are inadequate:
- **SYSTEM.md**: Generic bash-only instructions with hardcoded `/testbed` paths. No knowledge of the three-process architecture, JSONL protocol, env-server, or its own brain modules.
- **AGENTS.md**: A single placeholder line. Zero project-specific guidance.

The agent knows it runs in "a bash environment" but has no mental model of *what executes the bash*, *how its thoughts reach stdout*, *what its brain modules do*, or *why certain patterns work and others don't*. This is the difference between a mechanic who knows "use a wrench" and one who understands the engine.

## What the Agent Should Know

### 1. Its Architecture (3 processes, 2 protocols)
```
TypeScript TUI (pi-tui) ──JSONL──▶ AILANG brain (swe/rpc.ail)
        │                                  │
   env-server                          std/ai (LLM)
   (POST /exec)                      extract_bash → exec
```

### 2. Its Brain Modules (swe/*.ail)
- `types.ail` — AgentState, Msg, ExecResult, StepOutcome
- `parse.ail` — extract_bash (fence priority), is_done (sentinel), parse_cwd
- `prompts.ail` — base_system, with_cache_hint, with_agents_context, fmt_msgs, fmt_obs
- `rpc.ail` — rpc_loop (50 steps), conversation_loop, main(), emit(), abort/model guards
- `env_client.ail` — HTTP POST to env-server, ExecResult decoding
- `cache.ail` — SharedMem trajectory cache (swe:traj: keys)
- `agents_md.ail` — recursive upward AGENTS.md discovery

### 3. Its Tool Palette
- **Bash is the ONLY tool.** The LLM writes ```bash blocks; AILANG extracts and executes them.
- No LLM function-calling API. No file API. No native APIs.
- File operations must use standard unix commands (find, cat, grep, sed, etc.)
- The env-server returns HTTP 200 always; exit_code in JSON body communicates failure.

### 4. Its Protocol
- **stdout**: JSONL events (session_start, thinking, proposed_cmd, obs, done, error)
- **stdin**: JSONL commands (abort, model_change, user_message, exit)
- Malformed stdin lines are silently skipped.

### 5. Its Constraints
- Each response: exactly ONE bash block
- Commands run in fresh subshells — must `cd` explicitly
- cwd tracking: agent tracks `cd /abs/path` and prepends it to every exec call
- Step budget: 50 iterations per task
- Yolo mode only: no confirm/reject

### 6. Its Workflow
1. Find and read relevant files
2. Create reproduction script
3. Edit source files
4. Verify fix
5. Submit with `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`

### 7. AGENTS.md Loading Behavior
- Scans upward from WORKDIR to root
- Loads all AGENTS.md files found
- Injects them into system prompt with path headers
- Project-level AGENTS.md overrides root-level

## Deliverables

### SYSTEM.md — Agent Self-Knowledge

Rewrite from scratch. Structure:

```markdown
# AILANG SWE Agent — Identity & Architecture

## What You Are
[One paragraph: you are the AILANG SWE agent, running as swe/rpc.ail,
communicating over JSONL with a TypeScript TUI, executing bash via
an HTTP env-server.]

## Architecture
[3-process diagram, JSONL protocol, what reads/writes what]

## Your Brain Modules (swe/*.ail)
[Brief description of each .ail module, what it does, what it imports]

## Your Interface: Bash Is Your Only Tool
[Explain the bash-block protocol, what the env-server actually does,
why there is no file API, the fence priority in extract_bash]

## JSONL Protocol
[What you emit on stdout, what you receive on stdin,
what happens on abort/model_change]

## Operating Constraints
- Exactly ONE bash block per response
- Commands run in isolated subshells; cd prefix is automatic
- 50-step budget per task
- Yolo mode only
- cwd is tracked by parse_cwd (absolute cd only)

## Recommended Workflow
[The 5-step workflow from current SYSTEM.md, expanded]

## What NOT To Do
[No file API hallucination, no LLM function-calling, no multiple bash blocks,
no assuming tools that don't exist]
```

The `base_system()` function in `swe/prompts.ail` reads this file and injects it as the system prompt (when no SYSTEM_MD env var is set). Currently it generates 11 hardcoded path examples — these should move into SYSTEM.md as patterns, and `base_system()` should be simplified to read SYSTEM.md or fall back to a minimal bootstrap.

### AGENTS.md — Project-Specific Operating Instructions

Rewrite from scratch. Structure:

```markdown
# AILANG Agent — Project Instructions

## Project Identity
[What this repo is: AILANG SWE agent built on AILANG language runtime,
fork at ailang/ (arniwesth/ailang), TUI in tui/ using pi-tui]

## Repository Layout
- `swe/*.ail` — Agent brain (types, parsing, prompts, rpc loop, env client, cache, AGENTS.md loading)
- `tui/` — TypeScript TUI (pi-tui-based terminal interface)
- `ailang/` — AILANG language runtime (fork)
- `scripts/` — Run and install scripts
- `runtime-patches/` — Runtime patches for patched builtins
- `.agent/` — Plans, research, reviews, summaries from past sessions

## How Your Brain Works
[Explain the boot sequence: main() → env vars → system prompt → rpc_loop
→ conversation_loop. Explain how AGENTS.md loading works (recursive upward scan).
Explain trajectory caching.]

## Model Configuration
[MODEL env var default, OpenRouter support, AI_STEP_DELAY_MS for rate limiting]

## Critical Gotchas
[Expression-body functions with semicolon sequencing don't work in AILANG,
export let not supported, multi-expression match arms need blocks,
_env_poll_stdin returns Option[string], etc. — collected from session summaries]

## Development Workflow
[How to build, run, test the agent]
```

## What Changes in Code

### SYSTEM.md
- **Complete rewrite**. Replace generic instructions with self-knowledge.
- The file is read by `with_agents_context` → no, actually `main()` in `rpc.ail` has `SYSTEM_MD` env var check: reads file if set, otherwise calls `base_system(cwd)`.

### swe/prompts.ail: base_system()
- Current: generates ~600 chars of hardcoded prompt with bash idioms and path examples
- After: can remain as fallback, but SYSTEM.md becomes the primary source. The `base_system()` function should be minimal — identity statement + bash-is-your-only-tool + one-line reference to SYSTEM.md content via the env var mechanism.
- **Decision**: Keep `base_system()` as a minimal fallback (in case SYSTEM.md is missing). SYSTEM.md is the authoritative document.

### AGENTS.md
- **Complete rewrite**. From one placeholder line to comprehensive project operating instructions.
- Read by `agents_md.ail:load_agents_content()` → `with_agents_context()` → injected into system prompt

### tui/src/brain.ts
- No changes needed. The env forwarding and system prompt loading already works.

### No changes to core logic
- The .ail modules don't need changes. They just consume the prompts. The improvement is purely in prompt content.

## Acceptance Criteria

1. **SYSTEM.md**: Agent reading it can answer: "What process runs me?", "How do I execute a command?", "What happens when I write ```bash?", "How does the TUI talk to me?", "What is my step budget?", "What happens on abort?"
2. **AGENTS.md**: Agent reading it can answer: "Where is my brain code?", "How does AGENTS.md injection work?", "What runtime patches are installed?", "What is the model config?", "What known gotchas exist in AILANG?"
3. `SYSTEM.md` exists at repo root and contains self-knowledge content
4. `AGENTS.md` exists at repo root and replaces the placeholder
5. Both files are concise — no filler, every paragraph teaches the agent something it couldn't infer from bash alone
6. The agent's own source code (swe/*.ail) is accurately described — no hallucinated capabilities or wrong imports
7. Known runtime limitations from session summaries are preserved as operational guidance
