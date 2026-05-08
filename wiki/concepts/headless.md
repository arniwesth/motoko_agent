---
sources: [summaries/2026-05-03-headless-config-plan-review.md]
brief: Configuration via JSON profiles and CLI arguments without environment variables for non-secrets.
---

# Headless JSON-Only Config

## Overview

The **Headless JSON-Only Config** architecture eliminates all environment variable configuration for non-secret settings. Instead, Motoko's headless operation uses JSON profiles selected via CLI arguments, combined with explicit runtime overrides, to determine every operational parameter. This design simplifies deployment, removes ambient state, and clears the path for a fully native execution backend.

## Context

Prior to this migration, Motoko relied on a mix of environment variables, CLI flags, and file-based config (TOML/JSON). The headless migration plan ([[summaries/2026-05-03-headless-config-plan-review]]) defined a strict separation:
- **Secrets** (API keys, etc.) remain as environment variables for security and process isolation.
- **All other configuration** lives in JSON profiles, parsed once, and threaded through the system as a `RuntimeConfig` struct.

This prevents accidental leakage of config state between runs and makes the system fully predictable from its invocation arguments.

## Implementation Details

### Core Config Module (`config.ail`)
- `CliOverrides` struct captures any `--key value` pairs passed on the command line.
- `parse_cli_args()` parses CLI arguments and returns a profile name and overrides.
- `load_config_from_cli()` merges a JSON profile file with CLI overrides, producing a complete `RuntimeConfig`.
- Only one `getEnv` call remains: `MOTOKO_CONFIG` used as a fallback to locate the JSON profile file when `--profile` is not given.

### Propagation Through the System
- **`supervisor.ail`** calls `load_config_from_cli(getArgs())`, validates secrets, starts the backend, and enters the agent loop.
- **`backend.ail`** uses `RuntimeConfig.backend` to decide the execution mode (HTTP, stdio, etc.).
- **`registry.ail` and `runtime.ail`** pass `RuntimeConfig` through to every extension via `register_with_config(RuntimeConfig)`.
- **All 5 production extensions** accept `RuntimeConfig` and never read environment variables.
- **`rpc.ail`** builds `RunSettings` directly from `RuntimeConfig`; no `getEnvOr` calls remain.
- **`tool_runtime.ail`** receives its parameters (`ohmy_pi`, `workdir`) explicitly, not from the environment.

### TypeScript TUI Integration
- The TUI (TypeScript) spawns `supervisor.ail` with CLI arguments that mirror the JSON profile and overrides.
- Only secret values are passed as environment variables to the subprocess.
- `index.ts` reads configuration from JSON, not TOML.

## Remaining Minor Debt
- `config.ts` still contains dead TOML parsing code (`CORE_MAP`, `EXTENSION_MAPS`, `loadMotokoConfig`) that should be removed for clarity.
- Two additional environment variables (`MOTOKO_STREAM_EVENTS` and `OPENAI_BASE_URL`) are still passed from the TUI to the subprocess; these could eventually be moved to JSON/CLI for full consistency.

## Relationship to Native Execution Backend

The headless JSON-only config is a prerequisite for the next major milestone: replacing the TypeScript execution backend (`env-server.ts`) with an AILANG-native or Go-hosted backend. Because all configuration (except secrets) now flows internally through `RuntimeConfig`, the native backend can simply receive the same JSON profile and CLI overrides, making the transition seamless. See [[concepts/native-execution-backend]] for the handoff details.

## Related Pages
- [[summaries/2026-05-03-headless-config-plan-review]] — Detailed review of the completed config migration.
- [[concepts/native-execution-backend]] — The planned AILANG/Go execution backend.
- [[concepts/env-server-ts-functionality]] — Capabilities of the current TypeScript backend.
- [[concepts/config-migration-verification]] — How the migration was verified.
- [[concepts/backend-execution-mode]] — Comparison of execution modes (HTTP, stdio, in-process).