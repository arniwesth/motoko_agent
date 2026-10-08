# LEG-P5 — registry wiring and the CI recipe (PLAN-001 §5 P5, dagr task `P5`)

You are a delegate of the 037 orchestrator, invoked through the `Delegate` tool. You own
exactly this task. You do not implement any other part, you do not edit the ADR or the
plan, you do not write any dagr run file, and you do not touch other panes, tabs or
worktrees.

## What this is

`P5` in `PLAN-001-implement-adr-001.md` §5: wire the finished package into the tree —
root manifest, lock, `make registry_gen`, one named profile — plus the two CI recipe
changes and the refusal fixtures. Done when `check_core` is green and the refusal
fixtures pass.

Depends on P2 (host refusal + Amendment 5, landed) and P4 (package + handler, landed:
`register.ail` 764 lines, 91/91 tests, `skills` row `config-caps pass` in a wired
clone). Both are on this branch — verify with `git log --oneline` before you start.

## Where you work

Worktree `/workspaces/motoko_agent-skills`, branch `feat/skills-extension` (verify with
`git rev-parse HEAD` and `git branch --show-current`; record the HEAD). Your `cwd` is
that worktree root. Do not touch the shared checkout at `/workspaces/motoko_agent`,
the worktrees `/workspaces/motoko_agent-fix3`, `/workspaces/motoko_agent-cgraph-iface`,
or any other session's panes, tabs or paths. Push nothing.

**Shared-file caution.** The root `ailang.toml`, `ailang.lock`, and
`src/core/ext/registry_generated.ail` are tree-shared files that other sessions'
worktrees also derive. P4's report holds the exact wiring diff (`WIRING.diff`: two
lines in root `ailang.toml`, regenerated lock, two lines of `registry_gen` output) —
reuse it. If `git status` shows anyone else's fingerprints on those files, stop and
report rather than merging past them.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §5 P5.
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — **D1** (the two
   `verify_extensions` recipe changes: run under the sandbox with
   `AILANG_FS_SANDBOX` set to the repo root, and print the rejection), **A1/A2**
   (one tool, one index; digests), **A3** (refusal fixtures per rule, run under the
   sandbox; controls that must start), **D2** (the same-key row: replace P2's
   stand-in literal with P3's exported `registration_refusal_key()`).
3. `.agent/projects/037_skills_system/evidence/p4/gates/wired/WIRING.diff` — the exact
   wiring P4 validated.
4. `Makefile:2839` (the `verify_extensions` recipe) and
   `scripts/verify_extension_boot.ail:60` (the registration path it boots through).
5. The P4 report (orchestrator holds it): discovery probe results (every rule refuses
   through real `std/fs`; controls start), the refused-catalogue sentence (P4's own
   wording vs D12's — noted as one-line change if wanted; leave as built), the D7
   `""`/`"./"` vs `"."` reading (reported, not decided — leave as built).

## What you build

- **Wiring**: root `ailang.toml` + `ailang lock` + `make registry_gen` (P4's diff);
  one named profile enabling `skills` (modelled on the P1 `skills_proto` shape, as a
  real tree profile, not `/tmp`).
- **CI recipe**: `verify_extensions` sets `AILANG_FS_SANDBOX` to the repo root and
  prints the rejection (currently hides lower-case JSONL `error` lines).
- **Refusal fixtures** (A3, under the sandbox): R1 ×3, V1–V8 incl. V4 ×4, two-violation
  case, must-start controls (no root; valid set incl. every D9 scalar style + a
  malformed optional field). P4's probe already proved every rule refuses through
  real `std/fs` — promote that shape into fixtures.
- **A1/A2**: one `Skill` schema checks; digest behaviour (index change moves
  `ext_config_digest`, resume continues; body-only edit moves nothing).
- **Same-key row**: import P3's `registration_refusal_key()` in place of P2's
  stand-in literal.
- The P2 delegate noted the amendment sentence "which can import both sides" is true
  of the script today and of the row only at P5 — now true; leave the sentence.

Gates: `make check_core` green; refusal fixtures pass; no newly-red gate vs
`evidence/p2/GATES.tsv` (P4's `evidence/p4/` holds the wired-tree gate logs to compare
against).

## Rules that bind you

- Touch only: root `ailang.toml`/`ailang.lock`, `registry_generated.ail`, the named
  profile dir, the `verify_extensions` recipe + boot script, the A3 fixtures, the
  same-string row, and your evidence. No default-profile membership (D11 — G2 rules),
  no DST profile re-pinning (P6).
- Heavy runs one at a time. No credentials in any file or output.
- Commit on `feat/skills-extension` as you go (small commits); push nothing.

## What to send back

In your completed answer AND in the answer file (WriteFile first): files changed with
`git status --short` / `git diff --stat`, `check_core` + fixture results with exit
codes and verbatim tails, commits made, and anything that could not run and why.
