# LEG-P1.2 — the prototype extension (PLAN-001 P1.2, dagr task `P1.2`)

You are a delegate of the 037 orchestrator, invoked through the `Delegate` tool. You own
exactly this task. You do not implement any other part, you do not edit the ADR or the plan,
you do not write any dagr run file, and you do not touch other panes, tabs or worktrees.

## What this is

`P1.2` in `PLAN-001-implement-adr-001.md` §3: the throwaway prototype that P1.3 measures.
Prototype quality, valid fixtures only, no refusal path. Its acceptance (from the plan's
task criteria): in the worktree only — the package, the root manifest, ailang lock, make
registry_gen, and a profile `skills_proto`. Registration keeps the gated shape (literal
`{config, caps}`, named payloads in register.ail). The handler prepends the directory line
`.motoko/skills/<name>` and applies the 25% size check. A session under `skills_proto`
lists the fixture skills.

## Where you work

Worktree `/workspaces/motoko_agent-p1proto`, scratch branch `scratch/p1-prototype`
(verify with `git rev-parse HEAD` and `git branch --show-current` before you start). Your
`cwd` is that worktree root. Its code is throwaway and is never merged; only the results
are promoted. Do not touch the shared checkout at `/workspaces/motoko_agent`, the
worktrees `/workspaces/motoko_agent-skills` and `/workspaces/motoko_agent-fix3`, or any
other session's panes, tabs or paths. Push nothing. Commit nothing — neither on the
scratch branch nor on `feat/skills-extension`.

The P1.1 probe (`packages/motoko-ext-yaml-probe/`) is already wired in this worktree
(uncommitted: `ailang.toml`, `ailang.lock`, `src/core/ext/registry_generated.ail`
modified, probe package untracked). Leave it alone; build alongside it. Do not remove it.

## Ground truth to read first, in this order

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §0 standing rules, §3 P1.2.
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — **D7** (bare relative root
   `.motoko/skills`), **D4** (index: `- <name>: <description>` lines in name order,
   whitespace collapsed, `enum` of names), **D8** (size check: estimate tokens of the
   JSON-encoded envelope as chars/4, tool error at 25%+ of `ctx.context_limit`, load when
   limit unknown/0), **D10** (directory line `.motoko/skills/<name>`, handler validates
   every call, reads through `ctx.ports.file_read`), **D12** (with no skills: one `Skill`
   schema that says so, no `enum`).
3. `packages/motoko-ext-yaml-probe/register.ail` in this worktree — the P1.1 delegate's
   probe. Reuse its frontmatter/discovery/decoding shape (`frontmatter`, `index_entry`
   over `std/yaml.decode`, literal `{ config, caps }` tail). Its report (your orchestrator
   holds it) adds: `++` is list-only (use `concat`/`join`/interpolation); avoid `show` and
   interpolation in hook-reachable text (or the hook walk marks it HOOK-UNRESOLVED — report
   only, does not gate); do NOT copy `test_dummy`'s tail (`if … then {config, caps: []}`
   fails the registration-shape gate — put the literal record at the tail, as
   `ailang_tools` does).
4. `packages/motoko-ext-mcp/register.ail:27` — one extension, many discovered things
   carried in `config` (the precedent). `packages/motoko-ext-herdr/register.ail:230` — a
   directory scanned at registration.
5. `packages/motoko-ext-abi/types.ail:1943` (`DescribeTools`), `:1948` (`ToolProvider`),
   `:46` (`ToolSchema = { name, description, parameters }`).

## What you build

`packages/motoko-ext-skills/` in this worktree (prototype quality):

- **Discovery** over the bare relative root `.motoko/skills`: `isDir`, then `listDir`,
  then `readFileResult` per `<entry>/SKILL.md`, then `std/yaml.decode` on the frontmatter.
  Valid fixtures only — no refusal path (a broken skill may be skipped or error; do not
  build the D1/D2 refusal machinery).
- **`DescribeTools` catalogue**: one `Skill` schema; description is the fixed instruction
  plus one `- <name>: <description>` line per skill in name order (whitespace collapsed);
  `name` parameter with the `enum` of discovered names. With no skills: description says
  so, no `enum` (D12).
- **`ToolProvider` handler** (`["Skill"]`): validates the name against the index (unknown
  name → tool error listing valid names), reads through `ctx.ports.file_read`, validates
  what it read (same V4–V7 rules as discovery), prepends the directory line
  `.motoko/skills/<name>`, applies D8's 25% size check on the JSON-encoded envelope
  (chars/4; error says the skill does not fit this model's context; load when limit is 0).
- **Wiring in this worktree only**: root `ailang.toml` + `ailang lock` + `make
  registry_gen`, and a config profile `skills_proto` (new directory under
  `.motoko/config/skills_proto/`, modelled on `.motoko/config/dogfood/`: `config.json`
  naming `skills` in `extensions.order`) that the session launches under.
- **Fixture skills** in a test workdir (NOT the worktree root): copies of two or three
  existing skills plus the shape P1.3 needs. Keep them outside the repo tree's own
  `.motoko/skills` so the prototype never indexes the repo itself.

Keep the gated shape throughout (literal `{ config, caps }`, named top-level payloads in
`register.ail`) so P1.1's answer carries over. Check `ailang check` on the package, then
`make registry_gen_check`, `make ext_ambient_inventory`, `make ext_hook_scope`,
`make profile_definition` — the first three gates from P1.1 must not newly fail because
of the prototype (ext_hook_scope stays red only on test_dummy's pre-existing row).

Done when: a session launched under `skills_proto` and pointed at the fixture workdir
lists the fixture skills in the `Skill` description (paste the description verbatim in
your reply as proof). Launch it the way the tree does (`./scripts/run-agent.sh` with the
profile's config, or the headless form `scripts/probe_budget_continue.sh` uses) — a
listing-only check, not a full task run; that is P1.3's job.

## Rules that bind you

- Touch only this worktree: the new package, fixture workdir files if inside the
  worktree (prefer `/tmp` for the fixture workdir to keep `git status` clean), and the
  worktree-local wiring (root manifest/lock/generated registry, the new profile dir).
- Commit nothing. Heavy runs one at a time. No credentials in any file or output. No
  model-costly runs beyond the one listing session — P1.3's measurement runs need the
  operator's spend go-ahead first (Q-SPEND) and are NOT this task.

## What to send back

In your completed answer AND in the answer file (use WriteFile for the answer file before
replying): files created/modified (this worktree's paths only), the `Skill` description
verbatim from the listing session, gate outputs (`registry_gen_check`,
`ext_ambient_inventory`, `ext_hook_scope`, `profile_definition`) with exit codes, the
HEAD you ran at with `git status --short` / `git diff --stat`, and anything that could
not run and why.
