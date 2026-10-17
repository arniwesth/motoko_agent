# AILANG public documentation site and how it is kept true

Survey of `sunholo-data/ailang`, branch `dev`, commit `2a1f3f295` (2026-10-03). Read-only.
All paths are relative to the clone root unless stated. `path:line` refers to that commit.

Conventions in these notes:

- **OBSERVED** means I read it in a file, or measured it with a read-only command on the clone.
- **INFERRED** means my conclusion from observations. The reasoning is given so it can be checked.
- **LIVE** means a read-only call on 2026-10-04 to the hosted MCP server (`mcp.ailang.sunholo.com`).
  That server is a deployed build, not necessarily this commit.

Limits of this survey: the clone is shallow (one commit), so no file history or dates from git were
available. Files outside the sparse checkout (`make/`, `tools/`, `.github/`, `mcp_tools/`) were read
with `git show HEAD:<path>`. No CI logs were available, so every statement about what CI does is from
workflow text, not from a run.

---

## 1. How the site is organised, and for whom

### 1.1 Shape

- OBSERVED. A Docusaurus site at `https://ailang.sunholo.com` (`docs/README.md:3-5`,
  `docs/docusaurus.config.js:22`). Docs are served under `/docs` (`docusaurus.config.js:134-135`).
  The blog is off (`docusaurus.config.js:141`).
- OBSERVED. Published content is `docs/docs/` only: 147 `.md`/`.mdx` files, 68,402 lines. The other
  47 of the 194 markdown files under `docs/` are not part of the site: `docs/README.md`,
  `VISION.md`, `LIMITATIONS.md`, `TESTING.md`, `docs-sync-findings.md`,
  `talk-building-a-language.md`, and the directories `docs/internal/` (9), `docs/guides/` (2),
  `docs/reference/` (1), `docs/testing/` (1), `docs/sprint-retros/` (25 md) and `docs/static/` (3).
- OBSERVED. Size by section of `docs/docs/` (files / lines): `guides/` 73 / 29,933; `prompts/`
  13 / 25,511; `reference/` 26 / 5,696; `references/` 4 / 1,075; `architecture/` 5 / 855;
  `benchmarks/` 8 / 438; `recipes/` 2 / 508; `start-here/` 3 / 109; top-level pages 8 / 3,477, of
  which the generated `design-docs.md` is 1,581.
- OBSERVED. The sidebar is hand-written in `docs/sidebars.js:23-286`, with one generated insert, the
  registry package list (`sidebars.js:14-20`, `:156`). It has six top-level groups: Start Here
  (`:25-40`), Learn AILANG (`:41-76`), For AI Agents (`:77-113`), Reference (`:114-160`), Build &
  Operate (`:161-245`), Internals & Vision (`:246-285`). Measured with the mission's own command
  (`design_docs/docs-mission.md:340`) at HEAD: `{top: 6, categories: 23, entries: 155, depth: 4}`.
  38 of the 155 entries and one category come from the generated package list.
- OBSERVED. The navbar has ten items (`docusaurus.config.js:160-212`), including an `llms.txt` link
  (`:203-206`).
- OBSERVED. 29 pages exist on disk but are in no sidebar entry: the ten historical prompt pages and
  `prompts/python`, six `reference/errors/*`, five `reference/std-*`, `reference/option-vs-result`,
  two `recipes/*`, `guides/agent-tool-policy`, `guides/mission-iteration`,
  `guides/mission-role-dispatch`, `examples/ai-api-integration`. (Compared the ids in `sidebars.js`
  with the file list. They may still be linked from other pages; I did not check inbound links.)

### 1.2 Audiences

The site names its audiences explicitly on three entry pages linked from the home page
(`docs/docs/intro.mdx:69-73`).

| Audience | Entry point | What it gets |
|---|---|---|
| Human users | `docs/docs/start-here/quick-start.mdx:11` "You're a human developer who wants to try AILANG" | Playground, examples, install, editor setup; the "Learn AILANG" group (`sidebars.js:41-76`) |
| People evaluating | `docs/docs/start-here/evaluating.mdx:12` | Implementation status, limitations, roadmap, benchmark dashboard, design rationale |
| Agents writing AILANG | `docs/docs/start-here/for-ai-agents.mdx:23-30` "I'm an AI agent reading this directly" | Hosted MCP, the current teaching prompt, `llms.txt`, the `ai` effect guide; the "For AI Agents" group (`sidebars.js:77-113`) |
| Humans configuring such agents | `for-ai-agents.mdx:14-21` | Agent onboarding, hooks setup, MCP |
| Agents (and people) working on AILANG itself | "Internals & Vision → Contributors" (`sidebars.js:274-282`), `design-docs` (`:283`), `roadmap/index` (`:252`), "Workflows" (`:103-111`) | `guides/development-workflow.md` (design doc → sprint plan → sprint execution, three skills, `:8`), the generated design-doc index and roadmap, mission guides |

- OBSERVED. `docs/VISION.md:303-313` ranks audiences: primary "AI Code Generators … Autonomous
  Agents … Multi-Agent Systems", secondary "Researchers … Tool Builders … Curious Humans".
- OBSERVED. Material for agents working on AILANG is mostly not on the site. It is in `CLAUDE.md`,
  `.claude/rules/`, `.claude/skills/` and `design_docs/` (already known), and in the unpublished
  `docs/internal/` runbooks. The public "Contributors" group is three pages.
- Existence only, not analysed (other agents own them): `guides/coordinator*.md`,
  `guides/agent-messaging.md`, `guides/cloud-messaging-integration.md`,
  `guides/collaboration-hub.md`, `guides/mission-bootstrap.md`, `guides/mission-model-fleet.md`,
  `guides/mission-iteration.md`, `guides/mission-role-dispatch.md`.

Pages I was asked to read, in one line each:

- `guides/development-workflow.md`: the three-skill workflow, the autoclose guard (`:250-261`), and
  test-determinism rules (`:282-350`). Two statements conflict with a CI gate, see section 8 item R4.
- `guides/state-system-workflow.mdx`: messaging + sprint JSON + skills as persistence across
  sessions. All examples are dated 2025-11 and `v0_4_2` (`:55`, `:118`, `:274`).
- `guides/agent-workflows.mdx`: four coordinator handoff workflows. Footer says "Last updated: March
  2026 (v0.9.0)" (`:382`).
- `guides/claude-code-integration.mdx`: a 105-line hub page that states its own scope: "the pages it
  links own the details" (`:11-13`) and has a "Where the Details Live" table (`:82-91`).
- `guides/agent-mcp.md`: the hosted MCP server, see 1.4.

### 1.3 `llms.txt`

- OBSERVED. What it is: one text file "for LLM consumption" that concatenates README, selected docs
  and the teaching prompt (`llms.txt:1-5`). Three identical copies are tracked: `llms.txt`,
  `docs/llms.txt`, `docs/static/llms.txt` (125,478 bytes, 3,796 lines; `cmp` equal for the first two).
- OBSERVED. How it is produced: `tools/generate-llms-txt.sh` (`make generate-llms-txt`,
  `make/docs.mk:21-22`). It appends, in order: `README.md` (`:37-44`); `docs/index.md` if present
  (`:52-60`); four named guides from `docs/docs/guides/` (`:62-79`); every `docs/reference/*.md`
  (`:81-94`); the active prompt from `prompts/versions.json` (`:96-113`);
  `docs/reference/implementation-status.md` (`:115-123`); `examples/STATUS.md` (`:125-133`). It then
  copies the result to the repo root and to `docs/static/` (`:140-145`). `CHANGELOG.md` and
  `CLAUDE.md` are excluded on purpose (`:46-47`).
- OBSERVED. It is not regenerated by CI. The `docs` job in `ci.yml` runs the generator on pushes to
  `dev` but the commit step is commented out: "Disabled: Auto-commit causes race condition with test
  job / Run sync-prompts.sh and generate-llms-txt.sh manually before releases"
  (`.github/workflows/ci.yml:675-679`). The deploy workflow publishes the committed root file:
  `cp llms.txt docs/static/` (`.github/workflows/docusaurus-deploy.yml:222`).
