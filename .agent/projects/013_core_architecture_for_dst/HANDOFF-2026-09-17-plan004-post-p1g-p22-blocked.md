# HANDOFF 2026-09-17 — PLAN-004 v2 fresh session → post-reboot session (container reboot)

Last commit: `2062605` P1R R1: K1–K7 in the runner, eval_matrix, and the catching halves.
`dagr check .dagr/run-plan004-v2.json --strict --json` → `[]` (run `run-plan004-v02`, 74 events).
`dagr check .dagr/run-w1-p4E-1789561998813.json --strict --json` → `[]` (41 tasks, 52 events).
HEAD `2062605` = E (P1G-pinned). memory.current ~5.9 GiB at handoff. No heavy run in flight.
Marker `.dagr/.plan-w1-p4E-1789561998813` names `./.dagr/run-plan004-v2.json` — the ONLY dagr_plan
this session ever declared; never declare another. First Delegate of the next session must pass
`dagr_plan: ".dagr/run-plan004-v2.json"` + `dagr_task` with a graph id (P1R rework pattern).

## Where the run stands (operator graph `.dagr/run-plan004-v2.json` — authoritative)

DONE: QRET, PRESERVE (commit 5bc6d50, re-verified 176 OK), SWEEP (exit 0, 51/51, log sha256 defe2e97),
SCAN0 (r2.1 confirmed, 57-turn window clean, _scan0/ 0700/0600 + exposure row), PLANW/REV1/REV2/PLAN1G,
V5/V5R/V5G, PSYNC/PREV (summaries), PLAN2G (settled in v2 under operator grant 2026-09-16),
P1.1(+R+G, commit 6500311, P1.1R ACCEPT WITH CORRECTIONS C1–C3 incl. C2 PortedWorld test obligation — MET in P1.5),
P1.2a-v2 (a225404, M1), P1.2b-v2 (3f99293 + R4 record bb7a027 + E7 fix 053904a),
P1.3-v2 (45d71fb, M3/M4/M5), P1.4a (62a919d, M6), P1.4b (6c8bbc9 + R2 regen 0b023b0: 119 spans, 14 flags),
P1.5 (301554f, M8), P1.6 (64d08ab, M9), P1.7a-v2 (9c1067d2, M10+M15 A-rows; orchestrator wired A7/A8 in),
P1.7b-v2 (3ff4dbd, M11), P1.8 (a20d988, M12), P1.9a (d68d1ee + R3 fixture d74079d: sent-message K2@14),
P1.9b-v2 (52b7d56 + R1 wiring 2062605: K1–K7 in runner, eval_matrix 621 green),
P1R-v2 (a1 RETURN R1–R4, a2 followup ACCEPT WITH CORRECTIONS), P1G (settled BUILT under grants 2026-09-16/17;
E = 2062605 + ailang ae36986/daf06db1; ../motoko_agent-eval ABSENT — collision check passes as absent),
P2.1 (guard, 55 tests).
BLOCKED: P2.2 (failed a1, `blocked`, unblock = operator directive). QUEUED: P3.1 ← P2.2 ← P3.2-v2 ← P3.3-v2 ← P3G; P4/P5. CANCELED: P6.

## The stop: P2.2-BLOCKED (B1+B2+B3, all confirmed, delegate mot-dlg-1789640469372)

- B1 (code gap): runner has NO real-entry path — mode_admit→jr_real_refused (ran=false), candidate refuses
  EVAL_ENTRY pre-P1G, no P1.3 selector mode. Needs a REVIEWED code part + new E (evaluator change).
- B2 (dirty checkout): A9b TrackedChanges (PLAN-003 doc, RESEARCH doc, ailang.lock 195275ae vs E ae10391c) +
  AssembledTreeDiffers (58 untracked files count). Committing the lock alone will NOT clear it.
- B3 (no E record/worktree): e_pin null → Toolchain/PackagesUnpinned; no ../motoko_agent-eval → -dev refusal.
- Probe receipt: `admit --entry` → refused ran=false, 6 preflight findings. Answer file:
  `.motoko/herdr-delegates/answer-mot-dlg-1789640469372.md`. NOTHING was committed or run heavy; corpus untouched.

## Awaiting operator directive (proposed, from the session; P1G-style grant suffices)

1. New reviewed part P2.3: wire real-entry admission + records + candidate + selector modes; then RE-PIN E + regen MATRIX at new E.
2. C11: commit vs revert ailang.lock (+2 docs); define clean-A (recommend: admit only from a clean checkout at the admitted commit).
3. Materialise --e-record JSON from P1G pin values; `git worktree add ../motoko_agent-eval <new-E>`.
Also open (ruled, for next revision / P3.1 gates): fs_node decoder callees (unprotected+unrefused, K2@5 diverger —
protect 3 fns + FsNode, walk from load_program/decode_artifact, R2-owner scope); C8 copy-with-pins; C10 JWT
accept-and-print (no dst_secrets change); C12 K4 wording; C13 upstream batched; CF1/CF3 record-only; CF2 regen at E;
D5-R2/C8/C12 ADR lists; M15 path/intent swap semantics settled (K2@14 sent-message vs K7 digest-only kept renamed).

## For the next session

- Reconcile from `git log` (expect HEAD 2062605; chain 8f70d33→…→2062605 in §6 of PLAN-004) + §6 + graph receipts.
- In-flight: NONE — all delegates settled (19 answer files under .motoko/herdr-delegates/, see listing §6).
  At most 2 in flight, at most 1 heavy; every real-segment run through scripts/eval/mem_guard.py; 12 GiB rule.
- Untracked-but-expected: MATRIX.tsv (generated-untracked policy, commit col d74079d+dirty — CF2 says regen at clean E);
  mem_canonical_bench/growth_probe scripts; review docs (P1.1R, P1R, followup) + this handoff (reviewers never commit).
  Pre-existing dirt (NOT this run's): PLAN-003 doc, RESEARCH doc, ailang.lock modified, docs/, little-coder/.
- First Delegate goes to whatever the directive creates (P2.3?) or a non-heavy verify; settle P2.2's unblock by directive only.
- Privacy (§0.6) binds every brief: counts, digests, indices, identities only — never corpus content.
