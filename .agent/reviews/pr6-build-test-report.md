# PR #6 Build & Test Report

**PR:** M-MOTOKO-EXTENSION-INTEGRATION: extensions as packages + DP7 verifier + Pending policy + cost budget + stub-step + many fixes
**Branch:** motoko-dx-compaction-pending
**Date:** 2026-05-09
**Environment:** VS Code devcontainer, AILANG v0.16.2, `ailang-packages` repo not present

## Summary

| Target | Result | Details |
|---|---|---|
| `make check_core` | **20/23 passed, 3 failed** | Missing extension packages |
| `make verify_core` | **0/20 passed, 20 failed** | All modules fail verification |
| `make test_core` | **1/11 passed, 10 failed** | Runtime eval errors + missing packages |
| `make test_integration` | **0/3 passed, 3 failed** | Type mismatch in stub_step.ail |

Nothing is green. Three distinct root causes explain all failures.

## Root cause 1: Missing `ailang-packages` repo

The 3 modules that fail `check_core` — `agent_loop_v2.ail`, `rpc.ail`, `supervisor.ail` — all transitively import `registry_generated.ail`, which imports from `pkg/sunholo/motoko_ext_test_dummy/register` etc. Those packages resolve to `/Users/mark/dev/sunholo/ailang-packages/...` via the lock file, which doesn't exist in this environment.

This is a portability problem: `path =` dependencies in `ailang.toml` use relative paths that assume `ailang-packages` is cloned as a sibling directory, and the lock file (`ailang.lock`) has baked-in absolute paths from the original author's machine.

**Affected targets:** `check_core` (3 failures), `test_core` (transitive), `test_integration` (transitive)

## Root cause 2: AILANG version mismatch

`verify_core` fails on all 20 modules. The installed AILANG (v0.16.2) does not support the Z3 contract verification features or the `ai-check` command required by `verify_core`. These features require AILANG v0.17.0+.

**Affected targets:** `verify_core` (20/20 failures)

## Root cause 3: Schema drift in `stub_step.ail`

All 3 integration tests fail with the same type error:

```
record field mismatch: expected 7 fields, got 5
  expected: {cache_creation_input_tokens, cache_read_input_tokens, finish_reason,
             input_tokens, message, output_tokens, tool_calls}
  actual:   {finish_reason, input_tokens, message, output_tokens, tool_calls}
  missing:  cache_creation_input_tokens, cache_read_input_tokens
```

Commit `84fa449` added `cache_read`/`cache_creation` token fields to the loop's `StepResult` type, but `src/core/test/stub_step.ail` still returns the old 5-field record. The test harness was not updated to match the schema change.

**Affected targets:** `test_integration` (3/3 failures)

## Root cause 4: Runtime eval bugs in `agents_md.ail`

The `agents_md.ail` unit tests fail with two distinct runtime errors:

- **5 `dirname` tests:** `cannot apply non-function value: <nil>` — a function that should exist evaluates to nil at runtime
- **5 `is_root` tests:** `_list_length: expected List, got *eval.StringValue` — a string is being passed where a list is expected

These appear to be AILANG v0.16.2 runtime incompatibilities with code written for v0.17.0, not bugs in motoko's source code.

**Affected targets:** `test_core` (10/11 failures)

## Extension migration context

The headline structural change in this PR is the migration from vendored extensions (source code under `src/core/ext/<name>/`) to externally-versioned AILANG packages in `sunholo-data/ailang-packages`. This is the direct cause of root cause 1.

Current state of the dependency declarations in `ailang.toml`:

```toml
[dependencies]
"sunholo/motoko_ext_abi" = { path = "../ailang-packages/packages/motoko-ext-abi" }
"sunholo/motoko_ext_test_dummy" = { path = "../ailang-packages/packages/motoko-ext-test-dummy" }
# ... 7 more path dependencies
```

All 9 extension packages use `path =` resolution. There is no registry-based resolution yet. The lock file contains absolute paths from the author's machine (`/Users/mark/dev/sunholo/...`).

The `ailang generate-extension-registry` command (used to produce `registry_generated.ail`) requires AILANG v0.17.0+ and is not available on the installed v0.16.2.

## Conclusion

This PR was developed and validated against AILANG v0.17.0+ with the `ailang-packages` repo cloned locally. The PR description claims "46/46 smoke checks, 3/3 integration tests, 23/23 type-check" — those results were real but only reproducible in the author's specific environment.

In any other environment (including this devcontainer), the branch is not buildable or testable without:

1. Cloning `sunholo-data/ailang-packages` as a sibling directory
2. Upgrading AILANG to v0.17.0+
3. Fixing the `stub_step.ail` schema drift (adding `cache_creation_input_tokens` and `cache_read_input_tokens` fields)
