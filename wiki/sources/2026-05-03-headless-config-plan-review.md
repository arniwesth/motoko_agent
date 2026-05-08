# 2026-05-03 Headless Config Plan Review and Handoff

## What happened this session

Reviewed the state of the headless Motoko migration after the
`Headless_JSON_Only_Config.md` plan was implemented by a prior agent. The key
architectural decision — drop env var config entirely for non-secrets, use JSON
profiles + CLI args only — is fully landed.

### Verified complete

- **config.ail**: `CliOverrides`, `parse_cli_args`, `load_config_from_cli` all
  exist. Env overlay (`cfg_string`, `env_default`, `shell_string`) removed.
  Only 1 `getEnv` remains (MOTOKO_CONFIG fallback for `--profile`).
- **rpc.ail**: Zero `getEnvOr` calls. All config flows through `RunSettings`
  struct built from `RuntimeConfig`.
- **tool_runtime.ail**: Zero env reads. Accepts `ohmy_pi: bool` and
  `workdir: string` as parameters.
- **All 5 production extensions**: `register_with_config(RuntimeConfig)`
  signatures. Zero env reads. test_dummy intentionally unchanged.
- **registry.ail / runtime.ail**: Pass `RuntimeConfig` through to extensions.
  `CORE_EXT_ORDER` and `CORE_EXT_STRICT` no longer read from env.
- **supervisor.ail**: Uses `load_config_from_cli(getArgs())`, validates
  secrets, starts backend, runs agent loop.
- **TypeScript TUI**: Spawns `supervisor.ail` with CLI args. Only secrets
  passed as env vars. `index.ts` reads JSON config, not TOML.
- **CLAUDE.md**: Updated to document JSON-only config model.

### Remaining minor debt

- `config.ts` still contains dead TOML code (`CORE_MAP`, `EXTENSION_MAPS`,
  `loadMotokoConfig`). Unused but not deleted.
- `MOTOKO_STREAM_EVENTS` and `OPENAI_BASE_URL` still passed as env vars from
  TUI to subprocess — could move to JSON/CLI for consistency.

## Handoff: native AILANG execution backend

The next major milestone for fully headless pure-AILANG Motoko is replacing
`src/tui/src/env-server.ts` (the TypeScript/Bun execution backend) with an
AILANG-native or Go-hosted backend. This removes the last TypeScript runtime
dependency from headless operation.

### What env-server.ts does today

The backend is an Express HTTP server that the AILANG supervisor calls over
HTTP. It handles:

- **`POST /exec`** — Execute bash commands with configurable timeout, stdout/
  stderr capture, truncation, exit code. This is the core hot path.
- **`GET /health`** — Liveness check.
- **Delegated tool dispatch** — ReadFile, WriteFile, EditFile, Search tools
  dispatched to child processes with timeout and output size limits.
- **OhMyPi tool integration** — Optional delegation to external tool handler.
- **Compose authoring** — Subagent subprocess management for composition.
- **Snippet execution** — AILANG snippet check/run with capability control.
- **Sandboxing** — `AILANG_FS_SANDBOX` enforcement, path guards.
- **Truncation** — Stdout/stderr byte limits, smart truncation.
- **Subprocess lifecycle** — Timeout, cancellation, cleanup on SIGTERM/SIGINT.

### Starting points

- Read `src/tui/src/env-server.ts` for the full HTTP contract.
- Read `src/tui/src/env-server-main.ts` for the standalone entrypoint.
- Read `src/core/env_client.ail` for the AILANG HTTP client that calls the
  backend.
- Read `src/core/backend.ail` for the backend abstraction layer
  (`start_or_connect_backend`, `exec_backend`, `stop_backend`).
- The backend config is already in `RuntimeConfig.backend` (mode, url, port,
  command, args, startup_timeout_ms, auto_start).

### Key decisions for the next plan

1. **Implementation language**: AILANG-native using `std/process` + `std/stream`,
   or Go-hosted bundled with the AILANG runtime?
2. **Protocol**: Keep HTTP (`external_http` mode), switch to stdio JSONL, or
   in-process calls?
3. **Scope**: Start with `POST /exec` only (the core hot path), or cover
   delegated tools and compose authoring from the start?
4. **Sandboxing**: How to replicate `AILANG_FS_SANDBOX` path enforcement?
5. **Timeout/cancellation**: AILANG's `std/process` `exec` has timeout support
   but may need streaming stdout for large outputs.

### Relevant plans

- `.agent/plans/Motoko_Core_Config_Supervisor.md` — Phase 8 (future native
  backend) outlines the scope.
- `.agent/plans/Headless_JSON_Only_Config.md` — The completed config plan.
- `.agent/plans/Brain_Owned_Tool_Execution.md` — May have related design notes.
