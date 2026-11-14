# T0 dry run — P0.1 (`pair_step`/`finish_fold` vs `updatePending`)

Method: executed differential checks on the real code only. No models.

## Harness
- `harness/p01_diff.ts` (bun). Host twin: the real `SessionJournal`, driven through its private
  `recordAppended` (→ `noteHistoryMessage` / `replaceLastHistoryMessage` → `updatePending`) and
  `recordReplaced`, reached by a cast; the value compared is `pendingToolCalls`, which is what
  `writeExit` copies into `exit.pending_tool_calls`. Fold twin: the real `fold_journal`
  (→ `pair_step`, `finish_fold`, `strip_dangling`) via `harness/fold_template.ail`, which the TS
  instantiates with the cases and runs with `ailang run --relax-modules`. Journals are built with
  journal.ail's own writer twin `journal_lines_of_records`, as in `evidence/diff/enumerate_fold.ail`.
  The generated module is written to `<tree>/.p01tmp/` (pkg imports only resolve inside the tree)
  and that directory is deleted after every run.
- Ops: `i<100` append ALPHABET[i]; `100+i` append with `replaces_previous`; `200+i`
  `history_replaced(resume)` of seed++[ALPHABET[i]]; `300+k` resume of seed++RESUME_SET[k].
  ALPHABET (all inside P0.1's hypotheses — no empty id, no tool message with calls):
  asst[], asst[a], asst[a,b], asst[b], tool a, tool b, user, asst with tool_call_id a,
  user[a], asst[a,a].
- Executable properties (on every case the fold accepts):
  - **P0.1**: host pending == `SessionState.dangling` (as ordered lists).
  - **X-1** (exploratory): the folded `SessionState.history` is well paired — every tool message's
    `tool_call_id` is among the `tool_calls` of the nearest preceding message that has calls.

## Runs (logs in `harness/run_*.log`)
| generator | size | cases | result |
|---|---|---|---|
| exhaustive, append-only ops 0–9 | length ≤ 3 | 1,111 | 0 P0.1, 0 X-1 violations |
| exhaustive, all 25 ops (append, replace-previous, 201,202,300–302) | length ≤ 2 | 651 | 156 P0.1, 52 X-1 violations |
| exhaustive, append + replace-previous (20 ops) | length ≤ 3 | 8,421 | NOT COMPLETED: the run exited 3 (harness error, not a result), most likely because a concurrent run deleted the shared `.p01tmp/` |

## Findings (reports.tsv)
- **A1-T0-1 (P0.1)**: `replaceLastHistoryMessage` applies `updatePending` to the replacement
  without undoing the replaced message; the fold drops the replaced message. Witness `1,100`.
- **A1-T0-2 (P0.1)**: `history_replaced` resets the host's open set to `[]` without scanning the
  replacement messages; the fold pairs them and can report trailing calls dangling. Witness `201`.
  The host side is `recordReplaced`, not `updatePending`; reachability uncertain (see notes).
- **A1-T0-3 (X-1)**: `strip_dangling` keys on `seq`, and all messages of one `history_replaced`
  share a seq, so a reused dangling id is stripped from an earlier, answered assistant too, leaving
  an orphan tool result the transcript check passes. Witness `300`.

Not reported (known and documented in `PairingModel.lean` as `admits_duplicate_result` /
`admits_result_after_user`): `pair_step` checks `cur_ids`, not `open_ids`, so a second result for
an answered call, or a result after a user message, is accepted. Both twins agree on those.
Append-only histories within the hypotheses showed no P0.1 disagreement up to length 3.

Caveat: concurrent runs share `<tree>/.p01tmp/` and each deletes it on exit; run the harness one at a time (the length-3 append+replace run was started alongside others and failed with exit 3 for that reason; it was not rerun).