- OBSERVED. The committed file says "Last updated: 2026-05-16T14:48:01Z" (`llms.txt:7`). Its sections
  are: README (`:12`), one guide, `wasm-integration.md` (`:197`), one reference file,
  `reserved-keywords.md` (`:1154`), "AI Teaching Prompt (Latest: v0.16.0)" (`:1341`), Examples
  Status (`:3705`).
- INFERRED. The generator's inputs have moved under it and it skips them silently. Three of the four
  named guides are now `.mdx` (`getting-started.mdx`, `ai-prompt-guide.mdx`, `module_execution.mdx`
  on disk) while the script looks for `.md` and guards with `if [ -f … ]` (`:65-67`). It reads
  `docs/reference/` (one file) and not `docs/docs/reference/` (26 files), so the language reference
  and `implementation-status.md` are not included. The active prompt is v0.16.6
  (`docs/src/constants/version.js:2`) but the file embeds v0.16.0.
- OBSERVED. The site describes it differently: "`llms.txt` — full corpus index in one file"
  (`for-ai-agents.mdx:29`) and "Agent fetches `llms.txt` (huge, no filter)" (`agent-mcp.md:17`).

### 1.4 The hosted MCP docs server

- OBSERVED. `mcp.ailang.sunholo.com/mcp/` is a public, anonymous, read-only server with "~21 typed
  tools" and one write tool, `submit_feedback` (`docs/docs/guides/agent-mcp.md:3`, `:22`). It is
  advertised in the page head with `rel="mcp"` (`docusaurus.config.js:84-94`). It is separate from
  the local execution MCP in `ailang_bootstrap` (`agent-mcp.md:7-9`).
- OBSERVED. Tool catalogue (`agent-mcp.md:51-100`): version-scoped language reference
  (`ailang_versions`, `prompt_get`, `stdlib_modules`, `stdlib_module`, `stdlib_search`,
  `effects_catalog`, `limitations_list`); examples (`examples_list`, `example_get`,
  `example_for_concept`); docs (`docs_nav`, `docs_search`); unscoped history (`design_docs_list`,
  `design_doc`, `roadmap`, `changelog_for_version`); benchmarks (four tools); `submit_feedback`.
- OBSERVED. The tools are AILANG modules in `mcp_tools/` that read JSON from a snapshot directory
  (`mcp_tools/lib.ail:3-12`). The snapshot is built by `tools/build-snapshot/main.go` and "baked into
  the Cloud Run image at build time so each revision is a frozen point in time" (`agent-mcp.md:137`).
  The served version comes from `std/VERSION` (`tools/build-snapshot/main.go:56-62`).
- OBSERVED. What the snapshot derives each answer from:
  - Design docs: the state is the directory name, one of `planned`, `implemented`, `rejected`, and the
    version is the second path component (`main.go:684-710`). The tool ignores its `state` and
    `version` arguments and returns the whole index (`mcp_tools/design.ail:13-14`).
  - Limitations: parsed from `docs/LIMITATIONS.md`. Every `## ` heading becomes one entry with
    `Status: "by-design"` hard-coded (`main.go:344-383`, the constant at `:374`). That file calls
    itself "a pointer + short summary; the website copy is authoritative" (`docs/LIMITATIONS.md:3-7`).
  - Docs search: every page under `docs/docs`, body "capped at 4 KB" (`main.go:965-968`).
  - Docs nav: "mirrors the on-disk directory structure" (`main.go:991-992`), not `sidebars.js`.
  - Prompt: the highest-numbered `v*.md` in `cmd/ailang/prompts/` (`main.go:392-393`).
  - Versions: the current version plus every prompt-file version (`main.go:510-534`).
  - Roadmap: `roadmap.json` is named in the layout comment (`main.go:23`) and read by the tool
    (`mcp_tools/design.ail:29-30`), but `buildUnscoped` has no step that writes it (`main.go:488-508`).
- LIVE. `roadmap` returns `{"detail": "missing:/srv/snapshot/unscoped/roadmap.json", "error":
  "snapshot_read_failed"}`. `limitations_list` returns four entries, all `"status": "by-design"`,
  titled "Open limitations (summary)", "Execution policy residuals", "Resolved (were documented as
  broken; re-verified working at v0.33.1)" and "Reporting New Limitations". `ailang_versions` returns
  `latest: "0.52.1"` and 53 versions, 0.2.0 to 0.16.6 then 0.52.1.
- INFERRED. So `agent-mcp.md:84` ("What's shipping next, what's been rejected and why") describes a
  tool that currently errors, and `:61` ("Known design limitations … optionally by category")
  describes a tool that returns page sections, one of them the list of resolved items, labelled as
  by-design limitations. `docs_nav` (`:75` "Sidebar tree as JSON") returns a directory tree that
  includes the 29 pages the sidebar omits. "Full-text search" (`:76`) covers the first 4 KB of each
  page; the mean page is about 465 lines.

---

## 2. How documentation is kept in step with code

Summary first. There are four kinds of mechanism, with very different strength:

1. **Generated from the code's own table, and gated in CI.** CLI reference, environment variables.
2. **Regenerated at site build, never committed.** Design-doc index, roadmap, current prompt,
   examples status table, version constants, registry package pages.
3. **Checked by a CI gate, with a self-test that proves the gate can fail.** Examples, changelog
   index, context docs, prompt freeze, prompt commands.
4. **Advisory scripts run by an agent.** The `docs-sync` scripts. They exit 0 whatever they find.

Everything else (the prose of 147 pages, 1,192 inline code blocks, `llms.txt`, hard-coded version
strings) has no mechanical check.

### 2.1 Table

