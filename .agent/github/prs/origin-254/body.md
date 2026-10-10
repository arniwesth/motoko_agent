---
repo: arniwesth/motoko_agent
pr: 254
branch: docs/005-start-script-from-root
ticket: null
title: "docs(005): the orchestrator's start script refuses to run outside the repository root"
---

## Summary

The first orchestrated session of the finalize-policy migration was started on 2026-10-10 with
#253's start script. Motoko came up as the orchestrator and delegated, but the dagr pane said
"waiting for run file — cannot read" a path under the plan's directory. The script had been
started from inside that directory.

This makes the script refuse to start from anywhere but the repository root, and records what
that session showed in its first ten minutes. One rule of the prompt changes with it.

## Changes

- docs(005): the start script refuses to run outside the repository root

2 files changed.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/PROMPT-motoko-finalize-policy-migration-start.md`:
  the operator's command starts with `cd`; the prompt's rule for a blocked delegate changes; a
  new section, *What the first session showed*.
- `.agent/projects/005_harness_policy_boundary/start-orchestrator.sh`: the new refusal.

## Predicted outcome

- **The dagr pane finds its run file in a session started with the script.** The cause was a
  mismatch the script allowed. Motoko ran from the root, because the script changes directory
  for it. herdr reports the shell's directory as the pane's. The extension hands the dagr view
  a relative path (`DAGR_RUN=./.dagr/run-<pane>-<session>.json`), and the view resolves it
  against the pane's directory. The script cannot move the shell, so it now refuses and prints
  the command to run.
- **The relative path itself is not fixed.** It is in `packages/motoko-ext-herdr`
  (`argv_dagr_pane`, called with `workdir` `.`). Started with plain `make motoko` the shell is
  always at the root, so only a wrapper that changes directory can expose it.
- **An orchestrator no longer parks on a block that clears by itself.** The prompt had it stop
  at the first `DelegateCheck` that reports a blocked delegate. It now checks three more times.
  This applies to sessions started with the prompt from here on, not to the one running.
- **Nothing a session does changes otherwise.**

## Test evidence

Checked on 2026-10-10.

- [x] **The cause, from the running session.** The dagr view's process had
  `DAGR_RUN=./.dagr/run-w4-pK-1791634942922.json`, its own working directory was the repository
  root, and its plugin context gave the focused pane's directory as
  `.agent/projects/005_harness_policy_boundary`. `herdr pane list` showed the orchestrator's
  pane with that directory and a foreground directory at the root. The run file existed at the
  root's `.dagr/` and passed `dagr check --strict`.
- [x] **The pane rendered once that path resolved.** A symlink at the path the view was waiting
  for, in a gitignored `.dagr/` directory beside the plan, made it draw the run at once.
  `git status` in the shared checkout did not change.
- [x] **The script refuses from the plan's directory.** In a copy of the layout: exit 1, the
  command to run printed, no run file written.
- [x] **The script still works from the root**, and from the root reached through a symlink:
  run file written, `dagr check --strict` prints `[]`, the stand-in for `make motoko` runs with
  its argument.
- [x] **`bash -n`** on the script.
- [x] **The other two findings, from the session's files.** The run file has attempt `W3-7·a1`
  settled `settled_unverified` after seven seconds ("no answer file was written") and `W3-7·a2`
  working on `claude-opus-5-5`. The first delegate's transcript has no user message. The
  orchestrator's pane shows it parked at 12:25:40 asking the operator to answer the delegate,
  while the delegate's transcript shows it working from 12:25:30.
- [ ] Why the first delegate never received its task was not determined.
- [ ] The changed rule for a blocked delegate was not tried in a session.
- [ ] The session had not finished a task when this was written.
- [ ] No code changed, so no gate was run. CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
