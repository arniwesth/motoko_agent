# LEG-SWEEP — the pre-boundary sweep (PLAN-001 (031) v1.1, release line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not
implement any other part, you do not edit the plan, the ADR, the dagr run file, or any other agent's
files, and you do not touch panes, tabs or worktrees.

## What this is

`SWEEP` in `PLAN-001-implement-adr-001-abi-8.md` §2. 013 ADR-001 D6 requires `make dst DST_JOBS=1` at
HEAD **before any boundary edit**; ABI 8.0 is a boundary edit of the largest kind, so the sweep runs
first and its result is what P0.4 is allowed to start on.

Kind: **heavy run, record only. No commit. No source edit of any kind.**

## Ground truth to read first

1. `.agent/projects/031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md` §0 items 1–3 and §2
   `SWEEP`.
2. `.agent/projects/013_core_architecture_for_dst/PLAN-004-implement-adr-004.md` §0 items 1–2 — the
   sweep convention and the memory rule you inherit.
3. `Makefile:504-519` (`DST_JOBS`, `DST_LOG`, `DST_TARGETS`), `Makefile:697` (`DST_KNOWN_RED`),
   `Makefile:703-716` (the `dst` recipe), `scripts/dst/sweep_summary.sh` (the closing summary).

## Grounding

Branch `arniwesth/031-abi-8-0`. HEAD is `75fefdcb`, a **documents-only** commit on top of `2f3ee4d1`;
`src/`, `packages/`, `tools/`, `scripts/` and the `Makefile` are byte-identical to `2062605`. Extension
ABI `7.4`. AILANG `v0.33.0`, the pinned build — do not upgrade it, do not work around it; an AILANG
bump is a plan §7 event, not something a delegate does.

## The run

One command, from the repo root:

```
make dst DST_JOBS=1
```

`DST_JOBS=1` is not optional: it is the serialization that makes the run comparable and keeps it inside
the memory rule.

**Exclusivity.** Heavy runs are one at a time (PLAN-004 §0 item 2; cgroup limit 24 GiB, the 12 GiB
`memory.current` rule). While this sweep runs you start nothing else heavy, and you do not run a second
`make` in parallel. If you find another heavy run already in progress, wait for it; do not race it.

**Duration.** The full target list is long. Let it finish. Do not shorten `DST_TARGETS`, do not pass
`-k`/`-j`, do not substitute a subset — a partial sweep is not this artifact.

## What you record

Every target's result, **including the ones that pass** — the register is not evidence of this sweep's
reds (PLAN-004 §0 item 1). For each target: name, exit code, and the closing summary line
`scripts/dst/sweep_summary.sh` prints for it. Then:

- the run's overall exit code;
- the reds, each compared against `DST_KNOWN_RED := driver_plus_herdr herdr_graded` (`Makefile:697`):
  **explained by the register** or **not explained**;
- wall-clock duration and `DST_JOBS`;
- anything that could not run, with the reason.

A red **not** explained by the register does not get diagnosed by you and does not get fixed by you: it
**blocks P0.4 until the operator rules**. Report it plainly, name the target, quote the failing excerpt,
and stop.

## Deliverables

1. Copy the sweep log out of the churn path so it survives:
   `cp .ailang/dst-last.log .agent/projects/031_system_one_decisions/evidence/SWEEP-2026-09-20.log`
   (create the `evidence/` directory if it does not exist).
2. Write `.agent/projects/031_system_one_decisions/RECORD-SWEEP.md` containing the per-target table,
   the summary, the register comparison and the blocked/not-blocked verdict. Keep it mechanical: exit
   codes and quoted lines, no narrative.
3. **Do not commit.** `SWEEP` produces a §9 record, and the orchestrator writes §9 and commits it. Do
   not edit `PLAN-001-implement-adr-001-abi-8.md`.

## Your last act: the typed result envelope

Print it in the pane, verbatim in this shape:

```
RESULT SWEEP
head: <sha>
command: make dst DST_JOBS=1
exit_code: <n>
duration_s: <n>
targets_total: <n>  passed: <n>  failed: <n>  skipped: <n>
reds_explained_by_register: [<target>, ...]
reds_NOT_explained: [<target>, ...]        # empty list = P0.4 unblocked
could_not_run: [<what>: <why>, ...]
files_written: [<paths>]
log: .agent/projects/031_system_one_decisions/evidence/SWEEP-2026-09-20.log
```

## Rules that bind you

- No edits to `src/`, `packages/`, `tools/`, `scripts/` or the `Makefile`. This task changes no code.
- No session content, credentials, tailnet or host addresses in the record or the envelope.
- Do not touch `.dagr/`, Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
- If the task as briefed cannot be done, stop and say why in the envelope's `could_not_run`. Do not
  substitute a smaller run and report it as this one.
