# PR #7 Build & Test Report

**PR:** M-MOTOKO-EVAL-HARDENING + parallel-execution isolation + Bedrock hybrid-tool fix (v0.18.1-3)
**Branch:** motoko-bisect-gap1
**Date:** 2026-05-09
**Environment:** VS Code devcontainer, AILANG v0.16.2 (pre-fix) → v0.18.4 (post-fix), `ailang-packages` repo not present

## Summary

| Target | Result | PR #6 comparison |
|---|---|---|
| `make check_core` | **20/23 passed, 3 failed** | Same count, different errors |
| `make verify_core` | **0/20 passed, 20 failed** | Same |
| `make test_core` | **1/11 passed, 10 failed** | Same |
| `make test_integration` | **0/3 passed, 3 failed** | Same count, different error |

Nothing is green. The failure count is identical to PR #6 but the error signatures shifted — indicating real progress underneath.

## What changed vs PR #6

### check_core — 3 failures, different root causes

- `agent_loop_v2.ail` and `supervisor.ail` now fail with `IMP010: symbol 'stepWithCache' not exported by 'std/ai'` — a new stdlib function that AILANG v0.16.2 doesn't have. In PR #6 these failed because extension packages were missing. The extension resolution is now working (no more "package directory not found"), but the code needs a newer stdlib.
- `rpc.ail` fails with a type unification error in `registry_generated.ail` — an effect-row mismatch where `on_build_system_prompt` is expected pure but the registered hooks carry `{Env, FS}` effects. This is a type-system version mismatch.

### test_integration — 3 failures, cleaner error

- PR #6 failed with the `stub_step.ail` schema drift (missing `cache_creation_input_tokens` fields).
- PR #7 fails with `stepWithCache not exported by std/ai` — the stub_step schema issue was fixed, but the code now depends on a stdlib symbol that doesn't exist in v0.16.2.

### test_core and verify_core — identical to PR #6

- `test_core`: same `agents_md.ail` runtime bugs (5 `dirname` nil-application errors, 5 `is_root` type confusion errors). Only `is_root_test_1` passes.
- `verify_core`: blanket 20/20 failure — Z3 contract verification requires AILANG v0.17.0+.

## Install script bug (filed on PR #7)

The install script (`scripts/install-prerequisites.sh`) has two bugs that prevent AILANG from being upgraded:

### Bug 1: No version check
`install_ailang()` tests `if command -v ailang` — if any `ailang` binary exists on PATH, it skips installation entirely. Every other tool in the script (Go, Bun, Node) has a minimum-version check, but AILANG does not.

### Bug 2: Wrong pinned version
The ref is hard-coded to `v0.16.2` inside the function body. This branch requires v0.18.4+ (`stepWithCache`, updated extension hook effect signatures).

### Bug 2b: Missing ldflags
`go build ./cmd/ailang` produces a binary that reports `AILANG dev` with no semver string. AILANG's own Makefile uses `-ldflags` to inject the version from `git describe --tags`. Without them, even a correctly-built v0.18.4 binary fails any version check.

### Fix applied

Two changes to `scripts/install-prerequisites.sh`:

1. **Added `ailang_version_ok()` function** — uses the same `version_ge` pattern as Go/Bun/Node to compare the installed version against a new `AILANG_MIN_VERSION` variable. If the binary exists but is too old, it logs a warning and proceeds to upgrade.

2. **Bumped pinned version + added ldflags** — `AILANG_REF` is now `v0.18.4` (top-level variable, no longer buried in the function). The build step replicates AILANG's own Makefile ldflags (`Version`, `Commit`, `BuildTime`) so the binary reports a proper semver.

After applying the fix, `ailang --version` correctly reports `v0.18.4` and the `stepWithCache` / stdlib errors in `check_core` are expected to resolve once running against the v0.18.4 stdlib.

## Remaining blockers (post AILANG upgrade)

Even after upgrading AILANG to v0.18.4, the following issues may persist:

1. **Extension packages** — the `ailang-packages` repo must be cloned as a sibling directory. All 9 extension deps use `path = "../ailang-packages/..."` resolution. Without it, modules that import `registry_generated.ail` will fail.

2. **Lock file portability** — `ailang.lock` contains absolute paths from the original author's machine (`/Users/mark/dev/sunholo/...`). These need to be re-resolved locally.

3. **`agents_md.ail` runtime errors** — the `dirname` and `is_root` test failures may be genuine AILANG runtime bugs that need investigation regardless of version.