| Mechanism | Where | What it guarantees | What it does not |
|---|---|---|---|
| CLI reference generated from the dispatch table | `make docs-cli`, `make check-cli-docs` (`make/code-health.mk:248-275`); page header `docs/docs/reference/cli.md:9-11`; CI step `ci.yml:370` | `reference/cli.md` is byte-equal to a fresh render of `cmd/ailang/commands.go`, and a second test asserts every route in the table is on the page (`code-health.mk:270-272`) | Nothing about the other pages that cite commands. The mission notes "CLI went 89 → 17 top-level commands; old names still resolve as routes" (`design_docs/docs-mission.md:352-353`) |
| Env-var reference generated from the config registry | `make docs-env` → `tools/gen-env-docs` (`make/docs.mk:24-25`); `docs/docs/reference/env-vars.md:9` "(243 variables). Do not edit" | The page is produced from `internal/config`. A metric `env_vars_documented_pct` "gates it at 100" (`.claude/skills/cli-doc-maintainer/SKILL.md:35`) | I found no workflow file that mentions `docs-env`, `gen-env-docs` or `simplicity-metrics`. Whether CI enforces it some other way is not verified |
| Prompt freeze | `make check-prompt-freeze` (`code-health.mk:236-237`), `ci.yml:361` | The prompt file's bytes have not changed (SHA256) | "structurally blind to the BINARY changing underneath it" (`code-health.mk:239-240`) |
| Prompt truth | `make check-prompt-commands` → `tools/check_prompt_commands.sh`, `ci.yml:368` | Every `ailang <cmd>` the devtools prompt teaches is a route the binary accepts | Only command names, only the devtools prompt |
| Version constants | `docs/scripts/generate-version-constants.sh`, run in the deploy workflow (`docusaurus-deploy.yml:233-234`); release step `update_version_constants.sh` (`.claude/skills/release-manager/SKILL.md:126-135`) | On the deployed site `STABLE_RELEASE` is the highest `v*.*.*` tag (the script exits 1 if there are no tags, `:16-23`) and `ACTIVE_PROMPT` is `.active` in `prompts/versions.json` (`:14`) | Only six files import the constants (`intro.mdx:9`, `guides/agent-integration.mdx:8`, `guides/getting-started.mdx:6`, `src/pages/index.jsx:26`, `start-here/for-ai-agents.mdx:8`, `start-here/evaluating.mdx:8`). 83 pages contain a hard-coded `v0.N.N` string (grep, excluding prompts, design-docs, roadmap). See 2.2 |
| Current prompt page | `docs/scripts/sync-active-prompt.sh` → `docs/docs/prompts/current.md`, in `sync-all` on every `npm start`/`npm run build` (`docs/package.json:7-12`) | The published "current prompt" is the active file from `prompts/versions.json` | The older prompt pages. `sync-prompts.sh` copies the active prompt and up to five `production`/`latest` versions (`:26`, `:44-50`) and never deletes, see section 8 item R6 |
| Design-doc index and roadmap | `docs/scripts/sync-design-docs.sh`, in `sync-all` | The two pages list what is in `design_docs/implemented/*/` and `design_docs/planned/*/` at build time | See section 4. Status is the directory, nothing else |
| Stdlib index drift guard | `docs/scripts/check-stdlib-index.sh`, in `sync-all` | If `ailang` is on `PATH`: the set of backticked `std/x` names in `reference/stdlib.md` equals `ailang docs --list`, both directions (`:28-59`); refuses an empty list (`:34-38`) | If `ailang` is not on `PATH` it prints "skipping drift check" and exits 0 (`:15-19`). INFERRED: this is the case in CI. The deploy workflow runs `make build`, which writes `bin/ailang` (`make/build.mk:21-25`), and no step adds `bin/` to `PATH` (no `GITHUB_PATH` in `docusaurus-deploy.yml`). The script header says it "fails the build" (`:2-4`) |
| Examples run | `make verify-examples` (`make/examples.mk:9-28`), CI `ci.yml:508`; self-test `verify-examples-gate-selftest` (`examples.mk:30-50`); manifest drift lint (`:23-28`) | Every file in `examples/runnable/` runs, pinned `expected.stdout` is compared, and a floor fails the gate if zero comparisons ran (added by docs-10, `docs-mission.md:450-456`) | Top-level `examples/*.ail`: `verify-examples-toplevel` exists (`examples.mk:73-79`) but no workflow file mentions it, nor `verify-cli-examples`. `make ci` lists it but "CI never invokes" `make ci` (`ci.yml` comment after the context-doc step) |
| Site examples are the tested files | `raw-loader` imports (`docs/docs/examples.mdx:8-21`, `intro.mdx:48-49`); webpack rule `docusaurus.config.js:105-122` | A page that imports `examples/runnable/x.ail` shows the file the gate ran | Measured: 73 such imports in 13 files, against 1,192 inline ` ```ailang ` fences in 55 files (excluding `prompts/`). Nothing runs the inline blocks. `check_examples.sh:93-108` only prints a count |
| Examples status table | `scripts/update_docs_examples.go` rewrites the block between `EXAMPLES_STATUS` markers (`:139-153`) from `examples_report.json`; run in deploy (`docusaurus-deploy.yml:251-263`) | The published table is from the binary built in that deploy | The deploy tolerates failures (`… --json > examples_report.json \|\| true`, `:257`), so a red example is displayed, not blocking. The committed copy is stale by design: "Last updated: 2026-04-21 … 164 passed, 0 failed, 1 skipped" (`docs/docs/examples.mdx:415-417`); the mission measured 211 passed, 6 skipped (`docs-mission.md:454-456`). The script still carries literal patterns "66+" and "97+" (`update_docs_examples.go:170-177`) |
| Site build | `onBrokenLinks: 'throw'` (`docusaurus.config.js:33`); `docs-gate` job (`docusaurus-deploy.yml:302-334`), named as a required context (`ci.yml:27`); guard that the PR path list covers the push path list (`docusaurus-deploy.yml:58-117`, `.github/docs-build-paths.txt`) | A PR touching docs-relevant paths must build the site. Broken internal page links fail the build | Broken anchors and broken markdown links only warn (`docusaurus.config.js:34-35`). Orphan pages are not detected. A fresh checkout cannot run `make docs-build`: the tracked `docs/src/data/packages-sidebar.json` references pages that are gitignored (`docs/.gitignore` last block), which the mission records at `docs-mission.md:538-546` |
| Changelog index gate | `scripts/check_changelog.sh`, `ci.yml:310`, plus a self-test | Root `CHANGELOG.md` has exactly one heading and links the active `changelogs/*current*` file; any other heading fails (`:74-92`); an empty `changelogs/` fails (`:51-59`) | Content of the changelog |
| Referenced-path gate | `scripts/check_referenced_paths.sh` | No literal `tools/…` or `scripts/…` script reference with extension `.sh .bash .py .pl` dangles | States its own blind spots (`:2-15`): "a green here means 'no LITERAL tools//scripts/ script reference dangles', never 'no reference dangles'". `docs/scripts/…` is out of scope |
| Context-doc size gate | `make check-context-docs`, `ci.yml:346` | Already known; not re-derived | |
| Limitations entry policy | `docs/docs/reference/limitations.md:13-17`, `docs/LIMITATIONS.md:9-12` | A convention: each open entry has a repro and a "Verified at" date; fixed items move to a dated list | Not mechanised. The stamp is v0.33.1 / 2026-08-17 while the release is v0.52.1. A sibling page contradicts it, section 8 item R3 |
| Registry package pages | `docs/scripts/sync-registry.sh`; daily cron rebuild (`docusaurus-deploy.yml:27-29`) | Package pages track the registry within a day | Exits 0 with an empty sidebar if the registry is unreachable (`:39-44`); the CI step is `continue-on-error` (`docusaurus-deploy.yml:292`) |
| MCP snapshot refresh | Release step 7.6 (`.claude/skills/release-manager/SKILL.md:362-370`); a smoke gate requires the test MCP to serve the released version (`:376-379`) | The test MCP serves the tagged version | Prod is "a manual promote" (`:372`). The content checks of 1.4 are not covered |
| `docs-sync` scripts | Section 3 | Nothing; they report | All five returned `rc=0` with findings (`docs/docs-sync-findings.md:11-15`) |

OBSERVED. CI has a docs-only lane: a PR touching only `design_docs/**/*.md` or `changelogs/**/*.md`
skips the compiler matrix (`ci.yml:67-76`), but `docs/` is excluded from that lane ("the website has
its own build"), and so are `CLAUDE.md` and `.claude/**/*.md` because they "change agent behaviour and
must stay gated" (`ci.yml:67-69`). The hygiene job is not skipped on docs PRs: it "carries 19 hygiene
gates … those are about DOCUMENTATION as much as code: a design doc can leak an address or cite a
path that does not exist" (`ci.yml:90-93`).

### 2.2 Version constants in detail

- OBSERVED. The committed `docs/src/constants/version.js` is two lines: `STABLE_RELEASE = 'v0.52.1'`,
  `ACTIVE_PROMPT = 'v0.16.6'`. That is the form the `docs-sync` "Quick Fix" prints
  (`.claude/skills/docs-sync/scripts/check_versions.sh:63-70`). The generator would write seven
  constants (`generate-version-constants.sh:46-66`).
- INFERRED. Two of the seven have a dead source. `DEV_VERSION` is read from a `## [Unreleased - v`
  heading in root `CHANGELOG.md` (`:26`), a heading the changelog gate forbids (`check_changelog.sh:
  74-92`); root `CHANGELOG.md` is a 24-line index. `COVERAGE` has a literal fallback of "37.2%"
  (`:29`). No page imports either.
- OBSERVED. `main` and `dev` both deploy to the same Pages site (`docusaurus-deploy.yml:7`, `:350`).

### 2.3 A design rule stated in the build files

OBSERVED. Several gates carry the same two rules in their comments:

- Point the gate at the source, not the generated copy: "a gate pointed at the generated artifact
  measures the build, not the intent" (`make/code-health.mk:259-260`). The prompt gate reads
  `prompts/devtools`, "not cmd/ailang/prompts/devtools — that is a generated mirror"
  (`tools/check_prompt_commands.sh:32-38`).
