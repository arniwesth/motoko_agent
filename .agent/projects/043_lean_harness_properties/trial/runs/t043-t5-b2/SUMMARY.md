# T5: the fold's path (`path_up`, `find_entry`), run B2, Kiro's method

Target: `src/core/journal.ail`: `contains_string` :1364-1366, `find_entry` :1392-1397,
`path_up` :1403-1410, one call site :1684 (`path_up(all, leaf, [], [])` in `fold_journal`).
Intent: the comment at :1399-1402 and ADR-003 D4 rule 1 ("From `leaf` to the root by
`parent_id`, stopping at the first repeated id; reversed.").
Tools: Lean 4.28.0 (`7e01a1bf5c70`), core only, `lean` on single files; ailang v0.54.14
(`e1ef33fa`). Work ran from 19:52 to about 20:25 UTC on 2026-11-04. Nothing in the tree was
modified, and `git` was not run.

## Verdicts

| Property | Verdict | Where |
|---|---|---|
| **P5.1** terminates on every entry list, parent cycles included | **Proved** (model). Every differential case also terminated on the real code. | `P5_1_terminates` |
| **P5.2** no id twice in the result | **Proved** (model). 0 violations on the real output. | `P5_2_nodup` |
| **P5.3** a chain, ending at the start id if the start names an entry | **False.** Two counterexample families, both reproduced on the real code. | `bug_P5_3_cycle`, `bug_P5_3_header_cycle`, `bug_P5_3_empty_id` |

The part of P5.3 that does hold is proved as `P5_3_chain_part`: the result is always a chain,
and when it is non-empty its last entry has the start id. What fails is non-emptiness.

### The defect (B2-T5-1): a cycle discards the whole path

`path_up` handles a repeated id with `else if contains_string(seen, id) then []` (:1405). The
comment and D4 rule 1 call this "stopping at the first repeated id", which means keeping
`acc`, the path climbed so far. Returning `[]` throws that path away. On the real code:

- `path_up([{a, parent a}], "a", [], [])` returns `[]`. D4 rule 1 gives the path `[a]`.
- `path_up([{h, parent m}, {m, parent h}], "m", [], [])` returns `[]`. D4 rule 1 gives
  `[h, m]`, root first.
- Through the unmodified resume path (`parse_journal_text`, `journal_leaf`, `fold_journal`, as
  `rpc.ail:553-557` calls them), take a valid journal from the real writer twin and change only
  the header's `parent_id` to the leaf's id. The fold refuses it with `header`, although the
  header is on the path. The unedited journal folds.
- In the differential set, 1,446 of the 5,955 call-site cases whose start names an entry hit
  this.

The fix is `then acc` (`pathUpFix` in the model). It is proved to keep P5.2 (`fix_P5_2`), to
give P5.3 for every start id other than `""` (`fix_P5_3`), and to change nothing except the
`[]` answers (`fix_conservative`). On the real code, `repro/check_fix.sh` applies it to a
throw-away copy of the tree in which every file except `journal.ail` is a symlink. In that
copy, `repro_cycle.sh` exits 0 and the fold accepts the header-cycle journal. `FIXED=1
diff/run_diff.sh` also gives 0 mismatches between `pathUpFix` and the fixed body.

Provenance: `src/eval/journal/reader.ail` keeps a pinned copy of this fold. Its copy of
`path_up` reads `then acc`, and its SOURCE pin `db222e4c…` is exactly the sha256 of the fixed
body. The current body hashes to `beb53cc9…`, while `find_entry` and `contains_string` still
match their pins. So `[]` was introduced after that copy was pinned.

### The second P5.3 counterexample (B2-T5-2): the empty id

`journal_entry_of_json` accepts `"id": ""`. `path_up` tests `id == ""` first, as the
"no parent" sentinel, so a start id `""` that names an entry gives `[]`. The cycle fix does not
change this (`bug_P5_3_empty_id` shows `pathUpFix` also gives `[]`). `fix_P5_3_no_empty_ids`
proves that the cycle fix plus a decoder that refuses empty ids gives P5.3 for every start.
That decoder change was not tried on the real code. On the real fold, a journal whose last
line has id `""` is refused with `header`. 1,547 call-site cases in the differential set hit
this, and they remain on the fixed real output.

### Exploratory findings

- **X-1 (B2-T5-3), observation: a repeated id silently cuts the path.** `find_entry` takes the
  first match in file order, and `journal_leaf` takes the last line's id. Nothing refuses a
  repeated id. If the last line repeats an earlier id, the fold accepts and folds a path that
  skips the journal's last lines: here it reports `open:history_appended` instead of
  `run_finished`. P5.1 to P5.3 still hold in this case. Whether repeated ids should be refused
  is a question about D1's intent.
- **X-2 (B2-T5-4): the climb is quadratic.** Each step's `find_entry` rescans the file from the
  start, and `contains_string` rescans `seen`. CPU time for the real `path_up` on a linear
  journal, with the no-climb baseline subtracted, was 846 ms at 500 entries and 13,496 ms at
  2,000 entries. That is a ratio of 15.9 for 4× the length, where quadratic predicts 16. Wall
  clock reached 69 s at 3,000 entries. The fold runs on every resume.
  The comment "Recursion depth is the PATH length, not the file's" is also not true of the
  climb as a whole. `find_entry` recurses to the matched entry's file position, and AILANG has
  no tail-call elimination (`Makefile:394-398`). The production ceiling of 1,000,000
  (`runtime-process.ts:1005`) means the depth does not fail at realistic sizes.

### Reachability (Kiro steps 6-7)

None of the four is shown reachable from a real writer. The host writer
(`session-journal.ts:89-91`, `:368-371`) writes ids as `entryId(seq)`, which are unique and
never empty, a null parent on the header, and the previous leaf as every other parent. Cycles,
empty ids and repeated ids need an edited or corrupted file, or a future branching writer (D4
rule 4). Every journal shape in the repros is accepted by the strict decoder.

For B2-T5-1, the user-visible change is narrow. Only a cycle that passes through the header
changes the fold's answer, from `Refusal::Header` (misleading, since the header is present) to
a successful fold. Any other cycle is refused `header` with or without the fix, because the
first entry of the stopped path is not a header.

X-2 needs no malformed input. It applies to every long journal.

## Method record

**Step 1, the model.** `PathUpModel.lean`. An entry is reduced to `(id, parent_id, seq)`:
the three functions read only `id` and `parent_id`, and `seq` shows which entry was found. The
structure follows the source line for line. `pathUp` is defined by well-founded recursion on
`fresh seen es`, the number of entries whose id is not yet in `seen`, so Lean accepting the
definition is itself a termination proof. `pathUpFuel` spends one unit of fuel per call, so
P5.1 can be stated as a bound on the number of calls.

**Step 2, the differential test.** `diff/run_diff.sh` uses 29,004 cases. They are exhaustive up
to length 3 over 12 entry kinds × 4 starts × 3 (`seen`, `acc`) variants, plus 6,000 random lists
up to length 12, plus 192 shuffled chains up to 24 ids, open or closed into a cycle. The real
functions are not exported, so `ailang run --entry` and imports cannot reach them.
`diff/build_harness.sh` copies the three bodies verbatim from `src/core/journal.ail` at run time
and prints their sha256, and the copies run on the real `JournalEntry` type.

- **Step (2) changed the model 0 times.** The first run gave 0 mismatches in 29,004, and so did
  the final run (`diff/run/run_diff.log`, both outputs sha256 `217ac2f4…`).
- The edits made during the work were Lean compile errors in proofs (lemma tactics, a name
  clash with core's `Inv`, elaboration of the concrete instances), one infrastructure bug, and
  no behavioural change. The infrastructure bug: the tail's comment contained the case
  path, and its `/-` opened a nested Lean comment. None of these edits was prompted by a
  mismatch.

Negative controls each mutated one copied real body and left the model unchanged:

| Mutant | Lines that differ |
|---|---|
| `[]` → `acc` | 3,251 |
| last match instead of first | 3,244 |
| `None => []` | 7,150 |
| drop `id :: seen` | real side does not terminate |
| `contains_string` blind to `"a"` | real side does not terminate |

The two non-terminating mutants show that the `seen` guard is what P5.1 rests on.

**Step 3, proofs and axioms.** 35 theorems check. `axioms.txt` holds `#print axioms` for every
theorem and for the two model functions. Nothing uses `sorry` or `native_decide`. The axioms
used are `propext` and `Quot.sound`, plus `Classical.choice` in the invariant-based theorems,
which comes from core `simp`/`by_cases` lemmas. Every `bug_` theorem states a concrete
counterexample, and `witness_linear` is a non-vacuous instance for P5.2 and P5.3's chain
part.

**Step 4, reproductions.** Each script in `repro/` runs from the tree root (`bash
../out/repro/<script>`) and exits 1 when the defect is present. The direct check runs the
verbatim real body. The fold-level check runs the unmodified exported `parse_journal_text`,
`journal_leaf` and `fold_journal` on journals written by the real writer twin
(`journal_lines_of_records`) and then edited in one field. Each script takes 4 to 30 s (last run: 7, 4, 5, 18 s; `repro/*.last.log`).

## What I could not do, and the limits

- The proofs are about the model. The model is tied to the code only on the 29,004 cases
  (lists of at most 12 entries, chains of at most 24). This is the transcription gap that
  RESEARCH §9 names.
- The differential test's real side is a verbatim copy of the bodies in a harness module, not
  the module itself, because the functions are not exported. The bodies are pure, and their
  hashes are printed on every run. The fold-level reproductions avoid the copy.
- Reachability is not shown for any finding (see above).
- The empty-id fix (refusing `""` in the decoder) is proved only in the model, as
  `fix_P5_3_no_empty_ids`. It was not run on the real code.
- X-2 is a CPU-timing check. Other processes shared the machine, so wall-clock figures are
  noisy and the repro uses CPU time after a warm-up run. Its exit-0 side was not exercised,
  because no linear-time variant was built.
- P5.1 for `pathUpFix` rests only on Lean accepting its well-founded definition. No fuel
  theorem was stated for it.

## Files

- `PathUpModel.lean`: the model, the lemmas, every theorem, the axiom prints.
- `axioms.txt`: the axiom report from the final run.
- `reports.tsv`: four reports, B2-T5-1 to B2-T5-4.
- `diff/`: `gen_cases.py`, `enumerate.lean.tail`, `harness_head.ail`, `harness_driver.ail`,
  `build_harness.sh`, `check_props.py`, `run_diff.sh`, `README.md`, and `run/` (logs, body
  hashes, output hashes).
- `repro/`: `common.sh`, `write_journal.ail` (the real writer twin), `fold_file.ail` (the
  real resume fold of a file), `repro_cycle.sh`, `repro_empty_id.sh`,
  `repro_duplicate_id.sh`, `repro_quadratic.sh`, `check_fix.sh`, `scale_path_up.sh`, and
  `scale_timings_wallclock.txt`.
