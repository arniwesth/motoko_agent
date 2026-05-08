---
doc_type: short
full_text: sources/2026-03-30-ailang-swe-agent-extensions.md
---

# AILANG SWE Agent Extensions: Custom System Prompt

## Motivation

The hardcoded system prompt in `swe/prompts.ail` limited per-repo customization. Introducing a `SYSTEM_MD` environment variable allows using a version-controlled `SYSTEM.md` file to override the prompt, enabling tailored agent behavior without modifying source code.

## Key Changes

- **Environment variable `SYSTEM_MD`** — points to a file whose content is used verbatim as the system prompt. Falls back to the built-in `base_system(cwd)` when unset or file missing.
- **File i/o in `swe/rpc.ail`** — the `main` function now imports `readFile` and `fileExists` from `std/fs`, with `FS` capability added to its effect signature.
- **Precedence** — if `SYSTEM_MD` is set and the file exists, its content is used; otherwise the default `base_system` is employed. In both cases, the trajectory cache hint (`with_cache_hint`) is appended when available.
- **TUI integration** — `tui/src/brain.ts` passes the `FS` capability to the runtime; `tui/src/index.ts` documents the new env var.

## Usage

```bash
SYSTEM_MD=/path/to/SYSTEM.md node tui/dist/index.js "Fix the regression"
SYSTEM_MD=./SYSTEM.md WORKDIR=/repo node tui/dist/index.js "..."
# Unset -> built-in
node tui/dist/index.js "Fix the regression"
```

## Unchanged Components
- `swe/prompts.ail` remains pure and unchanged.
- `rpc_loop` and `conversation_loop` logic does not know about the override.
- The TypeScript build still passes with zero errors.

## Concepts

- [[concepts/system-prompt-override]]
- [[concepts/environment-variable-configuration]]
- [[concepts/swe-agent-customization]]