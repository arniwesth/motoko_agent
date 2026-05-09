---
doc_type: short
full_text: sources/Self_Modifying_Brain_Safe_Cutover.md
---

# Self-Modifying Brain: Safe Cutover Plan v2 – Summary

This document defines a **safety-first cutover mechanism** for an AILANG agent’s core logic (the “brain”), replacing risky hot-swap drafts. The core contribution is a staged upgrade pipeline with four non-negotiable gates: canonical path validation, isolated compile checks, mandatory end‑to‑end smoke testing, and a transactional swap backed by an automatic rollback watchdog.

## Why v2 is required
- Previous attempts suffered from false positives: shared paths, relaxed module resolution, and insufficient runtime testing.  
- The original `probe_main` startup check does not verify actual command execution.  
- Untrusted upgrade paths could mutate the live system before validation.

## Safety Invariants
1. No swap without strict candidate validation in the canonical `swe/` directory.  
2. No swap without a smoke test that exercises the `/exec` command path.  
3. No filesystem mutation from unvalidated upgrade paths.  
4. Swap is transactional; failure before `session_start` triggers automatic rollback.  
5. Input is always blocked during swap and unblocked on every exit path.

## Key Mechanisms

### Phase 0 – Protocol Hardening & Strict Allowlist
- The `upgrade_ready` event is treated as untrusted input.  
- A new `UpgradeManager` resolves candidate paths with `fs.realpathSync`, rejects symlinks, enforces an allowlist (only `swe_next/` and `ailang_next_bin` inside `AGENT_DIR`), and verifies required files exist.  
- Violations produce `upgrade_result.failed(stage="allowlist")`.  
- See [[concepts/upgrade-allowlist]] and [[concepts/path-validation]].

### Phase 1 – Isolated Candidate Validation
- A temporary workspace is created (`/upgrade-work/<id>/`).  
- The candidate is copied into `swe/` (canonical path) to avoid cross‑root module resolution issues.  
- Strict compilation checks (`ailang check swe/rpc.ail` without `--relax-modules`) are run; failure aborts the upgrade.  
- Optional per‑module deep checks improve diagnostics.

### Phase 2 – Mandatory End‑to‑End Smoke Test
- A new entrypoint `smoke_main` in `swe/rpc.ail` exercises the runtime command loop: it emits `session_start`, `thinking`, `proposed_cmd`, executes a command via `exec_in`, emits `obs`, and finally `done`.  
- The manager validates the full JSONL event sequence and enforces a timeout (`SMOKE_TIMEOUT_MS`).  
- A candidate that cannot execute the command path fails smoke and is never deployed.  
- This moves beyond a simple startup probe to ensure the brain can interact with the environment server.

### Phase 3 – Transactional Swap with Watchdog Rollback
- The swap begins by blocking input, killing the current brain, atomically moving the old `swe` to a backup, and deploying the validated candidate.  
- A watchdog timer (`SWAP_WATCHDOG_MS`) monitors the resumed brain for `session_start`. If the event does not arrive, or the brain exits/errors before it, the system automatically rolls back: restores the backup `swe`, respawns the old brain, unblocks input, and emits `upgrade_result.failed(stage="watchdog_rollback")`.  
- This guarantees a live system at all times. Concepts: [[concepts/transactional-swap]] [[concepts/watchdog-rollback]].

### Phase 4 & 5 – Integration, Types, and Test Suite
- `Brain` constructor is extended with options for entry point, binary, and environment.  
- `AgentEvent` adds `upgrade_ready` and `state_snapshot`.  
- A new `upgrade-manager.ts` becomes the single owner of swap state.  
- Tests covering allowlist rejection, compilation failure, smoke timeout, rollback, and input‑block lifecycle are required before rollout.

## Operational Knobs
- `PROBE_TIMEOUT_MS`, `SMOKE_TIMEOUT_MS`, `SWAP_WATCHDOG_MS` with sane defaults, surfaced in failure messages.

## Rollout Strategy
Phases must be completed sequentially (0→1→2→3→4→5) and none of the earlier three phases can be skipped before production use.

## Done Definition
All five safety invariants are met; tests cover success and failure paths; the UI never enters a permanently blocked state.

See also:  
- [[sources/Self_Modifying_Brain.md]] (original risky approach)  
- [[concepts/self-modifying-brain]]  
- [[concepts/upgrade-pipeline]]