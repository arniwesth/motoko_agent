# T5, the fold's path: `find_entry` and `path_up` (src/core/journal.ail:1392-1410)

Arm B, replicate 1. Method: Kiro's, as RESEARCH-lean-harness-properties.md §1 describes it.
Model in Lean 4.28.0 (core only, no Mathlib, no Lake). Differential test against the real
functions under ailang v0.54.14. Proofs and `bug_` theorems. Reproduction on the real code.
The real code was executed only for the differential test (step 2) and the reproductions
(step 4). Nothing was written in the tree, and `git` was not run.

## Verdict

| Property | On the snapshot | Evidence |
|---|---|---|
| **P5.1** terminates on every entry list, cycles included | **Proved** (about the model) | `pathUp` is accepted as a total, well-founded definition. `p5_1_terminates`: on every `es` and `id`, the recursion returns within `es.length + 1` calls, with `pathUp`'s value |
| **P5.2** no id twice in the result | **Proved** (about the model) | `p5_2_no_repeated_id` |
| **P5.3** chain, first half: each `parent_id` is the previous entry's id | **Proved** (about the model) | `p5_3_chain` |
| **P5.3** second half: if the start id names an entry, the last entry has that id | **False**, two counterexamples, both reproduced on the real code | `bug_p5_3_cycle_returns_empty`, `bug_p5_3_cycle_through_header` (B1-T5-1) and `bug_p5_3_empty_id` (B1-T5-3) |

All three properties are stated for the caller's form, `path_up(es, id, [], [])`
(`fold_journal`, journal.ail:1684, the only caller). Lemmas that generalise over `seen` and
`acc` carry the induction.

### The findings (reports.tsv)

- **B1-T5-1, P5.3: on a parent cycle, `path_up` returns `[]`.** The repeated-id branch is
  `else if contains_string(seen, id) then []` (journal.ail:1405). The comment and ADR-003 D4
  rule 1 both say the climb STOPS at the first repeated id, which is to return `acc`; `[]`
  throws away the whole path. On `[{a, parent a}]` from `a`, `find_entry` finds the entry and
  `path_up` returns `[]`. Three pieces of evidence that this is a change and not the design:
  - the eval twin `ev_path_up` (src/eval/journal/reader.ail:1226-1233) returns `acc`;
  - its `-- SOURCE … sha256:db222e4c…` pin is the hash of the core body with `then acc`, and the
    current body does not match it (`repro/pin_check.py` exits 1). `find_entry` and
    `contains_string` still match their pins;
  - `p5_3_ends_at_start_unless_empty` shows that for any non-empty start id, this `[]` is the
    only way P5.3's second half can fail on the snapshot.
- **B1-T5-2, X-1: the same defect through the public API, on the unmodified file.**
  `fold_journal` folds a well-formed journal from the module's own writer (`accept`, 3
  messages). It refuses the same journal with `header` once the header's `parent_id` is pointed
  at the leaf or at itself. With the fix planted, both changed journals fold to the control's
  result.
- **B1-T5-3, P5.3: start id `""` with an entry whose id is `""`.** `path_up` returns `[]`
  from its first branch. `""` is the no-parent sentinel, but `journal_entry_of_json` accepts it
  as an id. This one is **not** the planted change: the eval twin and the fix behave the same
  way. Its severity is low and it is not shown reachable. It may be a gap in the registered
  statement rather than in the code.

**X-1 (exploratory), stated:** for a journal whose `parent_id` chain from the leaf revisits an
id, `fold_journal` folds the path D4 rule 1 names: the climb up to the first repeated id,
reversed, refused with `header` only if that path's first entry is not a header.

### Reachability (Kiro's steps 6-7): not shown

The host writes the header with `parent_id` null (src/tui/src/session-journal.ts:371) and
every later entry with the current leaf, so a host working as designed writes no cycle. A
cycle needs a hand-edited or corrupted journal, or a future branch, rewind or fork operation
(ADR-003 D8: "additive later work"). Rule 1's repeated-id clause exists for exactly such input.

At the fold, only a cycle **through the header** changes the answer. On any other cycle, the
stopped path does not start at the header, so both readings refuse with `header`. So B1-T5-1
is a definite violation of `path_up`'s stated contract, and its user-visible effect is
"`--resume` refuses a journal it should fold" on a malformed file. B1-T5-3 needs an empty
entry id, which the host never assigns.

### The fix (step 8), proved on the model

`pathUpFixed` is `then acc` on a repeated id, which is the eval twin's body. Proved:
- `fix_p5_2` and `fix_p5_3_chain`;
- `fix_p5_3_ends_at_start`, P5.3's second half for every start id but `""`;
- `fix_agrees_or_snapshot_empty`: on every input, the fix returns the snapshot's result unless
  the snapshot returned `[]`, so the fix changes nothing that works today.

Its termination is its definition's, with the same measure. With the fix planted in the real
code, the real outputs equal `pathUpFixed`'s on all 50,704 differential inputs.

## Step (2): how many times the differential test changed the model

**Zero.** The first differential run, over 48,704 inputs (families B and R below), had 0
mismatches. The final run adds family X and covers 50,704 inputs, also with 0 mismatches. The
model's definitions (`containsString`, `findEntry`, `pathUp`, and `pathUpFixed`, which is
differential-tested through the `fix` mutant) are as first written.

A zero on the first try is only worth something if the test can see a difference, so three
mutants were planted, one at a time, in a shim copy of the real code. Each must produce
mismatches against the model (`diff/negative_control/`):

| Mutant in `journal.ail` (shim copy) | Lines that differ from the model, of 50,704 |
|---|---|
| `fix`: repeated id returns `acc` (also compared with `pathUpFixed`: **0** mismatches) | 5,817 |
| `find_last`: `find_entry` returns the last entry with the id, not the first | 4,514 |
| `no_seen`: `seen` is never extended (depth-capped so that it terminates) | 4,827 |

