# `make eval_matrix` — video explainer

`eval-matrix-explainer.mp4` is a 4 min 46 s explainer of what `make eval_matrix` runs, what it
compares, what its output means and what it is for. It is for a reader who knows this repository
but not project 013. 1920×1080, 30 fps, H.264 with mono AAC, 19.9 MB. It is **narrated by a
synthetic voice**, and every spoken line is also on screen as a caption.

It was made on 2026-10-06 with `tools/explainer` (Manim Community 0.20.1, Kokoro v1.0) against
`main` at `59d5cbb9`. `eval_matrix.py` holds the seven scenes, one per beat.

It is **dated evidence**. The matrix is red at `59d5cbb9`, and scenes 5 and 6 show the counts of
particular runs. Scenes 2 to 4 describe the mechanism as `scripts/eval/candidate.py` has it at
that commit.

## What it shows

| Scene | Length | What it shows | Source |
|---|---|---|---|
| `S1_Question` | 38 s | The evaluator of ADR-004: a session journal is admitted (checks A1–A9, A9b), then a candidate change replays the recorded program (K0–K7). Each step ends in a verdict, and a table of 621 known cases checks those verdicts. | ADR-004 TL;DR, D2, D3; the 011 spike note, Part 6 |
| `S2_Row` | 40 s | One row of the expected table, a field to a line: the case, the suite file and test, then the expected verdict, first finding and position. Then the table as a whole: 621 rows by `expected_verdict`. | `MATRIX.expected.tsv`; PLAN-004 §3 "The D8 P1 matrix"; ADR-004 D8 |
| `S3_Run` | 45 s | `make eval_matrix` → `journal_replay.sh matrix` → `candidate.py matrix`. 27 files named by rows, run one at a time, plus the memory guard's tests as a gate: 28 suites in four kinds. `MATRIX.tsv` gets observed fields only. How long it takes. | `Makefile:3357–3368`; `journal_replay.sh:95`; `candidate.py:108–134`, `:1598–1723` |
| `S4_Join` | 43 s | The join on `case_id`, with three real rows: one `equal`, one `credited`, one `inapplicable`. The four statuses that leave a row unsatisfied, and the exit rule. | `candidate.py:1584–1595`, `:1715–1723`; the two TSV files |
| `S5_Tiers` | 38 s | The two observation tiers side by side: in the record tier the matrix parses a printed verdict and compares it; in the assertion tier the test compares and the matrix sees pass or fail. Then the clean run of 17 September as one bar: 185, 425, 11. | `candidate.py:116–134`; PLAN-004 §6, `P1R` R1 |
| `S6_Red` | 45 s | The clean run against the run at `59d5cbb9`: 29 rows failed, 33 missing, three suites non-zero, with each suite's reason. Then why that is read as a difference: the 011 spike's comparison of an unchanged and a changed tree, and its known-bad control. | the run's `matrix-logs/`; the 011 spike note, Part 6, and its `results/part6-*` |
| `S7_Not` | 37 s | What the matrix is not: part of `make dst`, run by CI, a run on a real session, an evaluation of a change. What it is for. | `Makefile:507–518`; `.github/workflows/`; `gen_fixtures.py`; PLAN-004 §0.6, §3 |

Each scene carries its sources in small type at the bottom left of the frame.

## What is measured, and where each number comes from

Paths without a leading directory are relative to the repository root. The run at `59d5cbb9` is
the 011 plan's baseline run of 2026-10-06, a clean worktree of `origin/main`; its output is in
`tmp/plan-011-baseline-2026-10-06/` of the main checkout, which is untracked.

