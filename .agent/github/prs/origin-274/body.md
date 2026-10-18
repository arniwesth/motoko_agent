---
repo: arniwesth/motoko_agent
pr: 274
branch: docs/034-orchestrator-prompt
ticket: null
title: "docs(034): a Motoko orchestrator prompt and start script for PLAN-001 W0"
---

## Summary

This adds what is needed to run 034 PLAN-001 (merged in #273) with Motoko as the orchestrator: a start script that puts Motoko in orchestrator mode, and the prompt to paste. The first session covers workstream W0 (Phase 0, tasks W0.1 to W0.7) as one pull request. Motoko delegates every task to Claude Opus 5.5 through the herdr extension and checks each result before the next. Both files are adapted from 005's pair, whose W1 session shipped as #256. Docs and a shell script only; no source changes.

## Changes

- docs(034): a Motoko orchestrator prompt and start script for PLAN-001 W0

3 files changed.

- **`start-orchestrator.sh`** (new). You run it in the herdr pane instead of `make motoko`, from the repository root. It writes `.dagr/run-034-plan-001.json`: the committed graph plus this pane's id with `mode: "delegate"`, which is what turns orchestrator mode on. It checks the file with `dagr check --strict` and then runs `make motoko`. Setting `MERGED="…"` seeds merged tasks as done for later sessions. It differs from 005's script only in paths and names.
- **`PROMPT-motoko-plan-001-start.md`** (new). It holds the steps before starting, the prompt itself, notes for the operator, and a table of later sessions (W0b, W1, W2/W3) saying where each stops for the operator. The prompt has Motoko:
  - create one worktree, `034-w0`, and hand each task to a Claude Opus 5.5 delegate;
  - stop if its pane runs as root, because W0.5 and W0.6 are accepted only on a non-root run;
  - never re-run `make dst` or `make eval_matrix` itself;
  - have W0.7's delegate open the pull request as a draft, as the bot, then stop.
- **`PLAN-001-effect-disclosure.md`**: the header points to both files.

## Governing docs

- `.agent/projects/034_ambiguous_tool_outcomes/PLAN-001-effect-disclosure.md`
- `.agent/projects/034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md`
- `.agent/projects/005_harness_policy_boundary/PROMPT-motoko-finalize-policy-migration-start.md` (the precedent)
- `.agent/projects/008_docs_system/ADR-001-plan-structure-in-dagr-and-retiring-linear.md` (D5: the committed graph names no pane)

## Predicted outcome

- Nothing changes until someone runs the script.
- Then a fresh Motoko session in a herdr pane starts as the orchestrator of `034/PLAN-001`, delegates W0.1 to W0.7, and ends with W0's draft pull request open.
- **How that will be checked:** by the first session. The prompt's *What was checked, and what was not* section says what has and has not been exercised.
- **Operator setup on this machine:** `permissions.defaultMode` in `~/.claude/settings.json` was set to `auto` on 2026-10-18, as 005's session ran. The extension starts delegates with no flags, so without the setting a delegate stops at its first shell command. The file is outside the repository.

## Test evidence

Run on 2026-10-17 and 2026-10-18 in a scratch copy of the repository layout, with a made-up pane id `w9:p99`:

- `start-orchestrator.sh --no-start` writes the run file. `dagr check --strict --json` prints `[]`, and the file has the pane, `mode: "delegate"` and `max_in_flight: 1`.
- With `MERGED` naming W0.1 to W0.7, those seven become `done` and the file still passes `--strict`.
- The script exits 1 for:
  - an unknown `MERGED` id (`W9.9`);
  - no `HERDR_PANE_ID`;
  - a start from a subdirectory.
- With the permission mode unset it warned. With `auto` set it reports `delegates' permission mode: auto` and gives no warning.
- `mode_from_doc_str` (`packages/motoko-ext-herdr/orchestrator.ail`), called on the written file through a small AILANG probe on v0.52.5:
  - for its own pane it gives `on:.dagr/run-034-plan-001.json:w9:p99:1:src/,scripts/,packages/,tools/,.agent/,.github/,.motoko/config/,Makefile,SYSTEM.md,AGENTS.md`;
  - for `w9:p98` it gives `off`.
- `seed_from_plan_str` (`packages/motoko-ext-herdr/dagr.ail`):
  - gives 26 tasks, all `queued` with 0 attempts;
  - with `MERGED` naming W0, gives 7 `done` with 1 attempt each and 19 `queued`.
- `dagr check .agent/projects/034_ambiguous_tool_outcomes/PLAN-001.dagr.json --strict` → `✓ clean — 26 tasks`. The script passes `bash -n` and is committed as mode 100755.
- The herdr extension is unchanged since `a7c77571` (2026-10-08), the version 005's prompt was checked against.

Not run: no Motoko session has been started with this prompt. Delegation, verification, the ship steps and the stop rules were exercised only by 005's session.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
