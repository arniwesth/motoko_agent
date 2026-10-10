---
repo: arniwesth/motoko_agent
pr: 253
branch: docs/005-orchestrator-start-script
ticket: null
title: "docs(005): a start script for the plan's Motoko orchestrator — one command in place of a pasted block"
---

## Summary

Adds `start-orchestrator.sh` beside the orchestrator's prompt that #249 brought. The operator runs
it in a herdr pane in place of `make motoko`. It writes the local run file that names the pane,
which is what puts Motoko in orchestrator mode, and then starts Motoko.

#249's prompt file had this as a 25-line block to paste into the pane before starting Motoko.
The operator found that cumbersome. Starting a session is now one command and one paste.

Follows #249, which merged while this was being written. Its first form was pushed to #249's
branch after the merge; that branch has been deleted again, and #249's description was restored
to the record that merged.

## Changes

- docs(005): a start script — one command writes the run file and starts Motoko

2 files changed.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/PROMPT-motoko-finalize-policy-migration-start.md`:
  its steps for the operator go from four to three, and its inline block is gone.
- `.agent/projects/005_harness_policy_boundary/start-orchestrator.sh`: new.
- `.agent/projects/005_harness_policy_boundary/PLAN-finalize-policy-migration.md`: the plan the
  session orchestrates. Not changed here.

## Predicted outcome

- **Starting the first session is: pull, run the script in a herdr pane, paste the prompt.**
  The script writes `.dagr/run-005-finalize-policy-migration.json` for that pane, checks it with
  `dagr check --strict`, and runs `make motoko` with its arguments.
- **A later session names what has merged.** `MERGED="WI-7 …"` seeds those tasks as done, so the
  tasks behind them are ready.
- **Two things that would trip a run are said before it starts.** The script warns when another
  run file names the same pane, and when `~/.claude/settings.json` sets no permission mode for
  delegates.
- **Nothing a session does changes.** The script is run by hand and nothing calls it.
- Why starting Motoko alone is not enough is unchanged: the herdr extension reads orchestrator
  mode once, at startup, from a file under `.dagr/` that names the session's own pane, and the
  committed graph names no pane (008 ADR-001 D5).

## Test evidence

Checked on 2026-10-10. The script and the prompt file are the same blobs that were tested.

- [x] **The script does what it says.** Run in a copy of the layout with a made-up pane id and a
  stand-in `Makefile`: it writes the run file, `dagr check --strict` prints `[]`, the file names
  that pane with mode `delegate` and ten guarded paths, and `make motoko` runs in the shared
  checkout with `PROFILE=dogfood` passed on. It was started from another directory.
- [x] **`--no-start`** writes the file and stops.
- [x] **`MERGED` with ten task ids** gives a run file with ten `done`, thirteen `queued` and
  one `canceled`, which passes `dagr check --strict`.
- [x] **It refuses** with no `HERDR_PANE_ID`, when run from a worktree, and when `MERGED` names
  a task the graph does not have. Each exits 1 and writes nothing new.
- [x] **It warns** when another run file names the same pane and when no permission mode is
  set, and goes on.
- [x] **A graph `dagr` rejects starts nothing.** With a dependency on an unknown task it prints
  dagr's finding, and the earlier run file is unchanged (same hash).
- [x] **The extension reads the file the script wrote.** `mode_from_doc_str` in
  `packages/motoko-ext-herdr/orchestrator.ail` gives `on` with `max_in_flight` 1 and the ten
  guarded paths for the named pane, and `off` for another. `seed_from_plan` gives 24 tasks, 23
  of them with the owner `claude-opus-5-5`, and the result passes `dagr check --strict`.
- [x] **`bash -n`** on the script.
- [ ] The script was not run against the real `make motoko`, and no Motoko session was started.
- [ ] No code changed, so no gate was run. CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
