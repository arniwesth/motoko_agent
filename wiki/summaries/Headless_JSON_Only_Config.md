---
doc_type: short
full_text: sources/Headless_JSON_Only_Config.md
---

# Headless JSON-Only Config

## Summary

This design document proposes a radical simplification of Motoko's configuration system, collapsing a complex four-layer precedence chain (hardcoded defaults < `.env` files < JSON profiles < shell env vars) into a clean two-layer model: **hardcoded defaults < profile JSON < CLI args**. Only API key secrets remain as environment variables. This enables fully headless operation where the AILANG supervisor is the sole entry point.

## Key Changes

The new precedence model eliminates ambiguity about which layer set a given value. One-off overrides use CLI flags (`--profile`, `--model`, `--workdir`, `--port`, `--ext-order`, `--system-prompt`, `--no-backend`), with the task passed as a positional argument. The `--profile` flag also falls back to the `MOTOKO_CONFIG` env var for backwards compatibility.

## Implementation Phases

### Phase 1 — CLI Arg Parser
Adds `CliOverrides` record type and `parse_cli_args()` parser to [[concepts/config-loading]] (`src/core/config.ail`). Introduces `load_config_from_cli()` as a new entry point that reads the profile, loads JSON, applies CLI overrides, and skips env overlay entirely. The supervisor switches to this path while legacy `load_runtime_config()` is preserved for the TUI path.

### Phase 2 — Thread Config Through rpc.ail
Removes all direct `getEnvOr` calls from [[concepts/rpc-layer]] (`src/core/rpc.ail`) and tool_runtime.ail. Every config value flows through typed records (`RuntimeConfig`, `InvocationConfig`) passed as function parameters. Adds new fields to `AgentConfig` (`semi_formal_verifier_mode`), `ContextModeConfig` (`timeout_ms`, `max_output_chars`), and `ExaSearchConfig`. Also cleans up `ComposeAuthoringConfig` by converting `author_tools_deny_globs` from a colon-separated string to a native `[string]` array.

### Phase 3 — Extension Config Plumbing
Extensions stop reading env vars entirely. The [[concepts/extension-registry]] (`registry.ail`) changes `resolve()` to accept `RuntimeConfig` and forward it to each extension's `register()` function. The `Env` effect drops from extension signatures. The largest change is in the compose extension (~16 env reads), with typed config captured in closures. This phase must complete before Phase 4.

### Phase 4 — Remove Env Overlay
Deletes all env overlay machinery from config.ail: `.env` file parsing, shell env overlay helpers, and three-layer merge functions. Config loading simplifies to: parse JSON + fill defaults + apply CLI overrides. The only remaining non-secret env read is `MOTOKO_CONFIG` as a fallback for `--profile`.

### Phase 5 — TypeScript TUI Migration
The [[concepts/typescript-tui]] spawns `supervisor.ail` with CLI args instead of passing env vars. The subprocess environment contains only secrets, `PATH`, and `HOME`. Significant dead code removal in `config.ts` including `CORE_MAP`, `EXTENSION_MAPS`, and `loadMotokoConfig()`.

### Phase 6 — Cleanup
Removes legacy TOML config files, updates default JSON profiles with new fields, and revises documentation (`README.md`, `CLAUDE.md`) to reflect JSON-only config.

## Verification Strategy

Includes AILANG type-checking and tests across all modified modules, a headless smoke test confirming no `getEnvOr` calls for non-secret values, and TypeScript test suite validation after Phase 5.

## Related Concepts

- [[concepts/config-loading]] — Config loading architecture and precedence chains
- [[concepts/rpc-layer]] — RPC module and env var removal
- [[concepts/extension-registry]] — Extension registration and config threading
- [[concepts/typescript-tui]] — TUI migration to CLI args
- [[concepts/headless-operation]] — Headless supervisor as sole entry point
