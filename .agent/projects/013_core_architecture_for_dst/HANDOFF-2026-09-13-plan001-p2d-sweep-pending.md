# Handoff: PLAN-001 P1+P2 nearly done — P2D sweep is the one open gate, then P3ORD

Written 2026-09-13 ~09:50 UTC, session closing. Branch
`arniwesth/013-plan003-and-herdr`, HEAD `de4b4f5`. Nothing pushed.
Memory at close: 3.2 GiB (quiet — good time for the sweep).

## 1. Where the graphs stand

**run-plan001** (pane `w1:p18`, live view was `w1:p1W`): everything done except P2D.
P1B `ad558d0` → P1C `379d806` → P2A `bd0eac7` → P2B `6b33f36` → P2G `c1bc518` →
P2T `2fe783a`, each one commit with its answer file
(`.motoko/ab/answer-{p1b,p1c,p2a,p2b,p2g,p2t}.md`). P2D is `working`
(attempt P2D·a1); its work is COMMITTED as `a6abda4` (derive.py order-of-witness
extension + ADR-001 partial-fallback amendment + `.motoko/ab/answer-p2d.md`) but
**not settled** — the phase-gate sweep never ran.

**run-plan003**: REV31 done (`db0dbc7`); P3ORD still `blocked` on PLAN-001 P2;
P4 blocked on ADR-002; QCANARY + PINDH operator-owned — do not touch.

## 2. The single next action: P2D's sweep, then settle, then P3ORD

```sh
cat /sys/fs/cgroup/memory.current   # must be well under 12 GiB or STOP
# no Delegate in flight (one at a time); nothing else running
nohup env -u AILANG_FS_SANDBOX make dst DST_JOBS=2 > .ailang/dst-p2d.out 2>&1 &
# poll with short commands: tail .ailang/dst-p2d.out, check the pid
```

- `env -u AILANG_FS_SANDBOX` is REQUIRED: the TUI exports
  `AILANG_FS_SANDBOX=/workspaces/motoko_agent`, which makes `smoke_parity` and
  `smoke_driver` fail on `/tmp/phase-a-tool-parity` escaping the sandbox
  (operator ruling 2026-09-13 — NOT a script defect, do not touch the script).
  P3 Part 6's sweep passed from a delegate pane for the same reason.
- Read the verdict ONLY from the closing `sweep_summary` block in
  `.ailang/dst-p2d.out`. Green = `exit 2 — no new failures` with ONLY
  `depth_canary` + `driver_plus_herdr` + `herdr_graded` red (all in
  DST_KNOWN_RED). Reference: P1C's sweep (`.ailang/dst-p1c.out`) read
  `458s wall, exit 2, FAILED(3)` exactly so.
- Any NEW red = stop condition. Report it with log lines; do not settle P2D.
- Then settle P2D·a1 (commit `a6abda4` + sweep summary, real `date -u`
  timestamps, `dagr check --strict --json` before `mv`), and take P3ORD under
  run-plan003 (`dagr_plan: ".dagr/run-plan003.json"`, `dagr_task: "P3ORD"`).
  P3ORD handoff is `answer-p2d.md` §5: `RunSummaryInfo.world_ordinal` field +
  `BEGIN₂.ordinal₀ == END₁.final` assertion (the `journal_resume`
  `from_ordinal is 0 — DEFERRED` line is what turns green).

## 3. State verified at hand-off

- `git log`: …`2fe783a` (P2T) → `a6abda4` (P2D work) → `de4b4f5`
  (**operator's**: "Build canonical_messages with one concat" — perf fix,
  measured 11.7→7.0 GB peak RSS on a 299-step replay; unrelated to PLAN-001,
  do not rebase onto or under it, just build on HEAD).
- Working tree: only `M ailang.lock` + untracked (`docs/`, `little-coder/`,
  `design_docs/planned/…`, `.motoko/ab/{task-p1b,muse-replay-*}`, P2T's
  `scripts/dst/mem_*.ail` probes — left alone, P2D may delete the mem files).
  No uncommitted `src/`/`scripts/`/`tools/` changes. No stash entries created
  by this session (one earlier `git stash` round-trip for P1C was fully
  restored and dropped — never do that again per operator order).
- No live delegates (all panes reaped except this session's; P2D's delegate
  died `agent_not_found`). No sweep running. oom_kill still 1 (no new OOM).
- Both graphs `dagr check --strict --json` clean at last write.

## 4. Traps for the next session

1. **Delegate answer files never arrive** in this container (unsandboxed
   delegates: P1C, P2A, P2B, P2T, P2D all finished `done` with no answer
   file). Verify from `git log`/`git show --stat HEAD`, re-run the named
   gates yourself, settle on that. P2G was the exception (DelegateCheck
   collected). Never commit uncommitted delegate work silently — verify first.
2. **Every DelegateCheck costs a step and blocks ~45s** (30s herdr timeout +
   overhead); a 15-minute delegate costs ~20 checks. Poll with `herdr pane
   read` / `git status` between checks, not back-to-back DelegateChecks.
3. **`make dst` never in foreground** — BashExec's ~35s timeout kills the tool,
   not make (the 21:36 zombie sweep). Detached (`nohup … &`) + poll only.
4. **Full sweep only at phase gates** (P1C done, P2D pending). Otherwise
   delegates run only their part's named targets.
5. **Operator-owned, never yours:** QCANARY, PINDH, P4 (blocked on ADR-002),
   `event_vocabulary_version()` bump (open since P1B — one deliberate commit),
   `driver_plus_herdr` re-issue, `depth_canary` re-measure.
6. **Numbers at HEAD:** vocab 43, frames 154 requests / 8 subjects
   (world_framed_wire), anchors 10/10 coherent (session.ail
   1431/1690/1802/3893/4114), profiles v30/v19/v11, table `01f5ebc5…`.
7. **In-flight handles:** none. Next task id: **P2D sweep → settle → P3ORD**.

## 5. Cross-references

- Plans: `PLAN-001-implement-adr-001.md`, `PLAN-003-implement-adr-003.md` §6.
- Decisions: `ADR-001-sequencing-the-dst-architecture-caps.md` v3 (D1, D2).
- Answers: `.motoko/ab/answer-{p1b,p1c,p2a,p2b,p2g,p2t,p2d}.md`.
- Sweep evidence: `.ailang/dst-p1c.out` (green reference), `.ailang/dst-last.log`.
- Prior handoffs: `HANDOFF-2026-09-12-plan003-p1-and-the-delegation-view.md`.
