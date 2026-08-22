# Handoff: implement `motoko-ext-herdr` — measure first, then build the delegation extension

Date: 2026-08-22
From: the session that authored `RESEARCH-herdr-delegation-surface.md` and built the container it
runs in
For: a fresh session implementing against HEAD
Deliverable: **first**, the six measurements 021 §7 owes, recorded; **then**, if and only if they
hold, a `motoko-ext-herdr` package giving Motoko two tools that delegate a sub-task to a coding
agent running in a herdr pane — landed as independently-revertible commits, with Linear issues
tracking each.

**There is no PLAN for this project, by decision.** 021 is the spec. Where this handoff and 021
disagree, **021 wins**; where 021 is silent, the *Stop and report* list tells you whether to decide
or escalate.

**The one thing that has changed since 021 was written, and it changes the order of everything:**
021 F-1 asked *"does this get built at all before `agent_confined` has run a session?"* and answered
*"start the container, measure §7, then design."* **The container now runs.** It builds, herdr
starts, panes work, and `gh` authenticates as `motoko-agent`. So F-1 is closed in favour of
proceeding — and §7 is now executable rather than aspirational. Do it first. Every one of the six
can invalidate a design decision below.

## Your task, in two phases

**Phase A — measure.** Run 021 §7's six items inside `agent_confined` and write the results into a
new `MEASUREMENTS-2026-xx-xx.md` beside 021. This is not preamble; §7 item 2 (does `agent start
--kind codex|claude` detect in this image?) is fatal to the whole design if it fails, and item 5
(do delegates comply with "write your answer to `<path>`"?) decides whether §3.2's answer-file
channel is the primary path or an optimisation over a fallback that must exist anyway.

**Phase B — build**, only against measurements that held. The spine is below.

Do **not** build a Linear extension (that is 022), and do **not** touch
`packages/motoko-ext-agentcli` (see *Scope fence*).

## Read first, in order

1. **`RESEARCH-herdr-delegation-surface.md`** — your spec. Load-bearing: **§3.1** (the 30 s wall and
   the precise `#158` escape condition), **§3.2** (the answer-file channel — the strongest idea in
   the document), **§4.1** (the two-tool surface), **§4.4** (conditional registration), **§5**
   (what is new and worse), **§6** (the forks you must not close yourself).
2. **`../018_agentcli_delegation/RESEARCH-agentcli-delegation-surface.md`** — the parent. Its **§2 is
   still binding**: dispatch by tool name not an enum (§2.1), no dollar figures (§2.3), no
   `on_model_call` seam (§2.7). Its §3 findings are the axis 021 is organised along.
3. **`packages/motoko-ext-exa-search/`** — the *shape* to copy. Four small modules, one of which is
   pure config. Read `types.ail` first; it is 45 lines and shows the whole pattern.
4. **`.devcontainer/agent_confined/README.md`** — how to get a container to measure in. You need
   `agent.sh build` then `agent.sh`; everything in Phase A happens in a pane.

Do not read `packages/motoko-ext-mcp/mcp.ail` expecting a working client — it is a dormant stub, and
mistaking it for the live one has already cost one session a wrong conclusion (022 §1).

## Current grounding (re-verified at HEAD `d992d73`, 2026-08-22)

Re-check each before editing; if any has moved, re-measure rather than trusting this list.

- **`agent_confined` runs.** herdr 0.8.2, `claude`, `codex`, `omp`, `agent-browser` and the
  `herdr-sidebar` plugin are baked in; `GH_TOKEN` is mapped from `MOTOKO_BOT_GH_TOKEN` so everything
  GitHub-shaped acts as `motoko-agent`. `agent.sh check` is the health gate.
- **`std/process.exec` takes no env parameter** and `--process-timeout` defaults to **30 s**, which
  the TUI never overrides (`grep -rn 'process-timeout' src/tui/src/` — no hits). This is the wall
  §3.1 routes around by never making a long call.
