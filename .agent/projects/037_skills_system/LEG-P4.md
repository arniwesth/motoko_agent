# LEG-P4 — the package, wiring (PLAN-001 §5 P4, dagr task `P4`)

You are a delegate of the 037 orchestrator, invoked through the `Delegate` tool. You own
exactly this task. You do not implement any other part, you do not edit the ADR or the
plan, you do not write any dagr run file, and you do not touch other panes, tabs or
worktrees.

## What this is

`P4` in `PLAN-001-implement-adr-001.md` §5: the effectful shell around P3 — discovery,
the `config` record, the catalogue, and the handler — in
`packages/motoko-ext-skills/register.ail` and its manifest. Done when the package
checks and the shape and call inventories (`ext_hook_scope`, `ext_call_inventory`)
are green on it.

Depends on P2 (landed: host refusal + Amendment 5) and P3 (landed: pure core,
`skills.ail` + `a6b_test.ail`, 73/73 green). Both are on this branch — verify with
`git log --oneline` before you start.

## Where you work

Worktree `/workspaces/motoko_agent-skills`, branch `feat/skills-extension` (verify with
`git rev-parse HEAD` and `git branch --show-current`; record the HEAD). Your `cwd` is
that worktree root. Do not touch the shared checkout at `/workspaces/motoko_agent`,
the worktrees `/workspaces/motoko_agent-fix3`, `/workspaces/motoko_agent-cgraph-iface`,
or any other session's panes, tabs or paths. Push nothing.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §5 P4.
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — **D7** (bare relative
   root, layout-1 scope), **D10** (call-time validation, directory line, `file_read`
   port; unreadable-at-call ends the runtime — stated, not built), **D2** (fail-safe:
   with a refusal recorded, catalogue lists no skills, every call returns the refusal),
   **D12** (no-skills text), **A6** (stub-port tests: present file, absent file,
   world-changing port), **A9** (call-time cases).
3. `packages/motoko-ext-skills/skills.ail` — P3's pure core. Call it; do not reimplement
   it. Notes from the P3 report (orchestrator holds it): `registration_refusal_key()`
   is exported for P5's same-string row (replace the stand-in there, not here);
   `load_skill(dir_name, text, call_id, declared_limit)` already takes the call id for
   V7; manifest `[effects] max` anticipates the `ToolProvider` row — confirm or correct.
4. The P1.2 report (orchestrator holds it): the prototype's `register.ail` shape that
   passed the gates — literal `{ config, caps }` tail, named top-level payloads, no
   `show`/interpolation/`intToFloat` in hook-reachable text, `concat` + `intToStr`.
5. Re-ground the research's M4 survey of what the inventories reject before writing:
   no `import std/x as X`, no leading-underscore helpers, no `*E` list functions,
   typed port receivers only. Plus the P3 finding: `std/list.zipWith` fails under
   `ailang test` but works under `ailang run` (v0.47.2) — route or avoid; filing
   upstream is the operator's call.

## What you build

- **Discovery** (`! {FS}`): `isDir` → `listDir` → `readFileResult` over
  `.motoko/skills`, building P3's listing data; `config` = index + sandbox-set flag +
  refusal (if any). Un-sandboxed launch with `ctx.workdir != "."` → handler tool-errors
  instead of loading (D7).
- **Catalogue**: one `Skill` schema from `config` via P3's index functions; D12
  no-skills text; fail-safe empty catalogue when a refusal is recorded.
- **Handler** (`["Skill"]`): name validation against the index; read through
  `ctx.ports.file_read`; P3 call-time validation + D8 size check + fail-safe refusal
  error. A6 stub-port tests; A9 call-time cases.
- Manifest effects row as the handler needs (check P3's anticipation).

Gates: `ailang check` + `ailang test` on the package; `make ext_hook_scope`,
`make ext_call_inventory`, `make ext_ambient_inventory`, `make profile_definition` —
`skills` row must be `config-caps pass` (ext_hook_scope stays red only on test_dummy's
pre-existing row); no newly-red gate vs P2's `evidence/p2/GATES.tsv`.

## Rules that bind you

- Touch only `packages/motoko-ext-skills/register.ail`, its manifest/lock, and your
  evidence. Do NOT wire the root manifest, generated registry, profiles, or CI (P5).
- Heavy runs one at a time. No credentials in any file or output.
- Commit on `feat/skills-extension` as you go (small commits); push nothing.

## What to send back

In your completed answer AND in the answer file (WriteFile first): files changed with
`git status --short` / `git diff --stat`, package checks + the four inventory gates
with exit codes and verbatim tails, commits made, and anything that could not run and
why. Name any ADR wording you found ambiguous (text wins; report, don't reinterpret).
