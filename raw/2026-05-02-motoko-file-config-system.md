# Motoko File Config System Session

Date: 2026-05-02

## Scope

Implemented the file-based Motoko config system from `.agent/plans/Motoko_Config_System.md` and created default project config files under `.motoko/`.

## Main Changes

- Added `src/tui/src/config.ts`.
  - Loads `.motoko/config.toml`.
  - Loads extension config files only for extensions listed in `[extensions].order`.
  - Supports explicit TOML-to-env mappings for core settings and extension settings.
  - Serializes booleans to `1`/`0`.
  - Serializes string arrays to comma-separated env values.
  - Skips empty strings and empty arrays.
  - Warns on invalid TOML without crashing.
  - Added `agent.ai_options_json` mapping to `MOTOKO_AI_OPTIONS_JSON`.

- Integrated config loading in `src/tui/src/index.ts`.
  - `.env` / `.export` are loaded first for secrets and fallback values.
  - `.motoko/*.toml` then overrides mapped project config keys.
  - Real shell environment variables remain protected and override both `.env` and `.motoko`.

- Added `src/tui/src/init-config.ts`.
  - `make init-config` creates `.motoko/config.toml`.
  - `make init-config ARGS=--all` also creates all known extension config files.
  - Existing files are not overwritten.

- Added tests in `src/tui/src/config.test.ts`.
  - Covers parsing, missing directory, missing keys, protected shell env behavior, `.env`/`.export` override behavior, booleans, arrays, empty values, extension loading, and invalid TOML.

- Added `smol-toml` dependency to `src/tui/package.json`, `package-lock.json`, and `bun.lock`.

- Updated docs:
  - `README.md`
  - `CLAUDE.md`
  - `.gitignore` comment noting `.motoko/` is intentionally committable.

## Default Config Files Created

Created:

- `.motoko/config.toml`
- `.motoko/compose.toml`
- `.motoko/context_mode.toml`
- `.motoko/exa_search.toml`
- `.motoko/omnigraph.toml`

The repo default `.motoko/config.toml` was changed to match `make run_test_local`:

- `MODEL=openai/google/gemma-4-26B-A4B-it`
- `WORKDIR=.`
- `AILANG_BIN=/workspaces/ailang_agent/ailang/bin/ailang`
- `OHMY_PI_TOOLS=1`
- `EDIT_MODE=hashline`
- `MOTOKO_PLAIN_VERBOSE_STREAM=1`
- `MOTOKO_AI_OPTIONS_JSON={"chat_template_kwargs":{"enable_thinking":true, "thinking_token_budget":256}}`
- `OPENAI_BASE_URL=http://100.79.48.75:8000/v1`
- `CORE_EXT_ORDER=context_mode,exa_search`
- `HYBRID_TOOLS=1`

The `[extensions]` section now includes comments explaining that extensions load in order and only matching `.motoko/<extension>.toml` files are loaded.

## Important Bug Found and Fixed

`make run` showed `ext: test_dummy` despite `.motoko/config.toml` specifying `context_mode,exa_search`.

Root cause:

- `.export` contained `export CORE_EXT_ORDER=test_dummy`.
- The first implementation had `.env` / `.export` overriding `.motoko`.

Fix:

- Changed effective precedence to:

```text
hardcoded defaults < .env/.export < .motoko/*.toml < real shell env vars
```

This lets `.export` continue to provide secrets while allowing committed project config to control mapped settings like `CORE_EXT_ORDER`.

## Verification

Commands run:

```bash
cd src/tui && bun run build
cd src/tui && node --experimental-vm-modules node_modules/.bin/jest --runInBand
```

Result:

- TypeScript build passed.
- Node-backed Jest passed: 18 suites, 102 tests.

Known test harness note:

- The repo's Bun-backed Jest command fails before executing tests with `TypeError: Attempted to assign to readonly property` inside Jest/stack-utils. This affects existing tests too, not just the new config tests.

## Current Worktree Notes

This session intentionally changed or added files under:

- `.motoko/`
- `.gitignore`
- `CLAUDE.md`
- `Makefile`
- `README.md`
- `src/tui/package.json`
- `src/tui/package-lock.json`
- `src/tui/bun.lock`
- `src/tui/src/config.ts`
- `src/tui/src/config.test.ts`
- `src/tui/src/init-config.ts`
- `src/tui/src/index.ts`
- rebuilt `src/tui/dist/*` outputs

There were pre-existing unrelated dirty files and untracked directories in the worktree before this work, including changes to `.agent/plans/Motoko_Config_System.md`, `ailang.lock`, scripts, and several untracked directories. They were not reverted.