Changes that were **not** model changes, recorded so the count can be checked:
1. The first proof draft did not compile. `containsString_iff`'s proof was wrong, the
   `pathUp.induct` case for `id = ""` binds 2 variables, not 4, and unfolding the dependent
   `match hf : findEntry …` with `simp` failed. One `lean` run exceeded 120 s and was stopped.
   The fix was to unfold only through four per-branch lemmas (`pathUp_empty`, `_seen`, `_none`
   and `_some`). Only proof scripts changed.
2. `beq_self_eq_true` on `String` pulls in `Classical.choice`, so it was replaced by
   `decide_eq_true rfl`. After that, no theorem uses more than `propext` and `Quot.sound`.

## The differential test (diff/)

- **Real side.** `path_up` is not exported, and AILANG refuses to import it. `make_root.sh`
  builds a package root outside the tree with every module symlinked to the tree, except
  `src/core/journal.ail`. That file is a copy in which `contains_string`, `find_entry` and
  `path_up` gain `export`, and nothing else changes. The script checks this: exactly three
  changed lines, each the original with `export ` prepended, otherwise exit 3.
- **Inputs,** in the same order on both sides. A line carries its input, and the result's
  `seq`s and length:
  - **B:** every entry list of length 0-3 over 20 entries (ids `""`, a, b, c; parents `""`, a,
    b, c and the missing `z`), from every start id. Lists up to length 2 also run with three
    non-empty `(seen, acc)` pairs. 48,420 lines. This family covers self-loops, 2- and
    3-cycles, duplicate ids, missing parents and empty ids.
  - **R:** chains `e0..e(n-1)` for n = 1-8, with e0's parent either `""` or every `e_k` (so
    cycles of every length up to 8), from every entry and from a missing id. 284 lines.
  - **X:** 2,000 seeded LCG lists of length 4-10 over 7 ids and 8 parents. The generated input
    is echoed in the line, so a drift between the two generators would show as a mismatch.
- **Result,** 2026-11-04: 50,704 lines each, byte-identical, sha256 `113d33e4e882a2ad…`
  (`diff/results.log`). ailang takes about 1 min and Lean about 40 s.
- **How often the defect shows.** In the caller's form (`seen = acc = []`), the snapshot and
  the fix differ on 4,579 inputs: 4,095 in B, 204 in R and 280 in X. In every one, the snapshot
  returns `[]` where the fix returns a non-empty path.

## Axioms (axioms.txt)

`#print axioms` for all 33 theorems in `PathUpModel.lean`. Every one uses at most `propext`
and `Quot.sound`, and `chainB_cons` uses none. There is no `sorryAx`, no `Classical.choice`
and no `Lean.ofReduceBool`. The file has no `sorry` and no `native_decide`. Concrete `bug_`
and witness theorems are closed with `decide` on the per-branch lemmas' side conditions.
Non-vacuity: `witness_chain` gives a concrete input meeting `fix_p5_3_ends_at_start`'s one
hypothesis (`id ≠ ""`), on which the snapshot returns the whole chain, root first.

## What was not done, and limits

- **The transcription gap stays open.** Every proof is about the model. The differential test
  ties the model to the code only on the 50,704 inputs it ran, through an export-only copy.
  The model drops `at_ms`, `kind` and `raw`, which these functions never read.
- **P5.1 on the real code** is evidence, not proof: the real `path_up` returned on every
  differential input, cycles included.
- **Reachability** is argued from reading the host writer, not demonstrated (above).
- **Not run:** `tools/eval_protected/protected.py`, the repository's own pin checker, because it
  reads revisions through `git`. `repro/pin_check.py` recomputes the three pins without it.
- **Observations, not reported as defects:**
  - Among entries that share an id, `find_entry` returns the first. The ADR makes ids unique
    (host-assigned seqs), and no registered property depends on which one is returned. The
    `find_last` mutant shows the test can tell the difference.
  - The cost is O(path × file) for `find_entry` plus O(path²) for `seen`. The comment claims
    only that the recursion depth is the path's length, which holds.
  - The twin's pins say L1405-1412 and L1394-1399, but the functions now sit two lines higher
    (1403-1410 and 1392-1397). So something above `find_entry` in journal.ail also changed
    since the copy; that is outside T5 and was not followed.

## Files

| File | What it is |
|---|---|
| `PathUpModel.lean` | Model (header names source and lines), all theorems, `#print axioms` |
| `axioms.txt`, `lean_check.log` | Axiom report and the full output of `lean PathUpModel.lean` |
| `reports.tsv` | The three findings |
| `diff/make_root.sh` | Builds the `real` (symlinked) or `shim` (export-only, optional mutant) package root |
| `diff/enumerate_pathup.ail`, `diff/enumerate.lean.tail` | The two halves of the differential test |
| `diff/run_diff.sh` | Runs both halves and diffs them; `--mutant NAME` for the negative controls |
| `diff/results/`, `diff/results.log` | The final run: `lean.out`, `ail_real.out`, `axioms.txt` |
| `diff/negative_control/` | The three mutant runs and their diffs |
| `repro/repro_P5_3_cycle.sh`, `repro/repro_X1_fold_cycle.sh`, `repro/repro_P5_3_empty_id.sh` | The repros: run from the tree root, exit 1 when the defect is present. `REPRO_MUTANT=fix` runs them on the fixed code |
| `repro/path_up_direct.ail`, `repro/fold_cycle.ail`, `repro/_common.sh` | Their harness modules and the shared runner |
| `repro/pin_check.py` | Recomputes the eval twin's SOURCE pins for the three functions |
