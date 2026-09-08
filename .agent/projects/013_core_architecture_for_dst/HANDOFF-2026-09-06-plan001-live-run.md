# HANDOFF — PLAN-001 live run, container rebuild

Date: 2026-09-06 ~08:40 UTC. Branch: `arniwesth/013-dst-architecture-adr`.
Run file: `.dagr/run-plan001.json` (strict-clean, `dagr check --strict` → `[]`, 19 events).
Orchestrator pane was `w3:p5`. Dagr view pane: `w3:p7` (label `dagr`).

## State: 4/11 done, P1B in flight

| Task | State | Notes |
|---|---|---|
| D6 | done (a2) | ext_ambient re-pin 17→18, `make ext_ambient_inventory_selftest` green. NOT committed (workdir) |
| P0 | done (a2) | 4 files (3 asks + eval). NOT filed upstream (gh not authed, skill absent). Records honest |
| INV | done (a3) | `tools/driver_leaf_inventory/derive.py`, 24 leaves, 4 fixtures green. Committed `5088611` |
| P1A | done (a2) | `src/core/context_limit.ail`, check clean. Committed `a24a78a` |
| P1B | **working (a1)** | Worker `mot-dlg-1788683105871` on `w3:pQ`. Has 1 edit in workdir (tool_catalog.ail description). Rest of steps 3–7 NOT done |
| P1C, P2* | queued | Blocked downstream |

Failed/settled_unverified attempts in history (a1s) are stale-marker + stalled-worker records. Do not "fix" them; history never moves backward.

## The live worker (P1B) — assume DEAD after rebuild

- Delegates do not survive a container rebuild. `w3:pQ` will be gone.
- Its 1 edit (`src/core/tool_catalog.ail` description line) is uncommitted workdir state — verify it survived, else redo (1 line, see `git diff src/core/tool_catalog.ail`).
- Run `DelegateCheck mot-dlg-1788683105871@w3:pQ`: if no answer file, settle `P1B·a1` as failed (heuristic, stale — same wording as prior settlements), open `P1B·a2` and either re-delegate (kind motoko!) or take over directly.
- Full P1B prompt is in `.motoko/herdr-delegates/task-mot-dlg-1788683105871.md`. Spec: PLAN-001 §P1 steps 3–7 + Anchor cascade.

## Uncommitted work that must survive / be redone

1. D6 re-pin: `tools/ext_ambient_inventory/fixtures/expected.json` (extensions 18 + repetition_guard entry). Re-verify: `make ext_ambient_inventory_selftest`.
2. P0 files: 3× `.agent/issues/ailang-*.md` + `.agent/projects/012_continuous_ailang_adoption/EVAL-m-effect-replay-contracts-partial.md`.
3. P1B partial: `src/core/tool_catalog.ail` 1-line description.
4. Plus unrelated workdir changes the operator owns (PLAN-002, Dockerfile, ailang.lock, other .agent docs) — do NOT touch.

## After rebuild: re-verify before doing anything

```text
git status --short          # expect the files above
git log --oneline -3        # expect 5088611, a24a78a on top (plus operator's live-run fix commits)
dagr check .dagr/run-plan001.json --strict --json   # expect []
```

Then: settle P1B·a1 per above, continue P1B → P1C → P2 chain per PLAN-001.

## Hard-won lessons (paid for already — do not re-pay)

1. **`Delegate` MUST pass `kind: "motoko"`** or it spawns claude-code. Two stale-marker incidents from this.
2. **Motoko delegates never go idle** — completion = answer file only. `DelegateCheck` "not written yet" is the steady state; poll + read pane + touch `liveness.last_output_at` in the run file.
3. **Empty-stop loop**: worker thinking ends `finish_reason: length` with 0 tool calls, repeatedly, writing nothing. Fix: `pane send-text` nudge ("write via BashExec heredoc NOW"), 1–2 nudges max, then settle failed and take over directly (INV·a3, P1A·a2 both landed this way).
4. **WriteFile is unreliable in delegates** (`missing path` error). Tell workers to use BashExec heredoc.
5. **Run-file protocol**: edit `.tmp` → `dagr check --strict --json` (must be `[]`) → `mv` over live. Never leave run.json invalid. Task state = projection of latest attempt. Retries append `cause`-carrying attempts, never rewrite.
6. **Keep `w3:p5` (orchestrator) clean** — running work there caused the original stale markers.
7. Every task's `owner` is `motoko`; model chip on attempts is `motoko·max`.
