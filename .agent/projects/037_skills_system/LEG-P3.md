# LEG-P3 — the package, pure parts (PLAN-001 §5 P3, dagr task `P3`)

You are a delegate of the 037 orchestrator, invoked through the `Delegate` tool. You own
exactly this task. You do not implement any other part, you do not edit the ADR or the
plan, you do not write any dagr run file, and you do not touch other panes, tabs or
worktrees.

## What this is

`P3` in `PLAN-001-implement-adr-001.md` §5: the pure, filesystem-free core of
`packages/motoko-ext-skills/` — every rule as a function over a listing and file
contents, with inline tests. No `register.ail` wiring (that is P4), no registry/CI
changes (P5), no profile re-pinning (P6).

Done when the package's inline tests are green (`ailang test` on the package), covering
each rule below plus A6b as pure tests over both compactors.

## Where you work

Worktree `/workspaces/motoko_agent-skills`, branch `feat/skills-extension` (verify with
`git rev-parse HEAD` and `git branch --show-current` before you start; record the HEAD).
Your `cwd` is that worktree root. Do not touch the shared checkout at
`/workspaces/motoko_agent`, the worktrees `/workspaces/motoko_agent-fix3`,
`/workspaces/motoko_agent-cgraph-iface` (the p1proto scratch worktree is gone —
removed at G1), or any other session's panes, tabs or paths. Push nothing.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §5 P3.
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — **D1** (R1, V1–V8,
   the refusal message naming every violation with path and rule), **D3** (what is
   checked: two required fields, ASCII names, decoder rejects what JSON cannot
   represent), **D4** (index: `- <name>: <description>` in name order, whitespace
   collapsed, 16,000-char total budget V8), **D8 as revised 2026-10-04** (size check:
   25% of the **declared** window on the JSON-encoded envelope; the "never cut"
   guarantee is struck — a skill passing the check can still be capped when the working
   limit is much smaller; V7 at about 60,000 chars), **D9** (frontmatter block shape,
   `std/yaml.decode`, V4's four cases), **A6b** (each side tested with the limit it is
   actually given — handler declared, compactor working).
3. `src/core/ext/registry_normalize.ail` — P2's `registration_refusal_key` /
   `read_registration_refusal` (your refusal message feeds this key; reuse the exact
   string, do not redefine it).
4. The P1 prototype's rules (from the P1.2/P1.3 reports, which your orchestrator
   holds): frontmatter extraction, V4–V7 call-time validation, whitespace collapsing,
   name-order index, 25% boundary exactness (24% loads, 25.0% errors), D12 no-skills
   text. Reuse the shapes; this is the production version, not a copy.
5. The inventories' constraints (re-ground before writing, per the plan): no
   `import std/x as X`, no helper named with a leading underscore, no `*E` list
   functions, typed port receivers only. Your module must already respect these —
   P4 inherits your file.

## What you build

In `packages/motoko-ext-skills/` (new package; manifest + lock as the tree's other
extension packages do it):

- **Frontmatter extraction**: text between first-line `---` and next `---` (one BOM
  ignored, CR-tolerant delimiter), decoded by `std/yaml.decode`.
- **Rules R1, V1–V8** as pure functions over a directory listing + file contents:
  R1 (non-directory `skills` entry: file, workdir-leaving symlink, absolute-target
  symlink); V1 (directory without `SKILL.md`); V2 (neither file nor directory);
  V3 (unreadable — representable as a read-error marker in the listing);
  V4 (four sub-cases); V5 (naming rule 1–64 `[a-z0-9-]`, no leading/trailing/doubled
  hyphen, matches directory; digits-only names decode non-string and refuse);
  V6 (missing/non-string/blank-trimmed/over-1024 description);
  V7 (JSON-encoded envelope length over ~60,000); V8 (index lines over 16,000).
  Not refused: regular root files, extra frontmatter keys, oversized bodies.
- **Index builder**: name order (`listDir` is sorted — assert it), whitespace
  collapsed to single spaces, budget enforced.
- **Size estimate**: on the encoded envelope, compactor arithmetic (chars over 4),
  25%-of-declared-window threshold, load-when-unknown(0) — per revised D8.
- **Refusal message**: every violation, each with path and rule, in one message
  (feeds P2's `registration_refusal` key).
- **A6b as pure tests over both compactors**, with each side given its real limit.

Inline tests for each rule, including the M5 edge shapes (duplicate key, tab indent,
`key: a: b`, `name: 123`, CRLF, BOM, anchors — see `evidence/m5_yaml_probe.sh`).

## Rules that bind you

- Touch only `packages/motoko-ext-skills/` (no `register.ail` yet — types + pure
  functions + tests only) and your evidence. Do NOT wire the root manifest, lock,
  generated registry, profiles, or CI.
- Heavy runs one at a time. No credentials in any file or output.
- Commit on `feat/skills-extension` as you go (small commits); push nothing.

## What to send back

In your completed answer AND in the answer file (WriteFile first): files created with
`git status --short` / `git diff --stat`, `ailang test` results with exit codes and
verbatim tails, the commits you made, and anything that could not run and why. Name
any rule whose wording you found ambiguous (rule text wins; report, don't reinterpret).
