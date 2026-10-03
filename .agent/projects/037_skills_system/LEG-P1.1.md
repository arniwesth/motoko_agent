# LEG-P1.1 — the `std/yaml` check (PLAN-001 P1.1, settles Q1)

You are a delegate of the 037 orchestrator (pane `w8:p1`). You own exactly this task. You do not
implement any other part, you do not edit the ADR or the plan, you do not write the dagr run file,
and you do not touch other panes, tabs or worktrees.

## What this is

`P1.1` in `PLAN-001-implement-adr-001.md` §3. **Settles Q1**: do the inventories accept an
extension that imports `std/yaml`? ADR D9 decodes frontmatter with `std/yaml.decode`, but nothing
under `src/core`, `scripts` or `packages` imports `std/yaml` today, so there is no precedent to
read the answer from. If the closure is unresolved or rejected, **stop** — D9 returns to the
operator with the output, and the fallback is the subset parser of ADR v0.1. Do not design around
a rejection.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §0 standing rules, §3 P1.1.
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — **D9** (what `std/yaml` must do),
   D2 (the registration shape you must keep: literal `{ config, caps }`, named top-level payloads
   in `register.ail`).
3. `.agent/projects/037_skills_system/evidence/m5_yaml_probe.sh` — `std/yaml.decode` already works
   on frontmatter shapes; reuse, do not rewrite.
4. `packages/motoko-ext-test-dummy/register.ail` — the registration shape the gates require
   (literal caps, named top-level functions). Your probe module follows it.
5. `tools/ext_ambient_inventory/derive.py` — what `ext_ambient_inventory` and `ext_hook_scope`
   measure (closure over `std/*` ifaces; unresolved modules surface as needed-but-not-resolved).

## Where you work

**In a scratch worktree on a scratch branch, never in the shared checkout.** The orchestrator will
create it for you — ask for it in your first message if it is not ready. The worktree is cut from
`feat/skills-extension` so it builds on the same base; its code is throwaway and is never merged.
Only the results (your envelope, and any tables the orchestrator promotes) are committed on
`feat/skills-extension`.

Concretely: a registration-shaped module that imports `std/yaml (decode)`, wired into the
**worktree's** root manifest / lock / generated registry only (`ailang lock`, `make registry_gen`
in the worktree — never the shared tree's `ailang.lock` or `registry_generated.ail`), then run:

- `make ext_ambient_inventory`
- `make ext_hook_scope`
- `make profile_definition`

## Rules that bind you

- Do not edit `src/`, `packages/`, `tools/` or `scripts/` outside the probe module and the
  worktree-only wiring the probe needs. Do not touch the shared checkout at
  `/workspaces/motoko_agent`, the worktree `/workspaces/motoko_agent-fix3`, or other sessions'
  panes, tabs or paths.
- Heavy runs one at a time; these three targets are light, but say before you run anything slow.
- No credentials in any file or output.

## Done when

The three gates have been run on the wired probe and you report, with the verbatim output:

- whether `std/yaml` resolves in the closure and whether each gate stays green;
- if rejected or unresolved: the exact rejection with its output, and STOP — that sends D9 back
  to the operator.

## What to send back

A typed result envelope to the orchestrator (pane `w8:p1`): files touched (worktree paths only),
commands run with exit codes and output excerpts, the verdict on Q1, and what could not run.
