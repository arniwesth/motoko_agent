# HANDOFF 2026-09-20 — PLAN-004 v2 parked (P2.4-era) → fresh Orchestrator session

Last commit (main): `b37fcd47` evidence set (122 files + MANIFEST, 122/122).
`dagr check .dagr/run-plan004-v2.json --strict --json` → authoritative graph (operator-owned, read-only).
`dagr check .dagr/run-w3-p1-1789663745618.json --strict --json` → `[]` (live file, 81 events).
Main HEAD `600f8ea3` (session-external release-plan commits on top of evidence commit).
E-new2 `5b839496` lives in `../motoko_agent-eval` (HEAD, clean). Memory ~15/28 GiB. **Nothing running**
(0 door/test/matrix processes). No heavy run in flight. Privacy (§0.6) binds every brief:
counts, digests, indices, identities only — never corpus content.

## Where the run stands (live graph `.dagr/run-w3-p1-1789663745618.json`)

- DONE: all of the Sep-17 handoff (P1.x, P1R, P1G, E=2062605) + G1 (C11/lock revert, worktree A,
  E-record, P2.3 reviewed 4 rounds + X6→X9 sweep: doors 36/36, 27/27 PINNED, 1.7 7/7 + mutgate,
  1.8 3/3, 1.9/1.10/1.11/1.14/1.18) + P2.3R·a6 ACCEPT WITH CORRECTIONS C1–C6 (X9 bytes stand).
- DONE: G2-first-half — new E `562acadc` committed (tree = X9 tree), MATRIX regen adjudicated
  GUARDRAIL-SATISFIED-BY-RULING (24 fail all /tmp-escape setup, no NEW), E-record `a92fe5e6…`
  attested, synthetic admit ADMITTED preflight=0 at new E.
- DONE: P2.2·a2 interim — **both real prefixes admitted SourceFaithful at new E** (57-call
  `1e2bc499…`, 28-call `cb75408d…`); B1 cleared in practice. Measurement STOPPED on lock_root.
- DONE: Rulings YES on A (guard_lock out, option 1) + B (sentinel scratch) + C (r6 two-row) +
  D lock_root folded = ONE new E (observer directive, 2 events recorded by="observer").
- DONE: 1.16-amendment — evidence set committed `b37fcd47` (122 files, manifest `a171480b…`).
- BLOCKED: P2.2 (unblock = adjudication of 14 E-new2 regen fails → attestation → repeats).
  P2.3 shows `done` (37 attempts) — closeout items (C1–C6 + teardown + ledger) ride with commits.
- QUEUED: P3.1 ← P2.2 ← P3.2-v2 ← P3.3-v2 ← P3G; P4/P5. CANCELED: P6.

## The three pending decisions (all operator)

1. **Adjudicate 14 E-new2 regen fails** (638 rows: 405/170/14/11/27; all 14 at shared `entry`
   fixture setup, `/tmp escapes sandbox` — ruled class, needs ruling not say-so). Brief staged.
2. **P2.4-style driver-fix part** (fresh clone at E-new2, mutgate/item, D diagnosed-first,
   commit-on-A+B+C-and-carry-D hatch) → E-new3 → re-pin → regen → P2.2 retry.
3. **G2 closeout** (C1–C6, 1.16 teardown, open rulings) folds into E-new3 record.

## For the next session

- Reconcile from `git log` (expect evidence commit `b37fcd47` under session-external tip) +
  `../motoko_agent-eval` HEAD `5b839496` + graph receipts. In-flight: NONE.
- Marker `.dagr/.plan-w1-p4E-1789561998813` names `./.dagr/run-plan004-v2.json` — the ONLY
  dagr_plan this lineage ever declared; never declare another. First Delegate passes
  `dagr_plan: ".dagr/run-plan004-v2.json"` + `dagr_task` with a graph id.
- At most 2 delegates in flight, at most 1 heavy; every real-segment run through
  `scripts/eval/mem_guard.py`; absolute `EVAL_LOCK_PATH`; 12 GiB rule; `--evaluator` a commit.
- Pre-existing dirt (NOT this run's): `little-coder/`, bench scripts, release-plan docs,
  `src/eval/journal/testdata/MATRIX.tsv` (generated-untracked per CF2 — regen at clean E, do NOT commit).
- Known harness gaps filed under `.agent/issues/`: no completion signal for detached legs
  (notify-directive mitigation in place); empty-stop silent quits on longest briefs (~17%).
- Standing rules: frozen-bytes 0.1 (any edit restarts Part-1 at 1.1); void-set discipline;
  LEG-TEMPLATE time-bound legs (rc 0/N/97/98/99/124) with trap-notify on every exit path;
  intake refuses reports lacking freeze.txt/naming >1 X or mutation records.
