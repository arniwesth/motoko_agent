---
repo: arniwesth/motoko_agent
pr: 250
branch: fix/verify-native-path-guard-clear-sandbox
ticket: null
title: "fix(make): verify_native_path_guard clears AILANG_FS_SANDBOX, so a session with verification enabled can finish"
---

## Summary

`make verify_native_path_guard` builds its own workdir under `/tmp`. Inside a Motoko session the
TUI sets `AILANG_FS_SANDBOX` to the session's workdir, AILANG then refuses the test's own files,
and 2 of its 6 checks fail. This clears the variable for that one command, as
`verify_strict_extensions` and `verify_strict_context_limit` already do.

It matters because the target is a prerequisite of `make check_core`, and a profile with
verification enabled runs `make check_core` after every final answer. Inside a session that
command could not pass, so the session could not finish. Two sessions looped on it: 320
rejections on 2026-10-08 and 57 on 2026-10-09.

**The hunk is the one #209 (`f902fb0e`) and #234 (`ed5a3ee5`) already carry, unchanged.** It was
written on 2026-10-01 and has waited in those two pull requests since. Landing it by itself
removes the trigger now, and both rebase onto it without a conflict.

**One clause of the new comment is ahead of `main`.** It says the target checks that "EditFile
works (mode bits kept)" inside the workdir. That check arrives with #209 or #234. The text was
kept as it is so that those two do not conflict.

**This removes the trigger, not the loop.** Any other verifier command that cannot pass will loop
the same way. Bounding that is the subject of #249.

**A passing gate is slow.** With this change, each final answer on such a profile waits for the
whole of `make check_core`: 164 s and 183 s in the two runs below, on cold caches. Before, it
failed after 39 s.

## Changes

- fix(make): verify_native_path_guard clears AILANG_FS_SANDBOX

1 file changed.

## Governing docs

None governs the change itself. The incident it answers is recorded in Amendment 1 to
`.agent/projects/005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`, proposed in
#249, which lists this fix as independent of the amendment.

## Predicted outcome

- **A session on a profile with verification enabled can finish.** Checked by starting a session
  on the `default` profile after this lands, asking for something that needs no tool call, and
  seeing `done` with no `dp7_verifier_rejected` event in its log.
- **CI is unchanged.** CI does not set `AILANG_FS_SANDBOX`, and removing an unset variable does
  nothing. Checked by the `check_core` job on this pull request.
- **#209 and #234 rebase without a conflict in this recipe.** Checked when either rebases.

## Test evidence

Run on 2026-10-09 at `36a96b1e` and at this branch's `f56c97d6`, AILANG v0.52.5, on clean
checkouts.

- [x] **The target, with the variable set to the workdir.** `main`: exit 2, 4 `OK`, 2 `FAIL`.
  This branch: exit 0, 6 `OK`.
- [x] **The target, with the variable unset.** Exit 0 and 6 `OK` on both.
- [x] **The command DP7 runs, under a session-like environment.** `bash -c 'cd "$1" && make
  check_core 2>&1'` under `env -i` with the fixed keys of `buildChildEnv`
  (`src/tui/src/runtime-process.ts`), `AILANG_FS_SANDBOX` among them.
  - `main`: exit 2 after 39 s, stopped at this target, with the same two `FAIL` lines and the
    same `Makefile:2820` error as the rejections in the two sessions' logs.
  - This branch: exit 0 after 183 s, 184 `OK`, 0 `FAIL`, `src/core/ type-check: 60 passed, 0
    failed`.
- [x] **The same two runs on the Motoko session's own version of the fix** (`69f7353a`, a
  different comment and no `.PHONY` line): exit 0, 6 `OK`; and exit 0 after 164 s, 184 `OK`.
- [x] **The hunk is identical to #209's and #234's.** The added and removed lines of `f902fb0e`,
  `ed5a3ee5` and this commit were compared with `diff`.
- [ ] **No live session was run.** The environment was reproduced from `buildChildEnv`'s fixed
  keys. Variables the TUI passes through from the operator's shell were not included.
- [ ] No mutant of the path guard was run against the target. The script is unchanged, and #234's
  review ran two.
- [ ] `make dst` and `make test` were not run. The change is one recipe line and a comment.
- [ ] CI had not finished when this was written.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
