---
doc_type: short
full_text: sources/2026-04-27-context-mode-extension-hardening.md
---

# Summary: Context Mode Extension Hardening

This session focused on making the `context_mode` runtime extension more dependable and reducing unnecessary fallback to `BashExec`. Key changes included integrating a proper MCP bridge, strengthening tool routing policies, adding readiness preflight checks, and automating package mirroring so development and runtime packages stay synchronized.

## Key Outcomes

### 1. Context-mode bridge integration
- Added `scripts/context-mode-mcp-call.mjs`, an MCP bridge that spawns `context-mode` over stdio, performs `initialize`, and calls `tools/call` for `ctx_*` actions.
- Updated `src/core/ext/context_mode/context_mode.ail` to use the bridge for `Ctx*` tools instead of direct shell invocations, aligning with the actual CLI.

### 2. Stronger routing and policy nudges
- Hardened `on_tool_policy` to deny `BashExec` for context-mode commands (`context-mode`, `ctx_*`, `Ctx*` variants) and remote URL fetches (`http://`/`https://` inside `BashExec`).
- Deny messages now explicitly redirect to extension tools (`CtxFetchAndIndex`, `CtxStats`, `CtxDoctor`, `CtxSearch`…) even when generic tool tables omit them.
- Expanded the [[concepts/tool-routing]] card (`AGENT.md`) with authoritative rules: extension tools are authoritative; no Bash preflight checks; preferred test order (`CtxDoctor` → `CtxStats` → requested operation).

### 3. Readiness preflight (auto-start/verify)
- Added per-session readiness logic: before non‑`CtxDoctor` calls, the extension runs a one‑time `ctx_doctor` preflight through the bridge, stores a ready marker in session‑shared state, and skips repeats once marked ready.
- This emulates a “check/start if needed” pattern for the stdio‑per‑call model without requiring a separate daemon manager.

### 4. Package mirroring automation
- Introduced `scripts/sync-extension-packages.sh` to mirror each extension under `src/core/ext/*` into `.packages/motoko_*` directories.
- The script excludes caches and source‑only metadata, writes correct package‑root metadata, and rewrites the mirrored dependency path from `../..` to `../motoko_core`, ensuring runtime resolution matches the [[concepts/package-mirroring]] layout.

### 5. Makefile automation
- `sync_packages` now runs `check_ailang`, `./scripts/sync-extension-packages.sh`, and `ailang lock` in sequence, so the lock file (`ailang.lock`) stays current with mirrored packages.
- `check_core` depends on `sync_packages`; `build` simplified to avoid duplicate sync/lock work and to rely on `check_core`.

## Root‑Cause Findings Documented During Debugging

1. **Runtime vs. development paths**  
   Runtime extension loading uses package‑based imports (`.packages`), while `src/core/ext/*` is the development source‑of‑truth. The two are kept in sync by the mirror script. A note was created at `.agent/notes/context_mode_runtime_vs_dev_paths.md` explaining this [[concepts/context-mode]] deployment pattern.

2. **Lock/hash warning cause**  
   The warning `dependency sunholo/motoko_context_mode content changed` appeared when mirrored package content changed but `ailang.lock` was stale, or when mirror manifests had an incorrect dependency path (`../..` → `../motoko_core`). Automating `ailang lock` in `sync_packages` now prevents such drift. This ties into [[concepts/ailang-lock]] management.

## Tests and Validation
- `ailang check` and expanded test suite for `context_mode.ail` all passed:
  - alias normalisation,
  - policy denies for context-mode Bash probes and remote URL fetches,
  - deny for non‑curl URL attempts,
  - prompt patch and compression behaviour.
- `make sync_packages` and `make check_core` succeeded, regenerating a consistent lock file.

## Remaining Nuance
- The tool planner may still emit a `BashExec` step as `planned` before policy filters re‑plan; enforcement happens at execution time, not in the initial plan text.
- Context‑mode uses a stdio MCP spawn‑per‑call model via the bridge; the readiness preflight verifies availability but does not keep a persistent daemon. This is an intentional design trade‑off for simplicity.