# `ailang check` and `ailang test` are separate coverage axes and only the first has a target

> **The filename is wrong and is kept for the links that point at it. The probe is NOT broken** —
> see "The probe was never broken" below. It is a sealing assertion whose failure is its pass
> condition, and six cluster reports carried the wrong claim from this file before anyone read what
> the probe asserts.

## Status

**RESOLVED 2026-08-04** by WI-A17 (cluster 15). `make test_coverage` closes the axis; the probe is
wired with inverted polarity. Report:
`.agent/projects/009_motoko_dst_execution/NOTE-cluster-15-execution-report-and-plan-corrections.md`.

## Branch

arniwesth/mot-46-execute-wi-a16-and-wi-a9 (surfaced while executing WI-A9);
resolved on arniwesth/mot-54-execute-wi-a17.

## Description

`make check_core` iterates `src/core/*.ail` and runs **`ailang check`** on each — type and effect
checking only. Nothing ran **`ailang test`** over those same modules, so every inline
`tests [((), true)]` block in `src/core/` was compiled but never executed.

This is the same defect class as cluster 1's C6/C7, which C7 did not catch because it looked at
`src/core/test/` rather than at `src/core/` itself. The two axes are independent: a module can be
green under `check_core` forever with a failing unit test inside it.

Measured at HEAD while wiring WI-A9:

| module | inline tests | run by any target before `ff8d8e5`? |
|---|---|---|
| `src/core/session.ail` | 21 | no |
| `src/core/phase_vocab.ail` | 27 | no |

`phase_vocab.ail`'s 27 include the **`RunSummary` wire goldens** (`:1105-1106`) — the artifact
ADR-001 relies on to hold the `finish_reason` strings stable as a project-007 compatibility surface.
They were unexecuted. WI-A9 changed the code that produces those strings, and the goldens that were
supposed to hold it to that would not have run.

`make test_core` exists but names only two modules explicitly (`agents_md.ail`, `parse_test.ail`),
and `make test` aliases it. So the gap is not that no test target exists — it is that the target
enumerates modules by hand and silently omits everything added since.

## How it was closed

`make test_coverage` (`tools/test_coverage/derive.py`, WI-A17) walks `src/core` **recursively** and
runs `ailang test --format json` over every `.ail` file in it. Final state at HEAD: **60 files
discovered, 39 carry tests, 370 tests, 360 passed**. It is in `make dst` and has its own CI step.

**Three things this file's proposed fix got wrong, all found by building it:**

1. **The suggested glob was `src/core/*.ail src/core/test/*.ail`, and that still misses
   `src/core/ext/runtime.ail`** (8 tests). Any enumeration that names directories reproduces the
   bug one level down. The walk is `rglob`.
2. **The count in this file, and in WI-A17's own handoff, is short by a file.** Both derive "carries
   tests" from `^\s+tests \[`, which cannot see `test "..."` blocks — so
   `src/core/prompts_test.ail` (6 tests) appears in neither. `requires` contracts also generate
   property tests. The tool therefore cross-checks a grep against the runner's JSON and goes red
   when they disagree.
3. **"Modules with no tests must not be counted as failures" is right, and the reason given for it
   is inverted.** `ailang test` exits **1** on a zero-test file (`"success": false`). What it does
   *not* do is fail when every test is SKIPPED: it prints "All tests passed!" and exits 0. See
   `ailang-test-reports-all-passed-when-every-test-skipped.md` — ten tests under `src/core` are in
   that state.

This file's cost caution held up: `session.ail` alone is ~44 s and the full sweep is **3m40**, so it
lives in the DST aggregate and its own CI step, not in `check_core`. Parallelising it is *slower*
(4m10 at `--jobs 4`, on twice the CPU) — the shared compile cache thrashes.

`terminal_trace`'s three explicit `ailang test` lines were **left in place** rather than collapsed.
They are cheap, and each carries a semantic label about what its module asserts that the generic
sweep does not.

## The probe was never broken

This file's original "second, smaller finding" said `scripts/probe_phase_vocab_sealed.ail` "fails at
HEAD" and "either predates the type being sealed or was written against a branch that exported it",
and recommended repairing or deleting it. **All of that is wrong**, and the claim propagated into
WI-A17's plan text and six cluster reports before anyone opened the file. Its first line reads:

```
-- This probe is expected to FAIL with IMP010: phase_vocab's sealed
-- constructors must not be importable outside src/core/phase_vocab.ail.
```

It imports `MkHistory` and `MkPayload` deliberately. **The compiler refusing that import is the
sealing assertion holding**, and project 004's plan records `ailang check
scripts/probe_phase_vocab_sealed.ail` still failing `IMP010` as its pass condition. Repairing it
would have inverted an invariant held since 004.

It is now checked by `make test_coverage` with **inverted polarity**: a successful compile is the
failure. The check requires `IMP010` **naming a sealed constructor**, not merely a non-zero exit —
a probe that started failing for an unrelated reason would satisfy "exit != 0" while asserting
nothing about sealing.

**The lesson, and it is why this file is corrected rather than deleted:** an artifact recorded as
broken in an issue tracker is read as broken by everyone downstream, and the recommendation to
"repair or delete" was inherited six times without anyone running the file's own first line to
ground. A probe whose failure is its pass condition needs that stated *in the target that runs it*,
which is now the case.

## Location

- `Makefile` — `test_coverage`, `test_coverage_selftest` (the fix)
- `Makefile` — `check_core`, globs `src/core/*.ail`, runs `ailang check` only
- `Makefile` — `test_core`, hand-enumerated; superseded but left alone
- `tools/test_coverage/derive.py` — the inventory and its ten rules
- `scripts/probe_phase_vocab_sealed.ail` — correct, and now wired

## Non-goals

- Do not add `ailang test` to `check_core` itself. `check_core` is the fast pre-commit gate and is
  invoked by DP7's verifier; 3m40 of unit tests in it would change the cost of every DP7 approval.
- `src/tui`, `packages/**` and scripts other than the sealing probe were out of scope. The general
  shape — *a glob-based target that covers one verb, and a hand-enumerated target that covers
  another* — is still worth checking for there.

## Notes

Related:
`.agent/projects/009_motoko_dst_execution/NOTE-cluster-4-execution-report-and-plan-corrections.md`
(C5), and `NOTE-cluster-15-…` for the resolution.
