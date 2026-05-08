---
doc_type: short
full_text: sources/2026-05-03-core-config-supervisor-json.md
---

# Motoko Core Config Supervisor JSON Migration Summary

**Date:** 2026-05-03  
**Context:** Motoko architecture refresh and AILANG constraints.

## Key Decision
To avoid modifying the `ailang/` runtime, the Motoko core configuration manager was reoriented from TOML to JSON. AILANG’s `std/json` provides native parsing, making it possible to implement the new supervisor and config logic entirely within AILANG scripts, while legacy TOML remains for TypeScript TUI compatibility during migration.

## Implementation Highlights

- **New Config Module** (`src/core/config.ail`) \
  Defines typed records for agent, backend, tool, extension, and runtime configs. Loads `.motoko/config/<profile>/*.json` with `std/json`, enforcing precedence: hardcoded defaults < `.env/.export` < profile JSON < shell env. Supports default, named, and absolute profile paths, with a flat fallback.

- **Supervisor & Backend** \
  Added `src/core/supervisor.ail` to load config, emit warnings, and start/connect to a backend via a new `src/core/backend.ail` module. The `BackendHandle` abstraction supports `external_http` and `none` modes, with the TypeScript backend launched through a regular command path.

- **RPC Agent Loop Update** \
  `src/core/rpc.ail` now exposes `run_with_config(cfg, inv)` and delegates to it from `main()`. Startup uses typed config for backend URL, model, workdir, hybrid tools, step delay, system prompt, extension order, and strictness.

- **Extension Initialization** \
  `src/core/ext/runtime.ail` gained `init_runtime_with_config(order, strict)` to respect config-driven extension ordering and strictness.

- **TypeScript Backend Adaptation** \
  Added standalone backend entrypoint `src/tui/src/env-server-main.ts`, configuration templates in `src/tui/src/config.ts`, and JSON config writing in `src/tui/src/init-config.ts`. Compiled output regenerated via `bun run build`.

- **Default JSON Profiles** \
  Provided sample profiles under `.motoko/config/default/` for config, compose, context_mode, exa_search, and omnigraph.

## Verification
All AILANG checks and targeted tests passed. The config entrypoint successfully emits normalized JSON. The supervisor starts the backend and routes through the real RPC path. Unrelated parse test failures were noted but not linked to these changes. No `ailang/` diff remains.

## Current State & Migration Path
The result is an incremental slice: core-owned config is now JSON, parseable by AILANG without runtime changes. The TypeScript backend remains the execution target, accessed via a standalone entrypoint. The TUI retains TOML compatibility for now. Future work can fully retire TOML once the migration is complete.

## Related Concepts
- [[concepts/json-config-migration]] – Strategy and tradeoffs of moving core config to JSON.
- [[concepts/motoko-supervisor]] – Design of the config-aware supervisor and backend abstraction.
- [[concepts/ailang-constraints]] – Reasons to avoid modifying the AILANG runtime.
- [[concepts/motoko-backend]] – Backend handle and standalone entrypoint for the TypeScript backend.