- **`#158` is still open.** `shell_tokens_in_process` fires on shell tokens in `req.cmd` *or any
  element of `req.args`*, and separately whenever `req.cwd` is `Some`; the wrap then rebuilds from
  `req.cmd` alone and **drops `req.args`**. §3.1 states the exact conditions under which a herdr
  design avoids it. Verify before relying on `ExtPorts.proc_exec`.
- **`provided_tools` is computed, not literal** (`packages/motoko-ext-agentcli/agentcli.ail:222`
  builds it from config), and `register_with_config` runs with `{Env, FS, IO, Process}` — which is
  what makes §4.4's conditional registration possible.
- **`agentcli` is enabled in exactly one profile** (`.motoko/config/default/config.json`), so a new
  package can coexist per-profile without a switch.

## The rule you will break by accident

**Do not let the extension advertise tools it cannot honour.** §4.4 exists because the failure mode
is quiet: outside a herdr pane every `herdr` call fails, and a tool that is offered and then errors
costs the model a turn and teaches it nothing. Read `HERDR_ENV`/`HERDR_BIN_PATH` in
`register_with_config` and return **empty `provided_tools`** when they are absent. The devcontainer
you are probably reading this in is exactly that case.

The second-order version: **do not test only inside a pane.** A run in the operator's devcontainer
must load the extension and offer nothing, silently. That is a test worth writing.

## The spine — four commits

Each is independently revertible and ends in a state you can demonstrate.

1. **`MEASUREMENTS-*.md`** — Phase A. No code. Ends with six answers and an explicit note against
   any that could not be taken and why.
2. **The package skeleton, inert.** `types.ail` (config + tool mappings), `register.ail`
   (env resolution + the `HERDR_ENV` gate), `herdr.ail` (hooks with `on_tool_handle` delegating),
   `ailang.toml`/`ailang.lock`. Ends green with `provided_tools` empty outside herdr and populated
   inside, and inline `tests [...]` on every pure function (018 F8 is an obligation, not a
   suggestion — `argv_for`, the name generator, the error decoder and the answer-file resolver are
   all pure).
3. **`Delegate` — the optimistic-synchronous path.** split → `agent start` → `agent prompt --wait`
   bounded under 25 s → read the answer file. Returns the answer, or a handle plus
   `status: working`. **Two error vocabularies must be decoded here** (§5.4): `ProcessError`'s seven
   constructors *and* herdr's JSON errors (`agent_not_ready`, `agent_blocked`,
   `agent_prompt_stalled`, `agent_not_running`, `timeout`). 018 F1's second defect — collapsing all
   of them into one PATH-flavoured sentence — must not be reproduced.
4. **`DelegateCheck`** — `agent get` for state plus the answer file if it has landed, and whatever
   F-5's answer requires for orphans.

Wire the package into root `ailang.toml` and enable it in **one** profile only.

## Linear issues — create these as part of the handoff

Track this work in Linear as well as in the tree. The `linear` MCP server is configured in
`.mcp.json`; if its tools are not present, say so and stop rather than working around it.

**Before creating anything:**

- **Confirm the team.** The repository's branch names — `arniwesth/mot-<n>-<slug>` throughout —
  show a Linear team with prefix **MOT** already in use, which is stronger evidence than 022 §6 F-5
  had when it recorded the team as unknown. Confirm it by listing teams, and **ask the operator** if
  more than one could plausibly be right. Do not create a team.
- **Know whose name goes on them.** A Linear API key is personal, so issues will be attributed to
  the key's owner. 022 §4 (F-1) is the open decision about whether Motoko should have its own Linear
  identity; until it is answered, everything you file reads as the operator. Mention this once in
  your report — do not solve it here.

**Create one issue per spine commit**, plus one per Phase A measurement that turns out to need real
work. Each issue must carry:

- a title naming the deliverable, not the activity (*"Delegate tool: optimistic-synchronous path"*,
  not *"work on delegation"*);
- a description that **links to this handoff and to 021 by path**, and states the acceptance
  criterion from the list below that it satisfies;
- the blocking relationship: the four spine issues are sequential, and **all of them block on the
  measurement issue**. If the measurements invalidate a design decision, the affected issue should
  be updated or cancelled rather than quietly reinterpreted.

