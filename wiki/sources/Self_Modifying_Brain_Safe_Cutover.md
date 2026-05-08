# Self-Modifying Brain: Safe Cutover Plan (v2)

## Goal

Deliver self-modification with **safety-first cutover** for the AILANG agent. The UI stays alive, but a staged brain candidate is only deployed after strict validation and a runtime smoke test. Failed swaps auto-rollback.

This plan supersedes risky parts of `Self_Modifying_Brain.md` and focuses on four non-negotiable gates:

1. Safe candidate validation in isolated root with canonical `swe/` path
2. Mandatory end-to-end brain smoke test (not only `probe_main`)
3. Strict path allowlist + validation on `upgrade_ready`
4. Transactional swap + auto-rollback watchdog

---

## Why v2 is required

The current hot-swap draft has failure modes that can produce false positives:

- `ailang check swe_next/rpc.ail` conflicts with strict module path rules (`module swe/...` vs file under `swe_next/...`).
- Using `--relax-modules` can silently resolve imports from active `swe/` and miss candidate errors.
- Current `tui` tests do not exercise the brain/runtime handshake.
- `probe_main` confirms only process startup, not command execution path.
- `upgrade_ready` paths are currently trust-based and not hardened.

v2 corrects all of the above.

---

## Safety invariants (must hold)

1. **No swap without strict candidate validation in canonical `swe/` root.**
2. **No swap without end-to-end smoke pass that exercises `/exec` path.**
3. **No filesystem mutation from unvalidated upgrade paths.**
4. **Swap is transactional; failure before stable `session_start` triggers automatic rollback.**
5. **Input is blocked during validation/swap and always unblocked on every exit path.**

---

## End-to-end flow (v2)

```text
1) Brain emits upgrade_ready (from sentinel in bash stdout)
2) TS receives event -> validates candidate path(s) against strict allowlist
3) TS runs isolated validation in canonical root (candidate mounted as ./swe)
4) TS runs mandatory runtime smoke (not probe-only)
5) If all gates pass: start transactional swap
6) Spawn resumed brain + watchdog timer
7) If resumed brain emits session_start in time -> commit
8) Else -> automatic rollback + restart old brain
```

---

## Phase 0 — Protocol hardening and strict allowlist

### Target files
- `swe/parse.ail`
- `swe/rpc.ail`
- `tui/src/brain.ts`
- `tui/src/index.ts`
- `tui/src/upgrade-manager.ts` (new)

### Changes

1. Keep `upgrade_ready` event, but **frontend treats it as untrusted input**.
2. Add `UpgradeManager.validateUpgradeReady(event)`:
   - Resolve with `fs.realpathSync`.
   - Candidate `new_swe_dir` must be exactly `${AGENT_DIR}/swe_next` (or explicit allowlist entry).
   - Optional binary must be exactly `${AGENT_DIR}/ailang_next_bin` if present.
   - Reject symlinks (`lstat.isSymbolicLink()`), non-existent paths, non-directories (for swe), non-executables (for binary).
3. Add candidate shape checks before any validation/swap:
   - Required files exist in candidate swe dir:
     - `rpc.ail`, `types.ail`, `parse.ail`, `prompts.ail`, `env_client.ail`, `cache.ail`, `agents_md.ail`

### Acceptance
- Path traversal or out-of-root values are rejected before any command execution.
- `upgrade_ready` with mismatched path produces `upgrade_result.failed(stage="allowlist")`.

---

## Phase 1 — Isolated candidate validation in canonical `swe/` root

### Target files
- `tui/src/upgrade-manager.ts` (new)
- `tui/src/index.ts`
- `tui/src/brain.ts` (options support)

### Changes

Create `UpgradeManager.runCandidateValidation()` that executes in an isolated workspace.

#### 1) Build isolated validation workspace

For upgrade id `<id>`:

- Workspace: `${AGENT_DIR}/.agent/upgrade-work/<id>/`
- Copy candidate into canonical path:
  - `${workspace}/swe/`  <- copy from `${AGENT_DIR}/swe_next/`
- If candidate binary provided:
  - `${workspace}/ailang_candidate` <- copy candidate binary

No validation command runs against `swe_next/...` paths.

#### 2) Strict compile/type gate (no relax)

From workspace root:

- `${AILANG_BIN_OR_CANDIDATE} check swe/rpc.ail`

Rules:
- **Do not** use `--relax-modules`.
- Fail on any non-zero exit.

#### 3) Optional deep checks (recommended)

Run strict checks per module for clearer diagnostics:
- `check swe/types.ail`
- `check swe/parse.ail`
- `check swe/prompts.ail`
- `check swe/env_client.ail`
- `check swe/cache.ail`
- `check swe/agents_md.ail`

### Acceptance
- Candidate with broken import/type in any `swe` dependency fails validation.
- Validation logs include exact command + stderr for UI reporting.

---

## Phase 2 — Mandatory end-to-end smoke test (not only `probe_main`)

### Target files
- `swe/rpc.ail`
- `tui/src/upgrade-manager.ts`
- `tui/src/brain.ts`

### Changes

Add a second smoke entrypoint in `swe/rpc.ail`:

