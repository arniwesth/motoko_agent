# 2026-05-03 Multi-Profile Config and Headless Core Plan

## Implemented

Implemented the multi-profile Motoko config system from
`.agent/plans/Multi_Profile_Config.md`.

Key code changes:

- Added profile-aware config resolution in `src/tui/src/config.ts`.
  - `MOTOKO_CONFIG` selects a profile.
  - unset/empty profile defaults to `default`.
  - absolute `MOTOKO_CONFIG` values are treated as config directories.
  - relative profiles resolve to `.motoko/config/<profile>/`.
  - old flat `.motoko/*.toml` layout still loads with a deprecation warning when
    the selected profile does not have `config.toml`.
  - exported `activeProfile()` and `resolveProfileDir()`.
- Updated extension config loading to read from the active profile directory.
- Updated `src/tui/src/init-config.ts`.
  - added `--profile <name>`.
  - changed scaffold target to `.motoko/config/<profile>/`.
  - added `--migrate` to move flat `.motoko/*.toml` files into
    `.motoko/config/default/`.
- Updated `Makefile`.
  - added `PROFILE ?= default`.
  - `make init-config` now calls `bun src/tui/src/init-config.ts --profile $(PROFILE) $(ARGS)`.
- Updated session logging.
  - `src/tui/src/session-logger.ts` now writes under `.motoko/logfile/`.
  - `.gitignore` now ignores `.motoko/logfile/` instead of root `logfile/`.
- Updated docs.
  - `README.md` documents `MOTOKO_CONFIG`, profile layout, migration, and new
    precedence.
  - `CLAUDE.md` documents profile config and updated init examples.
- Updated built `src/tui/dist/*` output with `bun run build`.

Repository config migration:

- Ran `make init-config ARGS=--migrate`.
- Moved existing committed config files from flat `.motoko/` into
  `.motoko/config/default/`:
  - `config.toml`
  - `compose.toml`
  - `context_mode.toml`
  - `exa_search.toml`
  - `omnigraph.toml`
- Moved existing local root `logfile/` contents into `.motoko/logfile/` so the
  new ignore rule keeps the worktree clean.

Tests and verification:

- `bun run build` passed in `src/tui`.
- Full Jest suite passed via:

```bash
cd src/tui
node --experimental-vm-modules node_modules/.bin/jest --testPathPattern='src/.*\\.test\\.ts' --runInBand
```

Result: 18 suites, 108 tests passed.

- Targeted `src/config.test.ts` passed with the new profile tests.
- `make init-config` confirmed idempotent for default profile.
- Benchmark profile scaffolding was verified in a temporary directory.

Known test caveat:

- `bun run test` currently fails before test execution with:

```text
TypeError: Attempted to assign to readonly property.
```

This affects every Jest suite during initialization under Bun/Jest in this
environment and appears unrelated to the config changes. The Node/Jest command
above passes.

## Planned

Created and iteratively revised:

- `.agent/plans/Motoko_Core_Config_Supervisor.md`

The plan now targets the long-term goal of running Motoko headlessly without
invoking the TypeScript TUI:

```bash
ailang run --entry main --caps ... src/core/supervisor.ail -- "task"
```

Important plan decisions:

- Motoko core becomes the owner of profile resolution, TOML config semantics,
  runtime config, extension config, and runtime supervision.
- `src/tui/src/env-server.ts` remains the initial execution backend, but only as
  a replaceable external backend.
- TypeScript TUI becomes optional and should eventually act as a client of the
  AILANG supervisor, not the runtime/config owner.
- Added a required standalone backend entrypoint:
  - `src/tui/src/env-server-main.ts`
- Added backend abstraction scope:
  - `src/core/backend.ail`
  - backend modes: `external_http`, `none`, future `native`, future `stdio`
  - backend startup config under `[backend]`
- Added explicit boundaries:
  - `AILANG_BIN`, provider API keys, and `MOTOKO_CONFIG` are bootstrap shell
    variables.
  - task text and one-off overrides are invocation inputs.
  - runtime and extension settings are core-owned config.
  - backend startup/behavior settings are core-owned config passed to the
    backend.
- Clarified `.env/.export` split:
  - non-secret config defaults may be parsed by `src/core/config.ail`.
  - provider secrets must be present in the actual process environment before AI
    provider initialization.
- Removed duplicate `ServerConfig`; backend port now lives in `BackendConfig`.
- Added backend HTTP contract inventory before supervisor work.
- Added a note to confirm final AILANG capability requirements during
  implementation.

## Worktree Notes

Unrelated pre-existing untracked directories were left untouched:

- `DR-Venus/`
- `ailang/`
- `little-coder/`
- `polyglot-benchmark/`

