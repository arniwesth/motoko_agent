# Phase 0 Inventory: `swe` → `core`

## Purpose

Establish a precise migration boundary and rename map before any code moves.

## Scope Boundary for This Migration

Active files to migrate:
- Runtime code (`swe/*.ail`, `tui/src/*`, runner scripts)
- Active project docs (`README.md`, `SYSTEM.md`, `AGENTS.md`, `CLAUDE.md`)
- Build/test plumbing (`Makefile`)

Intentionally excluded (stay untouched):
- `.agent/plans/**`
- `.agent/summaries/**`
- `.agent/research/**`

Other excluded non-runtime trees:
- `node_modules/**`
- `tui/dist/**`
- vendored `ailang/**` unless a direct migration blocker is found

## Discovery Commands Used

```bash
rg -n "\\bswe\\b|swe/|swe:" -S AGENTS.md CLAUDE.md README.md SYSTEM.md Makefile prompts.md scripts tui/src swe
rg -l "\\bswe\\b|swe/|swe:" -S AGENTS.md CLAUDE.md README.md SYSTEM.md Makefile prompts.md scripts tui/src swe | sort
find swe -maxdepth 1 -type f | sort
```

## Classification

## A. Runtime-Critical (must change in Phase 1)

- `swe/agents_md.ail`
- `swe/cache.ail`
- `swe/env_client.ail`
- `swe/parse.ail`
- `swe/parse_test.ail`
- `swe/prompts.ail`
- `swe/prompts_test.ail`
- `swe/rpc.ail`
- `swe/tool_runtime.ail`
- `swe/types.ail`
- `swe/version.ail`
- `tui/src/brain.ts` (entry path `swe/rpc.ail`)
- `tui/src/index.ts` (version probe path `swe/version.ail`)
- `Makefile` (`check_swe`, `test_swe`, and `swe/*.ail` references)

## B. Dev/Test/Tooling (should change in same PR)

- `swe/test-files/test_agents_md.ail`
- `swe/test-files/test_agents_run.ail`
- `swe/test-files/test_load_agents.ail`
- `swe/test-files/test_write.ail`
- `scripts/install-prerequisites.sh` (SWE naming text)
- `scripts/run-agent.sh` (SWE naming text)
- `scripts/test-openrouter-readme.sh` (grep for SWE identity text)
- `tui/src/ui.ts` (comment text)

## C. Active Documentation (should change in Phase 3/4)

- `README.md`
- `SYSTEM.md`
- `AGENTS.md`
- `CLAUDE.md`
- `prompts.md` (project-internal prompt/design notes)

## D. Historical/Archival (confirmed out of scope)

- `.agent/plans/**`
- `.agent/summaries/**`
- `.agent/research/**`

## Directory and Module Rename Map

Directory move:
- `swe/` → `core/`

Module declarations:
- `module swe/types` → `module core/types`
- `module swe/parse` → `module core/parse`
- `module swe/parse_test` → `module core/parse_test`
- `module swe/prompts` → `module core/prompts`
- `module swe/prompts_test` → `module core/prompts_test`
- `module swe/env_client` → `module core/env_client`
- `module swe/cache` → `module core/cache`
- `module swe/agents_md` → `module core/agents_md`
- `module swe/tool_runtime` → `module core/tool_runtime`
- `module swe/rpc` → `module core/rpc`
- `module swe/version` → `module core/version`

Import updates:
- `import swe/...` → `import core/...` across all migrated AILANG files

Entry-point updates:
- `tui/src/brain.ts`: `swe/rpc.ail` → `core/rpc.ail`
- `tui/src/index.ts`: `swe/version.ail` → `core/version.ail`

SharedMem prefix updates (Phase 2):
- `swe:current_model` → `core:current_model` (read fallback to old key)
- `swe:traj:*` → `core:traj:*` (read fallback to old key)

## Risks Identified During Inventory

1. AILANG strict module-path rules require atomic path + `module` declaration update.
2. Script/test text checks (for README identity wording) may fail after rebrand and must be updated together.
3. Rename completeness requires a deterministic gate after edits.

## Phase 1 Readiness

Ready to proceed with Phase 1 mechanical migration using this boundary:
- Update all files in categories A and B.
- Keep category D untouched.
- Apply category C in doc rewrite phases after runtime is green.
