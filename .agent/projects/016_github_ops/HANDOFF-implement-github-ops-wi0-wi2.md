# Handoff: implement GitHub PR ops WI-0 → WI-2 (auth, `gh` in the container, creation driver)

Date: 2026-08-16
From: the session that authored `ADR-001-github-pr-ops-pipeline.md`
For: a fresh session implementing against HEAD
Deliverable: `gh` available in the devcontainer authenticating as the bot for pipeline commands
only; a PR template; and a creation driver that authors a body, publishes it, and writes the PR
number back — landed as three independently-revertible commits.

**There is no PLAN for this project, by decision.** The ADR is the spec. 016's surface is
greenfield (`.agent/github/` does not exist) with almost no existing code to survey, so a PLAN
would have restated the ADR — the failure mode
`../../meta-decisions/sequence-implementation-handoffs-by-source-surface.md` names as producing
prose faster than code. Where this handoff and the ADR disagree, **the ADR wins**; where the ADR
is silent, the "Stop and report" list below tells you whether to decide or escalate.

## Your task

Implement **WI-0 → WI-2** from the ADR's appendix. This is the cheapest cluster that ends in one
green state — a PR created by the driver, with its number written back — and per the calibration
clause it is the cluster that produces the cost data the rest of the schedule rests on. Report
that data back (see "Calibration ask").

Do **not** build WI-3 (sync + state writer), WI-4 (backfill), or WI-5 (loop skill). WI-3 in
particular is deliberately deferred until this cluster reports real cost.

## Read first, in order

