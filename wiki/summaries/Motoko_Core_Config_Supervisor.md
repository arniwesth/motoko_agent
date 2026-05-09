---
doc_type: short
full_text: sources/Motoko_Core_Config_Supervisor.md
---

# Motoko Core-Owned Config and Supervisor Plan

This document details a phased migration to move configuration ownership and process supervision from the TypeScript TUI into AILANG (Motoko core). The goal is to enable headless Motoko usage without a TypeScript entry point, while keeping the current execution backend replaceable.

## Key Concepts

- **Config Ownership**: Currently TypeScript loads `.env`, TOML profiles, and sets env vars for the AILANG core. The plan transfers ownership to [[concepts/config-ownership]] in AILANG, using JSON profiles (`.motoko/config/<profile>/*.json`) and a new `src/core/config.ail` module.
- **Headless Supervisor**: A new entry point `src/core/supervisor.ail` will load config, start/connect to a backend, run the agent loop, emit JSONL events, and accept JSONL commands (abort, model change, reload) – enabling [[concepts/headless-mode]].
- **Replaceable Backend Abstraction**: The execution backend (currently `env-server.ts`) is abstracted behind a defined interface (HTTP health, `/exec`, tool calls) and a `src/core/backend.ail` module. This allows future native backends without altering the supervisor. See [[concepts/backend-abstraction]].
- **Profile Config in JSON**: To avoid AILANG runtime changes, TOML config is replaced by JSON. The TypeScript TUI may continue reading TOML as a compatibility bridge, but core headless mode uses JSON exclusively – a concrete [[concepts/profile-config]] migration.

## Phased Approach

The plan is split into 9 phases, from inventorying current env reads to creating a native backend plan:

1. **Phase 0**: Audit TypeScript and AILANG `getEnvOr(...)` calls, classify variables (bootstrap, runtime, backend, UI).
2. **Phase 1**: Introduce JSON profile files, update config generation (`make init-config`), and add tests. Legacy TOML triggers a warning.
3. **Phase 2**: Implement `src/core/config.ail` with typed `RuntimeConfig` records (Agent, Backend, Extension, Invocation). It merges defaults, `.env`, profile JSON, and shell envs with well-defined precedence.
4. **Phase 3**: Design backend config, a standalone backend entrypoint (`env-server-main.ts`), backend HTTP contract, and the `backend.ail` client module.
5. **Phase 4**: Refactor runtime code (`rpc.ail`) to use typed config objects instead of scattered `getEnvOr` calls, while preserving env override behavior.
6. **Phase 5**: Migrate extension initialization (compose, context mode, exa_search, omnigraph) to typed config records, removing direct env reads.
7. **Phase 6**: Build the headless supervisor entry point (`supervisor.ail`) that loads config, starts backend, runs agent loop, and handles JSONL commands. Achieve the first headless smoke test.
8. **Phase 7**: Simplify the TypeScript TUI to act as a client connecting to the supervisor, removing its config loading responsibilities.
9. **Phases 8–9**: Plan for a future native backend replacement and documentation/cleanup.

## Non-Goals
- No modification of the vendored AILANG runtime (`ailang/`).
- No hand-rolled TOML parser; JSON is the core format. The TypeScript backend remains the initial `external_http` backend; it is not being rewritten now.
- The TUI is kept optional and eventually demoted to a supervisor client.

## Risks and Mitigations
Key risks include duplicate config semantics, stranded TOML users, extension env coupling, and continued dependency on Bun/TypeScript for the backend. These are addressed by clear ownership boundaries, compatibility windows, and the replaceable backend design.

See also [[concepts/config-ownership]], [[concepts/headless-mode]], [[concepts/supervisor]], [[concepts/backend-abstraction]], [[concepts/profile-config]] for synthesized cross-document discussions.