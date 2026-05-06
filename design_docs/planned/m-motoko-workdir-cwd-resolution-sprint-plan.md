# Sprint Plan — M-MOTOKO-WORKDIR-CWD-RESOLUTION

**Sprint ID**: `M-MOTOKO-WORKDIR-CWD-RESOLUTION`
**Target**: motoko_agent post-cutover patch (next motoko release)
**Estimated**: 2-3 hours (single session)
**Risk**: Low (additive helper + leaf-call swaps, no architectural change)
**Dependencies**: M-MOTOKO-RPC-LOOP-FULL-MIGRATION cutover landed (PR #4 merged). Can also be developed against the same `ailang-tool-loop-migration` branch and tucked into PR #4.
**Design doc**: [m-motoko-workdir-cwd-resolution.md](m-motoko-workdir-cwd-resolution.md)

## Goal

Make motoko's tool dispatcher correctly apply its `workdir` argument to filesystem operations. Today the `workdir` arg is passed through `validate_path_common` (which already joins workdir+path correctly to validate path-escapes) but is **not used** at the leaf `readFileResult` / `writeFileResult` / `mkdirAllResult` / `rg` calls — those resolve against the AILANG runtime's process cwd instead, producing files at unexpected locations.

## Velocity reference

- **M-MOTOKO-RPC-LOOP-FULL-MIGRATION** (just shipped): 8 milestones, ~6 hours wall-clock per session against AILANG-native `tool_runtime.ail`. Touched the same code surface this sprint targets.
- **M-AILANG-FS-RESULT M4** (~30 min): the dispatcher migration to Result-returning fs builtins. Same scope shape (4 functions touched, regression smoke).

This sprint is much smaller than either: 4 leaf-call swaps + 1 helper + 1 smoke + 1 signature change. ~80 LOC + ~30 LOC tests.

## Milestones

### M1 — Implement path resolution (~60 LOC, ~1.5h)

**Files**:
- `src/core/tool_runtime.ail`

**Tasks**:
1. Add a small private helper near `validate_path_common`:
   ```ailang
   -- Resolve a tool-supplied relative path against the dispatcher's workdir.
   -- The path has already passed validate_path_common, so it's known to be
   -- relative + non-escaping. We just normalize the join (handle the
   -- "${workdir}/${path}" concatenation) so leaf fs calls operate on
   -- absolute paths inside the workspace, not paths relative to the
   -- AILANG runtime's process cwd.
   func resolve_workdir_path(workdir: string, path: string) -> string {
     if workdir == "" || workdir == "." then path
     else if endsWith(workdir, "/") then "${workdir}${path}"
     else "${workdir}/${path}"
   }
   ```
2. Update `run_read_file` (line 303): use `let resolved = resolve_workdir_path(workdir, path)` and pass `resolved` to `readFileResult`.
3. Update `run_write_file` (line 465): use `resolve_workdir_path` for the `mkdirAllResult` parent (via `path_dirname(resolved)`), the `writeFileResult` target, and the `fileExists`/`readFile` of the prior content.
4. Update `run_edit_file` (line 626): use `resolve_workdir_path` for `fileExists`, `readFile`, and the temp-file write at line 600.
5. Update `run_search` (line 370): add `workdir: string` parameter; resolve `dir` against `workdir` before passing to `rg`. Update the call site at line 178 to thread workdir through.

**Acceptance criteria**:
- `make check_core` green: 22/22 modules
- No new lint warnings beyond what was there before
- `dispatch_one("/tmp/foo", { tool: "WriteFile", path: "bar.txt" })` writes to `/tmp/foo/bar.txt` (not the AILANG runtime's cwd)
- Symmetric for ReadFile / EditFile / Search
- Absolute paths still rejected by `validate_path_common` (no behaviour change there)
- The bash-script `validate_path_common` guard remains the source of truth for path-escape detection — this sprint only changes leaf-call resolution, not the security model

### M2 — Regression smoke + matrix verify (~20 LOC, ~1h)

**Files**:
- `scripts/smoke_v2_workdir_resolution.ail` (new)
- `CHANGELOG.md`

**Tasks**:
1. Write `scripts/smoke_v2_workdir_resolution.ail`:
   ```
   - Create a unique temp workdir under /tmp/m-workdir-smoke-<pid>
   - Call dispatch_one(workdir, { tool: "WriteFile", path: "deep/nested/hello.txt", content: "hi" })
   - Verify the file exists at ${workdir}/deep/nested/hello.txt (using readFileResult against absolute path for verification)
   - Verify the file does NOT exist at ailang_cwd/deep/nested/hello.txt (the bug location)
   - Symmetric ReadFile call: ReadFile(path: "deep/nested/hello.txt", workdir) returns the content
   - Cleanup: removeFileResult on the temp workdir
   - Print PASS/FAIL summary
   ```
2. Run the smoke directly: `ailang run --caps IO,FS,Process,Env,Clock --entry main scripts/smoke_v2_workdir_resolution.ail` — must print PASS.
3. Re-run all v2 unit smokes (M3-M7) to confirm no regression:
   - `smoke_v2_policy_denial.ail`
   - `smoke_v2_handle.ail`
   - `smoke_v2_backend.ail`
   - `smoke_v2_hybrid.ail`
   - `smoke_v2_conversation.ail`
   - `smoke_v2_writefile_missing_parent.ail`
4. Re-run the M9 provider × task matrix: `GOOGLE_CLOUD_LOCATION=global /bin/bash scripts/smoke_v2_provider_matrix.sh`. Expect 25/25.
5. Add CHANGELOG entry under `[Unreleased]` documenting the fix.

**Acceptance criteria**:
- New smoke `smoke_v2_workdir_resolution.ail`: PASS
- All 6 prior v2 unit smokes still PASS
- M9 matrix: 25/25 across all 5 providers × 5 task variants
- CHANGELOG entry added

## Out of scope

- Reworking `validate_path_common`'s policy surface — keeping the bash-script guard as-is for path-escape detection. This sprint only changes leaf-call resolution, not security model.
- Pre-existing absolute-path rejection — separate concern.
- Changing AILANG's `std/fs` semantics — they're correct (resolve relative to process cwd). Fix is dispatcher-side only.

## Success metrics

- ✅ make check_core: 22/22
- ✅ All 7 v2 unit smokes (existing 6 + new workdir-resolution): PASS
- ✅ M9 provider matrix: 25/25
- ✅ CHANGELOG entry referencing the design doc

## Execution mode

**Sequential** — M2 depends on M1 (need the resolution helper before the smoke can verify it). Single session.
