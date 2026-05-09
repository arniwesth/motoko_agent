---
doc_type: short
full_text: sources/2026-05-02-motoko-file-config-system.md
---

# Summary: Motoko File Config System

This work implemented a file‑based configuration system for the Motoko TUI, as described in ``.motoko/` now stores project‑level TOML files that map to environment variables, enabling committed, shareable configuration. A key outcome was clarifying and enforcing the effective precedence order:

- hardcoded defaults (lowest)
- `.env` / `.export` secrets (overrides defaults)
- `.motoko/*.toml` committed project config (overrides `.env`)
- real shell environment variables (highest, never overridden)

## Core Components

- **`src/tui/src/config.ts`**: Loads and processes `.motoko/config.toml` and extension‑specific `.motoko/<ext>.toml` files in the order listed under `[extensions].order`. Handles TOML → env key mapping, serialization of booleans to `1`/`0`, string arrays to comma‑separated values, and warnings for invalid TOML without crashing.
- **`src/tui/src/index.ts`**: Integrates the config loader so that `.env` / `.export` is loaded first for secrets, then `.motoko` files override mapped keys, while shell environment variables remain protected.
- **`src/tui/src/init-config.ts`**: A helper (`make init-config`) that scaffolds default `.motoko/config.toml`, and with `--all` also creates extension config files, but never overwrites existing ones.
- **Tests** in `src/tui/src/config.test.ts` covering parsing, missing directories, key precedence, protected shell env, `.env`/`.export` override behavior, booleans, arrays, extensions, and invalid TOML.

## Default Files Created

Five TOML files under `.motoko/` were added to the repository: `config.toml`, `compose.toml`, `context_mode.toml`, `exa_search.toml`, `omnigraph.toml`. The main `config.toml` was set to match the local development run configuration (`make run_test_local`), including model, workdir, API keys placeholders, `CORE_EXT_ORDER=context_mode,exa_search`, and agent AI options.

## Bug Fix and Precedence Overhaul

A discovered bug caused `CORE_EXT_ORDER` to be taken from an old `.export` value (`test_dummy`) instead of the committed TOML. The root cause was that `.env`/`.export` initially had higher priority. The fix introduced a new precedence chain (`.env` < `.motoko` < shell) that allows `.export` to still hold secrets while letting the committed project config control operational settings.

## Verification

Build and test execution confirmed:
- TypeScript compilation passed.
- Node‑backed Jest passed (18 suites, 102 tests). A Bun‑based Jest runner fails on the repo due to a pre‑existing Jest/stack‑utils issue.

## Related Concepts
- [[config-precedence]] – The layered loading order and its implications.
- [[motoko-project-structure]] – Organization of `.motoko/`, `src/tui`, and default config generation.
- [[toml-env-mapping]] – How TOML keys are mapped to environment variables and serialization rules.
- [[extension-loading]] – Dynamic loading of extension configs based on `extensions.order`.
- [[makefile-config-init]] – The `make init-config` workflow for scaffolding configuration.