# `ailang test` reports "All tests passed!" and exits 0 when every test was SKIPPED

## Status

open (upstream, AILANG v0.26.0) — **worked around, not fixed.** `make test_coverage` reads the
counts instead of the exit status, so the ten affected tests are now visible. The underlying
reporting behaviour is unchanged and any *other* consumer of `ailang test` is still misled.

## Branch

arniwesth/mot-54-execute-wi-a17 (found while executing WI-A17, cluster 15)

## Description

A file whose tests are all skipped is reported as a full pass:

```
$ ailang test src/core/prompts_test.ail ; echo $?
✓ All tests passed!

6 tests: 0 passed, 0 failed, 6 skipped
  ✓ Passed: 0
  ✗ Failed: 0
  ⊘ Skipped: 6
0
```

Six tests, none of them executed, banner says they passed, exit code 0. `--format json` sets
`"success": true`.

**The exit status cannot express the state that matters.** Zero failures is not the same as zero
unrun tests, and the runner conflates them. A `make` target of the shape
`ailang test X && echo "  ✓ X"` — which is the shape used in a dozen places in this repo — is green
over a file whose entire suite is dead.

The complementary case is handled correctly and is worth stating so nobody "fixes" it: a file with
**zero** tests sets `"success": false` and exits **1** (`No tests found`). So the runner fails on
*no tests* and passes on *no tests that ran*, which is the wrong way round.

## Measured impact at HEAD

Ten tests under `src/core` are skipped, in three classes, and every file carrying them is green:

| File | Skipped | Reason string | Cause |
|---|---|---|---|
| `src/core/prompts_test.ail` | 6 | `Named test blocks not yet implemented` | `test "name" { ... }` is parsed and then skipped wholesale on this pin |
| `src/core/tool_runtime.ail` | 2 | `no generator for parameter opt: Option[string]` / `...b: ToolBackend` | the property generator covers primitives only, so a `requires` contract on an `Option` or a user ADT generates a property it cannot feed |
| `src/core/compress.ail` | 2 | `requires not satisfied by random input (consider tighter generators)` | `max_chars >= 0` and the generator keeps drawing negative ints |

The first two are upstream limitations. The third is ours.

`prompts_test.ail` is the sharpest: it exists solely to hold algebraic laws for `prompts.ail`, and
**every one of its six assertions has been dead for as long as the file has existed.**

## Workaround in this repo

`tools/test_coverage/derive.py` parses `--format json` and reads `total_tests`, `passed_tests`,
`failed_tests` and the per-test `status`/`error`. **No rule in it reads a process exit code.**

Skips are tolerated by REASON rather than by filename, recorded in
`tools/test_coverage/skip_reasons.json` with a justification and a disposition. A skip whose reason
is not recorded is red, so a new class cannot arrive quietly — which is how the
`no generator for parameter` class above was found, after the tool was built.

Each record carries `expected: always` or `expected: sometimes`. The two upstream limitations are
`always`, so **the day either is implemented upstream the record matches nothing, the inventory goes
red, and the tests get switched back on** rather than remaining quietly unrun. `compress.ail`'s is
`sometimes` because it depends on drawn input and failing on its absence would make the gate flaky.

## Suggested upstream fix

Either of these would be enough; the first is preferable:

1. **A `--fail-on-skip` flag**, or make skipped tests non-zero by default. A skipped test is not a
   passing test and the summary line should not say "All tests passed!" when none ran.
2. **At minimum, stop printing "All tests passed!" when `passed_tests == 0 && skipped_tests > 0`.**
   The JSON `"success"` field should also be false in that case.

Implementing `test "name" { ... }` blocks and widening the property generator to `Option` and
user-declared ADTs would remove eight of the ten skips here, but that is a feature request; the
reporting behaviour is the defect.

## Not yet filed upstream

Not submitted to `sunholo-data/ailang` — filing is an outward-facing action and was outside WI-A17's
scope. Worth routing through the `ailang-feedback` skill, as WI-A3 did for its two reports.

## Location

- `src/core/prompts_test.ail` — six dead tests
- `src/core/tool_runtime.ail:` `isSome`, `is_native_backend` — two unfed properties
- `src/core/compress.ail:57`, `:69` — two properties whose precondition the generator cannot satisfy
- `tools/test_coverage/derive.py`, `tools/test_coverage/skip_reasons.json` — the workaround

## Notes

Related: `ailang-test-coverage-has-no-target-and-a-probe-is-broken.md`,
`smoke-scripts-report-failure-but-exit-zero.md` (the same conflation of "did not fail" with
"succeeded", one layer out), and
`.agent/projects/009_motoko_dst_execution/NOTE-cluster-15-execution-report-and-plan-corrections.md`
correction 0.
