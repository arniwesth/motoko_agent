# Handoff: verify the herdr agent-state reporter against a running server, and close D3's second path

Date: 2026-08-22
From: the session that authored `ADR-001-herdr-agent-integration.md` and wrote the reporter
For: a fresh session working against HEAD
Deliverable: the ADR's five owed measurements taken and recorded; D3's known limitation either fixed
or formally accepted; the ADR's *"What is asserted rather than measured"* section replaced by
evidence — with Linear issues tracking each.

**The code is written, tested and shipped. None of it has met a running herdr server.** The unit
tests cover the mapping, the environment detection, the argv herdr will receive, sequence
monotonicity and release idempotence — everything except the part where herdr answers. That is the
gap this handoff closes, and the ADR says so in its own words.

## Your task

1. **Take the five measurements** in the ADR's *"What is asserted rather than measured"* list, inside
   `agent_confined`, and record them.
2. **Settle D3's second path** — a known, recorded limitation where the blocked state does not
   survive (below).
3. **Update the ADR in place**: replace the asserted-not-measured section with what was observed,
   and add a Corrections section if any decision turns out wrong. Follow
   `../016_github_ops/ADR-001-github-pr-ops-pipeline.md`'s Corrections convention — factual errors
   fixed in place, with the correction recorded.

## Read first, in order

1. **`ADR-001-herdr-agent-integration.md`** — the spec and the list you are closing. Load-bearing:
   **D2** (transitions reported from one place), **D3** (the `error` → `blocked` judgment call *and*
   its limitation), **D4** (inert outside herdr, non-blocking, bounded), **D7** (the compile-time
   contract).
2. **`src/tui/src/herdr-agent-state.ts`** — the reporter. Every non-obvious line has its reason
   above it.
3. **`src/tui/src/herdr-agent-state.test.ts`** — 11 cases, and the boundary of what they can prove.
4. **`.devcontainer/agent_confined/README.md`** — how to get a pane to measure in.

## The measurement that matters most

Item 2: **`herdr agent explain <target>` must confirm that screen detection was *skipped* for the
pane.** This is the one that distinguishes "it works" from "it looks like it works". A report herdr
ignores and a report herdr honours produce an identical-looking sidebar row, right up until the
screen manifest disagrees with the reporter. `explain` names the manifest source, whether a
lifecycle authority took over, and the matched rule — so it is the instrument, and item 2 is not
satisfied by seeing a row appear.

Items 4 and 5 need their own care: item 4 (the release fires on each of Motoko's several
`process.exit` paths) means exercising more than one exit, and item 5 (`HERDR_BIN_PATH` is injected
through `make run` → `scripts/run-agent.sh` → `bun`) is one `env` check in a pane that nobody has
actually run.

## D3's second path — the known limitation

Recorded in the ADR and not yet fixed. `error` maps to herdr's `blocked`, which is right for the
in-band `error` event: `AgentUI.handleEvent`'s `case "error"` sets the state, marks `taskDone`, and
nothing re-idles it, so the row stays blocked until the user acts.

It is defeated on the **runtime-exit recovery path**: `index.ts`'s `errorOccurred` branch calls
`ui.setAwaitingTask(true)`, which calls `setRunState("idle")`, superseding the blocked report —
possibly within the same second. The sidebar then shows the state the ADR rejected `idle` for
showing.

Three ways out, and the ADR deliberately did not choose:

- **Accept it**, and rely on herdr rendering an unfocused idle row as `done` — a weaker but non-silent
  signal. Cheapest; record it as a consequence.
- **Make the reporter sticky for `blocked`** — refuse to downgrade to `idle` without an intervening
  `working`. Rejected in the ADR as lying about Motoko's readiness for input; re-litigate only with
  a measurement showing the lie is harmless.
- **Change Motoko's recovery semantics** so a crashed run does not present as ready. That is a
  product decision beyond this record, and it belongs to whoever owns the TUI's error handling.

Measure how long the blocked row actually survives on that path before choosing. If it is visible
for several seconds in practice, "accept it" is defensible; if it flashes, it is not.

## Two follow-ons the ADR names but does not schedule

