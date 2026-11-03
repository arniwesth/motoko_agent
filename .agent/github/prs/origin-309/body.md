---
repo: arniwesth/motoko_agent
pr: 309
branch: arniwesth/041-hygiene-stale-comment
ticket: null
title: "fix: a stale checker path and a misleading guard diagnostic (041 hygiene)"
---

## Summary

Two hygiene fixes recorded as "not fixed, worth doing" in the 041 session record and handoff; neither is a PLAN-001 task. `src/core/process_limits.ail:18` named `evidence/W4/check_single_construction.py`, which `1270f310` moved to `scripts/verify_single_construction.py`; it now names the script and its Make target. `make verify_native_path_guard` printed "a native file tool followed a symlink out of the workdir" on **any** non-zero exit, including when `ailang` was not on `PATH` — which once caused `0 OK, 0 FAIL` to be read as "the guard fails open". It now says what happened.

## Changes

- docs(core): point the single-construction comment at its gate (041 hygiene)
- fix(make): say when the path-guard probe produced no verdict (041 hygiene)

2 files changed.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/HANDOFF-2026-11-02.md` (items at lines 83 and 115)
- `.agent/projects/041_process_execution_timeouts/RECORD-session-W1-W5-2026-11-02.md` (lines 124 and 558)

## Predicted outcome

- The comment sends a reader to a file that exists. Checked: `scripts/verify_single_construction.py` exists and `make check_core` still type-checks `src/core/process_limits.ail`.
- `verify_native_path_guard` reports by what the probe printed, not only by its exit code:
  - **no `OK:`/`FAIL:` row** → `the probe produced no verdict (exit <rc>): is ailang on PATH? Otherwise the run failed before its first check`;
  - **a `FAIL:` row** → the existing symlink message, unchanged;
  - **only `OK:` rows, non-zero exit** → `the probe exited <rc> with no FAIL row: it failed outside its checks; its stderr is discarded, so rerun the ailang command by hand`.
- What the target checks and when it fails are unchanged: it still exits 0 exactly when the probe exits 0, and non-zero otherwise. The probe, `tool_runtime.ail` and the guard are not touched. Still one shell invocation in the recipe.

## Test evidence

| Command | Exit | Last line |
|---|---|---|
| `make check_core` | 0 | `src/core/ type-check: 61 passed, 0 failed` (211 OK; `check_single_construction: 576 .ail files, 0 breaches`) |
| `make verify_native_path_guard` | 0 | 6 OK, 0 FAIL |
| `make test` | 0 | `All core runtime module tests passed!` |

Fix 2, both ways and the genuine failure. (a) passes in this worktree; (b) is `env PATH=/usr/bin:/bin`, so `ailang` (in `~/.local/bin`) is unreachable; (c) is a scratch `git archive` of this branch's tree, **not** the worktree, with the guard reverted to the historical bug (`Ok(_) => Ok(())`, accept on every exit code), so a symlink genuinely escapes. The committed probe and guard are unchanged.

```
=== (a) pass
OK: ReadFile through a symlink out of the workdir is refused
OK: WriteFile through a symlink out of the workdir is refused
OK: ...and nothing was written outside
OK: EditFile through a symlink out of the workdir is refused
OK: ...and the outside file is unchanged
OK: ReadFile inside the workdir still works
exit=0
=== (b) PATH=/usr/bin:/bin
verify_native_path_guard: the probe produced no verdict (exit 127): is ailang on PATH? Otherwise the run failed before its first check
make: *** [Makefile:2967: verify_native_path_guard] Error 1
exit=2
=== (c) scratch tree, guard reverted to Ok(_) => Ok(())
495c495
<           Ok(out) => if out.exitCode == 43 || out.exitCode == 44 then Err(path_error(id, tool, "path escapes workspace: ${path}")) else Ok(()),
---
>           Ok(_) => Ok(()),
FAIL: ReadFile through a symlink out of the workdir is refused — {"tool":"ReadFile","path":"link/secret.txt","content":"secret
FAIL: WriteFile through a symlink out of the workdir is refused — {"tool":"WriteFile","path":"link/planted.txt","bytes_written":7,"sha256":"372eb3774802a8d97badd0f3afdabbf7a17ef8a1f900b394db99a460b8
FAIL: ...and nothing was written outside — planted.txt exists
FAIL: EditFile through a symlink out of the workdir is refused — {"tool":"EditFile","path":"link/secret.txt","bytes_written":8,"sha256":"7f8b1dfc466b6249f06cbe55c9174df2578e7754da793fded244ef5cba2a3
FAIL: ...and the outside file is unchanged — changed
OK: ReadFile inside the workdir still works
verify_native_path_guard: a native file tool followed a symlink out of the workdir
make: *** [Makefile:2967: verify_native_path_guard] Error 1
exit=2
```

For contrast, (b) against the recipe on `main` printed `verify_native_path_guard: a native file tool followed a symlink out of the workdir` — the misleading message this fixes. The third branch was also exercised in a scratch tree whose probe copy always exits 1: six `OK:` rows, then `the probe exited 1 with no FAIL row: it failed outside its checks; ...`, exit 2.
