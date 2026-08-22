# Handoff: formalize `agent_confined` — write the record, run the acceptance sweep, close the residuals

Date: 2026-08-22
From: the session that built `.devcontainer/agent_confined/`
For: a fresh session working against HEAD
Deliverable: an **ADR** stating this profile's decisions as decisions; a **recorded R9 + R7
acceptance run** from a host shell; and the five residuals below either closed or explicitly
deferred with a reason — with Linear issues tracking each.

**The unusual shape of this project: the implementation exists and runs; the record does not.**
`.devcontainer/agent_confined/` is complete and in daily use — it builds, herdr runs, panes work,
`gh` acts as `motoko-agent`. But this project directory is **empty**. Every "why" currently lives in
two places that were never meant to carry it alone: comments at the point of decision in
`Dockerfile`/`docker-compose.yml`, and a long chronological `HISTORY.md`. Neither states a decision
*as a decision*, with its alternatives and its consequences. That is what you are writing.

**Do not go looking for a source record.** This profile was adapted from a confined-agent container
built for a different project. That material was deliberately removed from this repository and must
not be reintroduced, cited, or named — not in the ADR, not in commit messages. Every decision has to
stand on its own merits, and all of them can: the reasoning is in the code comments and in
`HISTORY.md`, and where it is thin, that is a finding to record rather than a gap to paper over.

## Your task

1. **Write `ADR-001-confined-agent-container.md`** in this directory. Structure per this repo's
   convention (see `../016_github_ops/ADR-001-github-pr-ops-pipeline.md`): Date/Status/Grounded at,
   a grounding-verified block, Relates to, Context, Options considered, numbered Decisions,
   Consequences.
2. **Run the acceptance sweep and record it** — `agent.sh check` from a host shell, and the R7 audit
   with a recorded baseline. Neither has ever been run to completion.
3. **Close or defer the five residuals** in the list below.

## Read first, in order

1. **`.devcontainer/agent_confined/HISTORY.md`** — your primary source. It is chronological and
   already carries the measurements: the port, three build defects, the macOS/bash-3.2 floor, the
   `extra_hosts` correction, the identity decision, the browser attempt and its removal, the
   `agent-browser` replacement, the sidebar, and the font probe. Your job is to turn the *decisions*
   in it into D-numbers and leave the *measurements* where they are.
2. **`.devcontainer/agent_confined/README.md`** — the operator-facing view, including the absence
   table and *Known gaps*. The absence table is close to a decision list already.
3. **`Dockerfile`, `docker-compose.yml`, `agent.sh`** — every non-obvious line has its reason above
   it. The ADR should compress those, not duplicate them.
4. **`checks/r9-container.sh`** — the acceptance criteria, already executable.

## The decisions the ADR needs to state

Derived from what is actually in the tree; renumber as you see fit, but do not silently drop one.

- **No `devcontainer.json`, and the container is never attached.** The load-bearing decision. R9 leg
  1 asserts the file's absence. Measured motivation is in `HISTORY.md`: in the operator's container
  a `gho_`-shaped credential is *live*, not merely announced, plus five forwarded-socket variables.
- **No sudo in the final image**, purged and asserted at build time; every new tool is therefore an
  operator-side rebuild, which is why herdr, the CLIs and the toolchain are baked in.
- **No ssh, no docker socket, no host credential mounts.**
- **herdr as the session layer**, and what that buys over a bare `docker exec`.
- **The agent's GitHub identity is `motoko-agent`, by construction** — including the deliberate
  mapping of `GH_TOKEN` in this profile only, which is the *inverse* of the operator profile's rule
  and needs stating carefully or it reads as a mistake.
- **A curated environment, not `env_file`** — and why the opposite choice was correct for the
  operator's profile. `HISTORY.md` has the reasoning and the list of what a delegate would otherwise
  inherit.
- **Versions pinned in the tree** (`versions.env`), with `upgrade` as a separate verb from `build`.
- **Read-only mounts over `.devcontainer`, `.vscode`, `.git/hooks`**, and the `EROFS`-on-checkout
  consequence.
- **What is deliberately *not* absent** — the tree is mounted whole, so in-tree credentials and
  agent-writable git configuration remain reachable. This is the honest counterweight and the ADR is
  weaker without it.
