# Handoff: implement Phase A

Audience: a fresh implementer session. The plan was authored fresh against HEAD `8227053`
(2026-07-03) and reviewed iteratively in the same session; this handoff cashes out that
session's residual context. Keep it short: **the plan is the spec — this file only tells you
how to hold it.**

## Mission

Execute `PLAN-phase-a-pure-foundations.md` in this directory, WI-0 → WI-4, in order. One
commit per WI (WI-3 is two: 3a/3b), each landing with the system shippable and the WI's
verification commands green. Done = the WI-4 gate checklist passes as a block, including
`diff -r` of parity baseline vs. after being empty. Do NOT start Phase B work, however
tempting a "while I'm in here" refactor looks — zero behavior change is the whole game.

## Reading order

1. `PLAN-phase-a-pure-foundations.md` — normative for everything you do. Its call-site
   survey and WI sections are the work; its gate checklist is your exit.
2. `ADR-001-phase-oriented-core.md` — Phase A section + Decision detail 4 (context for what
   the vocabulary module is); the Plan-Authoring Findings & Dispositions log (so you don't
   re-report G1–G8).
3. `sketch/sketch_vocabulary.ail` + `sketch/README.md` — the WI-2 seed. Run it before
   copying from it.
4. `NOTE-ailang-run-exit-code-false-alarm.md` — mandatory before writing the WI-0 harness.

## Verified-at, and when to re-verify

Every `file:line` in the plan was read at HEAD `8227053` on AILANG v0.26.0 (`3b52a24`).
Before editing:

- `ailang --version` must be v0.26.0/`3b52a24`; if not, STOP and re-validate per the plan.
- `git log --oneline -10 -- src/core/` — if anything landed after `d5bb7cc` (2026-07-02),
  treat every plan anchor as suspect and re-grep before each edit. (Doc/scripts commits
  after `8227053` — the plan itself, the tiers-smoke repair, ADR amendments — are expected
  and do not invalidate `src/core` anchors.)
- Re-grep line numbers before every edit regardless; `agent_loop_v2.ail` moves often.

## Residuals the plan defers to you (WI-0 baseline time)

- **Validate each listed smoke's determinism yourself**: run the harness twice, self-diff.
  Only `cost_budget_full_loop` and `compaction_full_loop` were double-run-validated during
  planning; `dp7_gate` (needs the workdir setup script) and the two you repair
  (`pending_full_loop`, `handle`) were not. The committed harness list defines the gate —
  fix or drop nondeterministic members *before* any production edit.
- **The two G8 smoke repairs** (`pending_full_loop.ail:81`, `handle.ail:65`): add the
  missing `ExtensionHooks` fields with passthrough impls. Match signatures against the ABI
  2.2.0 `types.ail` in the registry cache, not against memory — `handle` is two field
  generations stale.
- **Harness hygiene (the false-alarm lessons, non-negotiable)**: `set -euo pipefail`;
  `ailang check` each smoke before running it; never read `$?` after a pipeline; fail
  full-loop smokes that emit zero events.

## Discipline

- The plan's decisions (module name `phase_vocab.ail`, builders co-located, `decide` not
  landing, constants naming, what the sketch seeds) are settled — G1–G8 are dispositioned
  in the ADR log. New contradictions with HEAD are findings for a new plan/ADR note, not
  license to improvise.
- Run the WI's verification block at every WI boundary, not just at the end. The parity
  harness comparison is the point of the exercise — if it ever diffs, stop and understand
  before proceeding; do not "fix" the baseline.
- Expected side effects are asserted in the plan (e.g. `agent_loop_v2` inline tests 19→17
  after WI-3a). If a number differs, that's a finding.
