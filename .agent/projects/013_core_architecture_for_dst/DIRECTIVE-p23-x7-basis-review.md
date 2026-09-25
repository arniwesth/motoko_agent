# OPERATOR DIRECTIVE 2026-09-19 — run the X7 basis review before any delta re-runs

Authority: operator. Scope: P2.3 / P2.3R, PLAN-004 v2, G1. This does not change the X7 ruling of
2026-09-19T08:04:00Z; it inserts a gate ahead of the delta runs it authorized.

## 1. Delegate the basis review

Brief: `.agent/projects/013_core_architecture_for_dst/BRIEF-p23-x7-basis-review.md` — pass it
**verbatim**. Actor **claude**: the reviewer must be independent of the `motoko` implementor.
Read-only, light runs only. It must **not** spend the heavy slot on deltas.

Do **not** re-send the answer-file chain. The brief is deliberately short and points at
`STATE-p23-round4.md` (identity, env block, row status, hazards) and `LEDGER-p23-part1-rows.tsv`.
Re-ingesting the ~73 KB receipt chain is what stalled a11, a12 and a5.

## 2. Open it in the graph

```
P2.3R·a5
  cause: {type: "followup", ref: "P2.3R·a4",
          reason: "basis review of X7 ahead of the delta runs"}
  locator + liveness as usual
```

P2.3R goes `done → working`. P2.3 stays `blocked`; its `unblock` field already names this review.

## 3. Hold the delta delegate until a5 settles

The gate is worthless if both run. Serial, not parallel.

- **PROCEED** → delta delegate next; the round-4 verdict becomes `P2.3R·a6`.
- **RETURN-BASIS** → correct the fixes at an X8 **before** any delta hours are spent.

## Why

The deltas are hours; this review is ~20 minutes (P2.3R·a1–a4 each ran about that). If the basis is
refused afterwards, every delta byte is worthless. Both reviewable claims — the 2-file scope and the
six-row carry-over — are frozen and need no delta result.

## Receipt defects the reviewer is told about

- a17 (`answer-mot-dlg-1789802299896.md`) reports `collect-x6.log` as a 96-hex-char digest: the first
  49 chars of the real value with the tail of `collect-x6e.log`'s digest spliced on. Real value is in
  the ledger.
- a12 (`answer-mot-dlg-1789743819242.md`) reports `083cc8c1…` as the ref baseline — that is the log
  file's own sha256, not the ref digest inside it (`1876628c…`).

Treat the prose receipts as unverified; the ledger recomputes every digest from the file.
