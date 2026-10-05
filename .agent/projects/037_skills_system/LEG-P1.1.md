# LEG-P1.1 — the `std/yaml` check (PLAN-001 P1.1, dagr task `P1.1`, settles Q1)

You are a delegate of the 037 orchestrator, invoked through the `Delegate` tool. You own
exactly this task. You do not implement any other part, you do not edit the ADR or the plan,
you do not write any dagr run file, and you do not touch other panes, tabs or worktrees.

## What this is

`P1.1` in `PLAN-001-implement-adr-001.md` §3. **Settles Q1**: do the inventories accept an
extension that imports `std/yaml`? ADR D9 decodes frontmatter with `std/yaml.decode`, but
nothing under `src/core`, `scripts` or `packages` imports `std/yaml` today, so there is no
precedent to read the answer from. If the closure is unresolved or rejected, **stop** — D9
returns to the operator with the output, and the fallback is the subset parser of ADR v0.1.
Do not design around a rejection.

## Where you work

Worktree `/workspaces/motoko_agent-p1proto`, scratch branch `scratch/p1-prototype`, HEAD
`e483c2a8` (cut from `feat/skills-extension`; the orchestrator re-pointed it there on
2026-10-03 — verify with `git rev-parse HEAD` and `git branch --show-current` before you
start). Your `cwd` is that worktree root. Its code is throwaway and is never merged; only
the results are promoted. Do not touch the shared checkout at `/workspaces/motoko_agent`,
the worktrees `/workspaces/motoko_agent-skills` and `/workspaces/motoko_agent-fix3`, or any
other session's panes, tabs or paths. Push nothing.

The scratch worktree is a fresh checkout with no installed dependencies or build output.
Allow for that (install/build the way the tree's own docs say) and record what you did; a
red that means "want of a build" is not an inventory verdict.

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

## What you build

A registration-shaped probe module that imports `std/yaml (decode)`, wired into **this
worktree's** root manifest / lock / generated registry only (`ailang lock`,
`make registry_gen` in this worktree — never the shared tree's `ailang.lock` or
`registry_generated.ail`, and nothing committed on `feat/skills-extension`), then run from
this worktree root:

- `make ext_ambient_inventory`
- `make ext_hook_scope`
- `make profile_definition`

Keep the gated shape even in the probe (literal `{ config, caps }`, named top-level
payloads in the probe's register file) so the answer carries over to P1.2.

## Rules that bind you

- Touch only this worktree, and only the probe module plus the worktree-local wiring the
  probe needs. Commit nothing — neither on the scratch branch nor on
  `feat/skills-extension`. The delegate's word for "committed" in this task is the reply,
  not a commit.
- Heavy runs one at a time; these three targets are light, but say in your reply before
  anything slow would run.
- No credentials in any file or output.

## Done when

The three gates have been run on the wired probe and you report, with the verbatim output:

- whether `std/yaml` resolves in the closure and whether each gate stays green;
- if rejected or unresolved: the exact rejection with its output, and STOP — that sends D9 back
  to the operator.

## What to send back

In your completed answer to the orchestrator (plain structured text — no pane, no typed
envelope): files touched (this worktree's paths only), commands run with exit codes and
verbatim output excerpts, the verdict on Q1, and what could not run and why. Include the
HEAD you ran at and the wiring diff (`git status --short`, `git diff --stat`) so the
orchestrator can reproduce it.
