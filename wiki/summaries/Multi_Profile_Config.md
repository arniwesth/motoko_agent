---
doc_type: short
full_text: sources/Multi_Profile_Config.md
---

# Multi-Profile Config System Summary

## Overview

The Motoko project is introducing a **multi-profile configuration system** to replace the flat `.motoko/` directory layout with a hierarchical structure under `.motoko/config/<profile>/`. This allows developers to maintain named configurations (e.g., `default`, `benchmark`, `debug`) and switch between them using the `MOTOKO_CONFIG` environment variable, without manual file juggling. The system preserves full backward compatibility with existing flat-layout setups.

## Target Layout

```
.motoko/
  config/
    default/          # profile used when MOTOKO_CONFIG is unset
      config.toml
      compose.toml
      context_mode.toml
      ...
    benchmark/        # profile for performance testing
      config.toml
      compose.toml
    debug/            # profile for verbose logging
      config.toml
  logfile/            # moved from project root to .motoko/
```

Usage: `MOTOKO_CONFIG=benchmark make run TASK="..."`

## Core Design

### Profile Resolution ([[concepts/config-resolution]])
- `MOTOKO_CONFIG` is read **only from process.env**, never from config files.
- If unset → `"default"`; if relative path → resolved under `.motoko/config/`; if absolute → used directly.
- A **backward-compatibility fallback** checks for the old flat layout: if `.motoko/config.toml` exists and the profile-specific `config.toml` does not, the flat `.motoko/` directory is used with a deprecation warning.
- When both layouts exist, the profile directory takes precedence.

### Configuration Files
All TOML files (`config.toml`, `compose.toml`, `context_mode.toml`, extension configs, etc.) are loaded from the resolved profile directory. The precedence chain remains unchanged: `hardcoded defaults < .env/.export < profile TOMLs < shell env vars`.

### Migration Support ([[concepts/config-migration]])
- The `init-config` script gains a `--profile` flag to create profiles.
- A `--migrate` flag moves existing `.motoko/*.toml` files into `.motoko/config/default/`, enabling easy adoption.
- A Makefile target `make init-config PROFILE=<name>` simplifies profile creation; `make init-config ARGS=--migrate` handles migration.

### Logfile Relocation
Session logs are moved from `logfile/` at the project root to `.motoko/logfile/`, keeping all Motoko runtime data under a single hidden directory.

## Implementation Phases

The feature is rolled out in six phases:

1. **Config resolution** — `resolveProfileDir()` replaces `configDir()` in `config.ts`.
2. **Init-config script** — `--profile` and `--migrate` flags, output to nested profile dir.
3. **Migration of existing config** — run `make init-config ARGS=--migrate` and commit.
4. **Tests** — add profile-specific tests (named, default, absolute, fallback, extension loading, override) while keeping old tests for backward compat.
5. **Makefile update** — `PROFILE` variable for `init-config` target.
6. **Documentation** — README, CLAUDE.md, and env var table updates.
7. **Logfile relocation** — implement move in `session-logger.ts` and update `.gitignore`.

## Key Benefits
- **A/B testing and benchmarks** become trivial with dedicated profiles.
- **Reproducibility** — configurations can be committed and shared.
- **Zero disruption** — existing flat setups continue to work with a deprecation warning.
- **Cleaner organization** — all Motoko runtime data lives inside `.motoko/`.

## See Also
- [[concepts/configuration-profiles]] — general pattern for environment-specific configs
- [[concepts/config-resolution]] — detailed logic for resolving the active profile directory
- [[concepts/config-migration]] — strategies for migrating flat configs to profile-based structures