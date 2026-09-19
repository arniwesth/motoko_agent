# HANDOFF 2026-09-16 — PLAN-004 v01 session → fresh session on run-plan004-v2.json

Last commit: `8f70d33` PLAN-004 v2.1: apply PREV corrections 1-8.
Chain since grounding: `3920814` → `9615bb4` (v4 record) → `21c1728` (v5) →
`55f1100` (P2.1 guard) → `988a863` (V5R C1–C6) → `51978b5` (plan v2) →
`5bc6d50` (PRESERVE) → `8f70d33` (v2.1 corrections).
`dagr check .dagr/run-plan004.json --strict --json` → `[]`.
`dagr check .dagr/run-plan004-v2.json --strict --json` → `[]` (run `run-plan004-v02`,
evidence copy byte-identical).

## Settled in v01 (operator graph `.dagr/run-plan004.json` — authoritative)

PLANW/REV1/REV2/PLAN1G, QRET (adopt §0.11 default), V5 (commits 9615bb4+21c1728+988a863)
+ V5R (ACCEPT WITH CORRECTIONS, claude, sha256 `b53604f8…`) + V5G (operator, D8/M15 ruled,
status flip tasked), P2.1 (`55f1100`, pytest 55 passed), PRESERVE (`5bc6d50`, 176 OK),
PSYNC (`51978b5` + `8f70d33`) + PREV (ACCEPT WITH CORRECTIONS, claude, sha256
`61a79635…`) + PLAN2G (operator, this handoff). All reviews claude — Codex unavailable
in this container (recorded in briefs, receipts, review headers).

## In-flight delegate handles (all settled — none live)

- mot-dlg-1789502489543 (V5·a1) done · mot-dlg-1789502511105 (SWEEP·a1) settled_unverified
  (no answer file) · mot-dlg-1789503825349 (P2.1·a1) done · mot-dlg-1789505004700 (SWEEP·a2)
  done-preliminary only · mot-dlg-1789505227559 (V5R·a1) done · mot-dlg-1789506369809
  (V5·a2 corrections) done · mot-dlg-1789542708780 (PSYNC·a1) done · mot-dlg-1789544215759
  (PREV·a1) done · mot-dlg-1789544266669 (PRESERVE·a1) done · mot-dlg-1789552741272
  (PSYNC·a2 v2.1) done. At most 2 in flight was kept throughout.

## Next ready task ids (fresh session on `.dagr/run-plan004-v2.json`)

Per v2 graph: **SWEEP** (no complete §6 record — SWEEP·a2's shared `make dst` PID 2289290
exited without a sweep_summary closing; `.ailang/dst-last.log` 3.8 MB, 1335 ✓, 5 wire
gates PASS, ends at park_resume PASS), **PRESERVE** (done in v01 — mirror as summary),
**SCAN0** (deps PRESERVE), **P1.1** (deps SWEEP + operator directive if unexplained red).
Reconcile from `git log` + §6 per §8; first Delegate goes to a task outside PLAN2G
(SWEEP/PRESERVE/SCAN0/P1.1); settle PLAN2G in v2 on that receipt.

## Fresh-session start (§8)

Marker file must name `.dagr/run-plan004-v2.json`; first Delegate passes
`dagr_plan: ".dagr/run-plan004-v2.json"` + `dagr_task`; never declare another dagr_plan.
The next session is this run's orchestrator and delegates.
