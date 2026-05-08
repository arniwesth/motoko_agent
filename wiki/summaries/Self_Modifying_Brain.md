---
doc_type: short
full_text: sources/Self_Modifying_Brain.md
---

# Self-Modifying Brain Summary

## Overview

The document describes a hot-swap architecture for an AI agent's brain, enabling runtime code modification of AILANG modules and binaries without restarting the TypeScript UI. The upgrade process preserves full conversation history, ensuring state continuity through a resume mechanism.

## Upgrade Flow

The agent detects a user's meta-task to "extend yourself" and stages new code in a `swe_next/` directory. It signals upgrade readiness via a sentinel string (`UPGRADE_READY:<path>`) embedded in bash command output. The frontend validates the new code through a test suite and a probe run before atomically swapping directories and restarting the brain subprocess with the previous conversation messages restored from a snapshot.

## Key Components (Phases 0-10)

- **Sentinel detection** (Phase 0): `extract_upgrade_ready` in `parse.ail` re-emits `upgrade_ready` event from bash output.
- **State snapshot** (Phase 1): `encode_msgs` serialises full chat history just before the `done` event; emitted once per task.
- **Probe entry point** (Phase 2): `probe_main` in `rpc.ail` performs a smoke test of the JSONL handshake without LLM calls.
- **Resume path** (Phase 3): `main()` checks `RESUME_MSGS_FILE`; if present, loads past messages and enters conversation loop directly.
- **Brain class & UI changes** (Phases 4, 6b): new `BrainOptions`, `AgentEvent` types for `state_snapshot` and `upgrade_ready`, and `UpgradeResultEvent` (UI-internal). UI input blocking via `Editor.disableSubmit` ensures no user messages during upgrade.
- **UpgradeManager** (Phase 5): orchestrates test suite execution, probe spawn, atomic directory renames, and resume brain spawning. Handles failure cleanup and rollback.
- **Rollback** (Phase 10): `UpgradeManager.rollback()` swaps back to the most recent `swe_backup_<ts>` and restores the brain.
- **System prompt integration** (Phase 8): `AGENT_DIR` and self-extension instructions added to base system prompt.

## Rollback & Fault Tolerance

Swap procedure ensures atomicity: old brain killed before filesystem changes; `rename("swe_next", "swe")` is an atomic syscall. After failed probe, `swe_next/` is preserved for inspection. Rollback reverses the swap using `swe_backup_<ts>` and AILANG binary backups, all validated previously.

## Known Limitations & Risks

- Resumed brain inherits old system prompt from `msgs[0]` if prompts changed.
- `encode_msgs`/`parse_msgs` rely on existing stdlib but require careful testing.
- `ailang check` may not transitively validate imports; additional checks needed.
- Shared memory namespace contamination between probe and live session is a future risk.
- 30-second probe timeout may need tuning in constrained environments.

## Cross-Document Concepts

[[concepts/hot-swap architecture]]
[[concepts/sentinel detection]]
[[concepts/state snapshot]]
[[concepts/probe entry point]]
[[concepts/resume mode]]
[[concepts/upgrade manager]]
[[concepts/rollback]]
[[concepts/JSONL protocol]]
[[concepts/shared memory isolation]]