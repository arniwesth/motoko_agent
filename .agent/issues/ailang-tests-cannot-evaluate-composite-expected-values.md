# `tests [...]` cannot evaluate a composite expected value

## Status

**Filed upstream 2026-09-08 — ticket `fb_334b4d8dea088ada`**, category `bug`, via the
`ailang-feedback` skill's MCP channel. Worked around in this tree; no fix expected soon.

## Description

An inline `tests [...]` block whose EXPECTED value is a list or a record does not run:

```
test 0: failed to evaluate expected: expected literal expression, got *ast.List
test 0: failed to evaluate expected: expected literal expression, got *ast.Record
```

The ARGUMENT side is fine — a tuple of arguments works. Only the expected side must be a scalar
literal. Records were confirmed 2026-09-08; the report initially described it as list-only.

## Why it cost us weeks

The failure mode is not "a test errors". It is **a test that was never an assertion, reported as a
stable red**. `packages/motoko-ext-herdr/types.ail` carried twelve such tests, dead from the day
they landed, presenting as `264 tests: 252 passed, 12 failed`. Every expected value in them was
CORRECT — they were asserted against a shape the harness cannot compare. Two sessions read that
count as known-red before anyone diffed the expected values by hand.

`types.ail:583` had documented the constraint 70 lines above the offending block, and the tests were
written anyway, which is what makes this a footgun rather than a documentation gap.

## Workaround, in use here

A string-rendering wrapper per function, asserted instead of the value. This tree has eighteen
(`argv_split_str`, `sweep_stale_panes_str`, `open_task_ids_str`, …). The cost is a parallel function
existing only for the harness, and an assertion about the rendering rather than the value.

## The ask, as filed

1. Evaluate composite expected values.
2. Failing that, REJECT them at parse or check time — a compile error would have cost one minute
   instead of weeks.
3. Failing both, document the restriction.

(2) alone addresses the harm.
