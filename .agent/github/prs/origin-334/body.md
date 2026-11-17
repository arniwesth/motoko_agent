---
repo: arniwesth/motoko_agent
pr: 334
branch: fix/macos-portable-path-guard
ticket: null
title: "fix(path guard): portable and fail closed — macOS no longer lets symlinks out (#234 rebased)"
---

## Summary

Fixes #332. On macOS the native file tools' path guard failed open: ReadFile and WriteFile followed a symlink out of the workdir, and every EditFile failed. The guard needed GNU-only `realpath -m`, and every exit other than 43/44 was let through. EditFile copied mode bits with GNU-only `chmod --reference`.

**This is #234, rebased.** @sunholo-voight-kampff wrote that fix, tested it on a real Mac, and answered our review on 10/27. It then stalled: its one red gate was `new_contract_policy`, and #303 later made it conflict. This PR carries their commit, authored by them, onto `main`. It adds what CI needed, plus two more probe legs. One of those legs found a second login-shell bug, which this PR also fixes. It supersedes #234 and #209.

## History: why this kept coming back

| PR | State | What it did |
|---|---|---|
| #202 | merged | Honoured the guard's exit codes. That exposed `chmod --reference` on macOS, and it left the `realpath -m` fail-open in place by design. |
| #209 | open | Portable `chmod`, but the macOS symlink checks became **SKIP**. Superseded by #234. |
| #234 | open, conflicting | The portable resolver and fail-closed guard. Review answered; red only on `new_contract_policy`. |
| #299, #300 | closed | `-c` and fail-closed, dropped in favour of #303. |
| #303 | merged | `set +e` before `exit 43/44`, plus SHLVL legs. Its description says macOS and profile `exit 0` were still open. |

The fix existed but never landed, and nothing on our side runs on macOS. The probe's new legs below test the two rules a Linux CI could otherwise never see break: fail closed, and `-c`.

## Changes

- **`5effef36`** fix(path guard): one portable guard, fail closed; EditFile works on macOS. Author: @sunholo-voight-kampff. This is #234's three commits squashed, with only the conflicts with #303 and #309 resolved:
  - `path_guard_script()` uses plain `realpath` only. It resolves the deepest existing ancestor and re-appends the tail, stops at any symlink, and walks with `${p%/*}`, so a link named `nl\n` is not walked past. Exit 0 inside, 43 outside, 44 unresolvable, 45 workdir unresolvable.
  - The same script is exported from `src/core/tool_runtime` and `motoko_ext_ailang_tools/register`, and the probe asserts the two strings are equal. `motoko_ext_abi` stays at 8.0.
  - `validate_path_common` and `inside_workdir` run it under `bash -c` and allow only exit 0. An empty workdir is judged as `.`.
  - `atomic_write` copies the mode with `stat -c %a`, falling back to `stat -f %Lp`, then `chmod <mode>`. This is best effort; only the rename fails an edit.
  - #303's `set +e` lines go away with the `set -eu` they protected. Its SHLVL legs and #309's Makefile diagnostics stay.
- **`7df4994c`** fix(path guard): pin fail-closed and -c with probe legs; mktemp off -lc.
  - `path_guard_script` gets `ensures { result != "" }` and a `contracts.register` row. This is #234's red gate.
  - A guard exit other than 0/43/44 is refused with the guard's stderr: `path guard could not judge the path (exit N), so it was refused: <path>: <stderr>`.
  - `acquire_temp_path` moves from `bash -lc` to `bash -c`, as #299 proposed. It reads the temp path from stdout, so a login profile that prints, or that runs `exit 0`, broke every EditFile.
  - `verify_native_path_guard` gains two legs:
    - `[profile exits 0]`: the full scenario with a HOME whose `.bash_profile` is `exit 0`.
    - `[no realpath]`: a `realpath` that always fails, first on PATH. Every path must be refused as undecided, and nothing written outside.
  - Makefile: the diagnostic now matches `[label]` row prefixes. On `main` it calls the #332 failures "not on a symlink row".

6 files changed. `ailang.lock` changes only the `motoko_ext_ailang_tools` content hash.

## Governing docs

None under `.agent/projects/`. Context: #332, #234 with its review thread, #209 (`.agent/github/prs/origin-209/response-5937743550.md`), and #303 (`.agent/github/prs/origin-303/body.md`).

## Predicted outcome

