---
repo: arniwesth/motoko_agent
pr: 303
branch: fix/path-guard-set-plus-e
ticket: null
title: "fix(core): keep the path guard's verdict under a login shell"
---

## Summary

The native tools' symlink guard failed open when the caller had no `SHLVL`. ReadFile, WriteFile and EditFile then followed a symlink out of the workdir. The guard runs as `bash -lc` under `set -eu`. On `exit`, a login shell sources `~/.bash_logout`, Debian's stock file runs `clear_console -q` at `SHLVL=1`, that returns 1 with no console, and errexit ends the shell with 1 instead of 43. The caller refuses only on 43 or 44, so the escape read as a pass.

This PR adds `set +e` before `exit 43` and `exit 44`, so the verdict survives the hook. errexit is there for the `realpath` calls at the top, and by then the decision is already made.

**This supersedes #299's approach.** #299 changes `bash -lc` to `bash -c`. That would make a `realpath` found only through a profile (Homebrew coreutils on macOS) not be found, the guard would exit 127, and the caller reads 127 as a pass too. That swaps one fail-open for another, and `set +e` has no such trade.

**This keeps #299's probe half.** `scripts/verify_native_path_guard.ail` comes from `db6772f6`, with one comment changed because the guard still runs under `-lc`. #299's `tool_runtime.ail` change is not taken.

**#300 should be re-scoped against this.** It edits the same guard, and at its tip it has no `set +e`. The fail-open policy at the caller (refusing only on 43/44) is unchanged here and remains #300's question.

**macOS is untested.** This fix preserves today's macOS behaviour rather than improving it. Where `realpath -m` is missing the guard still exits non-43/44, and that still reads as a pass.

## Changes

- test(core): pin SHLVL in the path guard probe
- fix(core): keep the path guard's exit code under a login shell
- test(core): mutants and clean-environment differential for the path guard

6 files changed.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/evidence/path-guard-set-plus-e/` holds `mutate.sh`, `mutants.tsv`, `commit` and `differential.txt`.
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`

## Predicted outcome

`make verify_native_path_guard` and `make check_core` give the same result whatever the caller's `SHLVL`. Both pass from a clean environment that can find `ailang`, and both still pass ambient. An inside-workdir path is unaffected.

## Test evidence

**The clean-environment command needs `ailang` on its `PATH`.** With `PATH=/usr/local/bin:/usr/bin:/bin`, `ailang` is not found (it is in `~/.local/bin`), and that shape fails the same way before and after this fix. `verify_native_path_guard` prints `0 OK, 0 FAIL` and `Error 1`, and its message blames a symlink even though the recipe exited before the guard ran. `check_core` stops at `verify_native_process_tree`, not at the guard. The real differential adds `~/.local/bin`:

| Target | Environment | Before (`df14e9cb`) | After (`d23109ed`) |
|---|---|---|---|
| `verify_native_path_guard` | `env -i`, `PATH` with `ailang` | **fail**: 5 of 6 checks FAIL, including a file planted outside | **pass**: both legs, 6 of 6 |
| `verify_native_path_guard` | ambient | pass | pass: both legs, 6 of 6 |
| `verify_native_path_guard` | `env -i`, `PATH` without `ailang` | fail: `ailang` not found | fail: `ailang` not found |
| `check_core` | `env -i`, `PATH` with `ailang` | **fail**: stops at the guard | **pass**: `61 passed, 0 failed` |
| `check_core` | ambient | pass: `61 passed, 0 failed` | pass: `61 passed, 0 failed` |
| `check_core` | `env -i`, `PATH` without `ailang` | fail: `verify_native_process_tree` | fail: `verify_native_process_tree` |

`make test` passes, and it is a sanity signal only.

The new probe on the unfixed guard (`c023e16d`) isolates the bug: the `SHLVL unset` leg fails and the `SHLVL 1` leg passes all six.

**Inside-workdir control.** The committed guard script run directly under `bash -lc`:

| Path | `SHLVL` unset | `SHLVL=1` |
|---|---|---|
| `inside` | 0 | 0 |
| `new.txt` | 0 | 0 |
| `link/secret` | 43 | 43 |
| `link/planted` | 43 | 43 |

**Mutants**, at `d23109ed`, each from the clean environment:

| Id | Edit | Probe row | Result (unset / `SHLVL=1`) | Verdict |
|---|---|---|---|---|
| m1 | remove `set +e` at the 43 site | all six | red / green | killed |
| m2 | remove `set +e` at the 44 site | all six | green / green | **survived, as predicted** |
| m2a | 43 arm falls through, 44 site as fixed | ReadFile | green / green | passed |
| m2b | 43 arm falls through, remove `set +e` at 44 | ReadFile | red / green | killed |
| m3 | `exit 43` becomes `exit 0` | all six | red / red | killed |
| m4 | no edit | all six | green / green | passed |

**m2 survives because `exit 44` is unreachable in normal operation.** For an existing path, `realpath -m` and `realpath` agree, so the 43 arm has already refused it, and only a race between the two calls could reach 44. The `set +e` at 44 is kept for consistency, and m2a and m2b show it works once that arm is reached. With the 43 arm gone, WriteFile to a new file is not refused at all, because `[ -e ]` is false. So the 43 arm is the only protection for a new file.

**What this does not fix.** A `~/.bash_logout` or profile that calls `exit 0` still replaces the verdict: I measured 0 for an `exit 0` in `.bash_logout`, an `exit 0` in `.bash_profile`, and a `trap "exit 0" EXIT` in `.bash_profile`. A profile that only prints and fails is harmless (43). The fix removes errexit's part in this, not every way a hook can change the code.

Not run: macOS, and CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
