# LEG-P6 — repair, then re-pin (PLAN-001 §5 P6, dagr task `P6`)

You are a delegate of the 037 orchestrator, invoked through the `Delegate` tool. You own
exactly this task. You do not implement any other part, you do not edit the ADR or the
plan, you do not write any dagr run file, and you do not touch other panes, tabs or
worktrees.

## What this is

`P6` in `PLAN-001-implement-adr-001.md` §5: repair, then re-pin. Done when there is no
new red against the P0 baseline, at gate **G2** (evidence for A1–A10 reviewed once;
operator accepts and rules on D11 default-profile membership — that ruling is the
operator's, not yours).

Depends on P5 (landed: wiring, `skills` profile, CI recipe, A3 fixtures 41/41,
`check_core` green). On this branch — verify with `git log --oneline` before you start.

## Where you work

Worktree `/workspaces/motoko_agent-skills`, branch `feat/skills-extension` (verify with
`git rev-parse HEAD` and `git branch --show-current`; record the HEAD). Your `cwd` is
that worktree root. Do not touch the shared checkout at `/workspaces/motoko_agent`,
the worktrees `/workspaces/motoko_agent-fix3`, `/workspaces/motoko_agent-cgraph-iface`,
or any other session's panes, tabs or paths. Push nothing.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §5 P6, G2.
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — **D13** (four
   profiles, omitted lists, version changes), **D11** (NOT in default in v1 — you add
   `skills` to the four DST profiles' omitted lists with its measured reason; default
   membership waits for G2), **A7/A8** (gates, stated position).
3. `.agent/projects/037_skills_system/evidence/baseline/BASELINE.tsv` (P0) and
   `evidence/p5/GATES.tsv` (P5) — your comparators. P5's known state: three gates
   (`driver_plus_no_ops`, `driver_plus_compose`, `declared_vs_performed`) name
   `skills` in their pre-existing `ailang_tools` failure. **P6's job is to clear
   exactly this**: after the repair, those failures must not name `skills`.
4. The four DST profile files: `src/core/dst_driver_only.ail:957`,
   `dst_driver_plus_no_ops.ail:635`, `dst_driver_plus_compose.ail:686`,
   `dst_driver_plus_herdr.ail:303` (re-ground line numbers with grep).
5. The P5 report (orchestrator holds it): wiring diff, fixture suite, the
   `motoko_ext_abi`/`test_dummy` lock refreshes (another branch running `ailang lock`
   touches the same lines — if `git status` shows other fingerprints, stop and report).

## What you build, in this order (two changes, not one)

1. **Repair, as its own commit**: give `ailang_tools` its place in the four profile
   lists (install or omit with reason, per D13's rules). Each profile's version
   changes with it (009 ADR-001 line 1287: omitted-list membership is semantic scope).
2. **Then re-pin**: add `skills` to all four omitted lists with its measured reason
   (P1 numbers: load 88–100%, follow 53/54, reload 0 under structural / 1 under AI,
   7/7 families accept 16k), change each profile version, move the inventory fixtures
   and `declared_vs_performed`'s arms and counts.

Every moved pin is checked against the P0 baseline: a gate red before may not gain a
failure; the three P5 failures must no longer name `skills`. `driver_plus_herdr` is
green at baseline despite `DST_KNOWN_RED` (P0) — a later red on it is a new failure;
do not "fix" the stale entry (another owner's decision).

## Rules that bind you

- Touch only: the four DST profile files (+ versions), inventory fixtures, the
  `declared_vs_performed` arms/counts, and your evidence. No default-profile change
  (G2), no package/src changes beyond pins.
- Heavy runs one at a time. No credentials in any file or output.
- Commit on `feat/skills-extension` as you go (repair commit first, then re-pin);
  push nothing.

## What to send back

In your completed answer AND in the answer file (WriteFile first): files changed with
`git status --short` / `git diff --stat`, every moved pin with its gate result (exit
codes, verbatim tails), the baseline comparison (no new red; `skills` unnamed in the
three failures), commits made, and anything that could not run and why.