- **All work now happens in this container** (operator decision, 2026-08-22). This is the decision
  the rest of the profile was building towards, and it has two consequences the ADR must state.
  First, **identity fully collapses onto `motoko-agent`**: with no work happening outside, every
  commit and every PR carries the bot's name. 016 already anticipated exactly this —
  `tools/pr/README.md:33`: *"because both halves now carry the bot's name, identity no longer tells
  you whether a human decided something — that has to come from the state record."* That sentence
  stops being a caveat and becomes load-bearing: `.agent/github/` is now the only place the
  human/mechanism distinction survives — along with GitHub's web UI, where the operator still acts
  as themselves. Second, **the operator's devcontainer is kept** (operator decision, same day) with
  its job narrowed to reading and reviewing: rendered markdown, diffs, VS Code's tooling. It is not
  a fallback working environment. The ADR should state the division of labour — the four-place table
  in `.devcontainer/agent_confined/README.md`'s *Operating rules* is the shape — and both of its
  costs: **committing from the devcontainer silently reintroduces the operator's name**, and keeping
  it keeps its exposure (passwordless sudo, the forwarded ssh-agent socket, a live `gho_` credential
  helper, on the same tree). That exposure is an accepted price for a usable editor, and it is
  exactly why the agent does not live there — which is worth stating as a decision rather than
  leaving as an accident of history.
- **The exception to "all work happens here", and it is not optional.** `.devcontainer/**` is
  mounted `:ro` into this container, so **the profile cannot be maintained from inside itself**.
  Every Dockerfile, compose or `agent.sh` edit — and `agent.sh build` itself — needs a host shell.
  That is by design (R9 asserts the `:ro` flag; an agent that can rewrite its own confinement has
  none), but it means the policy has a carve-out that belongs in the ADR rather than in folklore.
  The related trap: a `git checkout` between branches whose content differs under those paths fails
  part-way with `EROFS`.

## The residuals — close or defer, with a reason

1. **No R7 baseline has ever been recorded.** The audit runs clean, but a baseline must be recorded
   **only from a sanitised tree** — a baseline taken over a planted directive approves it. Decide
   where it lives (it must not be in the repo: it is the thing the repo is checked *against*) and
   record it. Note the three approved non-sample hooks in `deepseek-harness/.git/hooks`.
2. **`OBSIDIAN_MCP_TOKEN` is granted to a container that cannot reach the server.** The obsidian MCP
   is addressed by a hostname this profile does not define. The token buys delegates nothing.
   Remove it, or route the host and say why. **Note this one edit is host-side**: it changes
   `.devcontainer/agent_confined/docker-compose.yml`, which is `:ro` inside the container you are
   working in. Make it from a host shell and commit it there, or the write simply fails.
3. **`agent.sh check` has never passed end-to-end.** The host legs pass; the container legs have
   only ever been run in the *operator's* container, where they correctly fail. Run it properly and
   paste the output into the ADR's grounding block.
4. **The operator's own profile is unhardened** — passwordless sudo, forwarded sockets, the
   remote-containers credential helper. Now that it is **kept on purpose** as the reading and review
   environment, this stops being a transitional residual and becomes a standing one. The ADR should
   record it with the argument for and against, and note what would change if it were ever hardened
   (VS Code attach is the mechanism that forwards the credential, so hardening it mostly means
   giving up the editor — which is the thing it is being kept for). Do not fix it.
5. **Two owner decisions are open and are not yours**: whether to delete the untracked ~105 MB
   `code-graph/` directory, and whether to rewrite pushed git history. See *Stop and report*.

## Linear issues — create these as part of the handoff

The `linear` MCP server is configured in `.mcp.json`; if its tools are absent, say so and stop
rather than working around it.

- **Confirm the team first.** The repository's branch names — `arniwesth/mot-<n>-<slug>` — show a
  Linear team with prefix **MOT** already in use. Confirm by listing teams; **ask the operator** if
  more than one could be right. Do not create a team.
- **Attribution:** a Linear API key is personal, so issues read as the key's owner. F-1 in
  `../022_linear_integration/` is the open decision about giving Motoko its own Linear identity.
  Mention it once; do not solve it.
- **One issue per deliverable**: the ADR, the acceptance run, and one per residual 1–4. Residual 5's
  two items get issues too, marked as blocked on an operator decision.
- Each issue links to this handoff by path and names the acceptance criterion it satisfies. Record
  the identifiers back in the ADR so tree and tracker can be reconciled.

## Branch, PR and Linear linkage

