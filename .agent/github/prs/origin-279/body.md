---
repo: arniwesth/motoko_agent
pr: 279
branch: arniwesth/034-w0b-deadline-wrapper
ticket: null
title: "test(034): probe the deadline wrapper, then withdraw Phase 0b (034 W0b.1, W0b.2)"
---

## Summary

This is Phase 0b of 034 ADR-001 (`034/PLAN-001` workstream W0b), and it ends there. W0b.1 (`034/PLAN-001/W0b.1`) probes a GNU `timeout` deadline wrapper through `run_process_result` on AILANG v0.52.5 and records the tool message the model reads. On those results the operator answered W0b.2 (`034/PLAN-001/W0b.2`) by **withdrawing Phase 0b**: W0b.3 (the wrapper) and W0b.4 (its mutation run) are canceled. The process-group kill is left to the AILANG `>=0.54.14` pin move (012), and partial output on timeout to sunholo-data/ailang#1878.

**No file under `src/` changes.** The PR adds the probe and its results, and updates the 034 records.

### W0b.1's five open points, as answered in `RESULTS-W0b.1-wrapper-probe.md`

1. **Exit 124.** From the rendered message, a wrapper deadline (case 25) cannot be told from a command's own 124 (26, 27): both are `exit_code: 124` with no fault. Elapsed time is the one signal that holds up: "124 and elapsed ≥ deadline" means the timer fired, and the only misreading errs toward `unknown`. `--verbose` is not usable: the command can forge the line (29), and its quoting depends on the locale (28 against 29b). Timing would add `Clock` to `run_process_result`'s effect row and up the chain to `live_tool_outcome`. A command that ignores TERM comes back as `signal`/`unknown` with its output lost (30).
2. **GNU `timeout` absent (stock macOS).** Approximated on Linux, not run on macOS. On the direct arm a missing `timeout` is `NotFound` before any launch (36), so an `exec`-level wrapper can fall back to running the call unwrapped without running anything twice, and `gtimeout` covers Homebrew (38). Inside a `bash -lc` string, absence looks like the command's own exit 127 (37), so the wrapper must not go there.
3. **The direct-exec arm.** The wrapper works on it: `tail -f` and `sleep 30` return at the deadline with their output (33, 34), where without it they hit the wall and lose it (32, 23). Case 35 shows the dropped `req.args` on the `bash -lc` arm is a real defect: `bash -lc "timeout"` ran, and the message rendered `cmd` as the full line.
4. **Case A under a wrapper.** Measured: the wrapper does not help it (40 against 39, both about 5,008 ms, `spawn_failed`/`unknown`, stdout `""`). The background work lands later. Case A is upstream's, sunholo-data/ailang#1879.
5. **AILANG `>=0.54.14`.** Not run; inferred from `RESULTS-v0.52.5.md`'s reading of the v0.54.15 source. The group kill and the early return go away there. What the wrapper would still add: partial output (#1878 is open), a per-call deadline below the wall, an `Ok` with an exit code, and TERM before KILL. Nothing for case A, the output limit, `setsid`, or a command that ignores TERM. `timeout` moves the command into its own process group (46), so a wrapper would need to be outermost and keep deadline + grace below the wall (42, 43).

### The W0b.2 decision

The operator chose **Option 3: withdraw Phase 0b**. W0b.3 and W0b.4 are `canceled` in `PLAN-001.dagr.json`, each with a note naming the probe. The plan's status moves to W1. The ADR records it as §6 ruling 6 and under D6. The `req.args` drop on the `bash -lc` arm was W0b.3's to fix; with W0b withdrawn it stays in the plan's *Follow-ups* as a fix of its own.

## Changes

- test(034): probe a deadline wrapper through run_process_result (034 W0b.1)
- docs(034): record W0b.2 withdrawal of Phase 0b and cancel W0b.3-W0b.4 (034 W0b.2)

What each part does:

- **W0b.1.** `evidence/wrapper_probe.sh` sends 26 `BashExec`/`RunTests` calls through `dispatch_one_typed` → `run_process_result`, with `timeout` written into the call, from a scratch tree that links the repo's `src/` and `packages/`. `wrapper_probe.ail` is the driver, `wrapper_probe.out` the raw output, and `RESULTS-W0b.1-wrapper-probe.md` the results. It also specifies witness rows ws1-ws5 (now unused) and lists the anchors W0 (#277) and #275 moved since the plan's grounding.
- **W0b.2.** The status lines, the Phase 0b and W0b.2 sections of the plan, D6 and §6 of the ADR, and the two canceled tasks in the graph.

## Governing docs

- `.agent/projects/034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md` (D6, §6 ruling 6)
- `.agent/projects/034_ambiguous_tool_outcomes/PLAN-001-effect-disclosure.md` (and `PLAN-001.dagr.json`; task addresses `034/PLAN-001/W0b.1`, `034/PLAN-001/W0b.2`, `034/PLAN-001/W0b.3` canceled, `034/PLAN-001/W0b.4` canceled)
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/RESULTS-W0b.1-wrapper-probe.md`

## Predicted outcome

- Nothing changes at runtime: no file under `src/`, `scripts/` or `packages/` is touched. A faulted tool result renders exactly as W0 (#277) left it. How that is checked: `make check_core`, and `git diff --stat origin/main..HEAD` lists only `.agent/` paths.
- Phase 0b is closed in the records: `dagr view` shows W0b.3 and W0b.4 as canceled, and no other task changes (W1.1 depends on W0.7, not on W0b). How that is checked: `dagr check --strict` prints `[]`.
- If #1878 lands upstream or the pin moves to `>=0.54.14`, the wrapper's case is re-read from `RESULTS-W0b.1-wrapper-probe.md` point 5; nothing here schedules it.

## Test evidence

All at this branch, uid 1001 (`id -u` → `1001`), AILANG v0.52.5:

| command | exit | last lines |
|---|---|---|
| `bash .agent/projects/034_ambiguous_tool_outcomes/evidence/wrapper_probe.sh` | 0 | `case 43 (deadline + grace over the wall): sleep 120.43 alive, its timeout gone`. Run at W0b.1, and again for this PR: every case renders as in the committed `wrapper_probe.out`, timings aside. `pgrep -af 'sleep 120\.'` afterwards found nothing left running |
| `make check_core` | 0 | `src/core/ type-check: 60 passed, 0 failed` |
| `dagr check .agent/projects/034_ambiguous_tool_outcomes/PLAN-001.dagr.json --strict --json` | 0 | `[]` |

Not run, or not run as specified:

- **AILANG `>=0.54.14`: not run.** Only v0.52.5 is installed; point 5 is inferred from source.
- **macOS: not run.** Point 2 is approximated by `PATH` stripping, a missing wrapper name and a `gtimeout` symlink.
- `make dst` and `make eval_matrix` were not run: W0b.4's baseline pass is canceled with it, and nothing they exercise changed.
- No model-in-the-loop run was made. CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
