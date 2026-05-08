# Branch Summary: TUI Refactor, OpenRouter Integration & Scripts Cleanup

## Overview
This branch focuses on modernizing the TUI interface, integrating OpenRouter model support, cleaning up the repository by removing obsolete scripts and build artifacts, and updating core documentation and agent memory.

## Key Changes

### 🎨 TUI & Frontend Enhancements
- **Slash Commands**: Implemented a slash-command registry (`tui/src/commands.ts`) with unit tests (`/model`, `/abort`, etc.).
- **OpenRouter Integration**: Added model presets and dynamic model switching support (`tui/src/models.ts`, `tui/src/brain.ts`).
- **UI Improvements**: Refactored layouts (`tui/src/ui.ts`), added ASCII logo generation (`tui/src/ascii-logo.ts`, `misc/imageToAscii.ts`), and improved terminal rendering.
- **Build Hygiene**: Deleted accidentally committed build artifacts (`tui/dist/*`) and updated `.gitignore` to prevent recurrence.

### 🧹 Scripts & Repository Cleanup
- **Mass Script Removal**: Deleted ~40 obsolete scripts (~3500 lines) related to legacy Docker security configurations, remote execution, and Pi/OMP/YUPI environment setup (`scripts/` directory).
- **Makefile Simplification**: Streamlined `Makefile` targets to match the current project structure.

### 🧠 Brain & Runtime Modules
- **Parsing Fixes**: Corrected robustness issues in `swe/parse.ail`.
- **Prompt Engine**: Updated `swe/prompts.ail` to support dynamic system prompt construction, including upward-scanning `AGENTS.md` files and SharedMem trajectory cache hints.

### 📚 Documentation & Metadata
- **Updated Core Docs**: Rewrote and expanded `AGENTS.md` and `SYSTEM.md` to reflect current architecture, runtime gotchas, and development workflows.
- **Agent Memory**: Populated `.agent/plans/`, `.agent/research/`, `.agent/reviews/`, and `.agent/summaries/` with session transcripts, architectural plans, and code review reports.
- **Added References**: `CLAUDE.md`, `References.md`, and `prompts.md` for external context and prompt templates.

## Impact
- **Codebase Size**: Reduced from +5300 lines to +3100 lines net change (heavy deletion of legacy code).
- **Developer Experience**: Cleaner repo, faster builds, structured command handling, and robust model switching.
- **Agent Capabilities**: Enhanced prompt injection pipeline supports better context awareness and trajectory caching across sessions.