1. **`ADR-001-github-pr-ops-pipeline.md`** — your spec. Load-bearing for this cluster: **D1**
   (identity follows agency — the rule the trap below attacks), **D2** (the layout block), **D4**
   (author → publish → write-back, the staging constraint, and the template's five fields), and
   the appendix's WI-0/1/2.
2. **`RESEARCH-github-pr-ops-pipeline.md`** §2.1 and §2.5 — only if you need *why*. Note §2.1
   contains a **stale path**: it says the driver writes `.agent/prs/<ticket>.md`, which predates
   the layout fork closing. D2 supersedes it: `.agent/github/prs/<alias>-<n>/body.md`.
3. **`../../prs/2026-08-13-pr-97-compaction-response.md`** — the genre of artifact this pipeline
   will eventually produce; useful for template tone, not required to build.

## Current grounding (re-verified at HEAD `90e86c1`, 2026-08-16)

Re-check each before editing; if any has moved, re-measure rather than trusting this list.

- **Two devcontainer variants have a `devcontainer.json`**: `.devcontainer/default/` and
  `.devcontainer/observability/`. `.devcontainer/otel/` holds only `logs-collector.yaml` — it is
  not a variant. *(The ADR appendix says "all variants" as if there were more; there are two.)*
- **Both variants share one compose file**, `.devcontainer/docker-compose.yml`
  (`dockerComposeFile: ../docker-compose.yml` in each). Its `environment:` block already passes
  six secrets through with the `${VAR:-}` idiom (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`,
  `OPENROUTER_API_KEY`, `GOOGLE_API_KEY`, `EXA_API_KEY`, `OBSIDIAN_MCP_TOKEN`). **Token
  passthrough is one line in one file, not an edit per variant.**
- **`gh` is not installed** (`command -v gh` → nothing). Install points are
  `.devcontainer/Dockerfile:7` (the `apt-get install` line: `ca-certificates curl git sudo unzip`)
  or `scripts/install-prerequisites.sh` (run at `Dockerfile:22`), which currently has no `gh`.
- **Driver precedent — this resolves the ADR's one open implementation fork.** There are two tool
  genres in this repo, and they are not interchangeable:
  - **Operator-invoked**: `tools/<name>/<name>.ts` with a `#!/usr/bin/env bun` shebang, wrapped in
    a Make target — e.g. `RMSEND := bun tools/rmsend/rmsend.ts` (`Makefile:41`) and the
    `remarkable*` targets (`Makefile:46-60`). Ten such tools exist under `tools/`.
  - **Agent-invoked**: `.agent/tools/*.ts`, which are **OpenCode Custom Tools** (see the header of
    `.agent/tools/code-graph-query.ts`); nothing in the Makefile references them.

  WI-2's driver is operator-invoked, so **follow the `rmsend` precedent**: `tools/pr/pr.ts` (or
  similar) + a `make pr` target. RESEARCH §2.1's throwaway "`make pr` or `.agent/tools/pr-create.ts`"
  conflated the two genres; it is not offering you a choice. WI-5's loop skill will be the
  agent-invoked genre — not your problem.
- **No test harness exists for either tool tree.** See "Stop and report" #3.

## The rule you will break by accident

**Exporting `GH_TOKEN` into the container makes *every* `gh` command run as the bot — including
the operator's.** `gh` prefers `GH_TOKEN`/`GITHUB_TOKEN` from the environment over the credentials
stored by `gh auth login`, and it does so silently. A plain global passthrough therefore
**inverts D1**: `make pr`, which D1 says must go out as the operator, would be authored by the bot,
and the identity separation the whole ADR exists to buy is gone on day one — with no error to
notice.

The ADR's WI-1 line asks for both "a `GH_TOKEN` passthrough" and "the operator's interactive
`gh auth` unaffected". Given gh's precedence rules those two clauses are in tension, and resolving
that tension is part of this cluster. The shape that satisfies both:

- pass the bot credential through under a **distinct name** (e.g. `MOTOKO_BOT_GH_TOKEN`), so it is
  inert for ordinary `gh` use and the operator's `gh auth login` keyring wins by default;
- have **pipeline commands only** map it into `GH_TOKEN` in the subprocess environment they spawn
  — never in the shell profile, never in `docker-compose.yml` as `GH_TOKEN`;
- make identity **observable**: every pipeline command should be able to report which account it
  will act as (`gh api user --jq .login`) before it writes anything.

Verify gh's precedence yourself rather than trusting this paragraph — but do not ship a global
`GH_TOKEN` export.

## The spine — three commits

**Commit 1 (WI-1a): `gh` in the image.** Add `gh` at one of the two install points above. Verify
whether Ubuntu 24.04's universe repo carries a usable `gh` version; if it is absent or too old,
use GitHub's official apt repo (`cli.github.com`) or the tarball release — pick one and record why
in the commit message. Keep it in the same layer discipline as the surrounding lines.
*Done when:* a rebuilt container gives `gh --version`, and the existing `postCreateCommand`
(`bun install && bun run build`) still completes.

**Commit 2 (WI-1b): credential passthrough.** One line in `.devcontainer/docker-compose.yml`'s
`environment:` block, following the existing `${VAR:-}` idiom, under a non-`GH_TOKEN` name per the
trap above.
*Done when:* with the variable unset on the host, the container starts and the operator's
interactive `gh auth login` works and `gh api user --jq .login` reports the **operator**; with it
set, a pipeline invocation reports the **bot** and an ordinary `gh` call still reports the
operator. Both variants get this for free via the shared compose file — confirm, don't assume.

**Commit 3 (WI-2): template + creation driver + mirror.** Three parts, one commit:
- the driver template with the five fields the ADR calls load-bearing — Summary, Changes,
  **Governing docs**, **Predicted outcome**, Test evidence;
- `.github/PULL_REQUEST_TEMPLATE.md` as the human-path mirror (the only pipeline file in
  `.github/`);
- the driver: derive ticket/project from the branch name (`arniwesth/mot-96-…` → `mot-96`), fill
  the template, `gh pr create --body-file`, then **write the returned number back** and finalize
  the directory at `.agent/github/prs/<alias>-<n>/body.md`.

*Done when:* running it on a throwaway branch against `origin` creates a PR whose body has all
five sections populated, leaves `body.md` in the right directory with the number in frontmatter,
and — run a second time on the same branch — **adopts the existing PR rather than creating a
second one** (the ADR's D4 crash-safety requirement; this is the acceptance test that matters
most). Delete the throwaway PR afterwards.

## Scope fence

**IN:** WI-0 (operator; see below), WI-1, WI-2, and the `.gitignore` entry for
`.agent/github/cache/` **only if** you find yourself creating the directory — otherwise it belongs
to WI-3.

**OUT:** the sync, the state writer, `state.yaml` in any form, backfill, the loop skill, issue or
CI ingestion, and any code-graph indexing of the new tree. If you find yourself writing a state
record, you have left this cluster.

**WI-0 is not yours.** The operator must create the machine account (email, 2FA), invite it as a
collaborator on `origin`, and mint a classic PAT with `public_repo`. Nothing beyond Commit 1 can
be verified without it. If it is not done when you start, build Commit 1, then **stop and say so**
rather than testing against the operator's own credentials — doing that would prove nothing about
the identity split and would create PRs under the wrong account.

## Stop and report — do not decide these inline

1. **Anything the ADR calls a decision.** The layout, keying, the invariant pair, artifact = source
   of truth, machine user over App: settled. If you believe one is wrong, record it and stop; do
   not diverge silently.
2. **The bot cannot be made to work upstream.** D1 rests on a user account having ambient public
   participation rights on `sunholo-voight-kampff/motoko_agent`. You will not exercise upstream
   posting in this cluster, but if you discover the premise is false, that is an ADR-level finding
   — the App upgrade path exists precisely for this.
3. **How this tree gets tested.** There is no test harness for `tools/` or `.agent/tools/`. Do not
   invent a framework as a side effect of WI-2. Ship the manual acceptance checks above, and report
   what a real check would need — that is input to WI-3, where correctness starts to matter
   (idempotent upsert, never mutating a judgment).
4. **Frontmatter fields.** The schema is provisional pending 008 fork 2. Use the minimum that makes
   the write-back work; do not design a schema.

## Calibration ask

Report back, in the commit messages or a short note: **actual time per commit**, **files touched**,
and **the ratio of sites needing judgement versus mechanical edit**. Every estimate past this
cluster is currently analogy, and WI-3's shape should be decided from these numbers.

## Acceptance criteria

- `gh --version` works in a rebuilt container; both devcontainer variants unaffected otherwise.
- `gh api user --jq .login` reports the **operator** for ordinary use and the **bot** for pipeline
  invocation, in the same container, with no shell-profile export of `GH_TOKEN`.
- A driver-created PR exists with all five template sections populated, `body.md` at
  `.agent/github/prs/<alias>-<n>/`, and the PR number in its frontmatter.
- Re-running the driver on the same branch adopts the existing PR; it does not create a second one.
- `.github/PULL_REQUEST_TEMPLATE.md` exists and matches the driver template's sections.
- Three independently-revertible commits; nothing from WI-3+ present in the tree.
