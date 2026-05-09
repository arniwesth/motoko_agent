---
doc_type: short
full_text: sources/2026-03-31-branch-cleanup-tui-openrouter.md
---

# Branch Summary: TUI Refactor, OpenRouter Integration & Cleanup

This branch upgrades the terminal interface, integrates OpenRouter model switching, performs extensive repository cleanup, and enhances agent memory and documentation.

## Key Contributions

### 🎨 TUI Modernization
- Implemented a slash-command registry (`[[concepts/tui-slash-commands]]`) with unit-tested commands like `/model` and `/abort`.
- Added dynamic OpenRouter model presets and switching via `[[concepts/openrouter-integration]]`.
- Refactored terminal UI layouts and added ASCII logo generation (`[[concepts/ascii-logo-generation]]`).
- Cleaned up accidental build artifacts and updated `.gitignore` to prevent future leaks.

### 🧹 Repository Cleanup
- Deleted ~40 obsolete scripts (~3500 lines) covering legacy Docker security, remote execution, and Pi/OMP/YUPI setups (`[[concepts/repository-cleanup]]`).
- Simplified the `Makefile` to match the current project structure and remove dead targets.

### 🧠 Brain & Runtime Enhancements
- Fixed robustness issues in `swe/parse.ail` (`[[concepts/brain-module]]`).
- Updated the prompt engine in `swe/prompts.ail` to support dynamic system prompts using upward-scanning `AGENTS.md` files and trajectory cache hints from SharedMem (`[[concepts/prompt-engine]]`).

### 📚 Documentation & Agent Memory
- Rewrote core docs (`AGENTS.md`, `SYSTEM.md`) to reflect current architecture and runtime gotchas.
- Populated `.agent/` directories with plans, research, reviews, and summaries (`[[concepts/agent-memory]]`).
- Added external references (`CLAUDE.md`, `References.md`, `prompts.md`) for better context sharing.