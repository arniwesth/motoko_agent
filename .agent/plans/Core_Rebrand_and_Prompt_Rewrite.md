# Plan: `swe` → `core` Rebrand + Prompt Identity Rewrite

## Goal

Reposition this project from a SWE-agent identity to an **agent harness research platform** by:
- Renaming the brain namespace and folder from `swe` to `core`
- Rewriting `SYSTEM.md` and `AGENTS.md` to reflect harness-first goals
- Preserving runtime behavior and compatibility during migration

## Why This Change

Current naming and docs encode a narrow product identity ("SWE agent") that no longer matches actual scope (tool/runtime orchestration, protocol evolution, self-modification, harness experimentation).

The rename should make architecture intent legible in code, docs, and runtime keys.

## Scope

In scope:
- AILANG module path migration (`module swe/...` → `module core/...`)
- Directory migration (`swe/` → `core/`)
- Import/call-site updates across AILANG + TypeScript + scripts + docs
- SharedMem key migration (`swe:*` → `core:*`) with temporary backward read compatibility
- Rewrite of root `SYSTEM.md` and `AGENTS.md`

Out of scope:
- Functional redesign of rpc loop/protocol semantics
- New runtime builtins or effect model changes
- Benchmarks/perf tuning (unless needed for validation)

## Architecture Decisions

1. **Canonical namespace becomes `core`**
- Files live under `core/`
- Module declarations become `module core/...`
- All imports become `import core/...`

2. **Compatibility window for state keys**
- New writes use `core:traj:*` and `core:current_model`
- Reads attempt `core:*` first, then fallback to existing `swe:*`
- Remove fallback in a later cleanup phase

3. **Prompt/document identity shift**
- `SYSTEM.md`: operational behavior + harness constraints, not SWE workflow branding
- `AGENTS.md`: internal architecture + invariants + migration-safe engineering rules
- Startup prompt-path behavior is preserved:
  - If `SYSTEM_MD` is set and exists, load it verbatim
  - Otherwise use `base_system(workdir)` fallback

4. **Two-step delivery**
- Step A: mechanical rename + compatibility
- Step B: narrative/docs rewrite

## Impacted Areas

Code:
- `swe/*.ail` (renamed to `core/*.ail`)
- `tui/src/brain.ts` (entry module path)
- `tui/src/index.ts` (version probe path)
- `Makefile` targets and test commands
- Any scripts and docs with hardcoded `swe/...`

Docs:
- `README.md`
- `SYSTEM.md`
- `AGENTS.md`
- `.agent/plans/*` references that should remain historical vs active

State/Storage:
- SharedMem key prefixes currently `swe:*`

## Execution Plan

## Phase 0 — Preflight Inventory

- Snapshot all active `swe` references in code paths (exclude archival docs unless intentionally edited)
- Classify references:
  - runtime-critical
  - dev/test commands
  - historical archive
- Define migration boundary for this PR (active files only)

Deliverable:
- Confirmed file list and rename map
- See `.agent/plans/Core_Rebrand_Phase0_Inventory.md` for the completed Phase 0 inventory and classification.

## Phase 1 — Mechanical Namespace Migration

1. Move directory:
- `swe/` → `core/`

2. Update AILANG modules:
- `module swe/...` → `module core/...`
- `import swe/...` → `import core/...`

3. Update launch points:
- Brain entry: `swe/rpc.ail` → `core/rpc.ail`
- Version probe: `swe/version.ail` → `core/version.ail`

4. Update build/test plumbing:
- Makefile check/test targets
- Any shell scripts referencing `swe/*.ail`

Deliverable:
- Project builds and type-checks against `core/*`

## Phase 2 — SharedMem Key Migration (Compatibility Mode)

1. Introduce new key prefixes:
- `core:traj:*`
- `core:current_model`

2. Read compatibility behavior:
- `get core key` → if missing fallback to `swe key`

3. Write behavior:
- write only `core:*` (or dual-write for one release if needed)

4. Document migration behavior in AGENTS/README

Deliverable:
- Existing cached trajectories/model settings still readable after rename

## Phase 3 — Doc Reframe (`SYSTEM.md`, `AGENTS.md`)

