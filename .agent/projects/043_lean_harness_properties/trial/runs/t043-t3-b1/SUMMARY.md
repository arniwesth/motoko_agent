# T3: the journal writer twin and the round trip (Kiro's method)

Target: `SessionJournal` (`src/tui/src/session-journal.ts:139`) and `journal_lines_of_records`
(`src/core/journal.ail:2137`), judged by `fold_journal` (`journal.ail:1677`). Properties:
P3.1 (host and twin journals fold alike) and P3.2 (the twin's round trip is accepted, and its
history is the one rule 3 defines). Toolchains: Lean 4.28.0 (core only, no Mathlib, no Lake),
ailang v0.54.14, bun. Nothing in the tree was modified, and no `git` was run.

## Results

| | |
|---|---|
| Lean theorems | 38. None uses `sorry` or `native_decide`. Every one is printed with `#print axioms` (`axioms.txt`), and none depends on anything beyond `propext` and `Quot.sound`. |
| Proved | P3.1 on the fragment without `session_resumed` and `first_kept`. P3.2 for every single run, with acceptance reduced to the run's own history passing the fold's final checks. Details below. |
| Falsified, with a `bug_` theorem and a reproduction on the real code | P3.1: 5 reports (B1-T3-1, -3, -5, -6, -9). P3.2: 2 reports (B1-T3-2, -7). |
| Other defects | X-1, the torn-tail adopt (B1-T3-8). X-2, the host's `exit.pending_tool_calls` (B1-T3-4). |
| Model changes in step (2) | **0.** The model agreed with the real code on the first differential run, and on every run after it. See "Step (2)" below. |

`reports.tsv` has the 9 reports. Each repro is one command, run from the tree root. It exits 1
when the defect is present and 0 when it is absent. All 9 exit 1 at this snapshot and take 0.6
to 2.2 s once ailang's module cache is warm. The first, cold run of a script took 58 s.

## Exploratory properties

- **X-1.** A journal that the host adopts after a crash stays readable: what `adopt()` claims
  in `session-journal.ts:302-306`.
- **X-2.** The host's `exit.pending_tool_calls` equals the `dangling` that `fold_journal` reports
  for the same journal. This is the "three-line TypeScript twin of the fold's trailing-pair
  rule" (`session-journal.ts:162-168`).

## What was proved (`T3Model.lean`)

