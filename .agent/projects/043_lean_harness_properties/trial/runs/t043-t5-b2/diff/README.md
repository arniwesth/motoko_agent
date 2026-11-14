# Differential test for `../PathUpModel.lean` (Kiro step 2)

`run_diff.sh` runs the Lean model and the real `path_up` / `find_entry` / `contains_string`
(src/core/journal.ail:1364-1366, 1392-1397, 1403-1410) on the same 29,004 cases and diffs
their output byte for byte.

| File | What it is |
|---|---|
| `gen_cases.py` | The shared case file: every entry list of length 0..3 over 12 entry kinds (ids `"" a b`, parents `"" a b x`) × 4 start ids × 3 (`seen`, `acc`) variants; 6,000 random lists of length 0..12 over 7 ids and a dangling parent; 192 shuffled chains of 1..24 ids, open and closed into a cycle. Deterministic (seed 43005). |
| `enumerate.lean.tail` | The Lean half, appended to the model: reads the cases, prints `<case>\|<result seqs>\|<length>`. |
| `harness_head.ail`, `harness_driver.ail`, `build_harness.sh` | The AILANG half. The three functions are not exported, so `build_harness.sh` copies their text **verbatim** out of `src/core/journal.ail` at run time, prints each copied body's sha256, and wraps it with a driver that prints the same line. `JournalEntry` is imported from the real module. `MUTANT=<symbol>:<sed>` mutates one copied body (negative control only; never `src/`). |
| `check_props.py` | P5.2 and P5.3 checked directly on the REAL output at the call-site variant (no model). |
| `run_diff.sh` | All of the above. Exit 0: both ran, 0 mismatches; 1: a mismatch; 2: a toolchain missing. `FIXED=1`: the fix on both sides (`pathUpFix` against the real body with `then acc`). |
| `run/` | Logs of the recorded runs and the copied bodies' hashes. |

## Runs (2026-11-04, Lean 4.28.0 `7e01a1bf5c70`, ailang v0.54.14 `e1ef33fa`)

| Run | Result |
|---|---|
| First run, model as first written | **0 mismatches** / 29,004. The model was not changed by step 2. |
| Final run (`run/run_diff.log`) | 0 mismatches / 29,004; both outputs sha256 `217ac2f4931da6d2…` |
| `FIXED=1` (`run/run_diff_fixed.log`) | 0 mismatches / 29,004 between `pathUpFix` and the real body with the one-line fix (sha256 `cd473cc1c0b2ecd2…`). On that fixed real output, `check_props.py` finds only the 1,547 empty-start violations of P5.3; the 1,446 cycle violations are gone |

Real bodies at those runs: `contains_string` `8b56ed48…`, `find_entry` `404f6f11…`, `path_up`
`beb53cc9…`. The first two equal the pins in `src/eval/journal/reader.ail:1188,1217`; `path_up`
does not (pin `db222e4c…`, which is the hash of the body with `then acc`, see
`../repro/check_fix.sh`).

## Negative controls (one mutant of the copied real body at a time, model unchanged)

| Mutant | Result |
|---|---|
| `path_up`: `contains_string(seen, id) then []` → `then acc` | 3,251 lines differ |
| `find_entry`: last match instead of first | 3,244 lines differ |
| `path_up`: `None => acc` → `None => []` | 7,150 lines differ |
| `path_up`: recurse with `seen` instead of `id :: seen` | real side does not terminate (stopped after >120 s): the `seen` guard is what P5.1 rests on |
| `contains_string`: never matches `"a"` | real side does not terminate (killed at 100 s), same reason |

## What it does not show

The model is tied to the code only on these inputs (lists ≤ 12 entries, chains ≤ 24); the
proofs are about the model. The AILANG half runs copies of the bodies in a harness module,
not the module itself; the copies are byte-identical (hashes above) and the functions are
pure, and the fold-level reproductions in `../repro/` use the unmodified exported functions.
