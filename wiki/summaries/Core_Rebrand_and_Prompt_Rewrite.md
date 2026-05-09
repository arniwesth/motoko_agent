---
doc_type: short
full_text: sources/Core_Rebrand_and_Prompt_Rewrite.md
---

# Core Rebrand & Prompt Rewrite Plan

## Overview
This plan transitions the project from a narrow SWE-agent identity to an **agent harness research platform**, involving a mechanical namespace migration (`swe` → `core`), a compatibility layer for state keys, and a complete rewrite of root documentation (`SYSTEM.md`, `AGENTS.md`) to reflect harness-first goals.

## Key Decisions
- **Canonical namespace**: `core` replaces `swe` in module paths, imports, directories, and runtime keys.
- **Backward compatibility**: SharedMem keys (`core:traj:*`, `core:current_model`) will be written, with reads falling back to legacy `swe:*` keys temporarily.
- **Doc identity shift**: New prompts emphasize operational constraints, tool orchestration, and harness invariants, removing SWE‑bench-centric language.
- **Two‑step delivery**: Mechanical rename first (Phases 0‑2), then documentation rewrite (Phases 3‑4).

## Phased Execution
1. **Preflight inventory** – Classify all `swe` references in active code paths (runtime, dev/test, archive).
2. **Mechanical migration** – Rename directory, AILANG modules, imports, and launch points; update TypeScript entry paths, Makefile, and scripts.
3. **SharedMem key migration** – Introduce `core:*` keys with read fallback; write only new keys after validation.
4. **Doc reframe** – Rewrite `SYSTEM.md` as a harness runtime guide; rewrite `AGENTS.md` with architecture invariants and migration rules.
5. **Validation** – AILANG checks, TUI launch smoke test, end‑to‑end agent run, and a residual‑name grep gate across active files.

## Impacted Areas
- `core/*` (formerly `swe/*`) AILANG modules
- TypeScript brain entry and version probe paths
- Build/test targets, shell scripts, and README
- SharedMem state keys (`swe:*` → `core:*`)
- Root `SYSTEM.md` and `AGENTS.md`

## Risks & Mitigations
- **Breakage from strict AILANG module paths**: mitigated by atomic rename and import updates.
- **Silent runtime failures**: explicit smoke tests on startup and version probe.
- **Cache/model continuity**: compatibility read fallback ensures old keys remain accessible during transition.
- **Docs drift**: synchronise docs after code changes and run command examples.

## Acceptance Criteria
- No active runtime code uses `swe/` paths.
- All AILANG modules compile under `core/*`.
- Agent starts and runs full session via TUI with `core/rpc.ail`.
- Root docs convey harness identity, not SWE‑agent branding.
- Old `swe:*` state keys remain readable during migration.
- Residual‑name grep gate passes (zero matches in active files).

## Related Concepts
- [[concepts/agent-harness]]
- [[concepts/shared-memory]]
- [[concepts/namespace-migration]]
- [[concepts/prompt-identity]]
- [[concepts/module-path-migration]]