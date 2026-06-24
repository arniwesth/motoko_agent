# TUI Edit Diff (issue #19) + Test Harness Investigation

Branch: `arniwesth/mot-18-fix-tui-edit-rendering`

## Overview

Two threads in one session:

1. **Issue #19 — "Bring back TUI edit diff."** After the port to upstream
   AILANG, WriteFile/EditFile rows stopped showing their diff. Root-caused and
   fixed. **Committed** (`78ba31e Fixed TUI edit rendering`).
2. **TUI test harness investigation.** `bun run test` ran **zero** tests.
   Root-caused (jest-under-bun is unsupported) and a runner fix + two residual
   test-failure fixes were prototyped. These were **reverted** — working tree is
   clean and the harness still runs under `bun` as before. Findings recorded
   below so the fix can be re-applied deliberately.

## Issue #19: edit diff disabled (FIXED)

### Root cause

The TUI's edit-diff renderer was never broken. `ui.ts` —
`parseUnifiedDiff` / `formatCollapsedDiffSummary` / `formatExpandedDiffLines`,
gated by `isEditToolFamily()` — was intact and tested
(`ui.tool-render.test.ts`). It simply stopped *receiving* the diff.

The renderer reads the unified diff out of `details.stdout`. The break was on
the runtime side, in the v2 wire-format bridge:

- The port routed tool dispatch through upstream `std/ai`. Edit-tool results
  now serialize their unified diff under a **`diff`** key (set by
  `tool_result_item_to_json` in `src/core/tool_dispatch_adapter.ail:90,99`),
  with **no `stdout` field**.
- `tool_messages_to_result_jsons` (`src/core/agent_loop_v2.ail:544`), which
  converts tool-role messages into the `native_tool_results` event the TUI
  renders, only forwarded `stdout`/`stderr`. For WriteFile/EditFile `stdout`
  was empty → TUI got empty stdout → `parseUnifiedDiff` returned `null` → no
  diff rendered.

The diff string itself (built by `build_write_file_diff` /
`build_edit_file_diff` in `src/core/tool_runtime.ail`) is a proper unified diff
(`--- a/…`, `+++ b/…`, `@@ … @@`), exactly what `parseUnifiedDiff` expects. The
TUI also already tags these rows with the right tool name (`toolRowToolNames`
set in `renderToolCalls`), so `isEditToolFamily()` fires.

### Fix

In `tool_messages_to_result_jsons`, fall back to the `diff` field when there's
no real `stdout`:

```
let stdout_raw = json_field_str(inner, "stdout", "");
let diff_str   = json_field_str(inner, "diff", "");
let stdout_str = if stdout_raw == "" then diff_str else stdout_raw;
```

This is purely the TUI wire-format path — the model still receives the original
`diff`-keyed payload via the tool-role message, untouched. `make check_core`
passes (24/24 modules).

## Test harness: `bun run test` ran 0 tests (investigated; fix reverted)

### Root cause

The `test` script ran jest as `bun node_modules/.bin/jest` — i.e. jest under
Bun's JS engine. jest-runtime 29's CommonJS module sandbox executes, at
`node_modules/jest-runtime/build/index.js:1636`:

```js
class Module extends _module().default.Module {}
Object.entries(_module().default.Module).forEach(([key, value]) => {
  Module[key] = value;   // throws under Bun
});
```

It copies every own-enumerable property of Node's `module.Module` onto its
sandbox subclass. Under Bun's `module` implementation one of those properties is
read-only, so the strict-mode assignment throws **"Attempted to assign to
readonly property"** during expect/jest bootstrap — aborting **every** suite at
setup before any test runs (all 30 reported "failed to run", 0 tests executed).
The `@jest/expect` / `stack-utils` frames in the trace were incidental (just
where the require chain was), not the cause. Jest's module sandbox is a
Node-internals mechanism Bun doesn't fully emulate.

### Fix that worked (reverted)

Run jest under Node with ESM VM modules — matching the repo's existing
`ts-jest` + `useESM` jest config in `src/tui/package.json`:

```diff
- "test": "bun node_modules/.bin/jest --testPathPattern='src/.*\\.test\\.ts'"
+ "test": "NODE_OPTIONS=--experimental-vm-modules node node_modules/.bin/jest --testPathPattern='src/.*\\.test\\.ts'"
```

With that, the suite actually ran: **214/215 passing**, including the
`ui.tool-render` edit-diff tests that cover the issue-#19 fix.

### Two residual failures (both root-caused; fixes reverted)

1. **`test/path-guard.test.ts`** — not a real jest suite; a hand-rolled script
   with its own `check`/`pass`/`fail` harness that ends in `process.exit()`,
   which jest flags as a suite failure (it even prints "6 passed, 0 failed"
   first). It's swept in because the greedy `src/.*\.test\.ts` pattern matches
   its absolute path (`.../src/tui/test/...`). Fix: convert to a real
   `describe`/`it`/`expect` suite (same six assertions, no `process.exit`).

2. **`src/scratchpad/loopback.test.ts`** — integration test that shells out to
   ripgrep via `execFileSync("rg", …)`. In this container `rg` is a harness
   shell *function*, not a spawnable binary (the real ripgrep is bundled inside
   VS Code, off-PATH), so node's spawn gets **ENOENT**. This exposed a **real
   latent bug** in `src/scratchpad/loopback.ts`: the search catch block mapped
   any non-numeric exit status to "rg exit 1 = no matches", so ENOENT was
   silently reported as **exit 0 / zero matches**, masking a missing-ripgrep
   environment. Proposed fixes:
   - loopback.ts: when there's no numeric status (spawn failure), return an
     explicit error (`exit 127`, "ripgrep (rg) could not be run"); keep the
     real rg-exit-1 → empty-matches path.
   - loopback.test.ts: guard with `ripgrepAvailable()` and `it.skip` when `rg`
     isn't spawnable, so the test runs where ripgrep exists and skips (not
     fails) where it doesn't.

   With all of the above, `bun run test` → 29 passed, 1 skipped, 220 tests
   passing, exit 0.

## Current state

- **Committed:** issue-#19 edit-diff fix (`src/core/agent_loop_v2.ail`).
- **Reverted / not applied:** the `package.json` runner change and the two
  residual test fixes. Working tree is clean; `bun run test` still runs jest
  under bun and therefore still executes 0 tests.
- An unrelated `ailang.lock` timestamp churn (regenerated by `make check_core`)
  was reverted during the session.

## Key references

- `src/core/agent_loop_v2.ail` — `tool_messages_to_result_jsons` (wire-format bridge)
- `src/core/tool_dispatch_adapter.ail` — `tool_result_item_to_json` (`diff` key)
- `src/core/tool_runtime.ail` — `build_write_file_diff` / `build_edit_file_diff`
- `src/tui/src/ui.ts` — `parseUnifiedDiff`, `formatToolDetailLines`, `isEditToolFamily`
- `src/tui/package.json` — `test` script (jest runner)
- `node_modules/jest-runtime/build/index.js:1636` — the Bun-incompatible Module copy