**Prerequisite — the base must carry the implementation.** At the time this was written the whole of
that work was **uncommitted** in one working tree: `.devcontainer/agent_confined/`,
`src/tui/src/herdr-agent-state.{ts,test.ts}`, the edits to `src/tui/src/{ui,index}.ts`,
`.devcontainer/docker-compose.yml`, `.mcp.json`, `Makefile` and all five project directories. Three
branches cut from `main` would each be missing the thing they are about. So **check first**: if that
work is not yet on `main` or on a branch you can base from, stop and ask which commit to use as the
base rather than re-creating it. Do not vendor a copy into your branch.

**Everything GitHub-related is `motoko-agent`, and the cheapest way to guarantee that is where you
work.** Do this handoff **from inside `agent_confined`**, in a herdr pane — not from the operator's
devcontainer. In the confined container the identity is true by construction and needs no
discipline: `GH_TOKEN` is mapped from `MOTOKO_BOT_GH_TOKEN`, `credential.helper` delegates to `gh`,
and `git config user.name/user.email` are the bot, all baked into the image. In the operator's
devcontainer none of that holds — commits there are authored by the operator and `git push` uses
their own `gh auth`, so the same work would land under the wrong name with no warning.

Concretely, in this workstream: **commits are authored `motoko-agent`, the branch is pushed with the
bot's credential, and the PR is opened by `make pr`** (never `PR_FLAGS=--as-operator`, which exists
to act as the operator and is the one thing you must not reach for). Check before your first commit
with `git config user.name` — it must print `motoko-agent` — and after opening the PR with
`make pr_whoami PR_FLAGS=--as-bot`.

**One branch and one PR per handoff.** This handoff is one unit of work; land it as one reviewable
change, not three.

1. **Create the parent Linear issue first** — the one whose deliverable is this handoff. The
   per-deliverable issues above become its sub-issues.
2. **Take the branch name from Linear** (its "copy git branch name"). It matches the
   convention already in use here — `arniwesth/mot-<n>-<slug>`, e.g.
   `arniwesth/mot-<n>-formalize-agent-confined`. The issue id inside the branch name is what makes Linear
   attach the branch and, later, the PR; do not hand-roll a name without it.
3. **Base the branch** on the commit identified in the prerequisite above.
4. **Open the PR with `make pr`.** That is 016's pipeline and it publishes as **`motoko-agent`**,
   which is the point — anything a mechanism emits is the bot. `make pr_draft` stages a body first;
   `PR_FLAGS=--as-operator` exists but is not what you want here.
5. **Reference the issue in the PR body** so the link survives even if the branch is renamed, and
   put the PR number back on the Linear issue.

Keep the three handoffs' branches independent: they touch different trees
(`.agent/projects/019_agent_confined/` plus small fixes under `.devcontainer/agent_confined/`) and
should not
depend on each other's review.

## Scope fence

- **Do not change behaviour while writing the record.** If the ADR makes a decision look wrong, say
  so in Consequences and open an issue — do not fix it in the same pass. The one exception is
  residual 2, which is a one-line removal.
- **Do not harden or remove the operator's devcontainer.** Residual 4 and the "all work happens
  here" decision both make its future a live question; the ADR records the options and the operator
  chooses. Changing it is not this session's work.
- **Do not reintroduce the removed provenance material**, in any form.

## Stop and report — do not decide these inline

- **Deleting `code-graph/`** (untracked, ~105 MB, 22 files naming the removed project). It looks
  like a deletion candidate and two tracked documents call it "history/reference only", but it is
  the operator's data.
- **Rewriting git history.** The removed terms remain in roughly ten commits on **pushed** branches,
  across two remotes. Scrubbing means `git filter-repo` plus coordinated force-pushes, invalidating
  clones and PR refs — and `.agent/github/` keys off commit SHAs, so it would need reconciling.
  Present the options; do not run it.
- **Any change that would make the container attachable.**

## Acceptance criteria

1. `ADR-001-confined-agent-container.md` exists, states every decision above as a numbered decision
   with alternatives and consequences, and contains **no reference to the removed source material**.
2. Its grounding block contains a real, pasted `agent.sh check` run with the container-side legs
   attempted — not skipped, not exit-2.
3. An R7 baseline exists outside the repo, recorded from a sanitised tree, and `--verify` passes
   against it. The command and the location are documented in the ADR.
4. Residuals 1–4 are each closed or deferred **with a reason**; residual 5's two items are recorded
   as awaiting an operator decision.
5. Linear issues exist for each deliverable, and their identifiers are in the ADR.
6. `git status` shows no unintended changes under `.devcontainer/**`.
7. Every commit on the branch is authored `motoko-agent` (`git log --format='%an <%ae>'`), and
   the PR is opened by the bot — evidenced in the PR body or on the Linear issue.
