# Amendments

Each is dated in `sequence.log` with the hash of what replaced what. Nothing hashed before an
amendment was edited; the earlier file stays beside the later one.

## A1, 2026-11-17, after STEP4 and before the draw: `mutator.py` did not do what `operators.md` says

Found by reading the STEP4 enumeration before any draw, against `operators.md`, which is unchanged.

1. **A type was taken for a list literal.** All 12 list-element candidates in `enumeration/` were
   the two arguments of `Result[[Message], AIError]` in six type annotations. `operators.md` makes
   a list literal the site. A `[` right after a name that is not a keyword is now a type
   application, and everything inside it a type.
2. **A list literal in a record field was missed.** `_is_type_bracket` read `, field: [` as a
   parameter annotation, so `emitted: [start_event, complete_event]` (`tool_phase.ail:545`) had no
   candidate. Only `let x: [T]` and `(x: [T]` are annotations now.
3. **The applier's own hash check never ran.** It looked for `enumeration-meta.txt` in the
   evidence root; the enumeration writes it under its own directory. It now reads
   `enumeration-a1/enumeration-meta.txt` and refuses when the hash is absent. (The runner checks
   every file's hash against `base.sha256` independently.)

Effect: 409 candidates at 266 sites become 399 at 265 (12 removed, 2 added; the diff of the id
columns is exactly those 14 lines). The STEP3 script is kept as `scripts/mutator-step3.py`,
rebuilt by reversing the A1 edits and checked to hash to the STEP3 line (`48bb2c45…`). The new
planted cases fail against it (`MISSING` the two list elements, `A TYPE WAS TAKEN FOR A LIST
LITERAL`) and pass against the amended script. `enumeration/` is STEP4 as first run, unedited;
`enumeration-a1/` is what the draw reads.

## A2, 2026-11-17, during tier 1 and before the scorer read any tier-1 result: the scorer's runtime-failure pattern

While designing the reach probes, a three-line program (`scripts/probe-semantics-test.ail`) showed
that AILANG v0.60.4 reports an integer division by zero as `Error: execution failed: RT001: integer
division by zero at <file>:<line>:<col>`, not as acceptance's `panic: division by zero` (v0.47.2).
`score.py` looked only for `panic:`, so it would have filed a runtime failure as INCOMPLETE: still
not a kill, but not named as what it is. It now also reads `execution failed` as PANIC. A planted
case in the new wording is added to the self-test; it reads PANIC with the amended scorer and
INCOMPLETE with the pre-A2 one (kept as `scripts/score-pre-a2.py`, with its self-test as
`scripts/score_selftest-pre-a2.py`). The same program showed that a pure `let _ = 1 / (n - n);` whose
value is never used is still evaluated, which the reach probes rely on.

## A3, 2026-11-17, during tier 1: the scorer counted rows, not members

m06's run printed five `journal-fold-disagrees` findings on each of five members, and `score.py`
listed the member once per finding ("(25)"). The state (KILL) is unaffected; the member list and its
count are now distinct members. A planted case with two findings on one member is added. The pre-A3
scorer is kept as `scripts/score-pre-a3.py`.

## A4, 2026-11-17, during tier 3: keep corpus_pr's whole output

`corpus_pr`'s recipe prints only the last 40 lines of a red run, which hides the failing row
(ADR-003 *Not decided* item 7). m01's and m04's runs showed only `✗ WI-A15 commit 1 FAILED`.
`run_gate.sh` now copies the non-wire lines of the recipe's own `/tmp/corpus_pr.out` into
`runs/corpus_pr/<id>/full.txt`. It was replaced with `mv` (a new file), so the instance running at
the time was not edited under it. m04's full output was still in `/tmp/corpus_pr.out` and was copied
by hand right after the amendment, before the next corpus_pr run. m01's had already been
overwritten; its failing row is not recorded. The pre-A4 runner is kept as `scripts/run_gate-pre-a4.sh`.

## A5, 2026-11-19, after the pilot was committed: "not reached" said more than the probe measured

Found when the operator asked whether the 11 unreached mutants are a weakness of the DST suite.
The reach probe (tier 2) ran only under `make corpus_judge`, so "not reached" means not reached
by its 18 members and 5 controls. The README said "11 are run by nothing at all", "No run here
walks any of them" and "recorded nowhere as unwalked", which reads as the whole suite and every
record. What it measured is `corpus_judge`'s bank, and the record searched is ADR-003.

Only wording changes. No verdict, count, yield or recommendation does. `README.md` is edited; the
README as first committed stays beside it as `README-pre-a5.md`, at the hash the FINAL step
records. The README also gains:

- a text search of `scripts/dst/` for the unwalked branches, marked as unmeasured;
- a line under *What was not verified*;
- one sentence in the recommendation: re-running the reach probes under `make dst` would show which
  of these sites another gate already walks.
