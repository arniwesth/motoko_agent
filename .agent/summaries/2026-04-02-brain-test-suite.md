# Brain Test Suite — Session Summary
**Date:** 2026-04-02  
**Branch:** `brain_test_suite`

## Objective

Implement the test plan from `.agent/plans/Brain_Test_Suite.md` for the `swe/` brain modules, run all tests, and fix any failures.

---

## What Was Done

### Phase 1 — Inline Tests in `swe/parse.ail`

Added inline `tests [...]` blocks to three functions:

- **`is_done`** (7 cases): positive and negative sentinel detection
- **`parse_cwd`** (10 cases): absolute `cd`, compound commands, relative paths, no-cd
- **`looks_like_shell`** (26 cases): shell token heuristics

Also exported `extract_fence` and `first_shell_line` (previously unexported) so they could be tested from a separate file.

**Result:** 43 inline tests all pass on `ailang test swe/parse.ail`.

**Syntax note discovered:** After `tests [...]`, the function body MUST use `{ }` braces. The `= expr` form is rejected by the parser.

---

### Phase 2 — New File `swe/parse_test.ail`

ADT-returning functions (`extract_fence`, `first_shell_line`, `extract_bash`) cannot use `Some`/`None` as inline test expected values — the test runner only supports primitive types (bool, string, int). Wrapper functions returning bool/string were written instead:

- `ef_some` / `ef_value` — test `extract_fence`
- `fsl_some` / `fsl_value` — test `first_shell_line`
- `eb_some` / `eb_value` — test `extract_bash`

Total: 31 tests.

---

### Phase 3 — Inline Tests in `swe/agents_md.ail`

Added inline `tests [...]` to:
- **`dirname`** (5 cases)
- **`is_root`** (6 cases)

Added `@verify(depth: 1)` annotations to two pure invariant functions (`is_root_length_bound`, `dirname_shrinks`).

---

## Bugs Fixed

### Bug 1: `extract_fence` — No closing fence check (`swe/parse.ail`)

**Symptom:** `extract_fence("```bash\necho hello", "```bash")` returned `Some("echo hello")` instead of `None`.

**Cause:** After splitting by the opening fence, the inner `split(rest, "```")` returned a single-element list when no closing fence exists. The match `cmd :: _` matched this single-element list.

**Fix:** Changed the inner match to require at least two parts:
```ailang
-- Before:
cmd :: _ => Some(trim(cmd))

-- After:
_ :: []        => None,
cmd :: _ :: _  => Some(trim(cmd))
```

---

### Bug 2: `assembleModuleResult` — Empty `Constructors`/`Types` maps (`ailang/internal/pipeline/pipeline_module_compile.go`)

**Symptom:** `ailang test swe/parse_test.ail` failed with `constructor Option.Some not found`.

**Cause:** `assembleModuleResult` always created empty `Constructors`, `Types`, and `Exports` maps. So `e.modules` never had type/constructor info from compiled modules.

**Fix:** Populated from compile unit data:
```go
// Constructors from unit.Constructors
for ctorName, ctorInfo := range unit.Constructors {
    loaded.Constructors[ctorName] = ctorInfo.TypeName
}
// Types from unit.Surface.Decls
for _, decl := range unit.Surface.Decls {
    if td, ok := decl.(*ast.TypeDecl); ok {
        loaded.Types[td.Name] = td
    }
}
// Exports from unit.Surface.Decls
for _, decl := range unit.Surface.Decls {
    if fn, ok := decl.(*ast.FuncDecl); ok && fn.IsExport {
        loaded.Exports[fn.Name] = fn
    }
}
```

---

### Bug 3: ADT constructors from imported modules not injected (`ailang/internal/testing/executor_helpers.go`)

**Symptom:** After fix 2, `Some`/`None` from `std/option` still not found.

**Cause:** `injectADTConstructors` only iterated over the source file's type declarations. Constructors from imported modules (like `std/option`) were never added to the evaluator's env.

**Fix:** Extended `injectADTConstructors` to also iterate over `e.modules`.

---

### Bug 4: Cluster harness missing module bindings and resolver

**Symptom:** `swe/parse_test.ail` wrapper functions failed because `CombinedResolver` was not used in the cluster harness.

**Cause:** The cluster harness (`EvaluateInlineTestsWithCluster`) used `BuiltinOnlyResolver`, which cannot resolve cross-module function references or ADT constructors.

**Fix:** Switched cluster harness to use `CombinedResolver` + `injectModuleBindings` (same pattern as the single-binding harness path).

---

### Bug 5: `std/string.length` vs `std/list.length` name collision (`ailang/internal/testing/executor_helpers.go`)

**Symptom:** `str_length(s)` in `agents_md.ail` sometimes resolved to `_list_length` (list length), causing `_list_length: expected List, got *eval.StringValue`.

**Cause:** Both `std/string` and `std/list` export a function named `length`. `injectModuleBindings` stored both under the unqualified key `length` in the env. Whichever module was processed last (map iteration order is random) won, causing non-deterministic behavior.

