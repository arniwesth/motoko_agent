---
doc_type: short
full_text: sources/Core_Rebrand_Phase0_Inventory.md
---

# Summary: Core Rebrand Phase 0 Inventory

## Purpose
Establish a precise migration boundary and rename map before any code moves, preventing incomplete or contradictory changes.

## Scope Boundary
Files to migrate (active):
- Runtime code (`swe/*.ail`, `tui/src/*`, runner scripts)
- Active project docs (`README.md`, `SYSTEM.md`, `AGENTS.md`, `CLAUDE.md`, `prompts.md`)
- Build/test plumbing (`Makefile`)

Intentionally excluded:
- `.agent/plans/**`, `.agent/summaries/**`, `.agent/research/**`
- `node_modules/**`, `tui/dist/**`, vendored `ailang/**` (unless a direct blocker)

## Discovery Approach
Used ripgrep to locate all references to "swe", including module paths and string literals, across source, docs, and scripts.

## Classification of Changes
- **A – Runtime-Critical**: Core `.ail` files, TUI entry points, Makefile targets. Must change in Phase 1.
- **B – Dev/Test/Tooling**: Test files, helper scripts, comments. Should change in same PR.
- **C – Active Documentation**: README, SYSTEM, AGENTS, CLAUDE, prompts. Defer to Phase 3/4 after runtime is verified.
- **D – Historical/Archival**: `.agent/` tree; stays untouched.

## Directory and Module Rename Map
- Directory: `swe/` → `core/`
- Module declarations: `module swe/xxx` → `module core/xxx`
- Imports: `import swe/...` → `import core/...`
- Entry points: `tui/src/brain.ts` (`swe/rpc.ail` → `core/rpc.ail`), `tui/src/index.ts` (`swe/version.ail` → `core/version.ail`)
- SharedMem prefix updates: `swe:current_model` → `core:current_model`, `swe:traj:*` → `core:traj:*` (with read fallback for old keys in Phase 2)

## Risks Identified
1. **AILANG module-path rules** require atomic updates of both the file location and the `module` declaration (see [[concepts/atomic migration]]).
2. **Script and test text checks** that grep for "swe" identity strings may fail after the rename and must be updated together (see [[concepts/rebrand testing]]).
3. **Completeness gate**: a deterministic validation step is needed after edits to confirm all references were changed (see [[concepts/migration validation]]).

## Phase 1 Readiness
With this inventory, the mechanical migration can proceed:
- Apply category A and B changes atomically.
- Leave category D alone.
- Postpone category C for documentation rewrite phases once the runtime is green.

This plan directly feeds into [[concepts/rebrand migration]] execution.