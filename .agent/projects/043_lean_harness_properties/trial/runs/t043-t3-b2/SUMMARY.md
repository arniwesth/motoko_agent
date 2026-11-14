# T3: the journal writer twin and the round trip (summary)

Target: `SessionJournal` (`src/tui/src/session-journal.ts:139`), the host's writer, and
`journal_lines_of_records` (`src/core/journal.ail:2137`), its AILANG twin, both judged by
`fold_journal` (`:1677`). ADR-003 D1, D4. Method: Kiro's, as RESEARCH §1 describes it. The
model is Lean 4.28.0, core only. It was differential-tested against the real code (bun 1.4.4,
ailang v0.54.14). Then came the proofs and `bug_` theorems, and every counterexample was
reproduced on the real, unmodified code.

## Results

| | |
|---|---|
| Findings (reports.tsv) | **6**: 2 on P3.1 from one host defect (B2-T3-3, -4), 2 from one twin defect (B2-T3-1 on P3.1, B2-T3-2 on P3.2), 1 on P3.2 that is a documented limitation (B2-T3-5), and 1 exploratory finding (B2-T3-6, X-1) |
| Reproduced on the real code | all 6. Each `repro` exits 1 now. The four with a one-line fix exit 0 against a patched temporary copy (`repro/logs/summary.txt`) |
| Proved for every length | P3.1 on runs with no resume (`p31_without_resume`), and P3.2's rule 3 on append-only runs (`p32_rule3_append_only`) |
| Lean theorems | 27, all checked. Axioms: `propext` only, one theorem with none. No `sorry`, `native_decide` or `Classical.choice` (`axioms.txt`) |
| Differential test | 7,381 runs, three comparisons each. Model vs real code: **0 mismatches** |
| **Times step (2) changed the model** | **0**: no mismatch ever sent the model back. The other changes are listed in `diff/MODEL_FIXES.md`: 1 generator revision, 1 spec revision, 1 model extension that matched on its first run, 4 non-semantic fixes |

## The properties as checked

- **P3.1** (registered). For a sequence of wire events, the host's journal and the twin's journal
  fold alike: the same refusal id, or both accepted with equal `history` and `dangling`. The
  host is the real `SessionJournal.record`, called once per event in order after `writeHeader`.
  It is checked twice: in **one process**, and **across processes**, where a new
  `SessionJournal` adopts the file before each `session_resumed`. The second is what a
  `--resume` after a kill -9 or a quit looks like.
- **P3.2** (registered). The twin's journal of a run's records is accepted, and its `history`
  is rule 3's history. It is checked **after rule 4**. Rule 4 strips the trailing dangling
  calls from `history` by design (`finish_fold`, `journal.ail:1722-1724`), so "rule 3's
  history" is compared with the fold's history *with rule 4's strip applied*, and `dangling`
  with the calls rule 4 reports. Read literally, without the strip, P3.2 fails on every run
  that ends with an open call. That is a gap in how the property is stated, not a code defect,
  and it is not reported.
- **X-1** (exploratory). P3.1's comparison on a wire sequence the wire *type* admits but no run
  emits at HEAD: `history_replaced.first_kept = Some(k)`.

"A run can emit" is made concrete as the model's `validRun`. The child (`Child.step`) emits its
events the way `session.ail` does: seed; appends chained from `c2_chain_step`; the hybrid
replacement chained from `prev` (`c2_append_step`); a checkpoint re-based to
`digest_messages(prefix ++ summary)`; a resume (`SessionResumed`, then a seed of the stripped
history, `session.ail:4805-4810`); and a follow-up turn (the operator's message, then the seed,
`session.ail:4387-4393`). A sequence is valid when every prefix's history passes the fold's
pairing, a result answers an open call, the hybrid replacement directly follows the plain
assistant, and a checkpoint or a follow-up turn happens with no call open. A crash is the
moment before a resume, and it may leave a call open.

## What I proved

All in `JournalTwinModel.lean`, every theorem printed in `axioms.txt`.

- **`host_twin_same_journal_without_resume` / `p31_without_resume` (P3.1, every length).** Take
  a run that starts with a well-formed seed and then emits any number of `history_seeded`,
  `history_appended` (with or without `replaces_previous`, any digests) and `history_replaced`
  with `first_kept = None`. The host and the twin write *the same journal* for it, so the two
  journals fold alike. Both excluded event kinds are needed, and the findings show why:
  `session_resumed` (B2-T3-1, -3, -4) and `first_kept` (B2-T3-6). The witness
  `p31_without_resume_witness` is a valid run with a hybrid replacement and a checkpoint.
