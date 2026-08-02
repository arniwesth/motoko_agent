# `ailang check` and `ailang test` are separate coverage axes and only the first has a target

## Status
open (partially addressed in `ff8d8e5`)

## Branch
arniwesth/mot-46-execute-wi-a16-and-wi-a9 (surfaced while executing WI-A9)

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

### Partially addressed

`ff8d8e5` added `make terminal_trace`, which runs `ailang test` over `dst_result.ail`,
`phase_vocab.ail` and `session.ail`, and wired it into CI. That closes the three modules WI-A9
touched. **It does not close the axis** — the remaining `src/core/*.ail` modules are still
check-only, and the next module to gain an inline test will be unrun again by default.

### Second, smaller finding: a broken probe nothing runs

`scripts/probe_phase_vocab_sealed.ail` **fails at HEAD** and did so before this session's work:

```
Error: IMP010: symbol 'MkHistory' not exported by 'src/core/phase_vocab'
```

It is in no target, which is how it stayed broken. It is unrelated to WI-A16/WI-A9 and was left
untouched. `MkHistory` is a constructor of the `History` type in `phase_vocab.ail`; the probe either
predates the type being sealed or was written against a branch that exported it.

## Location

- `Makefile` — `check_core`, globs `src/core/*.ail`, runs `ailang check` only
- `Makefile` — `test_core`, hand-enumerated: `src/core/agents_md.ail`, `src/core/parse_test.ail`
- `Makefile` — `terminal_trace`, added in `ff8d8e5`, runs `ailang test` over three modules
- `src/core/phase_vocab.ail:1105-1106` — the `RunSummary` goldens that were unexecuted
- `scripts/probe_phase_vocab_sealed.ail` — broken, unwired

## Fix

1. **Make the test target glob rather than enumerate**, mirroring `check_core`'s loop shape and its
   accumulate-then-fail structure so one failing module does not mask the rest:

   ```
   for f in src/core/*.ail src/core/test/*.ail; do ailang test "$f" ... done
   ```

   Two cautions from measuring it here: `ailang test src/core/session.ail` takes **~32 s** on its
   own, so a full glob is a minute-plus and belongs in the DST aggregate rather than in the
   fast inner loop; and modules with no tests must not be counted as failures.

2. Once (1) exists, `terminal_trace`'s three explicit `ailang test` lines become redundant and
   should collapse into it.

3. Decide `probe_phase_vocab_sealed.ail`'s fate separately — either repair it against the sealed
   `History` type and give it a target, or delete it. A probe that neither runs nor compiles is
   worse than no probe, because it reads as coverage in a directory listing.

## Non-goals

- Do not add `ailang test` to `check_core` itself. `check_core` is the fast pre-commit gate and is
  invoked by DP7's verifier; a minute of unit tests in it would change the cost of every DP7
  approval.

## Notes

The general shape — *a glob-based target that covers one verb, and a hand-enumerated target that
covers another* — is worth checking for elsewhere in the Makefile. `verify_core` (Z3 contracts)
globs correctly; `test_core` does not.

Related:
`.agent/projects/009_motoko_dst_execution/NOTE-cluster-4-execution-report-and-plan-corrections.md`
(C5).
