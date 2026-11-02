---
repo: arniwesth/motoko_agent
pr: 299
branch: fix/path-guard-login-shell
ticket: null
title: "fix(core): stop the path guard failing open under a login shell"
---

## Summary

**This is a fail-open security check, not just a flaky test.** `validate_path_common` ran its symlink guard with `bash -lc` and a script starting `set -eu`. A login shell sources `~/.bash_logout` on `exit`. With `SHLVL` unset or 0, Debian's stock file runs `clear_console -q`, which returns 1 with no console, and errexit ends the shell with 1 instead of 43. The caller refuses only on 43 or 44, so the tool followed the symlink: ReadFile returned the outside file's contents, WriteFile planted a file outside the workdir, EditFile changed one.

**The exposure reaches production wherever `AILANG_FS_SANDBOX` is absent.** The Motoko runtime has no `SHLVL`, because it is not in `buildChildEnv`'s allowlist, so on a host with that stock `~/.bash_logout` the guard does not stop an escape in a real session and the sandbox variable is the only protection left.

This PR runs the guard with `-c`, and makes the probe test both `SHLVL` conditions so the gate no longer depends on how it was started.

## Changes

- fix(core): stop the path guard running under a login shell
- test(core): pin SHLVL in the native path guard probe

2 files changed.

- `src/core/tool_runtime.ail`, `validate_path_common`: `-lc` to `-c`, with a comment giving the cause and the macOS cost.
- `src/core/tool_runtime.ail`, `acquire_temp_path`: `-lc` to `-c`. Nothing is wrong there today: the exit code is unread and the script has no `exit`, so `~/.bash_logout` cannot change anything. The change keeps an internal helper off profile files, whose output would otherwise land in the stdout it reads as a path.
- `scripts/verify_native_path_guard.ail`: the old `main` is now the `scenario` entry. The new `main` runs it in two children, `SHLVL` unset and `SHLVL=1`, and fails if either lets an escape through, if a child did not really have the pinned `SHLVL`, or if a child did not pass all six checks. The result no longer depends on the caller's `SHLVL`.
- `BashExec`'s own `bash -lc` is unchanged: it is user-facing behaviour.

### Risks and limits

- **macOS, untested.** Under `-c`, a `realpath` findable only through a profile (Homebrew coreutils put on `PATH` by `~/.bash_profile`, say) is not found. The guard then exits 127, which the caller also reads as a pass, so on such a host this fix swaps one fail-open for another. It depends on the `PATH` the process inherits; I could not test it here. From reading the script, a `realpath` without `-m` already failed open under `-lc` too.
- **The fail-open policy is deliberately left for a follow-up.** Refusing only on 43 or 44 is what turns any unexpected exit into a pass, and it is unchanged here. Refusing on anything unexpected is a separate decision with its own PR.
- **The probe's unset leg detects the defect only where the logout file does this.** On a host without that `~/.bash_logout` both legs pass with or without the fix.

### Overlap with open PRs

- **#234** (`fix/portable-path-guard`) rewrites these same guard lines: a portable script under `bash -c` that fails closed. It conflicts textually with this PR and would also close this defect. The operator chose to ship this narrow fix now; whichever merges second rebases. #234's probe changes need the `SHLVL` pinning kept.
- **#209** (`fix/macos-chmod-reference`) changes `atomic_write`, next to `acquire_temp_path`, and the same probe file.

## Governing docs

None: this is a standalone fix, not a plan item.

## Predicted outcome

`make verify_native_path_guard` and `make check_core` give the same result however they are started, and native file tools refuse symlink escapes with `SHLVL` unset. Checked by the probe's two legs, which run in `check_core`. It would be falsified by any `FAIL: [SHLVL ...]` line on this image.

## Test evidence

Same host, this image (Debian stock `~/.bash_logout`), `AILANG_FS_SANDBOX` unset, before and after on `44a71589` and this branch.

Mechanism, measured:

```
env -u SHLVL bash -lc 'set -e; exit 43'         -> 1
env -u SHLVL SHLVL=1 bash -lc 'set -e; exit 43' -> 43
env -u SHLVL bash -c  'set -e; exit 43'         -> 43
```

| probe | before | after |
|---|---|---|
| six checks, `env -u SHLVL` (old `main`, new `--entry scenario`) | 1 OK / 5 FAIL, rc 1 | 6 OK / 0 FAIL, rc 0 |
| six checks, `SHLVL=1` | 6 OK / 0 FAIL, rc 0 | 6 OK / 0 FAIL, rc 0 |
| new `main`, both legs, before and after the runtime change | 10 OK / 6 FAIL, all six in the unset leg, rc 1 | 16 OK / 0 FAIL, rc 0 |

| `make check_core` | before | after |
|---|---|---|
| `setsid make check_core`, run from a shell with `SHLVL=2` | rc 0 | rc 0 |
| `SHLVL=1 setsid make check_core` | rc 0 | rc 0 |
| `env -u SHLVL setsid make check_core` | **rc 2**, stopped at `verify_native_path_guard` | rc 0 |

The first row passes before the fix because the `SHLVL` it inherited was 2, which hides the bug: the shape alone does not expose it, an unset or 0 `SHLVL` does. The third row is the one that fails before. After the fix, all three run all 16 probe lines with no `FAIL`.

`make verify_native_path_guard`: rc 0, 16 OK. `make test`: rc 0, "All core runtime module tests passed!".

CI was not awaited. Not tested on macOS.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
