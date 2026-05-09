---
doc_type: short
full_text: sources/2026-05-03-headless-config-plan-review.md
---

# Summary: 2026-05-03 Headless Config Plan Review and Handoff

## Overview
This session verified that the [[concepts/headless-json-only-config]] migration is complete and identified the next milestone: replacing the TypeScript execution backend (`env-server.ts`) with a native [[concepts/native-execution-backend]]. The plan to drop environment variable config for non-secrets and use only JSON profiles + CLI args has landed successfully.

## Key Findings
- **Config Model Fully Landed**: All components (`config.ail`, `rpc.ail`, `tool_runtime.ail`, production extensions, `registry.ail`, `runtime.ail`, `supervisor.ail`) use `RuntimeConfig` and no longer read any `getEnv` calls for non-secret values. The TypeScript TUI now passes only secrets as env vars and reads JSON config directly.
- **Verified Coverage**: Every piece of the config pipeline was checked — `parse_cli_args`, `load_config_from_cli`, extension registration signatures, and the supervisor startup flow all align with the JSON-only design.
- **Minor Remaining Debt**: Dead TOML parsing code still exists in `config.ts` (`CORE_MAP`, `EXTENSION_MAPS`, `loadMotokoConfig`). A few remaining env vars (`MOTOKO_STREAM_EVENTS`, `OPENAI_BASE_URL`) are still passed from the TUI to subprocess. These do not compromise the headless goal but could be moved to JSON/CLI for consistency.

## Handoff: Native Execution Backend
- The [[concepts/env-server-ts-functionality|current backend]] is a TypeScript Express server handling bash execution, tool delegation, OhMyPi integration, compose authoring, and sandboxing.
- The goal is to build an AILANG-native or Go-hosted backend to eliminate the last TypeScript runtime dependency from headless Motoko.
- Starting points: `src/tui/src/env-server.ts`, `src/core/env_client.ail`, `src/core/backend.ail`.
- Key design decisions remain: implementation language, protocol (HTTP/stdio/in-process), scope (start with `POST /exec` or full feature set), sandboxing replication, and timeout/cancellation mechanisms.

## Related Concepts
- [[concepts/headless]]
- [[concepts/headless-json-only-config]] — The completed config architecture using JSON profiles and CLI args.
- [[concepts/native-execution-backend]] — Future AILANG-native or Go backend for process execution.
- [[concepts/env-server-ts-functionality]] — Capabilities of the current TypeScript backend that need replacement.
- [[concepts/backend-execution-mode]] — Comparison of execution modes: HTTP, stdio JSONL, in-process.
- [[concepts/config-migration-verification]] — Process and criteria used to confirm the config migration.
