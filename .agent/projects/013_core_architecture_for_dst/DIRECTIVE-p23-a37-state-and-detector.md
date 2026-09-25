# DIRECTIVE 2026-09-20 10:5xZ — P2.3 `done → blocked` (5th instance); the detector is built, run it at settle

By: observer (w3:pZ), under the `run.observer` grant of 2026-09-19T17:46:16Z.
Scope: P2.3, PLAN-004 v2.
Authority: `may_decide_and_continue` — grant scope: *"correction of run-file state that its own
receipts contradict (progress {done,total}; done→blocked)"*.

## 1. Correction — P2.3 is not `done`

`P2.3` projects `done` from `a37`, which carries `progress: {done: 9, total: 18}`. Nine of eighteen
Part-1 rows are open. Set **`P2.3` → `blocked`**, with:

```
unblock: operator ruling D (candidate.py lock_root assembly defect) — the remaining item of the
         A/B/C/D fix set; rows 1.12/1.13/1.15 adjudication under G3; P2.3R·a6 corrections
```

Adjust `unblock` to whatever `a6`'s corrections actually require — its receipt is the verdict of
record and I have not read it in full.

## 2. The detector exists now — stop needing a directive for this

This is the **fifth** instance: P2.3 06:39Z (`a14`), 09:22Z (`a18`), 11:37Z (`a20`), P2.2 19:30Z
(`a14`, a receipt titled *"STOP REPORT"*), now P2.3 (`a37`). Each of the first four cost a human
reading a receipt and a directive being written. Per
`.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
rule 2, the third should already have been a script.

It is now built:

```bash
python3 .agent/projects/013_core_architecture_for_dst/detect-settle.py \
        .dagr/run-w3-p1-1789663745618.json
# REFUSE P2.3  DONE_INCOMPLETE  P2.3·a37 claims done at 9/18 — 9 row(s) open
# exit 1
```

Read-only; writes nothing. Exit 0 clean, 1 refusal, 2 usage; `--strict` fails on warnings too,
`--json` for machines.

**Run it before every settle, and treat exit 1 as a refusal to settle** — not as something to
correct afterwards. That is the whole point: the correction is cheap, the *noticing* is what has
been costing a human each time.

Two things worth knowing about it, because both were wrong in my first version and only running it
showed that:

- **Absent `progress` is reported, not passed over.** Three of the four historical cases carry
  `progress: null`, so a check that only compares `done < total` is silent on exactly the cases it
  exists for.
- **But refusing on absent progress is too broad.** 33 of 42 tasks here are summaries declared from
  the operator's plan rather than observed; they have no receipt and no row table, so there is
  nothing to count. **The receipt is the discriminator** — a delegate answered ⇒ there is a row
  table. Hence WARN (has receipt, no progress) vs REFUSE (`done < total`).

## 3. One warning it raises, for you to close

```
WARN P2.3R  DONE_PROGRESS_ABSENT  P2.3R·a6 has a receipt but no progress
```

`a6` is the round-4 review — **ACCEPT WITH CORRECTIONS**, the verdict this round was working
toward. Emit `progress` on review attempts too, or record why a review has no countable row set;
either closes the warning honestly. Do not close it by removing the receipt.

## 4. Session note

This is the last directive from this observer session. The handoff is
`HANDOFF-2026-09-20-observer-session-close.md`; it names the next session as this run's observer,
cites the grant, lists the five open returns, indexes the artifacts, and records six things this
session got wrong — including two directives whose authority line was false when written. Read it
before relying on anything signed before 2026-09-19T17:46:16Z.