| On screen | File |
|---|---|
| 621 rows; the five column names; the three rows shown; 360, 165, 33, 32, 11 and 9, 6, 3, 1, 1 by `expected_verdict`; 11 rows with no test; 27 distinct suite files, of which 17 are pure `.ail` modules, 7 are `*_live_test.ail` and 3 are Python | `src/eval/journal/testdata/MATRIX.expected.tsv` (sha256 `e70bec34c4e04129…`) |
| the 28th suite, a gate named by no row | `scripts/eval/candidate.py:1679–1681` |
| the seven column names of `MATRIX.tsv`; the observed fields of the three rows | `candidate.py:1472–1473`; `tmp/plan-011-baseline-2026-10-06/MATRIX.tsv` (`68c723a7147c2d49…`) |
| the printed line `Diverged(K2:ProjectionDiffers[ReplayMismatch]@interaction:14)` | `…/matrix-logs/candidate_checks_live_test.ail.log:450` |
| 129 equal, 419 credited, 11 inapplicable, 33 missing, 29 failed | `…/matrix-logs/join.tsv` (`2e74609921ca689c…`) and the summary line of `matrix.stdout.log` |
| 28 suites, 25 of them exit 0, and the three that do not | `…/matrix-logs/suites.json` (`11b8af206ddea778…`) |
| 821 s; `make` exit 2 | `…/meta.txt` (`c0b49d6397b52ee3…`) |
| 27 failed, 1 error; refusals naming `ProtectedRegionTouched` on `src/core/session.ail`'s imports | `…/matrix-logs/test_candidate.log` |
| the generator's parser cross-check failure; 33 rows missing | `…/matrix-logs/selftest.log`; `join.tsv` |
| 1 pure test failing with `effect 'FS' requires capability` | `…/matrix-logs/candidate_checks.ail.log` |
| 185 equal, 425 credited, 11 inapplicable; `make` exit 0; 28 of 28 suites; `d74079d`; 17 modules | PLAN-004 §6, "`P1R` R1 … 2026-09-17" |
| 25 to 40 minutes | `Makefile:3362–3363` |
| 12 GiB | `scripts/eval/mem_guard.py:30`, `:88` |
| the four lines of the comparison; the two `rc=1` lines; `259265b5` | `.agent/projects/011_improve_test_axises/evidence/mutation-spike/results/part6-compare.txt`, `part6-known-bad.txt`, `part6-sequence.log` |
| ten admission checks; K0 to K7 | ADR-004 D3 |

The September counts were checked a second way. The main checkout still holds that run's
untracked `src/eval/journal/testdata/MATRIX.tsv`, dated 2026-09-17; its sha256 is
`1ac7f001…4686`, the hash PLAN-004 §6 records. Joined to the expected table at `59d5cbb9` on
`case_id` it gives 185 equal, 425 credited and 11 inapplicable.

## What is illustrative, not measured

- **The diagram in `S1_Question`** is a simplification of D2 and D3. It draws admission and
  candidate replay as two boxes and gives each a row of verdicts. In the code a candidate can also
  be refused after its run: `candidate.py` decides K0 once the run is over (PLAN-004 §6).
- **The row in `S2_Row`** is one tab-separated line in the file. The frame sets it a field to a
  line and breaks the test name over three lines. "M14, divergences" is the plan's name for the
  family. "Five others" folds the five smallest classes into one cell; the frame lists them.
- **The 28 squares in `S3_Run`** are grouped by kind, which is my grouping, read from the file
  names and from the branches of `matrix()`. The sweep over them is not the real order or the real
  timing: the suites run in sorted path order, `test_candidate.py` first and the gate last.
- **"Fourteen minutes"** is 821 s. That run is short because most candidates are refused before
  they compile; the Makefile's figure was not measured here.
- **The three rows in `S4_Join`** were chosen to show one status each. Fields are separated by two
  spaces instead of tabs.
- **The steps in `S5_Tiers`** paraphrase the docstring of `candidate.py`. `"status": "pass"` is the
  shape of a test's entry in `ailang test --format json`, as in `matrix-logs/digests.ail.log:16`.
  "Two rows in three" is 425 of 621, 68 percent.
- **The reasons in `S6_Red`** are short forms. "The protected manifest is stale" stands for
  refusals of the form `ProtectedRegionTouched:changed:<imports:1> src/core/session.ail` against
  `tools/eval_protected/manifest-A.json`, which is pinned at `65003110`. The cause of the parser
  cross-check failure is not known; the 011 note says the same.
- **"It gated the evaluator's build"** rests on PLAN-004 §3 ("`P1R` and `P1G` join the two files")
  and on `HANDOFF-2026-09-20-plan004-p24-parked.md`, which lists `P1G` as done.

## Where the source differs from what was expected

- **The exit status.** `candidate.py matrix` returns 0 or 1 (`:1723`). The 2 in `meta.txt` and in
  the 011 note is `make`'s status for a failed recipe. The frame says "make: exit 2".