- Every gate gets a self-test that makes it fail: "A green gate is not evidence; a gate that goes red
  on a real change is" (`make/examples.mk:141-146`). "A gate's coverage is a property of its
  enumerator … an enumerator that comes back empty must FAIL LOUDLY, never pass"
  (`scripts/check_changelog.sh:49-50`).

---

## 3. The `docs-sync` skill and `docs-sync-findings.md`

### 3.1 The skill

- OBSERVED. Purpose: "Sync AILANG documentation website with codebase reality. Use after releases,
  when features are implemented, or when website accuracy is questioned"
  (`.claude/skills/docs-sync/SKILL.md:3`). The `post-release` skill calls it as step 8
  (`.claude/skills/post-release/SKILL.md:722-734`), and the docs mission is told to use it and not
  reimplement it (`design_docs/docs-mission.md:12-14`).
- OBSERVED. Drift it looks for, by script:
  - `check_versions.sh`: `STABLE_RELEASE` against `git describe --tags --abbrev=0`, and
    `ACTIVE_PROMPT` against the highest `prompts/v*.md` (`:39-53`). Prints `[MISMATCH]`, never exits
    non-zero.
  - `audit_design_docs.sh`: counts all markdown under `planned/` and `implemented/` (`:21-22`);
    greps five hard-coded feature keywords in docs against `internal/` and `cmd/` (`:67-88`);
    compares "PLANNED FOR vX" banners in `docs/docs/roadmap/*.md` with the folder of the linked
    design doc (`:97-123`).
  - `derive_roadmap_versions.sh`: derives each planned doc's target version from its folder and
    marks it OVERDUE when the folder version is at or below the current tag (`:60-72`); `--check`
    compares banners in roadmap pages with folders and exits 1 on a mismatch (`:185-261`).
  - `check_examples.sh`: runs every `examples/runnable/*.ail` with `--caps IO`, then with no caps
    (`:62-83`); counts inline code blocks as an "anti-pattern" (`:93-108`).
  - `generate_report.sh`: a markdown report combining the above.
- OBSERVED. Principles (`SKILL.md:154-207`): planned features may be documented only with a status
  banner and a link to the design doc; examples are imported with raw-loader and "Never embed code
  directly in MDX", with an exception for reference pages (`:161-173`); "Design Docs = Ultimate
  Source of Truth - The folder structure tracks complete feature lifecycle" and "Moving `planned/` →
  `implemented/` = feature is done" (`:175-186`); "Themes Over Changelog" (`:200`).
- INFERRED. Parts of the skill no longer match the site.
  - The theme table and `resources/feature_themes.md` describe v0.5.x: roadmap pages
    `/roadmap/execution-profiles` "v0.6.0 planned" (`SKILL.md:59-61`), "Arrays … (new in v0.5.6)"
    (`feature_themes.md:89-90`), three roadmap pages marked "✅ CREATED"
    (`feature_themes.md:155-185`). `docs/docs/roadmap/` now contains only `index.md`.
  - `derive_roadmap_versions.sh --check` skips `index.md` (`:197-198`), so with one file in that
    directory the check compares nothing. The register's "Roadmap-page versus design-doc-folder
    consistency is clean" (`docs/docs-sync-findings.md:50`) is true of an empty set.
  - The audit's section "Website Pages Referencing Planned Features" prints the name of every file in
    `docs/docs/architecture/` with no test (`audit_design_docs.sh:51-60`). The register's "five
    architecture pages referenced planned material" (`docs-sync-findings.md:11`) is that listing; the
    directory has five files.
  - Both scripts loop over `v0_*` only (`audit_design_docs.sh:31`, `derive_roadmap_versions.sh:60`),
    so `v1_0_0`, `v1_1_0`, the two non-version folders and the 129 files directly in `planned/` are
    not listed per document.
  - `generate_report.sh` still tests for "Coming in v0.4" and "v0.4.4" (`:108-112`) and always
    prints "Add PLANNED banners to architecture pages" (`:151`).

### 3.2 The findings register

- OBSERVED. `docs/docs-sync-findings.md` is an "Internal tracking page for sprint `docs-2`
  (2026-08-28) … intentionally not published or added to the Docusaurus sidebar. Each finding is
  sized as a possible future queue item and has one primary mission clause" (`:3-5`).
- OBSERVED. Format: an evidence table of the five instruments with their return codes (`:9-15`); a
  scored table with columns ID, Description, Clause, Severity, Evidence / reproduction, Disposition
  (`:26-40`); "Clean controls and non-findings" (`:42-57`); "Routing notes" (`:59-63`).
- OBSERVED. What it found, 13 rows:
  - DOCS-2-01, HIGH: the instrument itself. `check_examples.sh` passed absolute paths, which
    conflicts with `module examples/runnable/X` declarations and produces false `MOD010`. Raw output
    "12 passed / 29 failed / 176 skipped"; corrected relative-path run "166 pass, 9 genuine failures,
    and 42 no-module/non-running" over 217 files (`:13`, `:17-19`, `:28`).
  - DOCS-2-02, MEDIUM: `intro.mdx` "stale v0.16.0". Later marked "REFUTED 2026-08-31 … false
    positive … The producing check … was structurally incapable of being correct here and has been
    removed" (`:29`).
  - DOCS-2-03, HIGH: "126 planned design documents are overdue relative to v0.34.0" (`:30`).
  - DOCS-2-04, MEDIUM: two instruments give different population totals, 159/1030 against 126/682
    (`:31`). Both scripts now carry a scope comment (`audit_design_docs.sh:20`,
    `derive_roadmap_versions.sh:160`).
  - DOCS-2-05 to -11, LOW: seven runnable examples with no `main` (`:32-38`).
  - DOCS-2-12, -13, MEDIUM: two examples need the `Env` capability the checker never grants
    (`:39-40`).
- OBSERVED. The register separates what the instruments could not establish: "No clause-3 site-build,
  clause-4 missing-page, clause-5 taxonomy, clause-6 benchmark, or clause-7 request-handling defect
  was established by these diagnostics" (`:55-57`).
- OBSERVED. Routing. Each row's Disposition names a destination: a tooling queue item, a deferred
  item, an aggregate follow-up, or a future cleanup. These became mission queue items: "Follow-ups
  spawned as docs-5 through docs-8" (`design_docs/docs-mission.md:390-391`). docs-5 fixed the
  examples (`:408-420`), docs-6 fixed the script (`:421-432`), docs-8 triaged the overdue docs
  (`:469-487`), docs-9 tested DOCS-2-02 and ruled it out (`:392-407`). The one row that needed a
  human became decision D-1 (`:65`).
- OBSERVED. A refuted finding is kept in place and annotated, not deleted, in both the register
  (`docs-sync-findings.md:29`) and the queue (`docs-mission.md:405-407`).

---

## 4. How internal design docs are exposed publicly

- OBSERVED. `docs/scripts/sync-design-docs.sh` writes two pages at every site build
  (`docs/package.json:8-12`):
  - `docs/docs/design-docs.md` from `design_docs/implemented/<dir>/*.md`, one `## <version>` section
    per directory, newest first (`:43-102`).
  - `docs/docs/roadmap/index.md` from `design_docs/planned/<dir>/*.md`, one `## Planned for <dir>`
    section per directory (`:105-181`), followed by a fixed "Long-term Vision" block (`:158-171`).
- OBSERVED. Each entry is a link to the file on GitHub `blob/dev` (`:12`, `:86`, `:150`) with the
  doc's first `# ` heading as the title, or the filename when there is none (`:19-28`). The design
  docs themselves are not rendered on the site.
- OBSERVED. **Status is derived from the directory path only.** The script reads no status field. A
  file under `implemented/` is listed as implemented; a file under `planned/<dir>/` is listed as
  "Planned for <dir>" with underscores turned into dots (`:30-33`).