- **The duplicated herdr-environment detection.** `readHerdrEnvironment` is TypeScript in the TUI
  host; `../021_herdr_delegation/` needs the same three-variable gate in **AILANG**, inside an
  extension process. The rule cannot be shared across that boundary, only restated, and nothing
  links the copies. If 021 lands, add a pointer in both directions.
- **`pane report-metadata`.** The reporter uses semantic state only. Display tokens could put the
  step count or context percentage in the sidebar row. Not scheduled, possibly not wanted — it adds
  a second thing to keep in step with the TUI's own status line, which D2 exists to avoid.

## Linear issues — create these as part of the handoff

The `linear` MCP server is configured in `.mcp.json`; if its tools are absent, say so and stop.

- **Confirm the team first.** Branch names (`arniwesth/mot-<n>-<slug>`) show a Linear team with
  prefix **MOT** in use. Confirm by listing teams; ask the operator if it is ambiguous.
- **Attribution:** issues read as the API key's owner until `../022_linear_integration/` F-1 is
  answered. Mention once; do not solve.
- **Issues to create:** one for the five measurements (a single issue is fine — they are one sitting
  in one pane), one for D3's second path, and one each for the two follow-ons above marked as
  candidates rather than committed work.
- Each links to this handoff and to the ADR by path. Record identifiers in the ADR.

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
   `arniwesth/mot-<n>-verify-herdr-agent-state`. The issue id inside the branch name is what makes Linear
   attach the branch and, later, the PR; do not hand-roll a name without it.
3. **Base the branch** on the commit identified in the prerequisite above.
4. **Open the PR with `make pr`.** That is 016's pipeline and it publishes as **`motoko-agent`**,
   which is the point — anything a mechanism emits is the bot. `make pr_draft` stages a body first;
   `PR_FLAGS=--as-operator` exists but is not what you want here.
5. **Reference the issue in the PR body** so the link survives even if the branch is renamed, and
   put the PR number back on the Linear issue.

Keep the three handoffs' branches independent: they touch different trees (the 020 ADR and, if D3
changes, `src/tui/src/herdr-agent-state.ts`) and should not depend on each other's review.

## Scope fence

- **Do not add reporting call sites.** D2 is that transitions come from `setRunState` and nowhere
  else; the initial `idle` and the session path are deliberate exceptions and are already there.
- **Do not change the `error` → `blocked` mapping** without an owner decision — D3 was approved.
- **Do not make the reporter blocking, retrying or supervised.** D4's three properties are
  requirements: it sits on the TUI's hot path, and a slow or throwing reporter costs a user their
  session over a sidebar update.
- **Do not add an `on_model_call`-style hook or touch the AILANG core.** D2 rejected routing this
  through the DST vocabulary for stated reasons.

## Stop and report — do not decide these inline

- **`herdr agent explain` shows screen detection was NOT skipped.** That means lifecycle authority
  was never granted and the row is coincidence. It invalidates D1's central claim; report rather
  than patching around it.
- **The release does not fire on some exit path**, leaving a ghost row. Note it; a heartbeat is
  explicitly rejected in the ADR as too much machinery for a cosmetic failure.
- **Anything suggesting Motoko should report `done`.** It cannot: `done` is herdr's *presentation*
  of an unfocused idle row, not a reportable state.

## Acceptance criteria

1. All five measurements are recorded in the ADR with what was observed, including item 2's
   `explain` output showing screen detection skipped for the pane.
2. D3's second path is either fixed or accepted **with a measured duration** behind the choice.
3. The ADR's *"What is asserted rather than measured"* section is gone, replaced by evidence; any
   decision the measurements contradict is corrected in place with a Corrections entry.
4. `bun run build` (tsc) passes and the herdr-agent-state tests are green; if behaviour changed,
   the test count went up.
5. Linear issues exist and their identifiers are in the ADR.
6. A `motoko` row is visible in `herdr agent list` alongside any delegate panes — the picture both
   this project and 019 were aiming at.
7. Every commit on the branch is authored `motoko-agent` (`git log --format='%an <%ae>'`), and
   the PR is opened by the bot.