- **`p32_rule3_append_only` (P3.2's rule 3, every length).** Take a seed `s` and appends `ms`
  chained as the child chains them. The twin's journal passes every digest check, and the
  history the fold hands to rules 3b/4 is exactly `s ++ ms`, with
  `foldJournal = finishFold` of that accumulator. The witness is enumeration run `1,2,0,3`.
- **Fixes (step 8), on the counterexamples.** `fix_twin_closes_checkpoint_then_resume` and
  `fix_host_closes_hybrid` (by `decide`). A bounded check in `enumerate.lean.tail` is a
  computation, not a proof. With both fixes, **0** of the 2,313 valid runs violate P3.1 (in one
  process or across processes), and the only P3.2 violations left are the 173 of B2-T3-5.

## What I could not prove

- **P3.1 in general.** It is false (B2-T3-1, -3, -4). With both fixes I have the bounded check
  above, up to length 4 in this alphabet, and no proof. A proof would need the host's
  `openCallIds` to equal the fold's dangling set at every resume. That is the
  `host_twin_agrees` theorem of `PairingModel.lean`, under its (H1)/(H2). Its hybrid case
  (`replaces_previous`) is exactly where the host is wrong (B2-T3-3). I did not lift it to this
  model.
- **P3.2 beyond append-only runs.** P3.2 is false with checkpoints, through B2-T3-2 (fixable)
  and B2-T3-5 (documented). For checkpoints alone, and for the hybrid replacement, there is only
  the bounded check: 0 violations within one run.
- Nothing about entries that do not carry history (`state_delta`, `run_finished`, `settings`,
  `park`, `wake`). P3.1 and P3.2 compare only verdict, `history` and `dangling`. See the
  observations below.

## Findings

| id | prop | root cause | where it shows | reachable at HEAD? |
|---|---|---|---|---|
| B2-T3-1 | P3.1 | the twin's `HistoryReplaced` arm never sets `replaced_since_seed` | checkpoint, then same-profile resume, then append: the host folds, the twin is refused `digest` | yes: the checkpoint and the resume are both live paths, and the host's arming for this case came from P3 Part 5's kill -9 gate |
| B2-T3-2 | P3.2 | same as B2-T3-1 | same | yes |
| B2-T3-3 | P3.1 | `replaceLastHistoryMessage` never calls `updatePending` | hybrid replacement, crash, resume: `dangling [c1]` (host) vs `[]` (twin), and `exit.pending_tool_calls` is wrong | only through journals recorded before 005 W3, because every `pending_tool_batched` is `true` at HEAD |
| B2-T3-4 | P3.1 | same, through `adopt()` | the same plus one append: the adopted host's journal is refused `digest`, the twin's folds | same as B2-T3-3. This is the `--resume` path of such a journal |
| B2-T3-5 | P3.2 | the conversation loop chains a follow-up turn from the empty base, but a checkpoint re-based the journal's chain | checkpoint, then the next turn: both writers' journals are refused `digest` (P3.1 holds) | yes, and **documented** as a known, fail-closed limitation (`session.ail:4372-4386`) |
| B2-T3-6 | X-1 | the host bounds `first_kept` by a count that leaves out the head system prefix after a checkpoint, then writes the entry anyway | the host's fold silently drops the tail the twin keeps | no: `first_kept` is always `None` at HEAD |

Shares of the violations among the 2,313 valid runs, attributed through the fixed models (the
model and the real code agree on every one of these runs). P3.1, one process: 76 = 65 from the
twin defect + 11 from the host defect. Across processes: 75. The difference is `7,0,4,6`: after
a profile switch, `adopt()` sets `replacedSinceSeed` for an arm-2 entry, which the live host
does not, and that arms the resume anyway, which hides the host defect there. P3.2: 238 = 65
from the twin defect + 173 from B2-T3-5.

## Differential test (step 2)

`diff/run_diff.sh` runs every action sequence of length 0 to 4 over nine child actions: 7,381
runs, of which 2,313 are valid. It compares four halves:

| half | what runs |
|---|---|
| Lean | the model: host, twin and host across processes, folded; validity; spec |
| AILANG (`gen_events.ail`) | the child's wire events, with digests from the **real** `chain_digest_after` / `chain_digest_base` / `chain_digests_over`; the **real** `journal_lines_of_records`, folded by the **real** `fold_journal` |
| bun (`host.ts`) | the **real** `SessionJournal`, in one process and across processes |
| AILANG (`fold_host.ail`) | the **real** `fold_journal` over the host's journal files |

Results:

| run | result |
|---|---|
| `diff/run_diff.sh`, final run, 2026-11-04 22:40Z, 4 min 41 s | **0 mismatches** between the model and the real code, over 7,381 runs × 3 comparisons (host, twin, host across processes). Exit 0. `real.out` sha256 `fbb1b67794836e96…`. An earlier full run, before the last harness fixes, gave the same counts. On the 2,313 valid runs, on the **real code**: P3.1 fails on **76** (75 across processes), and P3.2 on **238** (host against the spec: 184) |
| `T3_FIX=both diff/run_diff.sh`, the negative control, 3 min 39 s | The real side is patched with both one-line fixes (temporary copies) and the model is not. Result: **416 mismatches**, exactly the number the model predicts (`diff/negctl_expect.lean.tail`: host 152, twin 116, across 148). Exit 1, as required. On the patched real code, P3.1 fails on **0** of 2,313 (0 across processes) and P3.2 on 173, all of them B2-T3-5. So the fixes are checked on the real code over the whole enumeration, not only on the counterexamples |
| `repro/run_all.sh` (`repro/logs/summary.txt`) | all 7 unpatched runs exit 1 (B2-T3-1 to -6, with B2-T3-3 also run as `0,4,6,0` across processes for -4). The 4 runs against a one-line fix exit 0. B2-T3-5 still exits 1 with both fixes. 21 to 56 s each |

The real outputs also agree with what `p31_without_resume` proves. Across all 7,381 runs,
valid or not, the real host and the real twin fold differently on 271 runs, and every one of
them contains a resume (action 6 or 7).

## Observations not reported

Found by reading, not reproduced, and outside P3.1/P3.2's fields or unreachable.

- The twin writes a `settings` entry when `profile_to == ""` and `profile_from != ""`. The host
  requires `profileTo !== ""` (`session-journal.ts:793` vs `journal.ail:2085-2086`). That
  changes the folded `profile`, not `history`.
- The twin writes `run_started` for a `SessionStart` with an empty `run_id`. The host skips it
  (`session-journal.ts:510`). That affects the boundary only, and a run's trace starts with
  a `SessionStart` that names its run.
- `run_finished.run_id`: the host notes the run id from *every* event (`noteRunId`), the twin
  only from some arms (a dropped seed does not update it). That affects
  `BoundarySuspended`/`RunFinished` matching only.
- Arm 1 with `digests.length != messages.length`: the host sets `seeded`, writes nothing and
  marks the session unresumable. The twin recomputes the digests and writes the seed. A
  well-formed child cannot emit this.
- `adopt()` sets `replacedSinceSeed = true` for *every* `history_replaced`, including arm-2
  entries the live host wrote with it reset. The only effect seen is the masking above. Every
  extra arming it causes folds alike.
- A `history_appended` *before* the first seed (the operator's message on the empty-task path)
  makes the twin expand the seed from the wrong base and duplicate the message, while the host
  copies the child's digests. The live launcher cannot reach it: `rpc.run_with_config` waits for
  a first task (`session.ail:4661-4666`).
- The (H1)/(H2) shapes, an empty call id and a tool message with calls, are known from
  RESEARCH §6. They would also split the host's `openCallIds` from the fold's dangling set at a
  resume. They are not in this alphabet.
- `chain_digests_over(base, ms)` ignores `base` (`journal.ail:292-294`). Every caller passes the
  empty base.

## Limits

- **Symbolic digests.** The model treats sha256 as collision-free and keeps
  `chain_digest_base` and `chain_digest_after` apart. Envelopes (`id`, `parent_id`, `seq`,
  `at_ms`) are abstracted to a position. Entries that do not carry history are not modelled.
  The real halves exercise all of these, and the model still matched.
- **Bounded inputs.** One call id (`c1`), nine actions, up to length 4. The proofs cover every
  length only on their fragments.
- **I chose the inputs.** The event generator exists twice, in Lean and in AILANG, and is
  mine. Validity ("a run can emit") is my reading of `session.ail`. The same goes for the
  claim that a crash-resume reaches a fresh `SessionJournal` before `session_resumed`.
- **Reachability is by reading** (Kiro steps 6 and 7). No live session was run.
- **The tree.** The real code was executed only for steps (2) and (4). AILANG resolves package
  imports only inside the tree, so `run_diff.sh` and `case.sh` copy their `.ail` files into a
  temporary `t3tmp_*` directory there, and remove it on exit. Patched copies used for the
  negative controls live there or in `out/`, never over a tree file. The tree is otherwise
  untouched, and `git` was not run.

## Files

| file | what |
|---|---|
| `JournalTwinModel.lean` | the model (header: source files and lines), the `bug_` theorems, the proofs, the fixes, the X-1 case, `#print axioms` for all 27 theorems |
| `axioms.txt` | the axiom report: `lean JournalTwinModel.lean` output, with the Lean version and the file's sha256 |
| `reports.tsv` | the six findings |
| `diff/run_diff.sh` | the differential test (`T3_FIX=twin\|host\|both` for the negative control) |
| `diff/enumerate.lean.tail`, `diff/gen_events.ail`, `diff/host.ts`, `diff/fold_host.ail`, `diff/compare.awk` | its halves |
| `diff/MODEL_FIXES.md` | the step-2 ledger |
| `diff/work/`, `diff/work_negctl/` | outputs of the final run and of the negative control (`lean.out`, `real.out`, `run.log`). The large intermediates were deleted and can be regenerated |
| `diff/negctl_expect.lean.tail` | the model's prediction for the negative control (416 mismatches) |
| `repro/case.sh` | reproduces one counterexample on the real code. Run from the tree root. `T3_FIX=twin\|host\|both` runs it against a patched copy |
| `repro/run_all.sh`, `repro/logs/` | every repro, unpatched and patched, with logs |