- **28 suites, 27 named by rows.** The 28th, `scripts/eval/test_mem_guard.py`, is named by no row
  and runs last as a gate. A red gate fails the command without changing any row.
- **`MATRIX.tsv` has a column the plan does not list.** PLAN-004 §3 names the observed fields and
  `commit`; the code also writes `observed_by` (`record`, `assertion` or `reason`).
- **The September output joins clean.** The 011 note's Part 6 says the operator's last matrix
  output "has one failing row". That file has one row whose observed verdict is `fail`,
  `M7.crosscheck_detects_short_span`, and `fail` is what its row expects. Against it, 62 rows of
  the run at `59d5cbb9` have a different observation; the note says 58 at `259265b5`, which was
  not checked.
- **The run at `59d5cbb9` matches the one at `259265b5`** in every count: 28 suites, 621 rows,
  419, 129, 29, 33, 11, the same three suites red. It took 821 s where that one took 1,062 s.

Not covered: `HANDOFF-2026-09-20` mentions a 638-row matrix at a later evaluator commit in
`../motoko_agent-eval`. That worktree does not exist in this sandbox, and the film describes the
621-row table on `main` only.

## The voice

Each caption is spoken by Kokoro v1.0, voice `af_heart`: 35 clips, 216 s of speech. Nothing
leaves the machine. The `SAY` table at the top of `eval_matrix.py` respells a few terms for the
voice (`case_id` is said "case I D", `make dst` "make D S T", `013` "oh thirteen", and four
numbers in words). The captions are unchanged.

What was checked, since the voice was never listened to:

| Check | Result |
|---|---|
| Whisper `small.en` transcription of each clip against its line | 21 of 35 word for word. Thirteen differ by digits for spelt-out numbers, initialisms, punctuation or homophones (red/read, suite/sweet, then/than). One is a mishearing: "Make eval matrix" is heard as "Make a vowel matrix". |
| Where speech starts in the final file against the scenes' timelines | all 35 within 27 ms |
| Clips overlapping | none |
| Loudness of the final track | -17.2 LUFS integrated, peak -0.5 dBFS |
| Geometry lint | 0 errors, 0 warnings |

The mishearing is the film's first line, and the title is on screen as it is said. Whisper has no
word "eval": four other spellings were tried and none is transcribed as "eval". The line is
spoken /ɪvˈæl/.

A transcription round trip shows the words are intelligible and correct. It does not show that
the delivery sounds natural.

## Re-render

From the repository root:

```sh
tools/explainer/setup.sh --with-whisper   # once: about 1.5 GB plus 0.5 GB, no root
F=.agent/projects/013_core_architecture_for_dst/video/eval_matrix.py
tools/explainer/explainer lint   $F                # 25 s, draws nothing
tools/explainer/explainer render $F --draft        # a 480p preview in scratch
tools/explainer/explainer render $F --transcribe   # 3.5 min, writes the mp4 beside the file
```

The first render also synthesizes the 35 clips. The `.mp4` is git-ignored
(`.agent/projects/**/video/*.mp4`).

To show a later run, change the constants at the top of `eval_matrix.py` (`EXPECTED`, `CLEAN`,
`TODAY`, the sample case) and the numbers written into the captions and pills of `S2_Row`,
`S3_Run`, `S5_Tiers` and `S6_Red`. A caption has to be a string literal, so those numbers cannot
be computed.

## Notes on the source

- **Colour is meaning.** A join status keeps one colour in every scene: blue `equal`, green
  `credited`, grey `inapplicable`, amber for nothing observed (`skipped`, `missing`), red for
  observed and wrong (`mismatch`, `failed`). Purple is the evaluator. Verdict values such as
  `refused` are data and stay uncoloured: 360 rows expect a refusal.
- **The four hues were validated**, in the order they sit in a bar, against the film's
  background with the dataviz skill's `validate_palette.js` (`"#3987e5,#199e70,#c98500,#d03b3b"
  --mode dark --surface "#0f1115"`): all checks pass, worst adjacent pair 8.4 under simulated
  colour blindness and 16.9 under normal vision. The grey is neutral on purpose and outside that
  check.
- **No count is carried by colour alone.** Every bar has its counts in words beside it, each next
  to its colour, and all bars share one scale of 621 rows.
- **Layout was checked by eye** on contact sheets of two drafts and on full-size frames of the
  final render. The tool's lint does not judge balance or crowding.