- On macOS, with stock `/bin/realpath` and no GNU coreutils, `make verify_native_path_guard` and `make check_core` pass. ReadFile, WriteFile and EditFile refuse symlinks out of the workdir, and EditFile inside it works and keeps mode bits. @sunholo-voight-kampff, could you confirm on your Mac?
- On Linux nothing changes for paths inside the workdir.
- Anywhere the guard cannot run (no `realpath`, an unresolvable workdir), file tools refuse with a `could not judge` message. They no longer go ahead.
- A login profile can no longer change the guard's verdict or break EditFile.
- This is falsified by any `FAIL:` row of `verify_native_path_guard` on either platform.

## Test evidence

Linux, AILANG v0.60.4, `AILANG_FS_SANDBOX` unset. "BSD-like" means shims first on `PATH` that behave as stock macOS does: `realpath` takes only `-q` and every operand must exist, `chmod` rejects `--…`, and `stat` rejects `-c` and takes `-f %Lp`. **Not run on a real Mac.**

**The issue reproduces on `main` with the shims.** `main` (84ec0c94), `make verify_native_path_guard`, BSD-like:

```
FAIL: [SHLVL unset] ReadFile through a symlink out of the workdir is refused — {"tool":"ReadFile","path":"link/secret.txt","content":"secret…
FAIL: [SHLVL unset] WriteFile through a symlink out of the workdir is refused — {"tool":"WriteFile","path":"link/planted.txt","bytes_written":7,…
FAIL: [SHLVL unset] ...and nothing was written outside — planted.txt exists
FAIL: [SHLVL unset] EditFile through a symlink out of the workdir is refused — {"tool":"EditFile","fault":{"kind":"io_error","effects":"unknown",…
verify_native_path_guard: the probe failed, but not on a symlink row: …
```

The `[SHLVL 1]` rows are the same. These are the rows in #332.

**This branch.** `make verify_native_path_guard`: 4 legs, 36 OK, 0 FAIL, under both GNU and BSD-like tools.

| Leg | Checks |
|---|---|
| `SHLVL unset`, `SHLVL 1` | 14 each: inside read, empty workdir, inside edit, mode bits; symlink read, write and edit; dangling link; `nl\n` link; copies equal |
| `profile exits 0` | the same 14 |
| `no realpath` | 3: an inside read refused as undecided, a symlink write refused, nothing outside |

**Mutants.** Each was applied to this branch and run under GNU and BSD-like tools.

| Mutant | GNU | BSD-like |
|---|---|---|
| m1 fail open (non-0/43/44 allowed) | killed: `no realpath` leg, **the write lands outside** | killed |
| m2 walk past `-L`, both copies | killed: dangling-link rows | killed |
| m3 `exit 43` → `exit 0`, both copies | killed: every escape row | killed |
| m4 `basename`/`dirname` walk | killed: `nl\n` rows | killed |
| m5 empty workdir passed as is | killed | killed |
| m6 `chmod --reference` mode copy | survives (GNU has the flag) | killed: mode bits |
| m7 one guard copy changed | killed: copies-equal row | killed |
| m8 guard under `bash -lc` | killed: `profile exits 0` leg, every escape row | killed |
| m9 mktemp under `bash -lc` | killed: inside EditFile row | killed |
| m0 no edit | passes | passes |

m8 is the hole #303 described ("an `exit 0` in `.bash_profile`… still replaces the verdict"). It is open on `main` on Linux too, wherever such a profile exists.

**Gates** on this branch's tip:

| Gate | Result |
|---|---|
| `make check_core` | 0. 61 type-checked, 0 failed, and `verify_native_path_guard` 36 OK |
| `make verify_core` | 0. 82 proven, 0 unstated, 1 blocked, 0 files failed |
| `make new_contract_policy BASE=origin/main` | 0. `path_guard_script` carries a contract |
| `make verify_classify_check` | 0. 18 unit tests; register agrees, 83 contracts |
| `make registry_gen_check` | 0 |
| `ailang test src/core/tool_runtime.ail` | 19 passed, 0 failed, 3 skipped (`main`: 18, 0, 3) |
| `make test` | 0. A sanity signal only. |

Not run: `make dst`, `make eval_matrix`, `src/tui` tests, and `eval_protected_selftest`. `validate_path_common` gains a call to `path_guard_script`, which `tools/eval_protected/manifest-A.json` does not list. #303 changed the same function without touching it.

**Limits.**

- Not run on macOS. The shims model the flags, not every BSD difference.
- `/bin/realpath` exists on macOS 13 and later. On older macOS, the file tools now refuse every path, with `could not judge … realpath: command not found`, instead of letting everything through.
- Exit 44 is reported as "escapes workspace". On BSD `realpath` that also covers a dangling link that points inside the workdir. It is refused either way, and the wording is #234's.
- `BashExec` still runs under `bash -lc` and is not path-guarded. That is unchanged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
