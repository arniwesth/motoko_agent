# F3 results: m09 and m14 under a full `make dst`

Run on 2026-11-20, 07:40 to 08:08 UTC, by `mutants-dst-f3-plan.md` and nothing else. Two sweeps, one
drawn mutant each, in a scratch worktree recreated at `dd8a12f1`. Both sweeps restored the tree to
`base.sha256` (`sequence.log`, 08:07:46Z). Ordinary reading: `mutants-dst-f3-scores.txt`
(`score_dst.py`, unchanged). Failing rows absent from C-base, by target:
`mutants-dst-f3-new-rows.txt` (`scripts/new_rows_dst.py`, F2's reading aid, unchanged). Raw output:
`runs/dst/m09/`, `runs/dst/m14/`.

## Result

**Both are killed, under both readings**, and both predictions held, including the check named.

| mutant | the edit | predicted | ordinary reading: newly red | rule reading: the check about the broken behaviour |
|---|---|---|---|---|
| m09 | `tool_arguments_invalid` not emitted to the wire; the returned trace keeps it | killed, ledger_parity | ledger_parity | **killed**: `ledger_parity` `✗ ToolArgumentsInvalid: projected 0, returned 1` |
| m14 | an injected user message is journaled but not added to the history | killed, corpus_judge | corpus_judge, phase_c_l1 | **killed**: `corpus_judge` `CONTROL solver-feedback journal-fold-disagrees RED` |

## Reading the reds

- **m09.** `ledger_parity_dst.ail`'s subject 10, "invalid", compares the wire's count of each
  event with the returned trace's. On base the row reads `✓ ToolArgumentsInvalid: projected 1,
  returned 1`. The mutant removes the wire emission and keeps the trace record, and the row fails.
  That is 009 ADR-001 D6.4's parity, the rule the edit breaks. Nothing else goes red. `corpus_judge`'s
  `invalid-request` control, which reaches the line, stays green here as at tier 1: it reads only the
  trace.
- **m14.** `corpus_judge`'s `solver-feedback` control goes red on `journal-fold-disagrees` ("a fold
  of the run's journal-class records disagrees with what the run ended holding at 'history'"), and
  on the invariant set's summary row, which counts that one finding. Its prose check `✗ solver
  feedback: no finding from the set, none from the six checks` fails with it. That is ADR-003 D4,
  the rule the edit breaks, and the plan counts a CONTROL row red on it at the suite level. The JUDGE
  rows stay green (`red_judge=0`), as at tier 1: no bank member injects a message.
- **m14, recorded and not counted.** `phase_c_l1`'s `phase_c2_wiring_scenarios` fails 2 of 20:
  `empty_stop_guard_budget_exhaustion_floors` and `progress_contract_budget_exhaustion_finalizes`.
  Each pins the exact decision sequence of a guard that injects a user message. Under the mutant the
  run makes one more `InjectUserMessage, CallModel` round before `Finalize` (`actual=CallModel,
  InjectUserMessage, CallModel, InjectUserMessage, CallModel, InjectUserMessage, CallModel, Finalize`
  against two rounds expected). The pin sees a consequence of the missing message, not the message
  missing from the history or the journal disagreeing, so by the plan's rule it is recorded and not
  counted. Why one more round follows was not traced.

## What it changes

With F3, every drawn mutant that any `make dst` run reaches has run under a full `make dst` (or was
killed at tier 1 or 3 by a target `make dst` runs). Across the suite, **22 of the 30** are killed by
a check about the broken behaviour: the pilot's 14, F2's 6 and these 2. The other 8:

| | mutants |
|---|---|
| run, and no check names it | m02, m03, m11 |
| run, judged equivalent on walked paths | m05, m18 |
| run by no `make dst` target | m15 |
| judged dead code, and run by nothing | m08, m26 |

The pilot's verdicts are unchanged: m09 and m14 stay "not killed: no member reaches it" under
`corpus_judge`'s tier-1 rule, which counts JUDGE rows only.

## Not verified

- Why m14 adds a third inject-and-call round in `phase_c_l1`'s two scenarios. It does not bear on
  the kill.
- One sweep per mutant, under shared load (wall times 816 s and 806 s; the first sweep in the
  recreated scratch started without `.ailang/` caches). No sweep was INCOMPLETE.