- OBSERVED. Consequences visible at HEAD:
  - Non-version folders are rendered as versions: "## Planned for docparse-billing" and "## Planned
    for ailang-core-triage" (`docs/docs/roadmap/index.md:242`, `:250`). The second lists 46 triage
    notes and bug reports as planned features, for example "`messages send` silently stores unknown
    flags as the message body" (`:278`).
  - Only one directory level is read (`[ -d … ] || continue`, then `*.md`, `:127-136`). The 129
    markdown files directly in `design_docs/planned/` do not appear. 239 files one level down do.
  - Sprint plans are listed as design documents: 39 on the roadmap page, 388 on the design-docs page
    (grep of the committed pages). The footer counts them: "1130 design documents across 146
    versions" (`docs/docs/design-docs.md:1581`).
  - Folders older than the release are still "planned": sections from v0.29.0 to v0.50.0
    (`roadmap/index.md:59-219`) at release v0.52.1.
  - The in-file status can contradict the folder. `design_docs/planned/v0_29_0/m-eval-slim-prompt-
    self-discovery.md:3` says "**Status**: RULED OUT (docs-8 sweep, 2026-09-02)" and is listed under
    "Planned for v0.29.0" (`roadmap/index.md:234`). At least seven files under `planned/` have a
    status line beginning "Implemented" or "COMPLETE", for example `planned/v0_35_0/m-dx-microrag-
    context.md:3`, `planned/v0_35_0/m-unified-release-model.md:3` ("✅ Implemented — validated on
    v0.35.0"), `planned/v0_44_0/m-stdlib-root-resolution.md:3`,
    `planned/v0_52_0/m-ifc-declared-record-labels.md:3`; they are on the roadmap
    (`roadmap/index.md:161-164`, `:180`, `:85`).
  - The docs mission's own two landed features were not moved. docs-11 and docs-12 are `[LANDED]`
    (`design_docs/docs-mission.md:591`, `:640`), yet their design docs are still at
    `design_docs/planned/v0_29_0/m-dx27-docs-search-github-fallback.md` (status line `:3` "Planned")
    and `design_docs/planned/v0_33_1/m-eval-standard-mode-input-files-gap.md` (`:3` "Planned"), and
    the roadmap lists both (`roadmap/index.md:231`, `:190`).
- OBSERVED. The two generated pages are tracked in git and are stale there. The committed roadmap
  says "211 planned features across 25 upcoming versions" (`roadmap/index.md:312`); the directory
  now yields 239 across 29 folders. The committed design-docs page stops at v0.47.0 before the v1.x
  sections; `implemented/` has `v0_48_0`, `v0_51_0`, `v0_52_0`. The mission treats local
  regeneration as noise: "sync-script byproducts, never meant to be committed"
  (`docs-mission.md:530-532`).
- OBSERVED. `reference/implementation-status.md:9` delegates to the generated page: "auto-generated
  from `design_docs/implemented/` and always lists the latest versions — no hand-maintained list
  here."
- OBSERVED. The same path-derived rule is used by the MCP snapshot (`tools/build-snapshot/main.go:
  684-710`) and by `docs-sync` (`SKILL.md:175-186`).
- INFERRED. The scheme makes a folder move the only status change the public sees, and nothing
  checks that the move happened. The mission's docs-8 sweep found 18 of 54 overdue planned docs were
  already implemented (`docs-mission.md:469-477`). One month later the same condition is back.

---

## 5. The docs mission (`design_docs/docs-mission.md`)

### 5.1 What it is

- OBSERVED. A long-running mission, "advanced by a scheduled outer loop on the always-on rig"
  (`:3-4`), every 6 hours (`:15`), in its own clone (`:29-31`), reporting to a GitHub issue that
  rotates weekly (`:19-21`). North star: "A reader arriving at the website gets an accurate, current,
  and *non-redundant* account of what AILANG is and does — with no page contradicting the shipped
  binary, no example that does not run, and no third copy of something already said twice" (`:5-7`).
- OBSERVED. Its verify profile is `make docs-build`, `make verify-examples`, and `ailang check` on
  any touched `.ail` (`:42-51`). Metered ceiling $1 per iteration (`:159-160`).

### 5.2 The bar, clause by clause

"The bar — what 'the website is up to date' means" (`:91`). "Mark selected all seven clauses attended
on 2026-08-28; clauses 5-7 are his additions" (`:93`).

1. **Code/docs drift** (`:95-97`): "No page contradicts the shipped binary: feature status, version
   constants, CLI commands and flags, and design docs moved `planned/` → `implemented/`."
2. **Examples compile and run** (`:98-100`): every `.ail` under `examples/` passes
   `make verify-examples`; "Website examples are IMPORTED from `examples/`, never inlined — an inline
   code block is itself a clause-2 defect."
3. **Site build health** (`:101-102`): "`make docs-build` green, the Pages deploy passing, no broken
   internal links, no orphaned pages unreachable from the nav."
4. **New features get pages** (`:103-105`): tracked from the changelogs against the nav. "One page per
   iteration, and prefer a section in an existing page over a new page (clause 5 outranks clause 4)."
5. **Concision and anti-sprawl** (`:106-114`), top priority from 2026-10-01: "The site says each thing
   **once**, briefly." "**Deletion is the normal outcome of this clause** — never substitute 'add a
   clarifying note' for 'delete the duplicate'. Report each iteration's net line delta for the pages
   touched; a clause-5 item that grows the site failed." Navigation is included: "nav may only get
   shorter."
6. **Benchmark report maintenance** (`:115-119`): the benchmark JSON and pages are "current and
   honest", with a list of known traps "not to be rediscovered". "Maintains the *report* only — never
   re-runs or re-banks evals."
7. **Doc-related requests are answered** (`:120-124`): the mission works the `docs-mission` inbox and
   doc-related GitHub issues, with the exact read command given because "a bare local read shows an
   empty, wrong inbox".

Current standing against the bar (`:181-185`, STATUS 2026-10-01): "1 UNMET (docs-18 staleness); 2
UNVERIFIED (examples gate not run); 3 UNVERIFIED (origin CI in flight); 4 UNMET (docs-19 release
gap); 5 UNMET …; 6 UNVERIFIED …; 7 UNVERIFIED". No clause is recorded as met.

### 5.3 Queue (`:311-364`)

Tags: `[NEXT] [IN-SPRINT] [PARKED] [LANDED] [RULED OUT]` (`:311`). "Rebuilt 2026-10-01 (attended),
concision first" (`:313`). Each item records a line count before; "the evaluator checks the line
count after. Targets are ceilings, not goals" (`:315-316`).

| # | Tag | Item | Clause | Measure recorded |
|---|---|---|---|---|
| 1 | `[PARKED-ON-LANE]` | docs-14, three-camps pages: two pages to half a page (`:318-328`) | 5 | 213 + 276 lines → ≤60. Blocked: no independent judge could be started |
| 2 | `[NEXT]` | docs-15, the ten historical prompt pages (`:329-334`) | 5 | 22,788 lines, "a third of the site" |
| 3 | `[NEXT]` | docs-22, simplify navigation (`:335-342`) | 5 | navbar 10 → ≤6; sidebar depth 4 → ≤3; categories roughly halved |
| 4 | none | docs-16, messaging + coordinator cluster (`:343-346`) | 5 | 5 pages / 4,965 lines → under half |
| 5 | none | docs-17, the agent pages (`:347-348`) | 5 | 7 pages / 2,119 lines |
| 6 | none | docs-18, stale and verbose sweep of the six largest guides (`:349-353`) | 1+5 | one page per iteration, largest first |
| 7 | none | docs-19, release gap v0.36 → v0.49 (`:354-356`) | 4 | "44 releases since the pause, 86 commits touched `docs/docs`" |
| 8 | none | docs-20, benchmark report freshness (`:357-359`) | 6 | uncommitted JSON found in the main checkout |
| 9 | none | docs-21, inbox sweep (`:360-361`) | 7 | |

Empty-queue rule: "An empty queue is not a licence to draw from the design-doc backlog. When nothing
is `[NEXT]`, run the `docs-sync` instruments plus one clause-5 page-cluster audit, file the findings
as queue items, and land the top one if it fits the iteration" (`:87-89`).

### 5.4 Landed and ruled out (`:363-748`)

Landed:

- docs-0, charter ratified by human decision after three quorum rounds (`:368-383`).
- docs-2, first sweep with `docs-sync`, 13 findings (`:384-391`).
- docs-5, main entrypoints for seven example fixtures (`:408-420`).
- docs-6, `check_examples.sh` absolute-path bug fixed (`:421-432`).
- docs-10, `make verify-examples` made non-vacuous (`:433-456`).
- docs-8, overdue planned docs triaged: 54 real, 18 moved to `implemented/`, 31 still planned
  (`:469-487`).
- docs-1, inbox router script `tools/messaging/docs_inbox_router.sh` (`:488-512`).
- docs-3, benchmark provenance badge wired into four components (`:513-546`).
- docs-4, taxonomy pass: "3 deletions + 9 orphans wired + 5 redundant sections trimmed" (`:547-590`).
- docs-11, `ailang docs search` GitHub fallback, a Go feature (`:591-639`).
- docs-12, an eval-harness fix (`:640-744`).
- docs-13, charter restored (`:363-364`).

Ruled out, both kept in the queue with the reason:

- docs-7, "the mission cannot edit its own published content": "the premise was false, measured"
  (`:457-468`).
- docs-9, "`intro.mdx` is stale at v0.16.0": "the check's premise was false, measured" (`:392-407`).

INFERRED. Of the 12 landed items, two edited the site itself: docs-4 (pages and sidebar) and docs-3
(four site components). The rest repaired instruments (docs-6, docs-10), example files (docs-5),
design-doc folders (docs-8), the charter (docs-0, docs-13), added a router script (docs-1), ran the
first sweep (docs-2), or shipped Go code (docs-11, docs-12). The charter says why: the goal sections were archived by mistake and "iterations
5-16 ran without a definition of done and drifted into general design-doc backlog draws" (`:76-79`).

### 5.5 Decision ledger (`:55-70`)

- OBSERVED. "This marked table — not STATUS prose — is the source of truth for which decisions are
  open … Rows are append-only, IDs are never reused" (`:57-60`). It is machine-checked:
  `scripts/mission_decisions.sh --check` and `--open` (`:58-59`).
- OBSERVED. **There are no open rows.** D-1 to D-5 are all `RESOLVED` (`:65-69`); "No human decisions
  open" (`:186`).
  - D-1: fix the docs-sync instrument inside this mission (`:65`).
  - D-2: "MOOT — nothing to widen; the premise was false" (`:66`).
  - D-3, D-4: one-time use of a quorum carve-out for one design brief each, with conditions (`:67-68`).
  - D-5: accept two reviewer objections as wording fixes, no fifth quorum round (`:69`).
- OBSERVED. A complete ask carries the options, the loop's recommendation and the "Default if
  unanswered" (for example `:67`). Rulings record provenance: "Provenance is therefore the attended
  session, NOT the commit author" (`:67`).

### 5.6 Guardrails worth copying or avoiding

- "a charter claim about what a mechanism DOES carries the command that demonstrates it, or is not
  stated" (`:132-133`).
- "Deleting or merging a published page is outward-facing. Measure inbound links first (an empty
  search is a claim, not a fact) and leave a redirect where the URL was public" (`:136-137`).