Put the issue identifiers back into the handoff or the measurements doc, so the tree and Linear can
be reconciled later without guesswork.

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
   `arniwesth/mot-<n>-motoko-ext-herdr`. The issue id inside the branch name is what makes Linear
   attach the branch and, later, the PR; do not hand-roll a name without it.
3. **Base the branch** on the commit identified in the prerequisite above.
4. **Open the PR with `make pr`.** That is 016's pipeline and it publishes as **`motoko-agent`**,
   which is the point — anything a mechanism emits is the bot. `make pr_draft` stages a body first;
   `PR_FLAGS=--as-operator` exists but is not what you want here.
5. **Reference the issue in the PR body** so the link survives even if the branch is renamed, and
   put the PR number back on the Linear issue.

Keep the three handoffs' branches independent: they touch different trees (a new `packages/motoko-
ext-herdr/` plus 021's measurements doc) and should not depend on each other's review.

## Scope fence

- **Do not modify `packages/motoko-ext-agentcli`.** It works where herdr is absent, which includes
  the operator's devcontainer. §4.5 decided coexistence; F-3 asks what happens *eventually*, and
  that is not this session's call.
- **Do not add an ABI slot.** §4.3: `on_tool_handle` is sufficient, and 017 prices a new slot at 16
  packages.
- **Do not close F-2, F-4, F-5 or F-6 by implementation.** Where you need a behaviour to proceed,
  pick the narrowest one that works, and say in the commit message that you did so.
- **Do not enable the package in more than one profile.**
- **Do not build a Linear extension.** 022 is a separate project with its own open identity fork.

## Stop and report — do not decide these inline

- **§7 item 2 fails** (herdr cannot detect `codex`/`claude` in this image). This is fatal to the
  design as written; report rather than working around it with `pane run` and screen-scraping.
- **§7 item 1 shows `--env KEY=` does not defeat the CLIs' key preference.** That is 018 F2's
  billing guard failing, and it is the owner's call whether delegation proceeds without it.
- **F-4, the permission bypass.** 018 §2.6 has it on because nothing could answer an approval
  prompt; a herdr pane can. Tempting to flip. It is the owner's decision, recorded in 018.
- **An orphan-sweep design that kills panes you did not create.** §5.1 is a real new failure mode;
  a sweep with a wrong ownership rule is worse than the leak.
- **Anything that wants `--yes`, `--dangerously-*` or a credential written to disk.**

## Calibration ask

021 §7 item 6 is still unmeasured and everything's timeout budget rests on it. Report, from real
runs: median and worst-case wall-clock for a delegated task, the size of the answer file, and how
often `agent prompt --wait` returns `agent_prompt_stalled` at a 25 s bound. If the median exceeds
the bound, §4.1's "optimistic-synchronous" default is wrong and should become poll-first.

## Acceptance criteria

1. `MEASUREMENTS-*.md` exists and answers all six of 021 §7, or says explicitly why one could not be
   taken.
2. In the operator's devcontainer: the extension loads and advertises **no tools**. Demonstrated.
3. In an `agent_confined` pane: `Delegate` starts a `codex` (or `claude`) delegate, and its answer
   reaches the model — through the answer file if §7 item 5 held, through `agent read
   --source recent-unwrapped` if it did not.
4. A delegate that outlives its `Delegate` call is discoverable via `DelegateCheck`, and its state
   comes from `herdr agent get` rather than from a lock file.
5. Every pure function carries inline `tests [...]`; `make test` (or the package's own target) is
   green.
6. An error from each vocabulary — one `ProcessError`, one herdr JSON error — produces a distinct,
   accurate message. Demonstrate both.
7. Linear issues exist for the spine, correctly blocked, and their identifiers are recorded in the
   tree.
8. `agent.sh check` still passes, and `git status` shows no unintended changes under
   `.devcontainer/**` (it is mounted read-only in the agent's container for exactly this reason).
9. Every commit on the branch is authored `motoko-agent` (`git log --format='%an <%ae>'`), and
   the PR is opened by the bot.