- Keep `probe_main` (protocol startup check).
- Add `smoke_main` that exercises runtime command path end-to-end:
  - Emit `session_start`
  - Emit `thinking`
  - Emit `proposed_cmd`
  - Execute command via `exec_in` against env server (e.g., `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`)
  - Emit `obs`
  - Emit `done`

This avoids LLM/provider variance while still testing JSONL/event semantics + env execution.

`UpgradeManager` gate sequence:

1. `probe_main` pass (fast startup sanity)
2. `smoke_main` pass (mandatory runtime path)

Smoke pass conditions:
- Events appear in valid order.
- `obs` exists and contains exit code.
- Terminal `done` arrives within timeout (`SMOKE_TIMEOUT_MS`, default 30_000).

### Acceptance
- Candidate that starts but cannot execute command path fails smoke and never swaps.
- Candidate that emits malformed JSONL fails smoke and never swaps.

---

## Phase 3 — Transactional swap with watchdog and auto-rollback

### Target files
- `tui/src/upgrade-manager.ts` (new)
- `tui/src/index.ts`
- `tui/src/ui.ts`
- `tui/src/commands.ts` (optional rollback command wiring)

### Changes

Implement transaction API in `UpgradeManager`:

```ts
beginUpgradeTx(...)
commitOnSessionStart(...)
rollbackTx(...)
```

#### Transaction steps

1. `ui.blockInput()` synchronously.
2. Persist resume snapshot file (`/tmp/brain_resume_<id>.json`).
3. Set `swapping = true`.
4. Kill current brain.
5. Filesystem move sequence:
   - `rename(swe, swe_backup_<id>)`
   - `rename(validated_candidate_swe, swe)`
   - If binary candidate: backup + switch binary pointer
6. Spawn resumed brain.
7. Start watchdog timer (`SWAP_WATCHDOG_MS`, default 15_000).
8. Commit only when resumed brain emits `session_start`.

#### Watchdog rollback triggers

Rollback if any occur before commit:
- watchdog timeout
- resumed brain exit
- resumed brain `error` before first `session_start`
- spawn failure

Rollback steps:

1. Kill failed resumed brain (best effort)
2. `rename(swe, swe_failed_<id>)` (if present)
3. `rename(swe_backup_<id>, swe)`
4. Restore binary pointer if changed
5. Spawn old brain resume from snapshot
6. `swapping = false`
7. `ui.unblockInput()`
8. Emit `upgrade_result.failed(stage="watchdog_rollback")`

### Acceptance
- Forced startup failure after swap automatically restores previous brain.
- UI is never left permanently blocked.
- Old `swe_backup_*` remains available after successful commit for manual rollback.

---

## Phase 4 — Wiring and type updates

### Target files
- `tui/src/brain.ts`
- `tui/src/index.ts`
- `tui/src/ui.ts`
- `tui/src/upgrade-manager.ts` (new)

### Changes

1. Extend `Brain` constructor options:
   - `ailangBin`
   - `sweFile`
   - `entryPoint` (`main` | `probe_main` | `smoke_main`)
   - `extraEnv`
2. Add runtime events to `AgentEvent`:
   - `upgrade_ready`
   - `state_snapshot`
3. Keep `UpgradeResultEvent` as TypeScript-internal union in UI.
4. Index wiring:
   - Route upgrade events into manager.
   - Block input before async upgrade begins.
   - Suppress default process exit while `swapping = true`.

### Acceptance
- `index.ts` has a single owner for swap state and watchdog lifecycle.
- Event handling paths are exhaustive and typed.

---

## Phase 5 — Tests (must be added before rollout)

### Target files
- `tui/src/upgrade-manager.test.ts` (new)
- `tui/src/brain.test.ts` (new)
- existing tests updated as needed

### Required test cases

1. **Allowlist rejection**
   - `upgrade_ready` path outside `AGENT_DIR` rejected.
2. **Canonical validation gate**
   - candidate with broken `swe/parse.ail` fails strict check.
3. **Smoke gate**
   - candidate missing `obs`/`done` within timeout fails.
4. **Transactional rollback**
   - resumed brain fails before `session_start` => rollback executed.
5. **Input blocking lifecycle**
   - blocked during swap, unblocked on both commit and rollback.

### Acceptance
- `cd tui && npm test` covers upgrade manager core state machine and failure paths.

---

## Operational knobs

- `PROBE_TIMEOUT_MS` (default `30_000`)
- `SMOKE_TIMEOUT_MS` (default `30_000`)
- `SWAP_WATCHDOG_MS` (default `15_000`)

All must have sane defaults and be surfaced in failure messages.

---

## Rollout order

1. Phase 0 allowlist + protocol hardening
2. Phase 1 isolated canonical validation
3. Phase 2 mandatory smoke (`smoke_main`)
4. Phase 3 transactional swap + watchdog rollback
5. Phase 4 wiring/types
6. Phase 5 tests and rollout gate

No feature flag removal and no production use before phases 1–3 are complete.

---

## Done definition

The feature is complete only when all are true:

- Candidate validation is isolated and strict against canonical `swe/` path.
- Deployment requires both probe and runtime smoke pass.
- `upgrade_ready` paths are hardened by allowlist and filesystem checks.
- Swap automatically rolls back on watchdog failure, and UI remains usable.
- Tests cover allowlist, validation, smoke, rollback, and input-block lifecycle.