- Rotation rule: "Only `## STATUS …` blocks ever move" (`:168`).

Existence only, not opened: `design_docs/docs-mission-log.md`, `docs-mission-index.md`,
`docs-mission-dashboard.md`, `docs-mission-status-archive.md`, `docs-mission-status-index.md`,
`docs-mission-iter17-issue-inventory.md`, `docs-N-brief.md` and `docs-N-sprint-plan.md`.

---

## 6. Sprint retros (`docs/sprint-retros/`)

- OBSERVED. 35 entries, not on the site. Three kinds of content share the directory:
  1. Sprint retrospectives in the skill's format (4 files): `M-DOGFOOD-FIXES-retro.md`,
     `m-ci-build-speed.md` with `m-ci-build-speed-baseline.md`,
     `m-daneel-ailang-executor-2026-09-16.md`.
  2. One A/B experiment report with its raw JSON (2 entries):
     `m-agent-ailang-only-execution-ab-2026-09-16.md` (first 8 lines read only).
  3. Evidence from mission iterations (29 entries): independent evaluation reports per round
     (`iter338-gate1-ref-drift-eval-r1.md`, `-r2.md`, `-r3.md`), controller addenda, quorum JSON, an
     evidence JSON, a 58 KB consumer census, and three `motoko-iter*` evaluations.
- OBSERVED. What a retro is and who writes it: the `sprint-executor` skill, "After ALL waves are
  integrated and tests pass, write a retrospective. Create `docs/sprint-retros/<sprint-id>-retro.md`"
  (`.claude/skills/sprint-executor/SKILL.md:520-524`), listed as "Written to `docs/sprint-retros/`
  after parallel sprints complete" (`:835`). The author is the integrating agent.
- OBSERVED. Template (`sprint-executor/SKILL.md:526-558`): Summary (duration actual against
  estimated, execution mode, milestones passed); Milestone Timing table (estimated LOC, actual LOC,
  time, status); Parallelization Results; Friction Encountered; Recommendations for Next Sprint.
- OBSERVED. The retros follow it loosely. `M-DOGFOOD-FIXES-retro.md` matches the template and adds
  model and token columns (`:10-17`). `m-daneel-ailang-executor-2026-09-16.md` replaces
  "Parallelization" with "What the sprint found that the design did not" (`:20-27`) and "Measured in
  prod" (`:36-40`).
- OBSERVED. Evaluation reports are written by an independent judge model and name this directory as
  their path (`iter335-cache-module-id-recovery-evaluation.md:17-23`: `EVALUATION_RESULT`,
  `EVALUATION_SCORE`, `BLOCKERS`, `REPORT_PATH`). A controller addendum then corrects the judge:
  "The following qualifications correct factual or interpretive claims in the raw reports"
  (`iter335-cache-module-id-recovery-controller-addendum.md:12`). The raw report is "preserved
  verbatim beside this file" (`:3`).
- OBSERVED. A retired retro keeps its body and gains a banner: "**Retired 2026-09-03.** … Kept as a
  record of the measurements, not as a description of the pipeline" (`m-ci-build-speed.md:8-12`).
- OBSERVED. How a lesson reaches a skill or rule: Gate 5 of the shared `mission-control` skill. "Scan
  this iteration's friction … plus unread `docs/sprint-retros/` material. Route each item to exactly
  ONE lane: **skill fix** — edit the offending SKILL.md. Max ONE skill edit per iteration; requires
  ≥2 recorded frictions pointing at the same gap; state both in the commit message. **process fix** —
  edit the mission doc … **backlog** — new design doc … or re-prioritize the queue"
  (`.claude/skills/mission-control/resources/gate-5-retro.md:7-12`). A routing-policy change needs
  "≥3 evidence rows" (`:13`).
- OBSERVED. `sprint-retros` is mentioned in only two files under `.claude/` (those two skills) and not
  in `CLAUDE.md`, `AGENTS.md`, `.claude/rules/` or the site.
