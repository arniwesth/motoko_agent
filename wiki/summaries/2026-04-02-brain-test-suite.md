---
doc_type: short
full_text: sources/2026-04-02-brain-test-suite.md
---

# Brain Test Suite — Session Summary

**Date:** 2026-04-02

## Objective

Implement the test plan from `.agent/plans/Brain_Test_Suite.md` for the `swe/` brain modules, run all tests, and fix failures.

## Implementation

- **Phase 1:** Inline tests in `swe/parse.ail` for `is_done`, `parse_cwd`, `looks_like_shell` (43 tests pass).
- **Phase 2:** New file `swe/parse_test.ail` with wrapper functions to test ADT-returning functions (`extract_fence`, `first_shell_line`, `extract_bash`) because the test runner only supports primitive types (31 tests pass).
- **Phase 3:** Inline tests and verification annotations in `swe/agents_md.ail` for `dirname`, `is_root` (11 tests pass).

## Bugs Fixed

During implementation, 8 bugs were fixed, spanning the Go runtime and AILANG code:

1. **Missing closing fence check** in `extract_fence` — fixed pattern matching to require at least two parts after split.
2. **Empty Constructors/Types** in `assembleModuleResult` — populate maps from compile unit data so modules can see ADT constructors.
3. **ADT constructors from imports not injected** — extended `injectADTConstructors` to also scan `e.modules`.
4. **Cluster harness resolver** — switched from `BuiltinOnlyResolver` to `CombinedResolver` + `injectModuleBindings`.
5. **Name collision `std/string.length` vs `std/list.length`** — store both qualified and unqualified keys; resolver tries qualified first.
6. **Incorrect `substring` semantics** — third argument is end index, not length; fixed calls across `agents_md.ail`.
7. **`is_root` too broad for Windows** — changed to exact length checks to avoid false positives like C:\foo.
8. **dirname of "/" returned "."** — special-cased root path.

## Final Test Results

All 85 tests across `swe/parse.ail` (43), `swe/parse_test.ail` (31), `swe/agents_md.ail` (11) pass.

## Follow‑up: `make build` Fix

After the test session, `make build` failed due to parser restrictions:
- Expression bodies after `tests [...]` not allowed; changed to block bodies.
- `swe/prompts_test.ail` used invalid syntax; rewritten to use `forall` and brace blocks.

With these fixes, all 9 swe/ modules type-check, and the build succeeds.

## Deferred

Phase 5 (upgrade gate) deferred because `UpgradeManager` does not exist yet.

## Key Concepts

- [[concepts/ailang-testing]] – inline tests, wrapper functions, test runner limitations
- [[concepts/adt-in-testing]] – handling Option/Some/None ADT in test environments
- [[concepts/module-resolution-for-tests]] – CombinedResolver and qualified names to resolve collisions
- [[concepts/substring-semantics]] – `substring(start, end)` not `(start, length)`