---
doc_type: short
full_text: sources/2026-05-03-multi-profile-config-and-headless-core-plan.md
---

# 2026-05-03 Multi-Profile Config and Headless Core Plan

## Implemented
- Multi-profile config resolution from `.motoko/config/<profile>/` via `MOTOKO_CONFIG` env var, with fallback to flat `.motoko/*.toml` (deprecation warning) and absolute path support.
- Profile helpers `activeProfile()` and `resolveProfileDir()` added to `src/tui/src/config.ts`.
- `src/tui/src/init-config.ts` extended: `--profile <name>`, `--migrate` to move existing flat config into `default/` profile.
- Makefile support: `PROFILE ?= default`, `make init-config` passes `--profile $(PROFILE)`.
- Session logging relocated to `.motoko/logfile/`, `.gitignore` updated to ignore that directory.
- Repository migration performed: `config.toml`, `compose.toml`, `context_mode.toml`, `exa_search.toml`, `omnigraph.toml` moved to `.motoko/config/default/`; root logfile contents moved to `.motoko/logfile/`.
- Testing: full Jest suite (18 suites, 108 tests) passed via Node/Jest; `bun run build` succeeded; Bun/Jest fails on environment issue unrelated to config changes.
- Built `src/tui/dist/*` updated.

## Planned (Headless Core)
- Detailed plan in `.agent/plans/Motoko_Core_Config_Supervisor.md` to run Motoko headlessly via AILANG supervisor, bypassing the TypeScript TUI: `ailang run --entry main --caps ... src/core/supervisor.ail -- "task"`.
- Ownership shift: the Motoko core will own profile resolution, TOML config semantics, runtime config, extension config, and runtime supervision.
- TypeScript TUI becomes an optional client, with a new standalone backend entrypoint `src/tui/src/env-server-main.ts`.
- Backend abstraction introduced: `src/core/backend.ail` with modes `external_http`, `none`, future `native`, `stdio`; config under `[backend]`.
- Bootstrap boundaries: `AILANG_BIN`, `MOTOKO_CONFIG`, and provider API keys are shell variables; task text and one‑off overrides are invocation inputs; runtime/extension settings are core‑owned config.
- `.env/.export` split: non‑secret config defaults may be parsed by `src/core/config.ail`, provider secrets must already be set in the process environment before AI init.
- Removed duplicate `ServerConfig`; backend port placed in `BackendConfig`.
- Backend HTTP contract inventory planned before supervisor implementation; final AILANG capability requirements to be confirmed.

This work establishes [[concepts/multi-profile-config]] for environment flexibility and lays the groundwork for [[concepts/headless-core]] with [[concepts/backend-abstraction]] and an [[concepts/ailang-supervisor]] that separates the TUI from runtime control.