- INFERRED. Nothing records which retros have been read. "Unread" in the gate has no defined marker
  that I could find, and no retro carries a "routed to" line. The oldest retro's two recommendations
  ("Put concrete external acceptance commands … directly in sub-agent prompts", and add the retro "to
  the integrator's closing checklist", `M-DOGFOOD-FIXES-retro.md:48-54`) cannot be traced to a skill
  edit by text search. That retro also records its own near-miss: "The retro itself was nearly
  forgotten (user prompt caught it)" (`:53`).

---

## 7. Versioning of docs across releases

- OBSERVED. The site is single-version. There is no `versioned_docs/` or `versions.json` under
  `docs/`. The README lists "Versioned docs support" only as a reason for choosing Docusaurus
  (`docs/README.md:92`). Pushes to `main` and to `dev` deploy the same site
  (`docusaurus-deploy.yml:7`, `:350`).
- OBSERVED. Versioning is done per artefact:
  - **Release number on pages**: the `STABLE_RELEASE` constant, section 2.2.
  - **Teaching prompt**: its own version line, v0.16.6 against language v0.52.1, with a registry
    `prompts/versions.json` holding hash, description, tags and notes
    (`docs/docs/prompts/index.md:59-66`). The site publishes `current.md` plus ten older versions
    (`docs/docs/prompts/`, v0.8.2 to v0.16.5).
  - **Design docs**: a folder per target or shipped version, section 4.
  - **Changelog**: root `CHANGELOG.md` is an index of twelve files split by version range
    (`CHANGELOG.md:9-22`), with fragments in `changelogs/unreleased/` folded at release
    (`scripts/check_changelog.sh:103-105`). The release skill checks each implemented design doc is
    referenced in the changelog (`.claude/skills/release-manager/SKILL.md:95-110`).
  - **Limitations**: per-entry "Verified at" version and date (`docs/docs/reference/limitations.md:
    13-17`).
  - **MCP**: one endpoint, `for_version` argument, `{served_for, data}` envelope, and
    `unknown_version` "rather than a silent downgrade" (`docs/docs/guides/agent-mcp.md:49`,
    `:121-123`). Each image bakes one version's snapshot (`:121`).
  - **Compatibility promise**: `docs/docs/reference/stability.md` defines Stable / Experimental /
    Internal tiers for 1.x, marked "RATIFICATION: pending" (`:9-13`).
- OBSERVED. In-page version narration is treated as a defect by the mission: "no history, no war
  stories, no 'as of vX' narration that belongs in the changelog" (`design_docs/docs-mission.md:
  108-109`).
- INFERRED. A reader on an older release has no matching site. The version-accurate channels are the
  CLI (`ailang prompt`, "the most accurate, version-locked prompt", `prompts/index.md:14-16`) and the
  MCP `for_version` argument. LIVE: the MCP lists 53 versions but those are prompt-file versions
  (`tools/build-snapshot/main.go:511-527`), not snapshots.

---

## 8. Passages that record a documentation failure

### 8.1 The ten most instructive (recorded by the project, with a date or a measurement)

**F1. The charter archived its own definition of done.** `design_docs/docs-mission.md:76-79`:
"These sections (goal, bar, guardrails, routing) were swept into `docs-mission-status-archive.md` by
iteration 4's STATUS rotation on 2026-09-02, so iterations 5-16 ran without a definition of done and
drifted into general design-doc backlog draws." And `:169-170`: "moving them on 2026-09-02 left
twelve iterations without a definition of done." Fix: the rotation rule now names what may move
(`:168`).

**F2. A false sentence in a governing doc was cited as its own evidence.**
`design_docs/docs-mission.md:66`: "this row cited the charter's own Guardrails bullet as its evidence,
and that bullet was an unverified human-authored claim — so a false statement in the charter became
self-citing." Also `:467-468`: "this item was created from a false sentence in this charter, which
then got cited back as its own evidence". Work was deferred on it (`docs/docs-sync-findings.md:29`,
`:28`). Rule made: `docs-mission.md:132-133`.

**F3. The drift detector was the thing that had drifted.** `docs/docs-sync-findings.md:13`: "raw
output 12 passed / 29 failed / 176 skipped is unreliable because it passes absolute paths"; corrected
"166 pass, 9 genuine failures, and 42 no-module/non-running" (`:19`). `docs-mission.md:422-423`: the
instrument "has been silently over-reporting broken examples".

**F4. The example gate could not fail.** `design_docs/docs-mission.md:433-447`: "`make
verify-examples` is vacuous on two independent axes — found by Gate 0's weekly external-issue sweep
(2026-08-31), not by this mission's own tooling." "`expected.stdout` in `examples/manifest.json` is
never compared … corrupting one entry's `expected.stdout` to a deliberately wrong literal still
returns `rc=0`"; the manifest validator "prints its `checked` count but never asserts it against a
floor". The charter had named this gate as its proof that "every published example still verifies"
(`:47`).

**F5. A stale count of stale docs, and status by folder was wrong for a third of them.**
`design_docs/docs-mission.md:469-477`: "The '126' figure was itself stale … the real overdue set …
was **54** docs." Of those, "**18 docs confirmed genuinely implemented**" were still under
`planned/`. A second agent re-checked: "generator≠judge caught **3 of 22** high-stakes claims wrong
(2 outright reversals…)".

**F6. Release notes written to the wrong file, and a gate that saw one in five.**
`scripts/check_changelog.sh:4-7`: "Between v0.30.0 and v0.31.0, 8 commits appended entries to root
CHANGELOG.md while 33 correctly used the archive -- stranding 12 entries that would have silently
vanished from the release notes". `:15-20`: "root CHANGELOG.md carried FIVE stranded sections
spanning 169 lines, and the gate flagged exactly ONE of them."

**F7. A prompt that taught deleted commands while its integrity gate stayed green.**
`make/code-health.mk:239-242`: "M-V1-SIMPLIFY-S5 M3 deleted eight `observatory` subcommands and
freeze stayed green while `ailang devtools-prompt` went on teaching all eight."
`tools/check_prompt_commands.sh:9-12`: "the same defect class as `ailang fmt` telling eval models
their correct code was non-canonical for two weeks. The freeze gate pins the prompt's BYTES; this
one pins its TRUTH."

**F8. Audit scripts that became wrong when their subject was generated.**
`.claude/skills/cli-doc-maintainer/SKILL.md:50-56`: "they were not merely stale, they were **actively
wrong**: `audit_commands.sh` read 'Commands in main.go: 1' and demanded that an empty string be
documented … `audit_env_vars.sh` reported 272 variables as undocumented by comparing against a
`help.go` that has not listed environment variables since S4". The skill now opens: "There is nothing
here to keep in sync by hand any more" (`:8`), and marks its two resource files "pre-S5 history;
they are not instructions for today's CLI" (`:60-61`).

**F9. The agent-facing docs server served an old version for weeks.**
`.claude/skills/release-manager/SKILL.md:367-370`: "If you skip this step, the public MCP keeps
serving the **previous** version and agents get `unknown_version` for the new release (this silently
happened across v0.20–v0.24; prod was frozen at 0.19.1 for ~3 weeks)."

**F10. Reports that were written and never shown.**
`.claude/skills/mission-control/resources/gate-5-retro.md:85-87`: "measured 2026-09-28, all 150
digests in Daneel's ledger were `fyi · NOTE`, so decision asks were counted and never shown." Related,
same file `:45-51`: a message whose body was the literal string `--body-file /tmp/w110_xmsg.txt`,
sent with exit 0, twice, by two missions, because a rule about one tool sat next to another tool's
command. And `:38-42`: "The issue thread is a COMMUNICATION channel, not loop memory — the loop never
re-reads its own reports".

### 8.2 Further recorded cases

- `design_docs/docs-mission.md:392-407` and `.claude/skills/docs-sync/scripts/check_versions.sh:
  55-61`: a version check that "False-positived permanently"; "a queue item inherited a tool's raw
  `[STALE]` line without checking whether the tool's premise was sound".
- `make/examples.mk:141-146`: "Between 2026-05-22 (v0.0.12) and 2026-08-13 this gate was dead … and
  nothing noticed".
- `make/examples.mk:73-77`: "That gap let 8 examples ship using `++` on strings (list-only since
  v0.13.0) plus 2 missing imports, none caught by CI."
- `design_docs/docs-mission.md:522-526`: "iterations 1/2/4/5/6 each re-confirmed the same 'V1-owned
  inherited red' verdict … without re-measuring whether it was still true … it wasn't."
- `design_docs/docs-mission.md:329-330`: ten historical prompt pages are "22,788 lines — a third of
  the site". I measured the same: 25,511 lines in `prompts/` less `current.md`, `index.md`,
  `python.md`.
- `docs/scripts/sync-registry.sh:104-107`: an untrusted package summary containing `<workdir>` "breaks
  the Docusaurus build for the WHOLE site … reddened Docs-Deploy 2026-07-23".
- `design_docs/planned/ailang-core-triage/datetime-clock-ms-vs-seconds-docs.md:1-13` (2026-09-17):
  "prompt and one guide say 'seconds', implementation is milliseconds"; "The report is **verified
  and correct**".
- `.github/workflows/ci.yml:19-24`: "Measured 2026-09-10 — PR #1143 (a single .md) was red on … a
  compiler pipeline test it could not possibly affect. Four design docs sat unmerged, the oldest nine
  days".
- `docs/sprint-retros/M-DOGFOOD-FIXES-retro.md:24-29`: a sub-agent "reported 184 green tests yet
  panicked on the first REAL package … it skipped the package-shaped fixture its design doc
  explicitly required."
- `docs/sprint-retros/m-ci-build-speed.md:43-44`: a config file in the repo that "is reference-only —
  the actual config lives in the trigger's `build:` field."

### 8.3 Failures I observed that the repository does not record (all INFERRED from OBSERVED facts)

- **R1. `llms.txt`** is 140 days older than HEAD, embeds prompt v0.16.0 while v0.16.6 is active, and
  contains one guide and one reference file because its generator looks for paths that moved.
  Section 1.3.
- **R2. MCP `roadmap` errors and `limitations_list` mislabels.** Section 1.4.
- **R3. Two public pages contradict each other.** `docs/docs/reference/implementation-status.md:
  54-56` lists as "Active bugs": "Polymorphic arithmetic in lambdas panics" and "Pattern guards
  parsed but not evaluated". `docs/docs/reference/limitations.md:461` and `:479` say "Fixed in
  v0.7.0" and "Implemented in v0.6.2".
- **R4. A public contributor guide instructs what a CI gate forbids.**
  `docs/docs/guides/development-workflow.md:354` "Update CHANGELOG.md at each milestone" (also
  `:180`, and `:66` "Detects current version from CHANGELOG.md"). The gate rejects any release note
  in root `CHANGELOG.md` (`scripts/check_changelog.sh:74-92`). The mission's own executor hit it:
  "`make check-changelog` rejected M4's `CHANGELOG.md` edit" (`design_docs/docs-mission.md:275-277`).
- **R5. The home page.** `docs/docs/intro.mdx:95` renders "Recent Additions (v0.52.1)" above five
  items dated v0.12.0 to v0.16.0 (`:97-101`), and `:103-107` lists a "Roadmap" of "Execution
  Profiles (v0.6.0)", "Deterministic Tooling (v0.7.0)", "Shared Semantic State (v0.6.0)". The docs-9
  ruling (`docs-mission.md:401-402` "Nothing in `intro.mdx` needed to change") was about the version
  label on one bullet, not this.
- **R6. Prompt-page accumulation.** `sync-prompts.sh` copies and never deletes (`:28-50`), which
  accounts for ten old prompt pages in `docs/docs/prompts/`.
- **R7. `docs/README.md`** names a workflow that does not exist, `.github/workflows/jekyll-gh-pages.
  yml` (`:67`); says the sidebar is "auto-generated" (`:54`, `:82`); and lists a `blog/` directory
  (`:47`).
- **R8. `docs/TESTING.md`** (unpublished) uses `//` comments and `| Some(x) -> …` match arms
  (`:32`, `:88-91`) and clones from `github.com/sunholo/ailang` (`:21`), where current syntax is `--`
  comments and `pat => expr` (`docs/LIMITATIONS.md:45-56`, `:90-91`) and the org is `sunholo-data`.
  It ends "licensed under the MIT License" (`:642`); the README section in `llms.txt:187` says
  Apache 2.0.
- **R9. The stdlib index guard** likely never runs in CI. Section 2.1.
- **R10. Landed work left in `planned/`**, including the docs mission's own two features. Section 4.

---

## 9. What I read

**In full:** `docs/README.md`, `docs/VISION.md`, `docs/LIMITATIONS.md`, `docs/TESTING.md`,
`docs/docs-sync-findings.md`, `docs/sidebars.js`, `docs/docusaurus.config.js`, `docs/package.json`,
all six files in `docs/scripts/`, `docs/docs/guides/development-workflow.md`,
`state-system-workflow.mdx`, `agent-workflows.mdx`, `claude-code-integration.mdx`, `agent-mcp.md`,
`docs/docs/intro.mdx`, the three `start-here/` pages, `docs/docs/prompts/index.md`, `llms.txt` lines
1-300, `.claude/skills/docs-sync/` (SKILL.md, both resources, all five scripts),
`.claude/skills/cli-doc-maintainer/` (SKILL.md, both resources), `scripts/update_docs_examples.go`,
`scripts/check_changelog.sh`, `design_docs/docs-mission.md` (all 748 lines, untruncated),
`tools/generate-llms-txt.sh`, `.github/workflows/docusaurus-deploy.yml`, `.github/docs-build-paths.
txt`, `make/docs.mk`, `mcp_tools/design.ail`,
`.claude/skills/mission-control/resources/gate-5-retro.md`.

Sprint retros read in full (6): `M-DOGFOOD-FIXES-retro.md`, `m-ci-build-speed-baseline.md`,
`m-ci-build-speed.md`, `iter335-cache-module-id-recovery-controller-addendum.md`,
`iter339-pi-runner-shell-suite-eval-r3.md`, `m-daneel-ailang-executor-2026-09-16.md`. Plus the first
60 lines of `iter335-cache-module-id-recovery-evaluation.md`.

**Read with every entry seen but not every byte:** `docs/docs/roadmap/index.md` (all 312 lines, with
the URL of each entry shortened). `docs/docs/design-docs.md`: head, tail, all 146 section headings,
and counts by grep. I did not read the 1,130 link lines one by one.

**Sampled:** `docs/docs/reference/` (heads of `cli.md`, `env-vars.md`, `stdlib.md`, `limitations.md`,
`stability.md`; first 60 lines of `implementation-status.md`); `docs/docs/examples.mdx` (head and the
status markers); `.github/workflows/ci.yml` (lane classification, the hygiene steps, the `docs` job);
`make/examples.mk` (first 175 lines), `make/code-health.mk` (lines 236-276), `make/build.mk` (build
and install targets); `tools/build-snapshot/main.go` (about 300 of 1,198 lines); `mcp_tools/lib.ail`
(90 lines); `scripts/check_referenced_paths.sh`, `tools/verify_cli_examples.sh`,
`tools/check_prompt_commands.sh` (heads); `.claude/skills/sprint-executor/SKILL.md` (lines 500-560,
825-835); `.claude/skills/release-manager/SKILL.md` and `post-release/SKILL.md` (the docs steps);
one triage note and the status lines of all files in `design_docs/planned/*/`.

**Listed only, not opened:** the other 28 entries of `docs/sprint-retros/`; the remaining 68 files in
`docs/docs/guides/`; `docs/docs/architecture/`, `references/`, `benchmarks/`, `recipes/`, `packages/`;
`demos.mdx`, `feedback.mdx`, `playground.mdx`, `vision.mdx`, `why-ailang.mdx`; the prompt pages;
`docs/internal/`, `docs/guides/`, `docs/reference/`, `docs/testing/`,
`docs/talk-building-a-language.md` (first 20 lines only); `docs/src/`, `docs/static/`; the other
docs-mission files in `design_docs/`; `tools/gen-env-docs`, `scripts/verify_examples.go`,
`scripts/validate_manifest.go`, the Go tests behind `check-cli-docs`; the remaining MCP tool modules.

**Not available:** git history (shallow clone), CI run logs, the deployed site itself.
