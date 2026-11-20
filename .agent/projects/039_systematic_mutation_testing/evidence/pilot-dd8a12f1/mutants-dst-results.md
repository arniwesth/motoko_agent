# F2 results: the eight mutants at F1's reached sites, under a full `make dst`

Run on 2026-11-19, 18:52 to 20:25 UTC, by `mutants-dst-plan.md` and nothing else. Eight sweeps,
one drawn mutant each, in the scratch worktree at `dd8a12f1`. Every sweep restored the tree to
`base.sha256` (`sequence.log`, 20:25:07Z). Ordinary reading: `mutants-dst-scores.txt`
(`score_dst.py`, fixed before F2). Failing rows absent from C-base, by target:
`mutants-dst-new-rows.txt` (`scripts/new_rows_dst.py`, a reading aid written after the sweeps).
Raw output: `runs/dst/<mutant>/`.

## Result

**6 of the 8 are killed, under both readings.** m02 and m03 survive: `make dst` runs their lines
and no target goes red.

| mutant | the edit | predicted | ordinary reading: newly red | rule reading: the check about the broken behaviour |
|---|---|---|---|---|
| m02 | the intercept arm journals its messages with `replace = true` | not killed | none | **not killed** |
| m03 | `AllowAfterTimeout` means deny | killed, smoke_driver | none | **not killed** |
| m12 | the delegated tool's event is not emitted to the wire | killed, ledger_parity | ledger_parity | **killed**: `ledger_parity` `✗ DelegatedToolDeferred: projected 0, returned 1` |
| m13 | a policy-denied call's denial message is dropped | killed, smoke_driver or journal_resume | journal_resume, ledger_parity, phase_c_l1, world_framed_wire | **killed**: `journal_resume`'s fold refuses the journal, `refused: pairing` |
| m17 | the await-wake state keeps the pre-step world | killed, park_resume or herdr_graded | driver_plus_herdr, herdr_graded, park_resume, park_wake, world_framed_wire | **killed**: `world_framed_wire` `✗ frame parked: ordinal 15 repeated (stale-world re-request)`; `park_wake` `✗ stale world: world ordinals strictly +1 across both parks` |
| m19 | a policy-denied call's event is not emitted to the wire | killed, ledger_parity | ledger_parity | **killed**: `ledger_parity` `✗ NativeToolDenied: projected 1, returned 3` |
| m23 | a wake reply with `OperatorInput`, `HostError` or `Aborted` is dropped | killed, park_resume | park_resume, park_wake, terminal_trace, test_coverage | **killed**: `park_wake`'s `operator_input`, `host_error` and `abort` rows; `park_resume`'s `resume_aborted` and `resume_park_exit` rows |
| m30 | the wake match's `&&` becomes `\|\|` | killed, park_resume | park_resume, park_wake, terminal_trace, test_coverage | **killed**: `park_resume` `✗ resume_dropped: one ParkEntered … and NO WakeReceived`; `park_wake`'s `wrong_handle` rows |

**Predictions: 7 of 8 kill-or-survive calls held.** m03 was predicted killed and survived. Of the
six named targets, five were right (m12, m19, m13's journal_resume, m23, m30). For m17 I named
park_resume or herdr_graded. Both went red, but the rows that name a stale world are in
`world_framed_wire` and `park_wake`.

## Reading the reds

- **m13.** `journal.ail:623` defines the fold's `pairing` refusal: "the message contributed by
  entry N breaks tool-call pairing — … an assistant whose calls are left unanswered". Dropping the
  denial message leaves exactly that, so this is the kill. The other reds are recorded, not counted.
  `phase_c_l1`'s `step_budget_suspends_with_history` and `journal_resume`'s first row pin the
  history at 8 messages and see 5. `ledger_parity`'s and `world_framed_wire`'s census row
  `order: CostExhausted is appended BEFORE the RunSummary` fails downstream. The run is shorter, and
  `ledger_parity` prints only its `✗` rows, so why that row fails is not shown. `ledger_parity`'s own
  wire-against-trace counts stay green: `NativeToolDenied: projected 3, returned 3`, as on base.
  The denied event is still emitted.
- **m17.** The two stale-world rows are the kill. herdr_graded and driver_plus_herdr fail "the
  DISCOVERY instrument grades the run clean in both directions — 1 finding(s)". Their gate line reads
  "the call sequence desynchronised or an effect reached the live world"; the finding itself is not
  printed.
  park_resume's `resume_after_wake` and several park_wake outcome and metric rows also fail. All of
  these follow from the same stale world; none is counted separately.
- **m23, m30.** Each fails rows that name the wake outcome or the mismatched reply the edit
  mishandles. Each also fails `test_coverage`, which reports only `src/core/session.ail: 45/46
  passed`. By reading, the failing test is the one inline test of `wake_matches`,
  `test_wake_matches_request_id_always_and_wait_id_only_where_named` (`session.ail:5680`), whose
  asserts cover both edits. The output does not name it.

## The two survivors

- **m03: reached, and different only where no run goes.** `default_allow` decides an approval only
  when the approval read hits EOF, or the reply is unparseable or an unknown command
  (`resolve_approval`, `tool_phase.ail:98`). `smoke_driver` and `smoke_parity` compute it, so the
  request carries `default_allow=false` and the `approval_read` witness says so (`ports.ail:2165`).
  No outcome differs, so no run that reaches the line resolves that approval by EOF or an
  unparseable reply. The fault catalogue already records the gap. Its `approval_deadline_exceeded`
  class (`dst_fault_catalogue.ail:467`) applies only when `default_allow` is false: "with
  default_allow true the same input resolves to ApprovalAllowed and the class is not exercised".
  Which runs answer the approval, and how, is my reading of the source, not a run that tells the
  two apart.
- **m02: reached, and the difference is in a record no reaching run folds.** The edit flips the
  `replace` flag on the intercept arm's `history_appended` record. Its twin one function over (m22)
  was killed by `corpus_judge`'s `journal-fold-disagrees`. Five targets run the intercept arm
  (discovery, driver_plus_compose, smoke_driver, smoke_parity, strict_replay; F1), and none of them
  goes red. `journal_resume` folds a journal, but F1's probe left it green, so it does not run the
  arm. Whether the five never fold that run's journal, or fold it without comparing it with the
  history as `corpus_judge`'s rule does, was not checked.

## What it changes

Across the suite, 20 of the 30 drawn mutants are now killed by a named check: the pilot's 14 and
these 6. The other 10:

| | mutants |
|---|---|
| reached by `make dst`, killed by no check | **m02, m03** (F2), **m11** (the pilot's oracle gap) |
| reached by a bank member, judged equivalent on walked paths | m05, m18 |
| reached by no `make dst` target | m15 (ADR-003 D6's "a tool an extension handles") |
| judged dead code, and reached by nothing | m08, m26 |
| reached only by a `corpus_judge` control, not run under `make dst` | m09, m14 |

The pilot's verdicts are unchanged: they are defined on reach by a `corpus_judge` bank member, and
F2 adds a column beside them.

## Not verified

- Why `ledger_parity`'s `order` row fails under m13. Its program's other output is deleted, and no
  extra run was made to read it: m13's kill does not rest on it.
- Which inline test `test_coverage` caught under m23 and m30. See above.
- m09 and m14 were not run under `make dst`. F1 did not probe them, because `corpus_judge`'s
  controls already reach them, and F2 ran only F1's reached sites.
- One sweep per mutant, under shared load (wall times 321 s to 945 s). No sweep was INCOMPLETE.
