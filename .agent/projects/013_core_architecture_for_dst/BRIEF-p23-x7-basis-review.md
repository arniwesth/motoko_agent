P2.3R BASIS REVIEW of X7 — adversarial, read-only. PLAN-004 v2, G1. This is NOT the round-4
verdict: the deltas have not run. Verdict on the BASIS only — is X7 a legitimate foundation to
spend delta hours on? PROCEED or RETURN-BASIS.

READ FIRST (one file, not the answer-file chain):
  .agent/projects/013_core_architecture_for_dst/STATE-p23-round4.md — identity, env, row status, hazards.
  Cross-check convenience only: LEDGER-p23-part1-rows.tsv (+ .sh regenerates it). RECOMPUTE everything
  you rely on; the ledger is not evidence.
  Implementor report: .motoko/herdr-delegates/answer-mot-dlg-1789805051624.md (incremental publish 1).

Privacy §0.6: counts, digests, indices, identities — never corpus content. Read-only: no commits,
nothing staged, no byte edits in A or the clone. Light runs only; NO delta re-runs (that is the next
delegate's job — do not spend the heavy slot).

SCOPE — five items, all frozen, none needs a delta result.

1. SCOPE CLAIM. `git -C $T/clone show --stat 9ed0d389` is 2 files
   (scripts/eval/test_candidate.py, src/eval/journal/testdata/MATRIX.expected.tsv). Verify the 7
   evaluator files are byte-identical X6→X7 by blob id: candidate.py, journal_replay.ail,
   journal_replay.sh, entry_config.py, p23_collector.py, scan.ail, admission.ail. Any DIFFERS = RETURN-BASIS.

2. FIX-SET FIDELITY. The diff contains exactly the 5 authorized items and nothing else:
   (1) 1.7 helper try/except WorldRefused + sentinels; (2) mut4 self-seeding dirt; (3) mut5
   clean-clone routing; (4) m13 commit-evaluator; (5) m12 quarantine of 12 M12.component.* rows.
   Anything beyond that set is out of authorization.

3. FIX-SET SOUNDNESS — the reason this review exists. Rounds 2 and 3 both shipped fixes that were
   green for the wrong reason ("constant-false … test vacuous"; "red by construction"). For each
   fix, rule whether it makes the row pass for the RIGHT reason:
   a. Fix 1 writes a sentinel t0_settings.json ("{}\n") AND an expected_end.txt carrying the
      generator's expectation. If the test asserts the shell's output against a value the helper
      itself wrote, 1.7 goes 7/7 CIRCULARLY and proves nothing about typed pass-through — which is
      all of R6. Trace where expected_end.txt is read and by whom.
   b. Fix 2 appends to the tracked Makefile and restores in `finally`. What survives a hard failure?
      A dirty tree is what A9b refuses on, so a crashed test can poison later rows.
   c. Fix 3 routes admits through a clean scratch clone. Does the assertion still sit on the path
      the row names, or did it move off it?
   d. Fix 5 quarantines 12 rows. Round 3 struck rows for "crediting tests that do not exercise the
      claimed behaviour". Is test_m12_one_hit_per_component genuinely environmental, or is
      quarantine hiding a defect? scan.ail must be untouched — verify.

4. CARRY-OVER. Rows 1.3, 1.4, 1.5, 1.6, 1.8-shell, 1.9 are quoted from X6, not re-run. Check each
   digest against the file. Then rule PER ROW whether evaluator blob-equality is sufficient for THAT
   row, or whether the row depends on a test file that X7 changed. Authority for the carry-over is
   the operator directive event at 2026-09-19T08:04:00Z in .dagr/run-w3-p1-1789663745618.json —
   it is an operator ruling on amendment 0.1, not an implementor decision. Note: a17's receipt has a
   corrupted digest for collect-x6.log (96 hex chars, two digests spliced); real value is in the
   ledger. Assume nothing else in the prose receipts is clean.

5. MATRIX.expected.tsv. 24 lines changed: assertion tier only, no expected-value changes, rows only
   for the 5 items above.

OUT OF SCOPE: delta results; R5/selectors (excluded from half (i)); the standing list already ruled
in round 3; 1.16 teardown (operator-owned).

DELIVERY: WriteFile to ./.motoko/herdr-delegates/answer-<your-handle>.md. Per-item verdict with the
command and its output for every claim you make; a status token in the FIRST column of any table,
never an expected value where a result is read. State PROCEED or RETURN-BASIS in the first line.
If RETURN-BASIS, list what must change before any delta run, each with an acceptance check.
