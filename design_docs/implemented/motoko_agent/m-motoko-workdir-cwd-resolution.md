# M-MOTOKO-WORKDIR-CWD-RESOLUTION — Apply dispatcher workdir to fs operations

**Status**: Implemented (2026-05-06, branch ailang-tool-loop-migration)
**Target**: motoko_agent (next post-cutover patch)
**Priority**: P2 (medium — observed in M9, doesn't block the cutover, but produces surprising behaviour)
**Estimated**: ~2-3 hours
**Dependencies**: None
**Surfaced by**: M-AILANG-FS-RESULT M4 smoke testing during M-MOTOKO-RPC-LOOP-FULL-MIGRATION (2026-05-06)

## Problem

motoko_agent's tool dispatcher accepts a `workdir: string` argument that the caller (TUI / supervisor / agent loop) sets to the user's project root. This workdir is **passed all the way down to `dispatch_one`** and forwarded to `run_native_call`. But the actual `std/fs` operations (`readFileResult`, `writeFileResult`, `mkdirAllResult`) take a `path: string` and resolve relative paths against **the AILANG runtime process's current working directory**, NOT against the dispatcher's workdir argument.

Observed during M-AILANG-FS-RESULT M4 smoke testing:

```
$ # workdir argument was "/tmp/m-fs-result-smoke"
$ # smoke called dispatch_one("/tmp/m-fs-result-smoke", { tool:"WriteFile", path:"nested/dir/hello.txt" })
$ # WriteFile reported success (bytes_written=12, exit_code=0)
$ # but the file did NOT appear at /tmp/m-fs-result-smoke/nested/dir/hello.txt
$ # — it was at /Users/mark/dev/sunholo/motoko_agent/nested/dir/hello.txt instead
```

Root cause: `validate_path_common("WriteFile", id, path, workdir)` only validates the path *shape* (rejects absolute paths, dot-dot, etc.) — it doesn't *transform* the path by joining it with workdir before passing through to `writeFileResult(path, content)`.

## Scope

- `src/core/tool_runtime.ail`:
  - `run_read_file`: prepend `workdir + "/"` to relative paths before `readFileResult`.
  - `run_write_file`: same for the `mkdirAllResult` parent and the `writeFileResult` target.
  - `run_edit_file`: same for the read + write paths.
  - `run_search`: same for the search root.
  - `run_process_result` (BashExec/RunTests): the `cd <workdir> &&` prefix already added in M10's `bash -lc` wrapping fix handles this case for shell commands.
- The `workdir` argument is already plumbed; this is purely a path-resolution adjustment at the leaf calls.

## Why this matters

Without the fix, an agent that thinks it's working inside `/tmp/project-X` can silently scribble files into the AILANG runtime's process cwd (often the motoko_agent repo itself). M9's tool-write smoke happened to verify "the dispatcher returned Ok" but didn't verify "the file is at the path the model asked for", so the bug stayed hidden through the matrix run. Real agent sessions with non-cwd workdirs would have produced confusing behaviour (model writes file, can't read it back next turn because relative paths now resolve differently).

The legacy env-server delegation path implicitly handled this because the env-server ran in the workdir; v2 standalone runs the AILANG runtime in motoko's own cwd.

## Acceptance criteria

- [ ] dispatch_one with workdir=/tmp/foo and path=bar.txt writes to /tmp/foo/bar.txt
- [ ] Symmetric for ReadFile / EditFile / Search
- [ ] Absolute paths still rejected by validate_path_common (no behaviour change there)
- [ ] New regression smoke: `scripts/smoke_v2_workdir_resolution.ail` calls dispatch_one against a per-test temp workdir and verifies files materialise at the expected path
- [ ] M9 provider matrix re-run: still 25/25

## Out of scope

- Reworking validate_path_common's policy surface (just adding the join, not changing the security model)
- The pre-existing absolute-path rejection (separate concern: M-MOTOKO-ABSOLUTE-PATHS, lower priority)

## Cross-references

- Source observation: M-AILANG-FS-RESULT M4 [smoke run output](../../scripts/smoke_v2_writefile_missing_parent.ail)
- Related upstream: AILANG fs builtins are correctly designed (resolve relative to process cwd) — the fix is dispatcher-side, not std/fs-side
