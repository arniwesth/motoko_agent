---
repo: arniwesth/motoko_agent
pr: 300
branch: fix/path-guard-fail-closed
ticket: null
title: "fix(core): make the path guard fail closed"
---

## Summary

`validate_path_common` read only exit 43 and 44 as refusals, so every way the guard could fail to run became a silent pass. It now allows a path only when the guard positively decided it is inside:

| Guard result | Meaning | Outcome |
|---|---|---|
| exit 0 | inside the workdir | allow |
| exit 43 | lexical escape | refuse, `path escapes workspace: <path>` |
| exit 44 | escape through a symlink | refuse, `path escapes workspace: <path>` |
| any other exit | the guard could not decide | refuse, `path guard could not run (exit N), so the path was refused; this is a fault in the environment, not in the path: <path>: <guard stderr, first 200 characters>` |
| `exec` returned `Err` | bash did not run | refuse, `path guard could not run (<process error>), so the path was refused; ...` |

This closes the macOS exit-127 hole that #299 leaves open. The guard script is unchanged.

**#299 should land first; see "Merge order".** Without it, a real escape in the Motoko runtime gets the wrong message.

### Consequences to decide on

1. **A host with only BSD `realpath` (stock macOS, no GNU coreutils) can no longer use the native file tools.** `realpath -m` fails there on every path, including ones inside the workdir. Before this PR those paths passed, and so did symlink escapes. With a BSD-like `realpath` stub on the combined #299 tree, a `WriteFile` of a new file inside the workdir returned: `path guard could not run (exit 1), ...: fresh.txt: realpath: illegal option -- m`. This was tested with a Linux stub, not on a Mac. #234 holds a portable resolver, tested on a real Mac, that removes the dependency.
2. **Merging this before #234 trades a security hole for an outage on those hosts.** This PR follows the fail-closed policy as decided, but that decision's brief named only the Homebrew-through-a-profile case.
3. **Overlap with #234.** #234 makes the same policy change and also replaces the guard script. Whichever merges second has to reconcile the same lines. #234 is currently `CONFLICTING` against `main`.

### One change the policy forced

An empty workdir means the process cwd (`resolve_workdir_path`), but `realpath ""` exits 1. That used to pass and would now refuse every path, so the caller gives the guard `.` instead. #234 does the same. A mutant without this line fails the new empty-workdir row. Other newly refused cases:

- A workdir that does not exist and whose parent is also missing exits 1, and now refuses. It used to pass.
- A symlink loop inside the workdir exits 0, so it is unchanged.

## Changes

- fix(core): refuse when the path guard cannot decide
- test(core): pin the guard's could-not-run verdict

3 files changed. `Makefile` only rewords the `verify_native_path_guard` failure line, which claimed a symlink was followed even when the fault was a wrong refusal.

Callers of `validate_path_common`: `run_read_file`, `run_write_file`, `run_edit_file`. There are no others in `src/`, `packages/`, `scripts/` or `tools/`. `packages/motoko-ext-ailang-tools/register.ail` runs its own separate guard, which this PR does not touch.

## Governing docs

None under `.agent/projects/`. Context is in #299, #234 and the #209 thread (`.agent/github/prs/origin-209/response-5937743550.md`).

## Predicted outcome

- Any guard failure now shows up as a refused tool call with `kind: refused`, `effects: none`, instead of the tool going ahead. `make verify_native_path_guard` checks this.
- With #299 also merged, `check_core` passes with `SHLVL` unset as well as ambient. I confirmed this on a local trial merge.
- Linux hosts with GNU `realpath` see no change for paths inside the workdir.
- Hosts with only BSD `realpath` see every native file tool refuse until #234 or an equivalent lands.

## Test evidence

**Exit codes.** I extracted the script from this branch and ran it directly:

| Path | `bash -c` | `bash -lc`, SHLVL=1 | `bash -lc`, SHLVL unset | BSD-like `realpath`, `-c` |
|---|---|---|---|---|
| inside, or new nested file | 0 | 0 | 0 | 1 |
| `../outside` | 43 | 43 | 1 | 1 |
| symlink out | 43 | 43 | 1 | 1 |

A symlink out exits 43, not 44: `realpath -m` already resolves the link, so the second check is not reached in these cases.

**Before and after.** Each row is the same new verifier run in the ambient shell against each core. The escaping path is `link/secret.txt` or `link/planted.txt`, which leave the workdir through a symlink.