- **`host_twin_same_lines` / `p31_fragment`** (P3.1, for every length). Take any event sequence
  that:
  - opens with a seed carrying the child's chain digests (`session.ail:3871`),
  - contains no `session_resumed`,
  - and has no `first_kept` (HEAD's only checkpoint shape).

  On every such sequence the host and the twin write identical history entries, so their
  journals fold alike. Arbitrary later seeds (follow-up runs), appends (with or without
  `replaces_previous`) and checkpoints are all covered.
- **`p32_single_run`** (P3.2, for every single run). A run here is any sequence of appends,
  hybrid replacements and checkpoints after the seed, with the child's own digests. For every
  such run:
  - the fold of the twin's journal never refuses at rule 3 (no `digest` refusal),
  - its rule-3 accumulator is exactly `rule3` (rule 3 written over the records),
  - and the fold's result is `finish_fold` of that history.

  So a refusal can only come from the run's own history failing pairing, head-prefix or
  transcript.
- **`p32_single_run_history`.** When that fold accepts with no dangling call, its history is
  `rule3` of the records. That is P3.2's history clause.
- **Vacuity.** `witness_p31_fragment` and `witness_p32_single_run` give a concrete input that
  satisfies every hypothesis, including an accepted run of 10 steps.

The proofs do not cover acceptance for every single run. That depends on the run's own pairing
and is checked only within bounds: all 335 runnable single-run sequences of lengths 4 to 6 in
the differential were accepted by the real fold.

## What could not be proved, because it is false

| Report | Property | Root cause | Lean |
|---|---|---|---|
| B1-T3-1, B1-T3-2 | P3.1, P3.2 | The twin never sets `replaced_since_seed` (`journal.ail:2045-2053`). After a checkpoint, a same-prompt crash resume is not journaled as a replacement, and the resumed run's first append is refused with `digest`. Shown through the real `plan_resume`. | `bug_twin_forgets_checkpoint_at_resume`, `bug_twin_round_trip_refuses_checkpoint_resume`. Fix: `fix_twin_closes_checkpoint_resume`. |
| B1-T3-3, B1-T3-4 | P3.1, X-2 | The host's `replaceLastHistoryMessage` ignores its message (`session-journal.ts:854`). A hybrid replacement's calls never become pending. | `bug_host_hybrid_crash_resume`, `bug_host_pending_misses_hybrid_calls`. Fix: `fix_host_closes_hybrid_crash_resume`. |
| B1-T3-5 | P3.1 | The host's `first_kept` range check counts too few messages after a checkpoint, so it drops an in-range `first_kept` and writes the entry anyway. | `bug_host_drops_in_range_first_kept` |
| B1-T3-6 | P3.1 | An empty call id (RESEARCH §6.2's H1) makes the host and the twin arm differently at a resume, so `dangling` differs. | `bug_empty_call_id_dangling_differs` |
| B1-T3-7 | P3.2 | A follow-up run after a checkpoint: both journals are refused. This is documented as a known limitation at `session-journal.ts:646-655`. | `bug_followup_after_checkpoint` |
| B1-T3-9 | P3.1 | Message text that is not valid UTF-8: the child hashes raw bytes and its wire encoding substitutes U+FFFD, so the host's journal is refused and the twin's is accepted. | `bug_wire_replacement_breaks_host_chain`, over a model extension added after the probe found it |

Reachability:
- **B1-T3-1** reaches every checkpointed session that later crashes and resumes, and every
  multi-frame trace fed to the twin (the resume script, `test_crash_resume_replacement_folds`).
- **B1-T3-3** reaches journals written before hybrid mode was removed, including through
  `adopt()`. No new run is shown to emit the shape.
- **B1-T3-5** is latent: `first_kept` is always `None` at HEAD.
- **B1-T3-6** and **B1-T3-9** are not shown reachable.

B1-T3-1 and B1-T3-3 look like deliberately removed lines. In the twin, the field is declared,
documented, reset and read, but never set. In the host, the function takes a `message` and
never uses it.

## Step (2): the differential test (`diff/`)

`gen.ail` is a child simulator. It produces the journal-class wire events that a run, or a
session of several runs, emits, with the child's real digests. Its 13 steps are: append one of
several messages, a hybrid replacement, a checkpoint, a crash resume, a profile-switch resume, a
follow-up run, a checkpoint with `first_kept`, and a call with an empty id. The same simulator
is written in Lean, and `eventsOf` in `T3Model.lean` is that copy.

Each sequence takes four paths:

| Path | What runs |
|---|---|
| Real twin | `journal_lines_of_records`, then `fold_journal` |
| Real host | the real `SessionJournal`, driven only through `writeHeader` and `record` (`host.ts`), then `fold_journal` (`foldhost.ail`) |
| Model twin | the Lean model's twin, then its fold |
| Model host | the Lean model's host, then its fold |

The comparison is on the verdict: the refusal id, or `history` and `dangling`.

| Run | Sequences | Model twin vs real twin | Model host vs real host |
|---|---|---|---|
| `run_diff.sh`: every sequence of length 0 to 3 over all 13 steps | 2,380 | 0 mismatches | 0 mismatches |
| `run_diff_runnable.sh`: every runnable sequence of length 4, plus 3,000 seeded runnable sequences of lengths 5 and 6 (`runnable.py`'s run grammar) | 8,213 | 0 mismatches | 0 mismatches |

**How many times step (2) changed the model: 0.** No run ever showed a mismatch. Two edits were
made that the differential did not drive:
- `dropHist` was rewritten with `List.drop`, so that the kernel can evaluate it. It is
  equivalent for every `n`.
- The simulator was moved from the enumeration tail into the model file, so that the theorems
  can name it.

Both runs above used the final model.

**Negative control** (`negative_control.sh`, on the model side so that the tree stays
untouched):
- Changing one rule in the model's twin (`twinLinesFix`) gives 14 mismatches with the real twin.
- Changing one rule in the model's host (`hostLinesFix`) gives 22 mismatches with the real host.

So the test can tell each writer from a writer that differs in one rule.

**P3.1 on the real code, by root cause.** Over the 8,213 runnable sequences, 666 fold
differently. Each one was attributed by re-running the model with each fix in turn
(`work/attrib.lean.tail`):

| Root cause | Sequences |
|---|---|
| B1-T3-1, twin checkpoint resume | 361 |
| B1-T3-5, `first_kept` | 227 |
| B1-T3-6, empty call id | 58 |
| B1-T3-3, host hybrid pending | 20 |

Nothing else differs. With both fixes applied, the model still differs on 39 of the 2,380
sequences: B1-T3-5, B1-T3-6, and non-runnable resumes of journals that were already refused.

**P3.2, the real twin's refusals** over the runnable sequences:

| Refusal | Root cause | Sequences |
|---|---|---|
| `digest` | B1-T3-1 | 361 |
| `digest` | B1-T3-7, follow-up after a checkpoint | 330 |
| `digest` | artefact of my step 11 (below) | 2 |
| `pairing` | artefact of my step 11 | 62 |

Step 11 is my checkpoint that keeps a tail of exactly one message. That can orphan a tool
result, and it is not a HEAD shape.

## Observations not filed as reports

- **P3.2's wording against rule 4.** For a run cut in the middle of a tool phase, the fold
  strips the trailing call (D4 rule 4), so the folded history is not rule 3's.
  `obs_rule4_strips_rule3_history` states this. It is by design, so I proved P3.2's history
  clause for runs with no dangling call. For the same reason, rule 3 here includes the head
  system prefix on a checkpoint, as `journal.ail:1266-1270` says, which P3.2's "That is"
  paraphrase leaves out.
- **A hybrid replacement directly after a seed or a replacement** is refused by both writers
  alike. The fold's `digest_prev` after a replacement is the pre-replacement digest, while the
  child's is the chain over `init(seed)`. It is unreachable: a replacement always follows the
  plain assistant of the same run.
- **The twin writes `run_started` for a `SessionStart` with an empty `run_id`.** The host does
  not (`session-journal.ts:509-510`). This is unreachable, because the only empty-id
  `session_start` is `rpc.ail:284`'s raw banner, which is not a `LedgerEvent`.
- **`chain_digests_over` ignores its `base` argument** (`journal.ail:292-294`). Every caller
  passes the empty base, so this cannot be observed.

## Files

| Path | What it is |
|---|---|
| `T3Model.lean` | The model (host, twin and fold, with a header naming the source lines), the child simulator, `rule3`, all 38 theorems and the axiom prints. Check it with `lean T3Model.lean` (about 25 s). |
| `axioms.txt` | The output of `lean T3Model.lean`: the axiom report, one line per theorem. |
| `diff/run_diff.sh` | The differential test, exhaustive to length 3. |
| `diff/run_diff_runnable.sh` | The differential test over runnable sequences. |
| `diff/negative_control.sh` | The negative control. |
| `diff/gen.ail`, `diff/host.ts`, `diff/foldhost.ail` | The real-code halves of the differential. |
| `diff/enumerate*.lean.tail` | The Lean halves of the differential. |
| `diff/runnable.py` | The run grammar. |
| `repro/*.sh` | The reproductions. `_env.sh` is shared by all of them. |
| `repro/checkpoint_resume.ail` | The B1-T3-1 reproduction through the real `plan_resume`. |
| `repro/unicode_probe.ail` | The probe for B1-T3-9. |
| `repro/foldfile.ail` | The real file reader plus the fold, for B1-T3-8. |
| `work/*.log` | Logs of the recorded runs. |
| `work/attrib*.lean.tail` | The root-cause attribution. |
| `src`, `packages`, `ailang.lock` (in `out/`), and `repro/mod/` | Symlinks back to the tree, so that ailang resolves `src/core/...` without writing into it. |
