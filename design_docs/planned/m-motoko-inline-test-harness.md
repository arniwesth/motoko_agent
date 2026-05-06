# M-MOTOKO-INLINE-TEST-HARNESS — Fix `tests [((), true)]` pattern for exported functions

**Status**: Planned (blocking the inline-tests-as-contracts story)
**Priority**: P1 — self-checking gate is unrunnable without this
**Estimated effort**: 1-2 days (AILANG-side investigation + fix, or motoko-side workaround)
**Dependencies**: Requires AILANG-side root-cause analysis (`ailang test` runner behaviour)
**Source**: `motoko_explore` smoke test + pre-existing failures in `make check_core` (2026-05-06)

---

## Problem

The AILANG inline-test harness fails for modules that contain `tests [((), true)]` patterns referencing exported functions. The `make check_core` error (consistently observed throughout this session):

```
cluster harness evaluation failed: cannot apply non-function value: <nil>
```

This fires for:
- `src/core/agents_md.ail` (multiple inline tests)
- `src/core/context_usage.ail`
- `src/core/ext/runtime.ail`
- `src/core/compaction.ail` (new)
- `src/core/ext/registry.ail` (agent-written, uses same pattern)

**Production code type-checks correctly** (`ailang check` passes for all 23 modules). The harness failure is isolated to test evaluation.

### Failing pattern

```ailang
func parse_empty() -> bool
  tests [((), true)]
  {
    len(parse_core_ext_order_names("")) == 0
  }
```

When the test harness evaluates this, it calls `parse_empty()` (applying `()` to the function) and expects `true`. The error `cannot apply non-function value: <nil>` suggests the harness resolves `parse_empty` to `nil` — the function is not found in the evaluation context.

### Why it might be AILANG-side

The inline-test format `tests [((), true)]` says: "evaluate this function with `()` as input and expect `true`". The test runner must:
1. Evaluate the surrounding expression `parse_empty` to get a function value
2. Apply it to `()`
3. Compare result to `true`

Step 1 fails: `parse_empty` evaluates to `nil`. This could happen if:
- The test runner evaluates tests in an isolated scope that doesn't include the module's own functions (even exported ones)
- There's a bug in how the test runner handles `() -> bool` (0-argument) functions vs `(a, b) -> bool` (multi-argument) functions
- The test block sees a DIFFERENT version of the function (perhaps the elaborated IR loses the name)

### Why it might be motoko-side

- All the failing tests reference `parse_core_ext_order_names`, `estimate_tokens`, `context_limit_for`, `count_tool_msgs`, etc. — all pure functions that call OTHER module-level functions
- If the test runner only has access to the immediately-enclosing function's scope (not the full module), chained calls would fail

---

## Investigation steps

### Step 1: Minimal reproducer

```ailang
module test_inline_minimal

func helper() -> int = 42

func test_helper_returns_42() -> bool
  tests [((), true)]
  { helper() == 42 }

export func main() -> () ! {IO} = ()
```

Run `ailang test test_inline_minimal.ail`. Does it pass or fail?

If it PASSES: the bug is in how modules with exports interact with the test runner. The fix is motoko-side (restructure tests to not call across module boundary from test body).

If it FAILS: the bug is in the AILANG test runner itself for `() -> bool` functions. The fix is AILANG-side.

### Step 2: Export vs non-export isolation

```ailang
func non_exported_helper() -> int = 42

export func exported_helper() -> int = 99

func test_non_exported() -> bool
  tests [((), true)]
  { non_exported_helper() == 42 }

func test_exported() -> bool
  tests [((), true)]
  { exported_helper() == 99 }
```

If `test_non_exported` passes but `test_exported` fails: the runner is re-evaluating exported functions in a different scope.

If both fail: the runner can't resolve any module-level function from test bodies.

### Step 3: Check existing passing tests

The `tests [(a, b)]` format is used by some AILANG stdlib modules that DO pass. Compare their structure to motoko's failing ones.

---

## Mitigation (motoko-side, unblocks now)

While the AILANG-side fix is investigated, replace `tests [((), true)]` patterns with `ailang run`-compatible test scripts:

**Before (broken):**
```ailang
func parse_empty() -> bool
  tests [((), true)]
  { len(parse_core_ext_order_names("")) == 0 }
```

**After (workaround):**
```ailang
func test_parse_empty() -> bool
  { len(parse_core_ext_order_names("")) == 0 }
```

Run via `scripts/smoke_v2_*.ail` style scripts that call each test function in a `main()` and report results. This is already how `scripts/smoke_v2_compaction.ail` and `scripts/smoke_v2_policy_denial.ail` work on this branch.

The mitigation accepts that `make check_core` reports `cluster harness evaluation failed` for these modules until the AILANG runner is fixed. Tests are still runnable via the smoke scripts.

---

## Proper fix (AILANG-side, prerequisite for inline-tests-as-contracts)

The inline-test story is central to motoko's self-checking architecture (and `m-motoko-verify-ail.md` builds on it). The proper fix is:

1. AILANG test runner must resolve function names from the module's full lexical scope at the point the `tests` block is declared
2. Exported functions must be visible in the test evaluation context (same as they are in `ailang check`)
3. Add a test case in AILANG's own test suite: `ailang test` on a module where a `tests [((), true)]` function calls an exported sibling function

File this as an AILANG-side bug before or alongside the motoko-side workaround. The AILANG runner fix is the precondition for removing the workaround later.

---

## Impact on other design docs

- **`m-motoko-z3-contracts.md`**: Phase 2 contract sweep relies on `make verify_core` catching contract violations. The inline-test harness failure is separate from `ailang verify` (Z3 contracts). `make verify_core` can proceed even with broken test harness — Z3 verification is independent of the `tests [...]` runner.
- **`m-motoko-verify-ail.md`**: The `verify.ail` module story is partially orthogonal (it uses `ailang run`, not `ailang test`). But the broader inline-tests-as-contracts story is blocked until this is fixed.

---

## Acceptance criteria

- [ ] Minimal reproducer identified: AILANG-side or motoko-side root cause confirmed
- [ ] If AILANG-side: bug filed in AILANG issue tracker with reproducer
- [ ] `make check_core` reports `0 harness failures` (either via AILANG fix or by removing broken `tests [...]` blocks and replacing with smoke scripts)
- [ ] `scripts/smoke_v2_*.ail` coverage maintained for all previously-inline-tested functions
- [ ] `m-motoko-verify-ail.md` updated with outcome (blocked/unblocked depending on AILANG fix timeline)