### `SYSTEM.md` rewrite goals
- Identity: "AILANG agent harness runtime"
- Tool boundary clarity: bash/tool execution model and protocol
- Runtime constraints: effects/caps, loop/step behavior, command handling
- Avoid SWE-agent framing and SWE-bench-centric language

### `AGENTS.md` rewrite goals
- Project purpose: harness research platform
- Canonical module map under `core/`
- Known AILANG/runtime gotchas and invariants
- Safe modification workflow and validation commands
- Explicit notes on historical `swe` references in archival docs

Deliverable:
- Root docs align with new identity and actual architecture

## Phase 3.5 — Prompt Path Safety Checks

- Verify explicit startup behavior after rename:
  - `SYSTEM_MD=/abs/path/to/SYSTEM.md` is loaded verbatim
  - missing/unset `SYSTEM_MD` falls back to `base_system(workdir)`
- Verify AGENTS injection behavior is unchanged:
  - upward scan still discovers `AGENTS.md`
  - injected content appears in prompt context

Deliverable:
- Prompt assembly behavior is unchanged except updated `core/*` references and new identity wording

## Phase 4 — README + Command Surface Cleanup

- Update architecture diagrams and file trees to `core/`
- Replace user-facing "SWE agent" labels with "agent harness" naming
- Ensure run/test examples use new paths
- Keep one compatibility note for users with old scripts

Deliverable:
- Clean public-facing narrative and runnable commands

## Phase 5 — Validation

AILANG checks/tests:
- `ailang check core/types.ail`
- `ailang check core/parse.ail`
- `ailang check core/prompts.ail`
- `ailang check core/rpc.ail`
- `ailang check core/env_client.ail`
- `ailang check core/cache.ail`
- `ailang check core/agents_md.ail`
- `ailang test core/parse.ail`
- `ailang test core/parse_test.ail`
- `ailang test core/agents_md.ail`
- `ailang test core/prompts_test.ail` (if present/active)

TUI validation:
- Build: `cd tui && npm run build`
- Test: `cd tui && npm test`
- Smoke: launch via `scripts/run-agent.sh` and verify session start
- Verify `/model` and `/abort` still function

Repo validation:
- `make check_swe` (to be renamed to the new `core` check target as part of migration)
- `make test_swe` (to be renamed to the new `core` test target as part of migration)

Runtime behavior:
- Confirm AGENTS context loading still works
- Confirm cache hint retrieval works with migrated key logic
- Confirm brain version probe path works (`core/version.ail`)

## Risks and Mitigations

1. **AILANG module-path strictness breaks build**
- Mitigation: atomic update of file paths + module names + imports

2. **Silent runtime break in TypeScript entry paths**
- Mitigation: explicit smoke test on startup/version probe

3. **Cache/model continuity lost**
- Mitigation: compatibility read fallback from `core:*` to `swe:*`

4. **Docs drift from implementation**
- Mitigation: update docs after code migration, then run command examples

5. **Residual `swe/` references in active runtime paths**
- Mitigation: add deterministic grep gate over active files with archival exclusions

## Acceptance Criteria

1. No active runtime file path uses `swe/` (except compatibility comments or archival docs)
2. All active AILANG modules compile under `core/*`
3. Agent starts and runs end-to-end from TUI using `core/rpc.ail`
4. `SYSTEM.md` and `AGENTS.md` describe harness identity, not SWE-agent identity
5. SharedMem compatibility works for old `swe:*` keys during transition
6. README and developer commands are consistent with `core/`
7. Residual-name gate passes:
   - `rg -n "\\bswe/|\\bmodule swe/|\\bimport swe/|\\bswe:" -S --hidden --glob '!node_modules' --glob '!tui/dist' --glob '!.agent/plans/**' --glob '!.agent/summaries/**' --glob '!.agent/research/**'`
   - no matches in active runtime code/docs/scripts

## Follow-Up (Optional Cleanup)

After one stable release cycle:
- Remove `swe:*` read fallback
- Archive or annotate historical plan/summaries with legacy namespace notice
- Optionally provide a one-time migration utility for SharedMem keys
