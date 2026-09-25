# OPERATOR DIRECTIVE 2026-09-19 15:3xZ — NO X10 accepted; M15 root cause confirmed; two corrections

Authority: operator. Scope: P2.3, PLAN-004 v2, G1. Answers the X10 recommendation in
`answer-mot-dlg-1789828883089.md` §§ "Blockers" / m15 analysis.

## 1. NO X10 — accepted

Your recommendation stands. Do not open X10 for the M15 `changed_during_run` family in this round.

**Root cause confirmed.** All three citations verified independently against the X9 clone:

```
test_candidate.py:894   guard_lock = str(entry / "heavy.lock")      ← lock AT the entry root
mem_guard.py:269-270    os.ftruncate(fd, 0); os.write(fd, pid)      ← writes pid bytes into it
candidate.py:564-565    corpus_hashes(entry) = walk_files(entry, skip=("runs",))
                                                         ↑ skips runs/, NOT the entry root
```

The digest covers `heavy.lock`; `mem_guard` mutates it during the guarded run; the corpus really does
change mid-run. `corpus:changed_during_run` is therefore **correct behaviour** — the fixture
contaminates its own digest. It also explains the mode asymmetry exactly: nolive never takes the
guard lock, so nothing writes and the digest is stable. M15 is not broken in live mode; only live
mode runs the writer.

**Why deferring is right, beyond scope discipline.** The fix is not obviously one line, and the
tempting one-liner is the worst of the three:

- `skip=("runs", "heavy.lock")` in `corpus_hashes` — narrow, but the corpus digest would then
  silently ignore a real file, weakening what M15 attests. This round has already been returned
  twice for changes that made a green mean less.
- move `guard_lock` out of the digested entry (`test_candidate.py:894` only, no evaluator bytes) —
  cleanest; a lock has no business living inside the thing being digested.
- rule that the test setup is wrong and `changed_during_run` needs no change at all.

Choosing among those is a design decision, not a fix round. **Ruling: the open question is narrower
than an X10 — whether `guard_lock` belongs inside the digested entry. Put that question, with the
three options and your recommendation, in the P2.3R review packet. Do not implement any of them
under X9.**

Attach the full changed-path table per the 9 wires plus the `heavy.lock` mtimes at 1.13 settle, as
you planned.

## 2. Correction — "immune to the m15 class" did not hold

§1 asserts 1.13 is *"immune to the m15 `changed_during_run` class (no live-runner involvement)"*.
1.13 has since come back `rc=1` twice:

- `x9-113` — `ailang test` on `*_live_test.ail` reports no tests found; wrong invocation.
- `x9-113b` — after the fix to `ailang run --entry main` (correct; six of seven suites now report
  properly: `4 PASS, 0 FAIL`, `8/8 passed`, `all checks passed`), one suite fails:
  `seams_live_test.ail` → `Error: execution failed: path "/tmp/motoko-eval-p15-seam-sentinel"
  escapes sandbox "/workspaces"`.

Different cause from M15, so the *class* claim was arguably right — but "immune" was asserted before
the leg landed and reads as a verdict on the record. State expectations as expectations until the
`.rc` exists. Your own §1 does this correctly two lines later (*"`x9-113.rc` ABSENT at this publish
— NOT claimed"*); apply that discipline to the prose too.

**The seams failure needs a ruling, and it is the same shape as M15:** a leg failing because of how
it is invoked, not because the code is wrong. `AILANG_FS_SANDBOX=/workspaces` is set by the leg
script; the sentinel path `/tmp/motoko-eval-p15-seam-sentinel` is hardcoded and ignores `TMPDIR`.
Note that a17 reported 1.13 live suites green at X6 — that run cannot have had the sandbox set.
Report which, do not fix under X9.

## 3. Correction — `progress` overstates

`{done: 13, total: 18}` is stated twice while 1.12 is red, 1.13 is red, and 1.15 has not run. Closed
on real evidence: **1.7, 1.8, 1.10, 1.11, 1.18** plus the carried rows. Restate from the ledger.

Also still open: `generated_at` was 38 minutes stale at 14:47; refresh on every write. And `a28` is
`working` with no live delegate, opened at 14:45 to poll a leg that had already finished at
14:44:27 — settle it honestly against the `x9-113`/`x9-113b` results.

## 4. What was done well — keep doing it

- The **frozen-X9 verification block** is the strongest evidence hygiene this round has produced:
  HEAD before *and* after, `status --short` empty, nothing staged in A, lock state at launch.
- **Scripts verified by sha256 + `bash -n` before reuse, with template markers confirmed present**
  (`RC=97`, `trap finish EXIT`, `on_signal`, `trap_rc`). That check is exactly what would have caught
  a26's phantom "patched with notify" claim mechanically rather than by an operator reading the file.
- The **named-successor poller instruction** (*"read `$T/x9-113.rc` BEFORE reporting; on `99`
  re-launch"*) is the fix to the 13:14Z gap, written as a binding obligation rather than left to
  memory.
- **Self-correction on the record** (*"the words ran ahead of the action"*) — unprompted, and the
  right response to the a26 pattern.

## 5. Remaining

1.15; then 1.16 teardown (operator-owned, do not execute); the carry-over restatement (`scan.ail`
differs X7 `20700842…` → X8 `0dfdee2c…`; six blobs equal, one differs inside
`test_m12_one_hit_per_component`; attach the diff); then the P2.3R review of X9 carrying both open
rulings — `guard_lock` placement and the seams sentinel path.