**Fix (two-part):**
1. `injectModuleBindings` now stores functions under **both** `length` (unqualified) and `std/string.length` / `std/list.length` (qualified).
2. `CombinedResolver.ResolveValue` Case 2 now tries the qualified key (`ref.Module + "." + ref.Name`) first before falling back to unqualified lookup.

---

### Bug 6: `substring` semantics — `agents_md.ail`

**Symptom:** `dirname` and `is_root` produced wrong results. E.g., `dirname("/home/user/file.txt")` returned `"/"`.

**Cause:** `substring(s, start, end)` third argument is the **end index** (exclusive), NOT the length. Code used `substring(s, i, 1)` intending "1 character at position i", but this means "from i to position 1" (often empty or wrong).

**Fix:**
- `find_last`: `substring(s, i, 1)` → `substring(s, i, i + 1)`
- `is_root`: `substring(path, 1, 1)` → `substring(path, 1, 2)` and `substring(path, 2, 1)` → `substring(path, 2, 3)`

---

### Bug 7: `is_root` Windows root detection too broad (`swe/agents_md.ail`)

**Symptom:** `is_root("C:\\foo")` returned `true` instead of `false`.

**Cause:** The condition `substring(path, 2, 3) == "\\"` matched any path starting with `X:\...`, not just `X:\` (3-char root).

**Fix:** Changed to exact length checks:
```ailang
-- Before:
str_length(path) >= 2 && substring(path, 1, 2) == ":" &&
  (str_length(path) == 2 || substring(path, 2, 3) == "\\")

-- After:
(str_length(path) == 2 && substring(path, 1, 2) == ":") ||
(str_length(path) == 3 && substring(path, 1, 2) == ":" && substring(path, 2, 3) == "\\")
```

---

### Bug 8: `dirname("/")` returned `"."` instead of `"/"` (`swe/agents_md.ail`)

**Cause:** The condition `last_slash == 0 && str_length(clean) > 1` was false for `"/"` (length 1), falling through to `"."`.

**Fix:** Changed to `if last_slash == 0 then "/"` (always return "/" when the only slash is at position 0).

---

## Final Test Results

| File | Tests | Result |
|------|-------|--------|
| `swe/parse.ail` | 43 | ✓ All pass |
| `swe/parse_test.ail` | 31 | ✓ All pass |
| `swe/agents_md.ail` | 11 | ✓ All pass |
| **Total** | **85** | **✓ All pass** |

---

## Files Changed

### AILANG source
- `swe/parse.ail` — Added tests, exported functions, fixed `extract_fence` closing fence check
- `swe/parse_test.ail` — New file: 6 wrapper functions, 31 tests
- `swe/agents_md.ail` — Added tests, fixed `substring` usage, fixed `is_root`, fixed `dirname`

### Go runtime (test harness)
- `ailang/internal/pipeline/pipeline_module_compile.go` — `assembleModuleResult` now populates Constructors/Types/Exports
- `ailang/internal/testing/executor_helpers.go` — Module-qualified env keys, extended ADT constructor injection, CombinedResolver ADT case
- `ailang/internal/testing/executor.go` — Cluster harness switched to CombinedResolver + injectModuleBindings

---

## Follow-up — `make build` Fix (2026-04-02)

### Problem

`make build` failed with 3 type-check errors:
- `swe/prompts.ail:119` — `PAR_UNEXPECTED_TOKEN`: expression body after `tests [...]` rejected by parser
- `swe/prompts_test.ail` — `"AILANG requires 'let' keyword for bindings"`
- `swe/rpc.ail` — cascading failure from prompts.ail import

### Root Causes

**1. Expression bodies after `tests [...]` not supported.** Two functions in `swe/prompts.ail` (`with_cache_hint` and `fmt_obs`) used `= expr` after the `tests [...]` block. The AILANG parser requires `{ }` braces for the function body when `tests [...]` is present — the expression-body form (`= ...`) is rejected.

**2. `swe/prompts_test.ail` used invalid syntax.** The file used `property "name" (params) = expr` and `test "name" = expr` forms. The AILANG parser requires:
- `test` declarations: `test "name" { body }` (braces required)
- `property` declarations: `property "name" { forall(params) => expr }` (braces + `forall` required)

### Fixes

**`swe/prompts.ail`:**
- `with_cache_hint`: changed expression body to block body after `tests [...]`
- `fmt_obs`: changed expression body to block body after `tests [...]`

**`swe/prompts_test.ail`:**
- Rewrote all `property` declarations to use `forall(params) => expr` inside `{ }`
- Rewrote all `test` declarations to use `{ expr }` blocks
- Removed standalone `=` syntax throughout

### Result

```
swe/ type-check: 9 passed, 0 failed
npm run build: compiled successfully
```

### Known Note

Named test/property blocks may not be fully executed by the test runner yet (runner support was deferred), but they now pass static type-checking (`ailang check`), which unblocks `make build`.

---

## Deferred

- **Phase 5 (upgrade gate)**: `UpgradeManager` does not exist yet. Deferred.
