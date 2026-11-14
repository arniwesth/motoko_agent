# Step 2 ledger: every change to the model, the generator and the harness

The rule (RESEARCH §1, step 3): a mismatch between the model and the real code sends the model
back to step 2, and each such fix is counted. This file lists every change made after the
model first compiled, which ones the differential test forced, and which it did not.

## Model fixes forced by the differential test: **0**

The first comparison (820 sequences, lengths 0-3, before the full run) already gave 0 mismatches
between the model and the real code, for both the host and the twin. The full run (7,381
sequences, three comparisons each: host, twin, host across processes) also gave 0. No model
definition of `SessionJournal`, `journal_lines_of_records` or `fold_journal` was changed because
of a mismatch.

Zero can also mean the test is blind, so it was checked from the real side. Two one-line
patches to temporary copies of the real code (never the tree) changed the outcome exactly where
the model predicts, in `repro/` and in `run_diff.sh`'s negative control (`T3_FIX`, results in
SUMMARY.md).

## Changes that were not model fixes

| # | When | What changed | Why | Forced by a mismatch? |
|---|---|---|---|---|
| 1 | before any run | `Child.cur` instead of `Child.at`, which is a Lean keyword. A `sed` pass also turned `Nat :=` into `Ncur :=`, caught by the compiler and reverted | does not compile | no (compile error) |
| 2 | after the 820-sequence probe | generator action 8: from "a follow-up seed" to the real follow-up-turn emit, which is the operator's message chained from `c2_seed_digest(turn_history)` and then the seed (`session.ail:4387-4393`). Changed in `JournalTwinModel.lean` (`Child.step`) and in `gen_events.ail` together | fidelity of the INPUTS to what a run emits, found by reading `session.ail` | no (0 mismatches before and after) |
| 3 | same time | validity: a hybrid replacement (action 4) counts as a run's only when it directly follows action 0, the plain assistant journaled at extraction. It was "the last message is the plain assistant" | `0,7,4` (a replacement right after a resume seed) was being counted as a run's | no (the spec, not the model of the code) |
| 4 | same time | **model addition**: `Host.adopt` / `hostJournalAcross`, the host as a NEW process (`adopt()`, `session-journal.ts:288-333`) at each `session_resumed` | a crash resume in production goes through `adopt` | no (new behaviour modelled, matched on the first run) |
| 5 | full run | harness: `fold_host.ail` used a hand-written recursive filter that hit AILANG's 10,000-frame recursion limit on 14,762 journals. Replaced with `std/list.filter` | harness crash | no |
| 6 | repros | harness: the patched twin is imported from a temporary module path. A path starting with `.` (`.t3tmp…`) is a parse error (IMP012), so `case.sh` and `run_diff.sh` now use `t3tmp_XXXXXX` | harness crash | no |
| 7 | final run | harness: `run_diff.sh work` passed a RELATIVE work dir to `fold_host.ail`, which runs from the tree root (`readFile: open work/host.txt: no such file`). The work dir is now made absolute | harness crash | no |

## Count for SUMMARY.md

**Step 2 changed the model 0 times.** One generator revision (2), one spec revision (3), one
model extension that matched on its first run (4), and four non-semantic fixes (1, 5, 6, 7).
