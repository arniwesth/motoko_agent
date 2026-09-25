# OPERATOR DIRECTIVE 2026-09-19 16:0xZ — notify confirmed working; 1.15 decomposed; one row mismatch needs a ruling

Authority: operator. Scope: P2.3, PLAN-004 v2, G1.

## 1. The notify worked — that was the leg, not a poll and not an operator

At 15:49:22.222 you received `LEG DONE: x9-115 (row 1.15) rc=1 …`. That came from
`x9-115.sh:44`, byte-identical to `LEG-TEMPLATE.sh:44`, one second after the leg wrote
`finished rc=1 2026-09-19T15:49:21Z`. No operator sent it. **First time in this run that the work
woke you.** The mechanism is confirmed end to end: template script → `rc` derived from the work →
trap on exit → `send-text` + `send-keys` → idle pane submits → turn starts.

**Stop writing "Polling x9-115.rc".** You do not poll. Checked at 15:40: your turn had ended at
15:35:53 (`state: done`, 255 s idle), `agent_status: idle`, and the only `sleep` on the box was
PID 1's `sleep infinity`. Nothing was reading that `.rc`. The rest of your sentence — *"its own
poke should wake me first this time"* — was correct, and is what actually happened.

Write what will wake you and what happens if nothing does: *"x9-115 running, pid N, expected ~Ns.
I act again when its notify arrives or the operator pings. If neither happens the leg is
orphaned."* Three of the six legs still have no notify at all; for those, "polling" means nothing.

## 2. 1.15 `matrix=1` decomposes into three causes, only one of which is a suite failure

```
637 rows: credited=429, equal=179, inapplicable=11, mismatch=1, missing=4, skipped=13
suites 29, non-zero exit: src/eval/journal/seams_live_test.ail=1
```

- **One suite non-zero** — `seams_live_test.ail`, the same
  `path "/tmp/motoko-eval-p15-seam-sentinel" escapes sandbox "/workspaces"` that reddened 1.13.
  One cause, two rows.
- **13 skipped** = 4 × `M13.*.live` + **9 × `M15.*`**. The M15 family is *skipped* here, not
  failed. Consistent with the `@live` gate, and it means **MATRIX evidence has never covered M15
  either** — the gap is wider than row 1.12.
- **4 missing** — `M8.tool.empty_queue`, `M8.C2.uses_w`, `M8.C2.uses_p`,
  `M8.C2.rebuilds_script_and_queue`. Report whether these are expected-absent at X9 or a real gap.

## 3. The one mismatch is 1.7's own row — this needs a ruling

```
MATRIX.expected.tsv:629
  P2.3R.r6.d1_classes  …:test_p23_r6_d1_classes_through_shell  pass  -  aggregate:p23r6

mxlogs/candidate_obs.tsv:99
  …:test_p23_r6_d1_classes_through_shell  refused  MalformedEntry  path

mxlogs/join.tsv:629
  P2.3R.r6.d1_classes  mismatch
```

**1.7 passes in pytest (`1 passed in 270.23s`) and its MATRIX row mismatches.** The row expects
tier `pass` with `-`; the test now emits a verdict triple `refused / MalformedEntry / path` via the
`observe(…)` call at `test_candidate.py:1370`. They disagree in *kind*, not merely value.

This matters beyond bookkeeping. Round 3's R8 struck rows for *"crediting tests that do not
exercise the claimed behaviour"*. Row 629 currently credits `d1_classes` at the wrong tier, and the
observed triple records only the **unreadable** half (`MalformedEntry`) — the `BadSelector` half
that X9 exists to fix is asserted in the test but not observed into the matrix.

Report, do not fix. Specifically state: (a) which commit introduced the `observe(…)` call — X7 or
X8 — and whether row 629 was left behind by that change; (b) whether the correct repair is the row's
tier or a second `observe(…)` for the bad-end half; (c) that either is an evaluator-bytes or
expected-tsv change and therefore **not** available under frozen X9. It joins the `guard_lock` and
seams-sentinel questions in the P2.3R packet.

## 4. State

Clone is **clean** at X9 `e397d957…` as of 16:00Z — the `?? MATRIX.tsv` the leg reported has been
cleared. Confirm that before the review; row 1.15's spec is *MATRIX-evidence, NOT regen*, and the
leg did write `MATRIX.tsv` into the clone during the run.

Row tally on real evidence: **green 1.7, 1.8, 1.10, 1.11, 1.18; red 1.12, 1.13, 1.15; deferred
1.16.** All three reds now have identified causes that are **harness-invocation problems, not
evaluator defects**: `heavy.lock` inside the digested entry, a hardcoded `/tmp` sentinel under a
`/workspaces` sandbox, and a matrix row tier. State that framing in the review packet — it is the
single most useful thing the tail produced.

Restate `progress` from the ledger; it has read 13/18 while three rows are red.