| Row | Unfixed core | This PR |
|---|---|---|
| guard exits 127, ReadFile | **returned the secret** | refused, could-not-run |
| guard exits 127, WriteFile | **wrote outside the workdir** | refused, could-not-run |
| guard exits 1, ReadFile | **returned the secret** | refused, could-not-run |
| guard exits 1, WriteFile | **wrote outside the workdir** | refused, could-not-run |
| guard exits 127 or 1, EditFile | passed the guard, then `io_error` because the stub also broke `mktemp` | refused, could-not-run |
| no `bash`, all three tools | refused, but said "escapes workspace" | refused, could-not-run (`not found: bash`) |
| nothing written outside | **`planted.txt` exists** | OK |
| outside file unchanged | OK | OK |
| symlink escape, three tools, ambient `SHLVL` | refused, escape message | refused, escape message |
| ReadFile inside the workdir | works | works |
| ReadFile with an empty workdir | works | works |

The EditFile row is the weakest differential, because the stub stopped the edit before it could change anything on the unfixed core.

Mutants on this PR's core:

- Without the empty-workdir line, `ReadFile with an empty workdir still works` fails.
- With the `exec` `Err` arm back on the escape message, all four `no bash at all` rows fail.

The rows stub `bash` rather than remove `realpath`: under `-lc` a profile can reset `PATH`, so the missing `realpath` would not reach the guard on this branch. On the #299 trial merge, where the guard runs under `-c`, I ran the missing-`realpath` case by hand and all three tools refused with exit 127.

**Gates.** Baseline is `44a71589`, the base of this branch.

| Gate | Shape | Baseline | This PR |
|---|---|---|---|
| `make verify_native_path_guard` | ambient (`SHLVL=2`) | 0 (6 OK) | 0 (22 OK) |
| `make verify_native_path_guard` | `env -u SHLVL` | **2** (5 FAIL) | **2** (3 FAIL) |
| `make check_core` | ambient | 0, 60 type-checked, 200 OK | 0, 60 type-checked, 216 OK |
| `make check_core` | `env -u SHLVL` | **2** | **2** |
| `make test` | ambient | 0 | 0 |
| `make test` | `env -u SHLVL` | 0 | 0 |
| `make new_contract_policy BASE=origin/main` | ambient | not run | 0 |
| `make eval_protected_selftest` | ambient | **2** (`gen exited 1`) | **2** (`gen exited 1`, same) |

All gates ran with `AILANG_FS_SANDBOX` unset.

**The red `env -u SHLVL` rows are expected on this branch.** Both `check_core` failures are the verifier prerequisite, so make stopped before the later prerequisites and the type-check.

- **Baseline:** the login shell's `~/.bash_logout` turns exit 43 into exit 1, which reads as a pass, so the tools followed the symlink and wrote outside the workdir.
- **This PR:** the same exit 1 now refuses and nothing leaves the workdir, which is why the two "outside" rows turn green. The three remaining FAILs are the escape rows, which get the could-not-run message because the guard exited 1. That wording is wrong for a real escape, and #299 fixes it.

**Trial merge with #299, not pushed:**

| Gate | Shape | Result |
|---|---|---|
| `make verify_native_path_guard` | ambient, runs both SHLVL legs | 0, 48 OK, 0 FAIL |
| `make check_core` | ambient | 0, 60 type-checked, 242 OK, 0 FAIL |
| `make check_core` | `env -u SHLVL` | 0, 60 type-checked, 242 OK, 0 FAIL |

**Limits of this evidence:**

- `make test` only runs `src/core/agents_md.ail` and finishes in about a second, so it says nothing about this change. `verify_native_path_guard` is the real evidence.
- `make dst`, `make eval_matrix`, `make compose_live_exec` and `src/tui` tests were not run.
- `validate_path_common` now calls `process_error_to_string`, a new call-graph edge against `tools/eval_protected/manifest-A.json`, which this PR does not touch. The selftest that might notice cannot run in a worktree at baseline either, so that is unverified.
- Nothing was run on macOS.

## Merge order

**Merge #299 first, then rebase this PR.**

1. Without #299, the Motoko runtime has no `SHLVL`, so a real symlink escape is refused with "this is a fault in the environment, not in the path". That is safe but misleading.
2. #299 alone is a safe intermediate state. This PR alone leaves `check_core` red with `SHLVL` unset, as `main` already is.
3. The merge conflicts in both orders, in `tool_runtime.ail` and in the verifier.

To reconcile:

- Keep this PR's arms and #299's `-c`, plus its reasoning. Drop #299's "also let through" sentence, which this PR makes false.
- Keep #299's `scenario`/`leg` split and call `policy_rows` from `scenario`, using its `count_ok`.
- Change #299's `count_ok(lines) == 6` to `== 22` and its "all six checks" wording. Leaving it at 6 fails the verifier, so a mistake here cannot pass unnoticed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
