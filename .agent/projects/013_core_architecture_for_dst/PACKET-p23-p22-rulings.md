# P2.3 / P2.2 review packet — rulings requested (assembled 2026-09-19, read-only)

Scope: PLAN-004 v2, G1. This packet is the single file a ruling cites. Nothing here authorizes
implementation — every open item names the decision needed and what happens after it.

## 0. Where the run stands (counts/digests/identities only)

- New E `562acadc…` committed (tree = X9 tree `596b8ba1…`, verified). P1G pin `2062605` superseded.
- E-record `.motoko/eval-corpus/_g2/e-record-562acadc.json` attested, digest `sha256:a92fe5e6…`
  (gen full-hex new E, tool `bfd1c3db…`, lock `ae10391c…`, 23 packages + dot-pin).
- MATRIX regen of record at new E: 637 rows (credited 405, equal 170, failed 24, inapplicable 11,
  missing 27), commit column new E, no `+dirty`. Adjudicated GUARDRAIL-SATISFIED-BY-RULING
  (receipt `answer-mot-dlg-1789842194417.md`): all 24 fail = `/tmp` sandbox-escape setup phase,
  wire-quoted Q-A/Q-B; m12 green; c1 absent; missing-27 = 4 M8 known + 23 live-gaps; no NEW finding.
- P2.2 retry a2: selector + **both admissions `SourceFaithful`** at new E (57-call `1e2bc499…`,
  28-call `cb75408d…`, preflight 0, guard pass); measurement STOPPED on the lock_root defect.
  B1 (no real-entry path) cleared in practice.
- P2.3R round-4 review of X9: ACCEPT WITH CORRECTIONS C1–C6 (receipt
  `answer-mot-dlg-1789837181766.md`). X9 bytes stand; corrections ride to G2.
- Graph: P2.2 `blocked`, P2.3 `blocked` (closeout), P2.3R `done`. Both `dagr check` clean.

## 1. Carry-over restatement (for the record before any review)

Six evaluator blobs equal X7→X8→X9; `scan.ail` differs by one line inside
`test_m12_one_hit_per_component` (test function only, no production path affected):

```
@@ -981,7 +981,7 @@ pure func test_m12_one_hit_per_component() -> bool
-      && st_one_hit(st_poisoned("snapshot"), [], "snapshot:snapshot:1/line PrivateKeyBlock")
+      && st_one_hit(st_poisoned("snapshot"), [], "snapshot:snapshot:0/line PrivateKeyBlock")
```

Rows 1.3/1.4/1.5/1.6/1.9 remain carryable on that argument (a reviewer recomputing blob ids
otherwise stops at DIFFERS — P2.3R·a5/a6 both did). Authority: operator directive event
2026-09-19T08:04:00Z extended by diff-locality (X9 touches only the `Err` arm of `jr_sel_json`;
all door verdicts decoded `Ok`).

## 2. Open ruling A — `guard_lock` inside the digested entry (P2.2 blocker)

Confirmed at new E: `test_candidate.py:894` points the lock at the entry root;
`mem_guard.py:269–270` rewrites pid bytes into it; `candidate.py:564–565` hashes the root
(`skip=("runs",)` only). The digest covers the lock; live mode writes it;
`changed_during_run` is **correct behaviour** — M15 live 9/9 fail deterministically, nolive
clean (never takes the lock). First full-live run at any X — not a regression.

Options: (1) move `guard_lock` out of the digested entry (recommended — one test-bytes line,
keeps M15 attesting every entry byte, matches the shell path's `corpus/lock/` convention);
(2) `skip+=("heavy.lock")` (weakens the digest — the "green means less" pattern, twice-returned);
(3) setup-wrong, change nothing (leaves M15 live permanently unmeasurable).
Needs: operator ruling → driver-fix part → new E → re-pin → regen → P2.2 retry. NOT under X9.

## 3. Open ruling B — seams `/tmp` sentinel under the `/workspaces` sandbox

`seams_live_test.ail:91` hardcodes `/tmp/motoko-eval-p15-seam-sentinel`, ignoring `TMPDIR`;
every leg exports `AILANG_FS_SANDBOX=/workspaces`, so the suite cannot pass in-sweep (6/7 live
green, 1 red; same cause reddens 1.13, 1.15's suite exit, and orphans the 4 M8 rows — one cause,
five row-effects). Fix: sentinel under `TMPDIR`/sandbox scratch. Batch with A (same part,
disjoint files/legs) or rule separately — either way not under X9.

## 4. Open ruling C — r6 observe-tier mismatch (row 629)

Row expects tier `pass/-`; test emits `refused/MalformedEntry/path` via first-call-wins
`observe(…)` (`test_candidate.py:1370`, dates to freeze `929879ce` — latent since birth,
surfaced when 1.7 went green). The `BadSelector` half X9 fixed is asserted but never observed
into the matrix. Repair: row tier change or second-row restructure (a second `observe` is a
no-op by first-call-wins). Evaluator-bytes or expected-tsv change → not under X9.

## 5. Follow-ups named, not in any ruling above

- `:437` exact-string routing (`jr_end` message ~100 lines away, nothing pins them): structural
  typed-error fix, larger than a one-item batch.
- R5/selectors full mode (half ii): prefix-end bug (`show(assistant_seq)` vs string entry id)
  needs fix + new E; P2.2 worked around per plan text; P3.1 needs the mode.
- C1–C6 (P2.3R·a6): committed-mutation mutgate re-run; diff-locality carry ruling; `.rc`/ledger
  hygiene; m12-vacuous-record correction; litter/teardown; ledger progress.
- 1.16 teardown (operator-owned); 1.12-live/1.13/1.15 reds dispositioned above.

## 6. Receipt index (digests recomputed, not typed — see ledger)

Sweep: freeze chain X6→X9 (`$T/freeze*.txt`), doors (`door1-x6.log 27571da7…`,
`door2-x6.log 72c62c6b…`), 1.6 (`t16/run2.log 163a462d…`), 1.7 (`x9-17.log a551c7ea…` 7/7 +
mutgate `15931dd6…` PASS), 1.8 (3/3 ScanRefusal wires), 1.9 (0 entry-reads), 1.10 (R1d
`ba744059…`), 1.11 (MUT-4/5 redefined), 1.14 (`t114.log 569812a9…`), 1.15 (`x9-115.log`
637-row evidence), 1.18 (`x9-118.log c6c82610…`), E-record X9 (`7a60d968…`) → G2
(`a92fe5e6…`). P2.2: selector + both `SourceFaithful` receipts + STOP report
(`answer-mot-dlg-1789847872818.md`). Reviews: P2.3R·a1–a4, a5 RETURN-BASIS, a6 ACCEPT+C1–C6.
