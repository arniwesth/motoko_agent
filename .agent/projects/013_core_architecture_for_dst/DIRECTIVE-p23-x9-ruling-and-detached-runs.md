# OPERATOR DIRECTIVE 2026-09-19 — 1.7 ruling, X9 as a one-item batch, detached runs sanctioned

Authority: operator. Scope: P2.3, PLAN-004 v2, G1. Supersedes nothing; answers the `unblock` P2.3
currently carries.

## 1. Ruling on 1.7 — bad `end` is `BadSelector@path`. The implementation is wrong, not the test.

Authority is the D1 class table, `src/eval/journal/reader.ail:1561`:

```ail
export type SourcePosition = AtEntry(int) | AtLine(int) | AtPath

export type SourceRefusal
  = ChainBreak(SourcePosition, string)
  | MalformedEntry(SourcePosition, string)
  | UnknownEntryType(SourcePosition, string)
  | UnknownSchema(SourcePosition, string)
  | BadSelector(string)            -- the ONLY class carrying no position
```

`BadSelector` is structurally the selector class: there is no entry or line to point at, because the
selector is a property of the request, not of the data. The other four locate a defect inside the
journal. The fixtures follow exactly that split — `BadSelector` ×2 at `reader_position: "path"`,
`reader_field: "start"`; `MalformedEntry` ×8 at `entry:N` / `line:N` with real entry fields
(`at_ms`, `seq`, `pairing`, `request_id`).

Both existing comments already state the intended behaviour:

- `journal_replay.ail:328` — *"`jr_end` is refuse-closed — unknown end forms are a `BadSelector`
  refusal at decode time"*
- `journal_replay.ail:368` — *"an UNREADABLE dir is `MalformedEntry@path` — distinct from a bad end
  form (`BadSelector@path`)"*
- `test_candidate.py:1306` — *"DISTINCT labels for unreadable (`MalformedEntry@path`) vs bad end
  (`BadSelector@path`)"*

**The defect.** `jr_entry_typed`, `scripts/eval/journal_replay.ail:437`:

```ail
  match jr_sel_json(sel, env) {
    Err(e) => Err(jr_unreadable_refusal(e)),      -- one arm, two causes
```

`jr_sel_json` fails either because the file is missing / its JSON is malformed (genuinely
`MalformedEntry`) **or** because `jr_end` rejected the end form at `:335`
(`"selector.txt: end is not EndAt(_) or CutoffBefore(_)"`), which is `BadSelector`. The single arm
stamps `MalformedEntry` on both.

This is why round 3's finding never closed. Round 3 found *"`d1-empty-dir` and `d1-bad-end` both
yield `BadSelector@path`"*. R6 fixed the unreadable side by adding `jr_unreadable_refusal` but left
the shared arm, so the two cases collided again in the other direction. Same defect, mirrored.

**Do not change the test's expectation.** It asserts the correct value.

## 2. X9 — ONE item, nothing else

Split the `:437` arm so selector-decode failures route to `jr_source_refusal` (which already
constructs `BadSelector(e)` at `:363`) and only file/JSON failures reach `jr_unreadable_refusal`.

Carry with it, in the same commit, the stale comment at `:361` — *"An unreadable entry directory is
a D1 refusal at the selector"* — which describes pre-R6 semantics and now names the wrong case.

Nothing else. Batch size is deliberate: the measured per-item defect rate over round 4 is 3 of 5,
and at that rate a five-item batch has roughly a 1% chance of passing clean while a one-item batch
has 40%. Do not bundle the unrun rows into X9.

## 3. Mutgate record required at intake

New submission precondition, spec and tooling in
[`GATE-mutation-red-submission-precondition.md`](GATE-mutation-red-submission-precondition.md) and
[`mutgate.sh`](mutgate.sh):

```
baseline GREEN  →  mutated RED  →  restored GREEN, bytes identical
```

For X9: mutate the `:437` arm back to the catch-all; `test_p23_r6_d1_classes_through_shell` must go
**red**, then green on restore with the file digest unchanged. Run it in a throw-away
`git clone --shared`, never in `$T/clone`.

**A submission without the record is refused at intake, not reviewed and returned.** That refusal is
where the saving is.

## 4. Detached execution — SANCTIONED

The delegate tool budget is 30 s per command; the 1.7 leg takes ~256 s and the other open rows
40–300 s. a20 declined to detach because an unmonitored heavy run is against the rules, and it was
right to decline. It is now authorized, under these conditions:

- launch with `setsid` / `nohup`; record **pid, log path, `.rc` path and expected duration** in the
  receipt before the launching attempt settles;
- the launching delegate exits within minutes — it does not sit on the run;
- a **short poller** delegate reads `.log` / `.rc` and reports; it runs nothing heavy itself;
- one heavy run at a time; every guarded run through `scripts/eval/mem_guard.py` with an absolute
  `EVAL_LOCK_PATH`; the 12 GiB rule stands;
- never move the clone checkout while a run is in flight.

This unblocks X9's own verification and the seven rows a20 could not run.

## 5. Order

1. X9 (one item) + mutgate record → attach both to the receipt.
2. Detached: 1.7 full 7/7 leg at X9 — must be **7/7 GREEN** with the distinct-label half satisfied.
3. Detached, one at a time: 1.8 re-run (flagged STALE-CARRY), 1.10 X8 leg, 1.11 MUT-4/MUT-5 legs,
   1.12 ×2, 1.13, 1.15, 1.18. Then 1.16 teardown, operator-owned.
4. P2.3R round-4 review of X9.

## 6. Restate the carry-over before the review

The current claim is blob-equality across all seven evaluator files. That is now false:
`scan.ail` differs X7 `20700842…` → X8 `0dfdee2c…`. The change is one line inside
`test_m12_one_hit_per_component`, so no production path is affected and rows 1.3/1.4/1.5/1.6/1.9
remain carryable — but the argument must read *"six blobs equal; `scan.ail` differs by one line in a
test function, diff attached"*. A reviewer recomputing blob ids, as `P2.3R·a5` did, otherwise hits
DIFFERS and stops.

## 7. Graph

Open the X9 work as `P2.3·a21` (`cause: followup, ref: P2.3·a20`). P2.3 leaves `blocked` when that
attempt opens. Settle with `progress: {done, total}` on the attempt — the row table is 18 items and
the last three settles read `done` against an incomplete table, which has required three manual
corrections (a14, a18, a20).
